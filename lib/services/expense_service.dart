import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/expense_model.dart';

/// Consolidated Expense & Budget Service
class ExpenseService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  /// Fetch all logged expenses for a given user
  Future<List<ExpenseModel>> fetchExpenses(String userId) async {
    final client = _client;
    if (client == null) return [];

    final rows = await client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Insert new logged expense
  Future<void> addExpense(ExpenseModel expense) async {
    final client = _client;
    if (client == null) return;
    await client.from('expenses').insert(expense.toInsertJson());
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
    if (client == null) return [];

    final response = await client
        .from('budgets')
        .select()
        .eq('user_id', userId)
        .eq('month_year', monthYear);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create or Update Budget limit for a category
  Future<void> upsertBudget({
    required String userId,
    required String category,
    required double limitAmount,
    required String monthYear,
  }) async {
    final client = _client;
    if (client == null) return;

    await client.from('budgets').upsert({
      'user_id': userId,
      'category': category,
      'limit_amount': limitAmount,
      'month_year': monthYear,
    });
  }
}
