import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/investment_action_model.dart';

/// Persists a history of investment actions the user takes (or marks as
/// "considered") from the analytics pages, so "My Investments" can show
/// a timeline of past decisions.
class InvestmentService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<InvestmentActionModel>> fetchActions(String userId) async {
    final rows = await _client
        .from('investment_actions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              InvestmentActionModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> logAction(InvestmentActionModel action) async {
    await _client.from('investment_actions').insert(action.toInsertJson());
  }
}
