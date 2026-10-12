import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/money.dart';
import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';
import 'expenditure/recurring_schedule.dart';

/// Consolidated Expense & Budget Service
class ExpenseService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  /// Fetch logged expenses for a given user, newest first. Without [from] /
  /// [to] this returns every row (FinBot uses that); the expenditure
  /// screens pass a date range.
  Future<List<ExpenseModel>> fetchExpenses(String userId, {DateTime? from, DateTime? to}) async {
    final client = _client;
    if (client == null || userId.isEmpty) return [];

    var query = client.from('expenses').select().eq('user_id', userId);
    if (from != null) query = query.gte('expense_date', isoDate(from));
    if (to != null) query = query.lte('expense_date', isoDate(to));
    final rows = await query
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Sum of every expense the user has ever logged (amounts only).
  Future<double> fetchAllTimeTotal(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return 0;
    final rows = await client.from('expenses').select('amount').eq('user_id', userId);
    return (rows as List).fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
  }

  /// Columns added by the expenditure-upgrade migration. A database that
  /// hasn't run it rejects any write naming them, so writes retry without.
  static const _upgradeColumns = ['priority', 'recurring_id'];

  /// PostgREST's "column not in schema cache" error (PGRST204), or the
  /// Postgres "undefined column" error (42703).
  static bool _isMissingUpgradeColumn(Object e) =>
      e is PostgrestException &&
      (e.code == 'PGRST204' || e.code == '42703') &&
      _upgradeColumns.any((c) => e.message.contains(c));

  static Map<String, dynamic> _withoutUpgradeColumns(Map<String, dynamic> json) =>
      Map.of(json)..removeWhere((k, _) => _upgradeColumns.contains(k));

  /// Runs [write] with [json]; if the database predates the upgrade
  /// columns, runs it again without them so the expense still saves.
  Future<Map<String, dynamic>> _writeWithFallback(
    Map<String, dynamic> json,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) write,
  ) async {
    try {
      return await write(json);
    } catch (e) {
      if (!_isMissingUpgradeColumn(e)) rethrow;
      debugPrint('expenses: database is missing the expenditure upgrade '
          '(${(e as PostgrestException).message}); saving without priority.');
      return write(_withoutUpgradeColumns(json));
    }
  }

  /// Insert a new expense and return the stored row (with its id).
  Future<ExpenseModel?> addExpense(ExpenseModel expense) async {
    final client = _client;
    if (client == null) return null;
    final row = await _writeWithFallback(
      expense.toInsertJson(),
      (json) => client.from('expenses').insert(json).select().single(),
    );
    return ExpenseModel.fromJson(row);
  }

  /// Update an existing expense's editable fields; returns the stored row.
  Future<ExpenseModel?> updateExpense(ExpenseModel expense) async {
    final client = _client;
    if (client == null || expense.id == null) return null;
    final row = await _writeWithFallback(
      expense.toUpdateJson(),
      (json) => client.from('expenses').update(json).eq('id', expense.id!).select().single(),
    );
    return ExpenseModel.fromJson(row);
  }

  /// Delete an expense by ID
  Future<void> deleteExpense(String id) async {
    final client = _client;
    if (client == null) return;
    await client.from('expenses').delete().eq('id', id);
  }

  /// Fetch monthly budgets for a user for a specific month (e.g. "2026-10")
  Future<List<Map<String, dynamic>>> fetchBudgets(String userId, String monthYear) async {
    final client = _client;
    if (client == null || userId.isEmpty) return [];

    final response = await client
        .from('budgets')
        .select()
        .eq('user_id', userId)
        .eq('month_year', monthYear);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create or Update Budget limit for a category. Conflicts resolve on the
  /// table's (user_id, category, month_year) unique key, so saving the same
  /// category twice in a month updates instead of failing.
  Future<void> upsertBudget({
    required String userId,
    required String category,
    required double limitAmount,
    required String monthYear,
  }) async {
    final client = _client;
    if (client == null) return;

    await client.from('budgets').upsert(
      {
        'user_id': userId,
        'category': category,
        'limit_amount': limitAmount,
        'month_year': monthYear,
      },
      onConflict: 'user_id,category,month_year',
    );
  }

  Future<void> deleteBudget({
    required String userId,
    required String category,
    required String monthYear,
  }) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('budgets')
        .delete()
        .eq('user_id', userId)
        .eq('category', category)
        .eq('month_year', monthYear);
  }

  // ---------------------------------------------------------------------
  // Recurring expenses
  // ---------------------------------------------------------------------

  Future<List<RecurringExpense>> fetchRecurring(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return [];
    final rows = await client
        .from('recurring_expenses')
        .select()
        .eq('user_id', userId)
        .order('next_due_date');
    return (rows as List)
        .map((r) => RecurringExpense.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<RecurringExpense?> addRecurring(RecurringExpense item) async {
    final client = _client;
    if (client == null) return null;
    final row = await client.from('recurring_expenses').insert(item.toJson()).select().single();
    return RecurringExpense.fromJson(row);
  }

  Future<RecurringExpense?> updateRecurring(RecurringExpense item) async {
    final client = _client;
    if (client == null || item.id == null) return null;
    final row = await client
        .from('recurring_expenses')
        .update(item.toJson())
        .eq('id', item.id!)
        .select()
        .single();
    return RecurringExpense.fromJson(row);
  }

  Future<void> deleteRecurring(String id) async {
    final client = _client;
    if (client == null) return;
    await client.from('recurring_expenses').delete().eq('id', id);
  }

  /// Turns every due occurrence (up to [today]) of each active recurring item
  /// into an expense row, then advances its next due date. Idempotent: the
  /// insert ignores rows that already exist for (recurring_id, expense_date),
  /// so running it twice — or on two devices at once — never double-inserts.
  /// Returns how many occurrences were processed.
  Future<int> generateDueRecurring(List<RecurringExpense> items, DateTime today) async {
    final client = _client;
    if (client == null) return 0;
    var count = 0;
    for (final r in items) {
      if (r.id == null) continue;
      final dates = dueOccurrences(r, today);
      if (dates.isEmpty) continue;
      final rows = [
        for (final d in dates)
          ExpenseModel(
            userId: r.userId,
            amount: r.amount,
            category: r.category,
            note: r.note,
            expenseDate: d,
            priority: r.priority,
            recurringId: r.id,
          ).toInsertJson(),
      ];
      await client
          .from('expenses')
          .upsert(rows, onConflict: 'recurring_id,expense_date', ignoreDuplicates: true);
      await client
          .from('recurring_expenses')
          .update({'next_due_date': isoDate(advanceAfter(r, dates))})
          .eq('id', r.id!);
      count += dates.length;
    }
    return count;
  }
}
