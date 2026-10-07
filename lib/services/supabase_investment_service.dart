import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class SupabaseInvestmentService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Fetch investment action logs (BUY, SELL, CONSIDERED)
  Future<List<Map<String, dynamic>>> fetchInvestmentLogs() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('investment_logs')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Log real investment action
  Future<void> logInvestmentAction({
    required String actionType,
    required String symbol,
    required String assetClass,
    required double amount,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('investment_logs').insert({
      'user_id': user.id,
      'action_type': actionType,
      'symbol': symbol,
      'asset_class': assetClass,
      'amount': amount,
    });
  }
}
