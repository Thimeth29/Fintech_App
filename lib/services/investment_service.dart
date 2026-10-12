import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/investment_action_model.dart';

/// Persists a history of investment actions the user takes (or marks as
/// "considered") from the analytics pages, so "My Investments" can show
/// a timeline of past decisions.
class InvestmentService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  /// Fetch investment action logs for a given user
  Future<List<InvestmentActionModel>> fetchActions(String userId) async {
    final client = _client;
    if (client == null) return [];

    final rows = await client
        .from('investment_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => InvestmentActionModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Log an investment action
  Future<void> logAction(InvestmentActionModel action) async {
    final client = _client;
    if (client == null) return;
    await client.from('investment_logs').insert(action.toInsertJson());
  }
}
