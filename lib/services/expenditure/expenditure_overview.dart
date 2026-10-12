// Pure summary + alerts for the Expenditure hub — no I/O.
import '../../core/utils/money.dart';
import '../../models/debt_model.dart';
import '../../models/expense_model.dart';
import '../../models/expense_priority.dart';
import '../../models/recurring_expense_model.dart';
import '../../models/savings_goal_model.dart';
import 'goal_math.dart';
import 'recurring_schedule.dart';
import 'safe_to_spend.dart';

enum BudgetBadge { healthy, warning, over }

enum AlertLevel { info, warning, danger }

/// Where tapping an alert should take the user.
enum AlertTarget { budgets, plan, recurring, goals, debts, settings }

class ExpenditureAlert {
  final AlertLevel level;
  final String title;
  final String detail;
  final AlertTarget target;
  const ExpenditureAlert(this.level, this.title, this.detail, this.target);
}

class UpcomingBill {
  final RecurringExpense item;
  final DateTime dueOn;
  const UpcomingBill(this.item, this.dueOn);
}

class ExpenditureOverview {
  final DateTime month;
  final double monthSpend;

  /// This month's spend in categories that have a budget.
  final double budgetedSpend;
  final double totalBudget;
  final BudgetBadge? badge;
  final SafeToSpend? safeToSpend;
  final List<UpcomingBill> upcomingBills;
  final List<MapEntry<String, double>> cutSuggestions;
  final Map<String, double> prioritySplit;
  final List<ExpenditureAlert> alerts;

  const ExpenditureOverview({
    required this.month,
    required this.monthSpend,
    required this.budgetedSpend,
    required this.totalBudget,
    required this.badge,
    required this.safeToSpend,
    required this.upcomingBills,
    required this.cutSuggestions,
    required this.prioritySplit,
    required this.alerts,
  });

  double get budgetRatio => totalBudget <= 0 ? 0 : budgetedSpend / totalBudget;
  double get remainingBudget => totalBudget - budgetedSpend;
}

BudgetBadge? budgetBadgeFor(double spent, double budget) {
  if (budget <= 0) return null;
  final r = spent / budget;
  if (r > 1.0) return BudgetBadge.over;
  if (r >= 0.85) return BudgetBadge.warning;
  return BudgetBadge.healthy;
}

