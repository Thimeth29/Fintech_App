import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Consolidated Sandbox Service for Virtual Paper-Trading Portfolios & Holdings.
class SandboxService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  /// Fetch user virtual portfolio balance
  Future<Map<String, dynamic>?> fetchPortfolio() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;

    final response = await client
        .from('sandbox_portfolios')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return response;
  }

  /// Fetch virtual instrument holdings
  Future<List<Map<String, dynamic>>> fetchHoldings() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return [];

    final response = await client
        .from('sandbox_holdings')
        .select()
        .eq('user_id', user.id);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Execute Buy Trade in Sandbox
  Future<bool> buy({
    required String symbol,
    required String name,
    required String instrumentType,
    required double price,
    required double quantity,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return false;

    final totalCost = price * quantity;
    final portfolio = await fetchPortfolio();
    final currentBalance = (portfolio?['virtual_balance'] as num?)?.toDouble() ?? 100000.0;

    if (currentBalance < totalCost) return false;

    final newBalance = currentBalance - totalCost;

    // 1. Update Portfolio Virtual Balance
    await client.from('sandbox_portfolios').upsert({
      'user_id': user.id,
      'virtual_balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 2. Fetch existing holding if present
    final existing = await client
        .from('sandbox_holdings')
        .select()
        .eq('user_id', user.id)
        .eq('symbol', symbol)
        .maybeSingle();

    if (existing == null) {
      await client.from('sandbox_holdings').insert({
        'user_id': user.id,
        'symbol': symbol,
        'name': name,
        'instrument_type': instrumentType,
        'quantity': quantity,
        'average_price': price,
      });
    } else {
      final oldQty = (existing['quantity'] as num).toDouble();
      final oldAvg = (existing['average_price'] as num).toDouble();
      final newQty = oldQty + quantity;
      final newAvg = ((oldQty * oldAvg) + totalCost) / newQty;

      await client.from('sandbox_holdings').update({
        'quantity': newQty,
        'average_price': newAvg,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    }

    return true;
  }

  /// Execute Sell Trade in Sandbox
  Future<bool> sell({
    required String symbol,
    required double price,
    required double quantity,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return false;

    final existing = await client
        .from('sandbox_holdings')
        .select()
        .eq('user_id', user.id)
        .eq('symbol', symbol)
        .maybeSingle();

    if (existing == null) return false;

    final currentQty = (existing['quantity'] as num).toDouble();
    if (currentQty < quantity) return false;

    final totalProceeds = price * quantity;
    final portfolio = await fetchPortfolio();
    final currentBalance = (portfolio?['virtual_balance'] as num?)?.toDouble() ?? 100000.0;
    final newBalance = currentBalance + totalProceeds;

    // 1. Update Portfolio Balance
    await client.from('sandbox_portfolios').upsert({
      'user_id': user.id,
      'virtual_balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 2. Update or delete holding
    final remainingQty = currentQty - quantity;
    if (remainingQty <= 0.0001) {
      await client.from('sandbox_holdings').delete().eq('id', existing['id']);
    } else {
      await client.from('sandbox_holdings').update({
        'quantity': remainingQty,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    }

    return true;
  }
}
