// lib/services/expense_forecast_service.dart
//
// Next-month spending forecast in pure Dart, so it runs identically on
// web, Android, iOS and desktop.
//
//   forecast = Σ categories [ weighted average of the last ≤3 complete
//              months of non-recurring spend (weights 0.5 / 0.3 / 0.2,
//              most recent first, renormalised when fewer months exist) ]
//            × seasonal bump (December / April, default +15%)
//            + recurring expenses that fall due next month
//
// Range: ± one standard deviation of past monthly totals (needs 3+
// months), otherwise ±15%. Confidence: Low (1 month), Medium (2), High (3+).
//
// This replaced the bundled LSTM (see ExpenditurePredictionService), which
// was trained on values around 7.9M–8.2M and can't produce valid personal
// forecasts — see ExpenseViewModel.kUseLstmForecast.

import 'dart:math' as math;

import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';
import 'expenditure/recurring_schedule.dart';

enum ForecastConfidence { low, medium, high }

class ExpenseForecast {
  /// First day of the month being forecast.
  final DateTime month;
  final double total;
  final double low;
  final double high;
  final Map<String, double> byCategory;
  final double recurringTotal;
  final ForecastConfidence confidence;

  /// Number of past months the average was built from.
  final int monthsUsed;

  /// True when the only data was the current, still-running month (scaled
  /// up to a full month).
  final bool usedPartialMonth;
  final bool seasonalBumpApplied;

  const ExpenseForecast({
    required this.month,
    required this.total,
    required this.low,
    required this.high,
    required this.byCategory,
    required this.recurringTotal,
    required this.confidence,
    required this.monthsUsed,
    required this.usedPartialMonth,
    required this.seasonalBumpApplied,
  });

  String get confidenceLabel => switch (confidence) {
        ForecastConfidence.low => 'Low',
        ForecastConfidence.medium => 'Medium',
        ForecastConfidence.high => 'High',
      };
}

class ExpenseForecastService {
  /// Weights for the most recent, second and third most recent month.
  static const List<double> monthWeights = [0.5, 0.3, 0.2];

  /// Months (1–12) that get a seasonal uplift, and how much.
  static const Set<int> seasonalMonths = {12, 4};
  static const double seasonalBump = 0.15;

  /// Range used when there are too few months for a standard deviation.
  static const double fallbackRange = 0.15;

  /// Returns null when there is nothing at all to forecast from.
  ExpenseForecast? forecastNextMonth({
    required List<ExpenseModel> expenses,
    required List<RecurringExpense> recurring,
    required DateTime now,
  }) {
    final currentMonth = DateTime(now.year, now.month);
    final target = DateTime(now.year, now.month + 1);
    final targetEnd = DateTime(target.year, target.month + 1, 0);

    // Non-recurring spend per month, per category.
    final perMonth = <DateTime, Map<String, double>>{};
    final totalsPerMonth = <DateTime, double>{};
    DateTime? firstMonth;
    for (final e in expenses) {
      final d = e.effectiveDate;
      final m = DateTime(d.year, d.month);
      if (m.isAfter(currentMonth)) continue; // future-dated, ignore
      firstMonth = firstMonth == null || m.isBefore(firstMonth) ? m : firstMonth;
      totalsPerMonth[m] = (totalsPerMonth[m] ?? 0) + e.amount;
      if (e.isRecurring) continue;
      final cats = perMonth.putIfAbsent(m, () => {});
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }

    // Recurring bills that fall due next month.
    final recurringByCategory = <String, double>{};
    for (final r in recurring) {
      final n = occurrencesBetween(r, target, targetEnd).length;
      if (n == 0) continue;
      recurringByCategory[r.category] = (recurringByCategory[r.category] ?? 0) + n * r.amount;
    }
    final recurringTotal = recurringByCategory.values.fold(0.0, (s, v) => s + v);

    if (firstMonth == null && recurringByCategory.isEmpty) return null;

    // History months: up to 3 complete months before the current one, not
    // earlier than the user's first logged month (empty months after that
    // count as genuine zero-spend months).
    final history = <DateTime>[];
    if (firstMonth != null) {
      for (var i = 1; i <= 3; i++) {
        final m = DateTime(currentMonth.year, currentMonth.month - i);
        if (m.isBefore(firstMonth)) break;
        history.add(m);
      }
    }

    final base = <String, double>{};
    var usedPartial = false;
    if (history.isNotEmpty) {
      final weights = monthWeights.sublist(0, history.length);
      final weightSum = weights.fold(0.0, (s, w) => s + w);
      for (var i = 0; i < history.length; i++) {
        final w = weights[i] / weightSum;
        perMonth[history[i]]?.forEach((cat, v) => base[cat] = (base[cat] ?? 0) + w * v);
      }
    } else if (perMonth[currentMonth] != null) {
      // Only this (unfinished) month so far: scale it to a full month.
      final daysIn = DateTime(now.year, now.month + 1, 0).day;
      final factor = daysIn / now.day;
      perMonth[currentMonth]!.forEach((cat, v) => base[cat] = v * factor);
      usedPartial = true;
    }

    final seasonal = seasonalMonths.contains(target.month);
    if (seasonal) {
      base.updateAll((_, v) => v * (1 + seasonalBump));
    }

    final byCategory = <String, double>{...base};
    recurringByCategory.forEach((cat, v) => byCategory[cat] = (byCategory[cat] ?? 0) + v);
    final total = byCategory.values.fold(0.0, (s, v) => s + v);

    // Spread from complete past months' totals (up to 12).
    final pastTotals = <double>[];
    if (firstMonth != null) {
      for (var i = 1; i <= 12; i++) {
        final m = DateTime(currentMonth.year, currentMonth.month - i);
        if (m.isBefore(firstMonth)) break;
        pastTotals.add(totalsPerMonth[m] ?? 0);
      }
    }
    final spread = pastTotals.length >= 3 ? _stdDev(pastTotals) : total * fallbackRange;

    final monthsUsed = history.isNotEmpty ? history.length : (usedPartial ? 1 : 0);
    final confidence = monthsUsed >= 3
        ? ForecastConfidence.high
        : monthsUsed == 2
            ? ForecastConfidence.medium
            : ForecastConfidence.low;

    return ExpenseForecast(
      month: target,
      total: total,
      low: math.max(0, total - spread),
      high: total + spread,
      byCategory: byCategory,
      recurringTotal: recurringTotal,
      confidence: confidence,
      monthsUsed: monthsUsed,
      usedPartialMonth: usedPartial,
      seasonalBumpApplied: seasonal,
    );
  }

  static double _stdDev(List<double> values) {
    final mean = values.fold(0.0, (s, v) => s + v) / values.length;
    final variance =
        values.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / values.length;
    return math.sqrt(variance);
  }
}