ExpenditureOverview buildExpenditureOverview({
  required List<ExpenseModel> expenses,
  required Map<String, double> budgetLimits,
  required List<RecurringExpense> recurring,
  required List<SavingsGoal> goals,
  required List<Debt> debts,
  required double? monthlyIncome,
  required DateTime now,
  double upcomingSeettu = 0,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final month = DateTime(today.year, today.month);
  final thisMonth = expenses
      .where((e) => e.effectiveDate.year == month.year && e.effectiveDate.month == month.month)
      .toList();

  final monthSpend = thisMonth.fold(0.0, (s, e) => s + e.amount);
  final totalBudget = budgetLimits.values.fold(0.0, (s, v) => s + v);

  final byCategory = <String, double>{};
  final split = {for (final p in ExpensePriority.values) p: 0.0};
  final flexibleByCategory = <String, double>{};
  for (final e in thisMonth) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    split[e.priority] = (split[e.priority] ?? 0) + e.amount;
    if (e.priority == ExpensePriority.flexible) {
      flexibleByCategory[e.category] = (flexibleByCategory[e.category] ?? 0) + e.amount;
    }
  }

  final budgetedSpend =
      budgetLimits.keys.fold(0.0, (s, c) => s + (byCategory[c] ?? 0));

  final safe = computeSafeToSpend(
    monthlyIncome: monthlyIncome,
    expenses: expenses,
    recurring: recurring,
    goals: goals,
    debts: debts,
    now: now,
    upcomingSeettu: upcomingSeettu,
  );

  final bills = <UpcomingBill>[];
  for (final r in recurring) {
    if (r.priority != ExpensePriority.essential) continue;
    for (final d in occurrencesBetween(r, today, today.add(const Duration(days: 14)))) {
      bills.add(UpcomingBill(r, d));
    }
  }
  bills.sort((a, b) => a.dueOn.compareTo(b.dueOn));

  final alerts = <ExpenditureAlert>[];

  // Budgets past 80% / 100%.
  final overBudget = <String>[];
  budgetLimits.forEach((category, limit) {
    if (limit <= 0) return;
    final spent = byCategory[category] ?? 0;
    final ratio = spent / limit;
    if (ratio >= 1.0) {
      overBudget.add(category);
      alerts.add(ExpenditureAlert(AlertLevel.danger, '$category is over budget',
          '${formatRs(spent)} of ${formatRs(limit)} (${(ratio * 100).round()}%)', AlertTarget.budgets));
    } else if (ratio >= 0.8) {
      alerts.add(ExpenditureAlert(AlertLevel.warning, '$category at ${(ratio * 100).round()}% of budget',
          '${formatRs(limit - spent)} left this month', AlertTarget.budgets));
    }
  });

  // Where to cut: the largest flexible categories, when money is tight.
  final cuts = flexibleByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final needCuts = (safe?.isLow ?? false) || overBudget.isNotEmpty;
  final cutSuggestions = needCuts ? cuts.take(3).toList() : <MapEntry<String, double>>[];
  if (safe != null && safe.leftToSpend < 0) {
    alerts.add(ExpenditureAlert(
      AlertLevel.danger,
      'Spending is ${formatRs(-safe.leftToSpend)} over safe-to-spend',
      cutSuggestions.isEmpty
          ? 'Hold off on non-essential purchases until next month.'
          : 'Cut back on ${cutSuggestions.map((e) => e.key).join(', ')} first.',
      AlertTarget.plan,
    ));
  } else if (safe != null && safe.isLow) {
    alerts.add(ExpenditureAlert(
      AlertLevel.warning,
      'Only ${formatRs(safe.leftToSpend)} left to spend this month',
      cutSuggestions.isEmpty
          ? 'Keep non-essential spending light.'
          : 'Cut back on ${cutSuggestions.map((e) => e.key).join(', ')} first.',
      AlertTarget.plan,
    ));
  }

  // Bills in the next 14 days.
  if (bills.isNotEmpty) {
    final total = bills.fold(0.0, (s, b) => s + b.item.amount);
    final next = bills.first;
    final days = next.dueOn.difference(today).inDays;
    alerts.add(ExpenditureAlert(
      AlertLevel.info,
      '${bills.length} bill${bills.length == 1 ? '' : 's'} due in the next 14 days (${formatRs(total)})',
      'Next: ${next.item.note?.isNotEmpty == true ? next.item.note : next.item.category} '
          '${days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}'}',
      AlertTarget.recurring,
    ));
  }

  // Debts overdue or due within 7 days.
  for (final d in debts) {
    if (!d.isDueWithin(today, 7)) continue;
    final days = d.dueDate!.difference(today).inDays;
    final overdue = days < 0;
    alerts.add(ExpenditureAlert(
      overdue ? AlertLevel.danger : AlertLevel.warning,
      d.isLent
          ? '${d.personName} owes you ${formatRs(d.outstanding)}'
          : 'You owe ${d.personName} ${formatRs(d.outstanding)}',
      overdue ? 'Overdue by ${-days} day${days == -1 ? '' : 's'}' : (days == 0 ? 'Due today' : 'Due in $days day${days == 1 ? '' : 's'}'),
      AlertTarget.debts,
    ));
  }

  // Goals behind schedule.
  for (final g in goals) {
    if (g.status != SavingsGoal.active || g.deadline == null) continue;
    final p = computeGoalProgress(g, now);
    if (p.isOnTrack) continue;
    final pct = ((p.projectedShareAtDeadline ?? p.share) * 100).clamp(0, 999).round();
    alerts.add(ExpenditureAlert(
      AlertLevel.warning,
      '"${g.name}" is behind schedule',
      'At this rate you\'ll reach $pct% by ${shortDate(g.deadline!)}',
      AlertTarget.goals,
    ));
  }

  if (monthlyIncome == null || monthlyIncome <= 0) {
    alerts.add(const ExpenditureAlert(AlertLevel.info, 'Set your monthly income',
        'Unlocks safe-to-spend for this month', AlertTarget.settings));
  }

  alerts.sort((a, b) => b.level.index.compareTo(a.level.index));

  return ExpenditureOverview(
    month: month,
    monthSpend: monthSpend,
    budgetedSpend: budgetedSpend,
    totalBudget: totalBudget,
    badge: budgetBadgeFor(budgetedSpend, totalBudget),
    safeToSpend: safe,
    upcomingBills: bills,
    cutSuggestions: cutSuggestions,
    prioritySplit: split,
    alerts: alerts,
  );
}
