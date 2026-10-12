// lib/services/sandbox/anchor_service.dart
//
// Real-data starting points for each module's simulated prices. The
// scraped market_prices table comes first (the same data the live price
// source shows); the older per-feed lookups and then the constants in
// sandbox_config.dart fill any gaps. Anchors are stored on the wallet when
// a module unlocks, so the simulated path stays the same after a reload.

import '../../core/config/supabase_config.dart';
import '../../core/sandbox/sandbox_config.dart';
import '../asset_data_service.dart';
import '../investing_data_service.dart';
import 'live_price_source.dart';

class SandboxAnchorService {
  SandboxAnchorService({MarketPriceRepository? market}) : _market = market ?? SupabaseMarketPriceRepository();

  final MarketPriceRepository _market;
  Map<String, double>? _marketCache;

  /// Latest scraped values by key (empty when the table is unavailable).
  Future<Map<String, double>> _marketPrices() async {
    final cached = _marketCache;
    if (cached != null) return cached;
    try {
      final rows = await _market.fetchLatest();
      return _marketCache = {for (final r in rows) r.symbol: r.price};
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, double>> anchorsFor(SandboxModule m) async {
    _marketCache = null; // fresh values for every unlock
    final market = await _marketPrices();
    final base = switch (m) {
      SandboxModule.cse => await _cse(),
      SandboxModule.gold => await _gold(),
      SandboxModule.trading => {for (final i in kTradingInstruments) i.symbol: i.fallbackPrice},
      SandboxModule.fd => await _fd(),
      SandboxModule.govSecurities => await _gov(),
      SandboxModule.forex => {for (final i in kForexInstruments) i.symbol: i.fallbackPrice},
      SandboxModule.communityFund => <String, double>{},
    };
    // Scraped prices win over the older feeds and the fallbacks.
    for (final key in base.keys.toList()) {
      final spec = instrumentBySymbol(key);
      final live = market[spec?.priceKey ?? key];
      if (live != null && live > 0 && !(spec?.fictional ?? false)) base[key] = live;
    }
    return base;
  }

  /// The same source as Home's "Market today" gold tile, so they match.
  static Future<double> goldReferencePrice() async {
    try {
      final quotes = await GoldAssetDataService().fetchTopGainers();
      if (quotes.isNotEmpty && quotes.first.price > 0) return quotes.first.price;
    } catch (_) {}
    return kGoldBullion.fallbackPrice;
  }

  Future<Map<String, double>> _gold() async {
    final price = await goldReferencePrice();
    return {for (final i in kGoldInstruments) i.symbol: price};
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
