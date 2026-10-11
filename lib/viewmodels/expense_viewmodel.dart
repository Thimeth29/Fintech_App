import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb, visibleForTesting;
import '../core/utils/money.dart';
import '../models/expense_model.dart';
import '../models/expense_priority.dart';
import '../models/recurring_expense_model.dart';
import '../services/expense_forecast_service.dart';
import '../services/expense_service.dart';
import '../services/expenditure_prediction_service.dart';

/// Spend vs limit for one category's budget this month.
class BudgetStatus {
  final String category;
  final double limit;
  final double spent;
  const BudgetStatus(this.category, this.limit, this.spent);

  double get ratio => limit <= 0 ? 0 : spent / limit;
  double get remaining => limit - spent;
  bool get isWarning => ratio >= 0.8 && ratio < 1.0;
  bool get isOver => ratio >= 1.0;
}

class ExpenseViewModel extends ChangeNotifier {
  /// The LSTM in ml/ was trained on values around 7.9M–8.2M (aggregate
  /// figures, not one person's month) and its .tflite was never bundled, so
  /// it can't give valid personal forecasts. It stays off until it is
  /// retrained on personal-scale data — see ml/README.md. When off, the
  /// statistical [ExpenseForecastService] feeds [predictedNextMonthTotal].
  static const bool kUseLstmForecast = false;

  /// How far back the expenditure screens load (current + 6 previous months).
  static const int historyMonths = 6;

  final ExpenseService _service = ExpenseService();
  final ExpenseForecastService _forecastService = ExpenseForecastService();
  ExpenditurePredictionService? _lstm;

  /// Clock, overridable in tests.
  DateTime Function() now = DateTime.now;

  String? _userId;
  bool get isLoggedIn => (_userId ?? '').isNotEmpty;
  String? get userId => _userId;

  bool isLoading = false;
  String? errorMessage;
  List<ExpenseModel> expenses = [];

  // Monthly category budget limits (current month)
  List<Map<String, dynamic>> budgets = [];
  List<RecurringExpense> recurring = [];

  /// Sum of every expense ever logged; loaded on demand for "All time".
  double? allTimeTotal;

  bool isLoadingPrediction = false;
  double? predictedNextMonthTotal;
  String? predictionMessage;
  ExpenseForecast? forecast;

  // List filters on the Plan screen.
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? filterCategory;
  String? filterPriority;

  /// Set when an add/edit pushes a category past 80% or 100% of its budget;
  /// the screen shows it once via [takeBudgetAlert].
  String? _pendingBudgetAlert;

  // ---------------------------------------------------------------------
  // Existing getters (kept for Home and FinBot)
  // ---------------------------------------------------------------------

  /// Sum of the loaded expenses (current + previous [historyMonths] months).
  double get total => expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, double> get byCategory => _byCategory(expenses);

