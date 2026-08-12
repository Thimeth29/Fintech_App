import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ExpenseModel>> fetchExpenses(String userId) async {
    final rows = await _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _client.from('expenses').insert(expense.toInsertJson());
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }
}
