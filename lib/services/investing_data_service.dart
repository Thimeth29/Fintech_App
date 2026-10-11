// lib/services/investing_data_service.dart
//
// Data for the Investing Options pages.
//
// * FD rates and T-bill yields: no Sri Lankan bank or CBSL offers a public
//   API, so the `collect-rates` edge function scrapes the official pages
//   daily and upserts into the Supabase tables `fd_rates` and
//   `gov_security_yields`. The app subscribes with Supabase Realtime, so a
//   new scrape shows up on screen without a refresh.
// * CSE: the `cse-market` edge function proxies cse.lk (which sends no CORS
//   headers, so web builds can't call it directly). Mobile builds fall back
//   to calling cse.lk directly if the function is unreachable.
// * News: the `financial-news` edge function merges local + world RSS feeds.
// * Gold: computed live from the international spot price (gold-api.com)
//   and the USD/LKR market rate (open.er-api.com). Both are free, keyless.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/config/supabase_config.dart';
import '../models/investing_models.dart';
import '../models/market_data_model.dart';
import 'cse_service.dart';

class InvestingDataService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Every CBSL-licensed deposit taker we track. Shown even before the
  /// scraper has filled in rates, so users can always reach the official
  /// rate page.
  static const List<FdRate> fdDirectory = [
    // Licensed Commercial Banks
    FdRate(institution: 'Bank of Ceylon', type: InstitutionType.lcb, sourceUrl: 'https://www.boc.lk/rates-tariff'),
    FdRate(institution: "People's Bank", type: InstitutionType.lcb, sourceUrl: 'https://www.peoplesbank.lk'),
    FdRate(institution: 'Commercial Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.combank.lk/rates-tariff'),
    FdRate(institution: 'Sampath Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.sampath.lk'),
    FdRate(institution: 'Hatton National Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.hnb.lk'),
    FdRate(institution: 'Seylan Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.seylan.lk'),
    FdRate(institution: 'NDB Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.ndbbank.com'),
    FdRate(institution: 'DFCC Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.dfcc.lk'),
    FdRate(institution: 'Nations Trust Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.nationstrust.com'),
    FdRate(institution: 'Pan Asia Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.pabcbank.com'),
    FdRate(institution: 'Union Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.unionb.com'),
    FdRate(institution: 'Amana Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.amana.lk'),
    FdRate(institution: 'Cargills Bank', type: InstitutionType.lcb, sourceUrl: 'https://www.cargillsbank.com'),
    // Licensed Specialised Banks
    FdRate(institution: 'National Savings Bank', type: InstitutionType.lsb, sourceUrl: 'https://www.nsb.lk'),
    FdRate(institution: 'Regional Development Bank', type: InstitutionType.lsb, sourceUrl: 'https://www.rdb.lk'),
    FdRate(institution: 'SANASA Development Bank', type: InstitutionType.lsb, sourceUrl: 'https://www.sdb.lk'),
    FdRate(institution: 'HDFC Bank', type: InstitutionType.lsb, sourceUrl: 'https://www.hdfc.lk'),
    // Licensed Finance Companies
    FdRate(institution: 'LB Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.lbfinance.com'),
    FdRate(institution: 'Central Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.cf.lk'),
    FdRate(institution: "People's Leasing & Finance", type: InstitutionType.lfc, sourceUrl: 'https://www.plc.lk'),
    FdRate(institution: 'Citizens Development Business Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.cdb.lk'),
    FdRate(institution: 'LOLC Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.lolcfinance.com'),
    FdRate(institution: 'Singer Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.singerfinance.com'),
    FdRate(institution: 'Siyapatha Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.siyapatha.lk'),
    FdRate(institution: 'HNB Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.hnbfinance.lk'),
    FdRate(institution: 'Vallibel Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.vallibelfinance.com'),
    FdRate(institution: 'Mercantile Investments & Finance', type: InstitutionType.lfc, sourceUrl: 'https://www.mi.com.lk'),
  ];

  /// Weekly retail T-bill rates, scraped from Bank of Ceylon's rate page.
  static const List<GovSecurityYield> govSecurityDirectory = [
    GovSecurityYield(security: '91-day T-Bill', kind: 'bill', sortOrder: 1, sourceUrl: tbillSourceUrl),
    GovSecurityYield(security: '182-day T-Bill', kind: 'bill', sortOrder: 2, sourceUrl: tbillSourceUrl),
    GovSecurityYield(security: '364-day T-Bill', kind: 'bill', sortOrder: 3, sourceUrl: tbillSourceUrl),
  ];

  static const String tbillSourceUrl = 'https://www.boc.lk/rates-tariff';

  /// Live FD table: the directory, overlaid with whatever the scraper has
  /// written to Supabase. Re-emits whenever a row changes.
  Stream<List<FdRate>> watchFdRates() => _watchMerged<FdRate>(
        table: 'fd_rates',
        primaryKey: 'institution',
        directory: fdDirectory,
        keyOf: (r) => r.institution,
        fromJson: FdRate.fromJson,
      );

  Stream<List<GovSecurityYield>> watchGovSecurityYields() =>
      _watchMerged<GovSecurityYield>(
        table: 'gov_security_yields',
        primaryKey: 'security',
        directory: govSecurityDirectory,
        keyOf: (y) => y.security,
        fromJson: GovSecurityYield.fromJson,
      );

  Stream<List<T>> _watchMerged<T>({
    required String table,
    required String primaryKey,
    required List<T> directory,
    required String Function(T) keyOf,
    required T Function(Map<String, dynamic>) fromJson,
  }) async* {
    yield directory;
    if (!SupabaseConfig.isConfigured) return;

    try {
      await for (final rows in SupabaseConfig.client
          .from(table)
          .stream(primaryKey: [primaryKey])) {
        final live = {
          for (final item in rows.map(fromJson)) keyOf(item): item,
        };
        final merged = [
          for (final entry in directory) live.remove(keyOf(entry)) ?? entry,
          ...live.values, // rows the scraper added that aren't in the directory
        ];
        yield merged;
      }
    } catch (_) {
      // Table not created yet, offline, or RLS blocking reads — keep
      // showing the directory with links to the official pages.
    }
  }

  Future<Map<String, dynamic>?> _callFunction(String name) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final res = await http.get(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/$name'),
        headers: {'apikey': SupabaseConfig.supabaseAnonKey},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Live CSE snapshot. Null if the market data can't be reached at all.
  Future<CseSnapshot?> fetchCseSnapshot() async {
    final body = await _callFunction('cse-market');
    if (body != null && body['error'] == null) return CseSnapshot.fromJson(body);
    if (kIsWeb) return null; // browsers can't call cse.lk directly (CORS)
    return _cseDirect();
  }

  /// Mobile fallback when the edge function isn't deployed / reachable.
  Future<CseSnapshot?> _cseDirect() async {
    final cse = CseService();
    final indicesFuture = cse.fetchIndices();
    final gainersFuture = cse.fetchTopGainers();
    final losersFuture = cse.fetchTopLosers();
    final indices = await indicesFuture;
    if (indices.isEmpty) return null;

    CseQuote quote(StockQuote q) => CseQuote(
        symbol: q.symbol, name: q.name, price: q.price, changePercentage: q.changePercentage);
    return CseSnapshot(
      indices: [
        for (final i in indices)
          CseIndex(name: i.name, value: i.value, change: i.change, changePercentage: i.changePercentage),
      ],
      gainers: (await gainersFuture).map(quote).toList(),
      losers: (await losersFuture).map(quote).toList(),
      fetchedAt: DateTime.now(),
    );
  }

  /// Latest local + world financial headlines, newest first.
  Future<List<NewsItem>?> fetchNews() async {
    final body = await _callFunction('financial-news');
    final items = body?['items'] as List?;
    if (items == null) return null;
    return items
        .whereType<Map<String, dynamic>>()
        .map(NewsItem.fromJson)
        .where((n) => n.title.isNotEmpty && n.url.isNotEmpty)
        .toList();
  }

  /// Live gold estimate. Returns null if either feed is unreachable.
  Future<GoldQuote?> fetchGoldQuote() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://api.gold-api.com/price/XAU')).timeout(_timeout),
        http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(_timeout),
      ]);
      if (responses.any((r) => r.statusCode != 200)) return null;

      final gold = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final fx = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final spot = (gold['price'] as num?)?.toDouble();
      final lkr = ((fx['rates'] as Map?)?['LKR'] as num?)?.toDouble();
      if (spot == null || lkr == null) return null;

      final fxUnix = (fx['time_last_update_unix'] as num?)?.toInt();
      return GoldQuote(
        spotUsdPerOunce: spot,
        usdLkr: lkr,
        spotUpdatedAt: DateTime.tryParse(gold['updatedAt']?.toString() ?? '')?.toLocal(),
        fxUpdatedAt: fxUnix == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(fxUnix * 1000),
      );
    } catch (_) {
      return null;
    }
  }
}
