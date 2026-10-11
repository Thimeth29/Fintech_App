// lib/services/sandbox/anchor_service.dart
//
// Real-data starting points for each module's simulated prices. Anything
// that can't be fetched falls back to the constants in sandbox_config.dart.
// Anchors are stored on the wallet when a module unlocks, so the simulated
// path stays the same after a reload.

import '../../core/config/supabase_config.dart';
import '../../core/sandbox/sandbox_config.dart';
import '../asset_data_service.dart';
import '../investing_data_service.dart';

String fdAnchorKey(String bank, int months) => 'FD|$bank|$months';

class SandboxAnchorService {
  Future<Map<String, double>> anchorsFor(SandboxModule m) async {
    switch (m) {
      case SandboxModule.cse:
        return _cse();
      case SandboxModule.gold:
        final price = await goldReferencePrice();
        return {for (final i in kGoldInstruments) i.symbol: price};
      case SandboxModule.trading:
        return {for (final i in kTradingInstruments) i.symbol: i.fallbackPrice};
      case SandboxModule.fd:
        return _fd();
      case SandboxModule.govSecurities:
        return _gov();
    }
  }

  /// The same source as Home's "Market today" gold tile, so they match.
  static Future<double> goldReferencePrice() async {
    try {
      final quotes = await GoldAssetDataService().fetchTopGainers();
      if (quotes.isNotEmpty && quotes.first.price > 0) return quotes.first.price;
    } catch (_) {}
    return kGoldBullion.fallbackPrice;
  }

  Future<Map<String, double>> _cse() async {
    final live = <String, double>{};
    try {
      final snap = await InvestingDataService().fetchCseSnapshot();
      for (final q in [...?snap?.gainers, ...?snap?.losers, ...?snap?.mostActive]) {
        final p = q.price;
        if (p != null && p > 0) live[q.symbol] = p;
      }
    } catch (_) {}
    return {for (final i in kCseInstruments) i.symbol: live[i.symbol] ?? i.fallbackPrice};
  }

  Future<Map<String, double>> _fd() async {
    final anchors = <String, double>{
      for (final bank in kFdFallbackRates.entries)
        for (final t in bank.value.entries) fdAnchorKey(bank.key, t.key): t.value,
    };
    if (!SupabaseConfig.isConfigured) return anchors;
    try {
      final rows = await SupabaseConfig.client.from('fd_rates').select();
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final bank = '${r['institution']}';
        if (!kFdFallbackRates.containsKey(bank)) continue;
        for (final t in kFdTenures) {
          final v = r['rate_${t}m'];
          if (v is num && v > 0) anchors[fdAnchorKey(bank, t)] = v.toDouble();
        }
      }
    } catch (_) {}
    return anchors;
  }

  Future<Map<String, double>> _gov() async {
    final anchors = <String, double>{
      for (final e in kTbillFallbackYields.entries) tbillAnchorKey(e.key): e.value,
      for (final e in kTbondFallbackYields.entries) tbondAnchorKey(e.key): e.value,
    };
    if (!SupabaseConfig.isConfigured) return anchors;
    try {
      final rows = await SupabaseConfig.client.from('gov_security_yields').select();
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final name = '${r['security']}';
        final y = r['yield_rate'];
        if (y is! num || y <= 0) continue;
        final bill = RegExp(r'^(\d+)-day').firstMatch(name);
        final bond = RegExp(r'^(\d+)-year').firstMatch(name);
        if (bill != null) anchors[tbillAnchorKey(int.parse(bill.group(1)!))] = y.toDouble();
        if (bond != null) anchors[tbondAnchorKey(int.parse(bond.group(1)!))] = y.toDouble();
      }
    } catch (_) {}
    return anchors;
  }
}
