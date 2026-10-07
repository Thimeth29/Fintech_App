import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class SupabaseExpenseService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Fetch all logged expenses for current user
  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('expenses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Insert new logged expense
  Future<Map<String, dynamic>?> addExpense({
    required String category,
    required double amount,
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client.from('expenses').insert({
      'user_id': user.id,
      'category': category,
      'amount': amount,
      'note': note,
    }).select().single();

    return response;
  }

  /// Delete an expense by ID
  Future<void> deleteExpense(String expenseId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('expenses').delete().match({'id': expenseId, 'user_id': user.id});
  }

  /// Fetch monthly budgets
  Future<List<Map<String, dynamic>>> fetchBudgets(String monthYear) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('budgets')
        .select()
        .eq('user_id', user.id)
        .eq('month_year', monthYear);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create or Update Budget limit for a category
  Future<void> upsertBudget({
    required String category,
    required double limitAmount,
    required String monthYear,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('budgets').upsert({
      'user_id': user.id,
      'category': category,
      'limit_amount': limitAmount,
      'month_year': monthYear,
    });
  }
}
