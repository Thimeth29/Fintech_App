// lib/services/cse_service.dart
//
// Talks to the Colombo Stock Exchange's unofficial public JSON API
// (documented at https://github.com/GH0STH4CKER/Colombo-Stock-Exchange-CSE-API-Documentation)
// to pull today's top gainers, top losers, and headline index levels
// (ASPI / S&P SL20) for the app's live market-data analytics.
//
// This is an unofficial, undocumented-by-CSE endpoint, so it can change
// or go down without notice. Every call is wrapped so a failure just
// falls back to sample data instead of crashing the Investments page —
// good enough for a coursework build; swap in a proper backend/API key
// before relying on this in production.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/market_data_model.dart';

class CseService {
  static const String _baseUrl = 'https://www.cse.lk/api';
  static const Duration _timeout = Duration(seconds: 8);

  Future<List<StockQuote>> fetchTopGainers() => _fetchList('topGainers');

  Future<List<StockQuote>> fetchTopLosers() =>
      _fetchList('topLooses'); // CSE's own endpoint name (sic)

  /// All-Share Price Index and S&P SL20, the two headline CSE indices,
  /// fetched live in parallel. Powers the "Market Pulse" strip.
  Future<List<MarketIndex>> fetchIndices() async {
    final results = await Future.wait([
      _fetchIndex('ASPI', 'aspiData'),
      _fetchIndex('S&P SL20', 'snpData'),
    ]);
    return results.whereType<MarketIndex>().toList();
  }

  Future<MarketIndex?> _fetchIndex(String label, String endpoint) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/$endpoint'))
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final Map<String, dynamic> raw = decoded is List
          ? (decoded.isNotEmpty ? decoded.first as Map<String, dynamic> : {})
          : decoded as Map<String, dynamic>;

      if (raw.isEmpty) return null;
      return MarketIndex.fromJson(label, raw);
    } catch (_) {
      // Network blocked, endpoint changed, CORS on web, etc. — the view
      // model treats a missing index the same as missing quotes: fall
      // back to a "showing sample data" notice instead of crashing.
      return null;
    }
  }

  Future<List<StockQuote>> _fetchList(String endpoint) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/$endpoint'))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('CSE API returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> rawList = decoded is List
          ? decoded
          : (decoded['reqTradeSummery'] ?? decoded['data'] ?? []);

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(StockQuote.fromJson)
          .take(10)
          .toList();
    } catch (_) {
      // Network blocked, endpoint changed, CORS on web, etc.
      // Returning an empty list lets the view model fall back to
      // sample data and show a "showing sample data" notice instead
      // of a hard error.
      return [];
    }
  }
}