  String get suggestedAction {
    if (expenses.isEmpty) {
      return 'Add your first expense to start seeing where your money goes.';
    }
    final over = budgetStatuses.where((b) => b.isOver).toList();
    if (over.isNotEmpty) {
      return '"${over.first.category}" is over its budget this month — '
          'pause flexible spending there until next month.';
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final share = (top.value / total * 100).toStringAsFixed(0);
    return '"${top.key}" is your biggest spending category at $share% of '
        'total spend — consider setting a monthly cap for it.';
  }

  /// Total spend per calendar month, oldest first
  List<MapEntry<DateTime, double>> get monthlyTotals {
    final map = <DateTime, double>{};
    for (final e in expenses) {
      final d = e.effectiveDate;
      final key = DateTime(d.year, d.month);
      map[key] = (map[key] ?? 0) + e.amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  // ---------------------------------------------------------------------
  // Month / filter helpers
  // ---------------------------------------------------------------------

  DateTime get currentMonth => DateTime(now().year, now().month);

  List<ExpenseModel> expensesInMonth(DateTime month) => expenses
      .where((e) => e.effectiveDate.year == month.year && e.effectiveDate.month == month.month)
      .toList();

  double spendInMonth(DateTime month) =>
      expensesInMonth(month).fold(0.0, (s, e) => s + e.amount);

  double get currentMonthSpend => spendInMonth(currentMonth);

  Map<String, double> byCategoryInMonth(DateTime month) => _byCategory(expensesInMonth(month));

  /// Spend per priority for [month], in essential/important/flexible order.
  Map<String, double> byPriorityInMonth(DateTime month) {
    final map = {for (final p in ExpensePriority.values) p: 0.0};
    for (final e in expensesInMonth(month)) {
      map[e.priority] = (map[e.priority] ?? 0) + e.amount;
    }
    return map;
  }

  /// Months that have data, newest first — always includes this month.
  List<DateTime> get availableMonths {
    final set = <DateTime>{currentMonth, ...monthlyTotals.map((e) => e.key)};
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Expenses of [selectedMonth] after category/priority filters, newest first.
  List<ExpenseModel> get filteredExpenses => expensesInMonth(selectedMonth)
      .where((e) => filterCategory == null || e.category == filterCategory)
      .where((e) => filterPriority == null || e.priority == filterPriority)
      .toList()
    ..sort((a, b) {
      final c = b.effectiveDate.compareTo(a.effectiveDate);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });

  /// [filteredExpenses] grouped by day, newest day first.
  List<MapEntry<DateTime, List<ExpenseModel>>> get filteredByDay {
    final map = <DateTime, List<ExpenseModel>>{};
    for (final e in filteredExpenses) {
      map.putIfAbsent(e.effectiveDate, () => []).add(e);
    }
    return map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  void setSelectedMonth(DateTime month) {
    selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void setFilters({String? category, String? priority}) {
    filterCategory = category;
    filterPriority = priority;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------------

  double get totalBudget =>
      budgets.fold(0.0, (s, b) => s + ((b['limit_amount'] as num?)?.toDouble() ?? 0));

  /// This month's spend in categories that have a budget — what the total
  /// budget is compared against (unbudgeted categories like rent would
  /// otherwise make every month look "over").
  double get budgetedSpend {
    final spent = byCategoryInMonth(currentMonth);
    return budgets.fold(0.0, (s, b) => s + (spent[b['category']] ?? 0));
  }

  double? budgetFor(String category) {
    for (final b in budgets) {
      if (b['category'] == category) return (b['limit_amount'] as num?)?.toDouble();
    }
    return null;
  }

  /// This month's budgets with spend, most-used first.
  List<BudgetStatus> get budgetStatuses {
    final spent = byCategoryInMonth(currentMonth);
    return [
      for (final b in budgets)
        BudgetStatus(
          b['category'] as String? ?? 'Other',
          (b['limit_amount'] as num?)?.toDouble() ?? 0,
          spent[b['category']] ?? 0,
        ),
    ]..sort((a, b) => b.ratio.compareTo(a.ratio));
  }

  /// Returns (and clears) the budget alert raised by the last add/edit.
  String? takeBudgetAlert() {
    final a = _pendingBudgetAlert;
    _pendingBudgetAlert = null;
    return a;
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  Future<void> load(String userId) async {
    _userId = userId;
    if (userId.isEmpty) {
      // Demo mode / logged out: never query Supabase with an empty id.
      expenses = [];
      budgets = [];
      recurring = [];
      errorMessage = null;
      isLoading = false;
      _refreshForecast();
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final today = now();
      try {
        recurring = await _service.fetchRecurring(userId);
        final generated = await _service.generateDueRecurring(recurring, today);
        if (generated > 0) recurring = await _service.fetchRecurring(userId);
      } catch (_) {
        // Recurring table not migrated yet, or offline — expenses still load.
        recurring = [];
      }
      expenses = await _service.fetchExpenses(
        userId,
        from: DateTime(today.year, today.month - historyMonths),
      );
      budgets = await _service.fetchBudgets(userId, monthKey(today));
    } catch (e) {
      errorMessage = 'Could not load expenses.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    unawaited(loadPrediction());
  }

  Future<void> loadAllTimeTotal() async {
    if (!isLoggedIn) return;
    try {
      allTimeTotal = await _service.fetchAllTimeTotal(_userId!);
      notifyListeners();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Forecast
  // ---------------------------------------------------------------------

  Future<void> loadPrediction() async {
    if (kUseLstmForecast) {
      await _loadLstmPrediction();
      return;
    }
    _refreshForecast();
    notifyListeners();
  }

  void _refreshForecast() {
    forecast = _forecastService.forecastNextMonth(
      expenses: expenses,
      recurring: recurring,
      now: now(),
    );
    predictedNextMonthTotal = forecast?.total;
    predictionMessage = forecast == null
        ? 'Log a few expenses to unlock a spending forecast.'
        : null;
  }

  /// The original on-device LSTM path, kept for when the model is retrained.
  Future<void> _loadLstmPrediction() async {
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
      _lstm ??= ExpenditurePredictionService();
      final lastThree = months.sublist(months.length - 3).map((e) => e.value).toList();
      final prediction = await _lstm!.predictNextMonth(lastThree);
      predictedNextMonthTotal = prediction;
      if (prediction == null) {
        predictionMessage = kIsWeb
            ? 'Spending forecast runs on-device and isn\'t available in a web browser.'
            : (_lstm!.isAvailable
                ? "Couldn't generate a forecast this time."
                : 'Spending forecast model not bundled yet — see ml/README.md.');
      }
    } catch (_) {
      predictedNextMonthTotal = null;
      predictionMessage = "Couldn't generate a forecast this time.";
    } finally {
      isLoadingPrediction = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Expense CRUD — updates local state instead of reloading everything
  // ---------------------------------------------------------------------

  Future<bool> addExpense({
    required String userId,
    required double amount,
    required String category,
    String? note,
    DateTime? expenseDate,
    String? priority,
  }) async {
    try {
      final before = _budgetLevels();
      final saved = await _service.addExpense(
        ExpenseModel(
          userId: userId,
          amount: amount,
          category: category,
          note: note,
          expenseDate: expenseDate ?? dateOnly(now()),
          priority: priority,
        ),
      );
      if (saved != null) {
        expenses = [saved, ...expenses];
        allTimeTotal = allTimeTotal == null ? null : allTimeTotal! + saved.amount;
        _raiseBudgetAlert(before, saved.category);
      }
      errorMessage = null;
      _refreshForecast();
      notifyListeners();
      return saved != null;
    } catch (e) {
      errorMessage = 'Could not save expense.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExpense(ExpenseModel updated) async {
    try {
      final before = _budgetLevels();
      final saved = await _service.updateExpense(updated);
      if (saved == null) return false;
      final old = expenses.firstWhere((e) => e.id == saved.id, orElse: () => saved);
      expenses = [for (final e in expenses) e.id == saved.id ? saved : e];
      if (allTimeTotal != null) allTimeTotal = allTimeTotal! - old.amount + saved.amount;
      _raiseBudgetAlert(before, saved.category);
      errorMessage = null;
      _refreshForecast();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not update expense.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense({required String userId, required String id}) async {
    try {
      await _service.deleteExpense(id);
      final removed = expenses.where((e) => e.id == id).toList();
      expenses = expenses.where((e) => e.id != id).toList();
      if (allTimeTotal != null && removed.isNotEmpty) {
        allTimeTotal = allTimeTotal! - removed.first.amount;
      }
      errorMessage = null;
      _refreshForecast();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not delete expense.';
      notifyListeners();
      return false;
    }
  }

  /// Re-inserts a just-deleted expense (Undo). It gets a new id.
  Future<bool> restoreExpense(ExpenseModel expense) async {
    try {
      final saved = await _service.addExpense(expense);
      if (saved == null) return false;
      expenses = [saved, ...expenses];
      if (allTimeTotal != null) allTimeTotal = allTimeTotal! + saved.amount;
      _refreshForecast();
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not restore expense.';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Budget CRUD
  // ---------------------------------------------------------------------

  Future<bool> upsertBudget({
    required String userId,
    required String category,
    required double limitAmount,
    required String monthYear,
  }) async {
    try {
      await _service.upsertBudget(
        userId: userId,
        category: category,
        limitAmount: limitAmount,
        monthYear: monthYear,
      );
      budgets = await _service.fetchBudgets(userId, monthYear);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not save budget.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBudget({required String category}) async {
    if (!isLoggedIn) return false;
    try {
      final key = monthKey(now());
      await _service.deleteBudget(userId: _userId!, category: category, monthYear: key);
      budgets = budgets.where((b) => b['category'] != category).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not remove budget.';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Recurring CRUD
  // ---------------------------------------------------------------------

  Future<bool> saveRecurring(RecurringExpense item) async {
    try {
      final saved = item.id == null
          ? await _service.addRecurring(item)
          : await _service.updateRecurring(item);
      if (saved == null) return false;
      recurring = [
        for (final r in recurring)
          if (r.id != saved.id) r,
        saved,
      ]..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      // A start date in the past creates its due occurrences right away.
      final generated = await _service.generateDueRecurring([saved], now());
      if (generated > 0 && isLoggedIn) {
        await load(_userId!);
        return true;
      }
      _refreshForecast();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not save recurring expense.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecurring(String id) async {
    try {
      await _service.deleteRecurring(id);
      recurring = recurring.where((r) => r.id != id).toList();
      _refreshForecast();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not delete recurring expense.';
      notifyListeners();
      return false;
    }
  }

  /// Puts the view model in a logged-in state with fixed data, without
  /// touching Supabase. For widget tests only.
  @visibleForTesting
  void seedForTest({
    required String userId,
    List<ExpenseModel> expenses = const [],
    List<Map<String, dynamic>> budgets = const [],
    List<RecurringExpense> recurring = const [],
  }) {
    _userId = userId;
    this.expenses = [...expenses];
    this.budgets = [...budgets];
    this.recurring = [...recurring];
    _refreshForecast();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  Map<String, double> _byCategory(List<ExpenseModel> list) {
    final map = <String, double>{};
    for (final e in list) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// 0 = under 80%, 1 = 80–99%, 2 = 100%+ for each budgeted category.
  Map<String, int> _budgetLevels() => {
        for (final b in budgetStatuses) b.category: b.isOver ? 2 : (b.isWarning ? 1 : 0),
      };

  void _raiseBudgetAlert(Map<String, int> before, String category) {
    final status = budgetStatuses.where((b) => b.category == category).firstOrNull;
    if (status == null) return;
    final level = status.isOver ? 2 : (status.isWarning ? 1 : 0);
    if (level <= (before[category] ?? 0)) return;
    final pct = (status.ratio * 100).round();
    _pendingBudgetAlert = level == 2
        ? '$category is over budget: ${formatRs(status.spent)} of ${formatRs(status.limit)} ($pct%).'
        : '$category has used $pct% of its ${formatRs(status.limit)} budget.';
  }

  @override
  void dispose() {
    _lstm?.dispose();
    super.dispose();
  }
}
