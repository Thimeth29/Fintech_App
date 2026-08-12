import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import '../models/expense_model.dart';
import '../services/expense_service.dart';
import '../services/expenditure_prediction_service.dart';

class ExpenseViewModel extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  final ExpenditurePredictionService _predictionService =
      ExpenditurePredictionService();

  bool isLoading = false;
  String? errorMessage;
  List<ExpenseModel> expenses = [];

  bool isLoadingPrediction = false;
  double? predictedNextMonthTotal;
  String? predictionMessage;

  double get total => expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, double> get byCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  String get suggestedAction {
    if (expenses.isEmpty) {
      return 'Add your first expense to start seeing where your money goes.';
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final share = (top.value / total * 100).toStringAsFixed(0);
    return '"${top.key}" is your biggest spending category at $share% of '
        'total spend — consider setting a monthly cap for it.';
  }

  /// Total spend per calendar month, oldest first — the LSTM's expected
  /// input series (it was trained on a 3-month sliding window).
  List<MapEntry<DateTime, double>> get monthlyTotals {
    final map = <DateTime, double>{};
    for (final e in expenses) {
      final key = DateTime(e.createdAt.year, e.createdAt.month);
      map[key] = (map[key] ?? 0) + e.amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  Future<void> load(String userId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      expenses = await _service.fetchExpenses(userId);
    } catch (e) {
      errorMessage = 'Could not load expenses.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    // Fire-and-forget: doesn't block the expense list from rendering.
    unawaited(loadPrediction());
  }

  /// Runs the on-device LSTM (see ExpenditurePredictionService) on the
  /// last 3 calendar months of spending to forecast next month's total.
  /// Needs at least 3 months of history and the .tflite asset bundled
  /// (see ml/README.md); otherwise sets an explanatory message instead.
  Future<void> loadPrediction() async {
    final months = monthlyTotals;
    if (months.length < 3) {
      predictedNextMonthTotal = null;
      predictionMessage =
          'Log expenses across at least 3 different months to unlock a spending forecast.';
      notifyListeners();
      return;
    }

    isLoadingPrediction = true;
    predictionMessage = null;
    notifyListeners();

    try {
      final lastThree = months
          .sublist(months.length - 3)
          .map((e) => e.value)
          .toList();
      final prediction = await _predictionService.predictNextMonth(lastThree);
      if (prediction == null) {
        predictedNextMonthTotal = null;
        if (kIsWeb) {
          predictionMessage = 'Spending forecast runs on-device and isn\'t '
              'available in a web browser — try the app on Android, iOS, or desktop.';
        } else {
          predictionMessage = _predictionService.isAvailable
              ? "Couldn't generate a forecast this time."
              : 'Spending forecast model not bundled yet — see ml/README.md.';
        }
      } else {
        predictedNextMonthTotal = prediction;
      }
    } catch (_) {
      predictedNextMonthTotal = null;
      predictionMessage = "Couldn't generate a forecast this time.";
    } finally {
      isLoadingPrediction = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense({
    required String userId,
    required double amount,
    required String category,
    String? note,
  }) async {
    try {
      await _service.addExpense(
        ExpenseModel(userId: userId, amount: amount, category: category, note: note),
      );
      await load(userId);
      return true;
    } catch (e) {
      errorMessage = 'Could not save expense.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _predictionService.dispose();
    super.dispose();
  }
}
