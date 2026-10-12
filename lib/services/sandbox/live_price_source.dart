// lib/services/sandbox/live_price_source.dart
//
// PriceSource backed by real Sri Lankan market data. The app never scrapes
// anything itself: the scheduled scraper job (scraper/ in this repo) writes
// CBSL exchange rates and gold, CSE share prices, bank FD rates and T-bill
// yields into Supabase, and this class only reads them:
//
//   market_prices         one row per key, the latest value
//   market_price_history  one row per key per day, for charts
//
// It subscribes to market_prices with Supabase Realtime, so when the next
// scrape lands the new price appears on screen without polling.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/sandbox/sandbox_config.dart';
import 'price_source.dart';

double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

/// One row of market_prices.
class MarketPriceRow {
  final String symbol;
  final String kind; // stock | gold | forex | fd_rate | tbill_yield | tbond_yield
  final String name;
  final double price;
  final String unit;
  final double? changePct;
  final String source;
  final DateTime asOf;

  const MarketPriceRow({
    required this.symbol,
    required this.kind,
    required this.name,
    required this.price,
    required this.unit,
    required this.source,
    required this.asOf,
    this.changePct,
  });

  bool get isRate => kind.endsWith('_rate') || kind.endsWith('_yield');

  /// Null for a row that isn't usable (missing or non-positive price).
  static MarketPriceRow? tryParse(Map<String, dynamic> j) {
    final price = _num(j['price']);
    final asOf = DateTime.tryParse('${j['as_of'] ?? j['fetched_at'] ?? ''}');
    final symbol = j['symbol']?.toString();
    if (price == null || price <= 0 || asOf == null || symbol == null || symbol.isEmpty) return null;
    return MarketPriceRow(
      symbol: symbol,
      kind: '${j['kind'] ?? ''}',
      name: '${j['name'] ?? symbol}',
      price: price,
      unit: '${j['unit'] ?? ''}',
      changePct: _num(j['change_pct']),
      source: '${j['source'] ?? ''}',
      asOf: asOf.toLocal(),
    );
  }
}

/// Where live prices are read from. Supabase in the app; an in-memory fake
/// in tests.
abstract class MarketPriceRepository {
  Future<List<MarketPriceRow>> fetchLatest();

  /// Daily closes for [symbols] on or after [since], any order.
  Future<Map<String, List<PricePoint>>> fetchHistory(Iterable<String> symbols, DateTime since);

  /// Calls [onRow] for every inserted or updated row. Returns a function
  /// that stops listening.
  Future<void> Function() watch(void Function(MarketPriceRow row) onRow);
}

class SupabaseMarketPriceRepository implements MarketPriceRepository {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null; // Supabase not initialised (tests, offline start-up)
    }
  }

  @override
  Future<List<MarketPriceRow>> fetchLatest() async {
    final c = _client;
    if (c == null) return const [];
    try {
      final rows = await c.from('market_prices').select();
      return [
        for (final r in List<Map<String, dynamic>>.from(rows))
          if (MarketPriceRow.tryParse(r) case final row?) row,
      ];
    } catch (_) {
      return const []; // table not migrated yet, or offline: simulated prices take over
    }
  }

  @override
  Future<Map<String, List<PricePoint>>> fetchHistory(Iterable<String> symbols, DateTime since) async {
    final c = _client;
    final list = symbols.toSet().toList();
    if (c == null || list.isEmpty) return const {};
    try {
      final d = since.toIso8601String().substring(0, 10);
      final rows = await c
          .from('market_price_history')
          .select('symbol, price_date, price')
          .inFilter('symbol', list)
          .gte('price_date', d)
          .order('price_date');
      final out = <String, List<PricePoint>>{};
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final date = DateTime.tryParse('${r['price_date']}');
        final price = _num(r['price']);
        if (date == null || price == null || price <= 0) continue;
        out.putIfAbsent('${r['symbol']}', () => []).add(PricePoint(DateTime(date.year, date.month, date.day), price));
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> Function() watch(void Function(MarketPriceRow row) onRow) {
    final c = _client;
    if (c == null) return () async {};
    try {
      final channel = c
          .channel('market-prices')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'market_prices',
            callback: (payload) {
              final row = MarketPriceRow.tryParse(payload.newRecord);
              if (row != null) onRow(row);
            },
          )
          .subscribe();
      return () async {
        try {
          await c.removeChannel(channel);
        } catch (_) {}
      };
    } catch (_) {
      return () async {};
    }
  }
}

class LivePriceSource extends PriceSource {
  LivePriceSource({MarketPriceRepository? repository, DateTime Function()? now})
      : _repo = repository ?? SupabaseMarketPriceRepository(),
        _now = now ?? DateTime.now;

  final MarketPriceRepository _repo;
  final DateTime Function() _now;
  final Map<String, MarketPriceRow> _latest = {};
  final Map<String, List<PricePoint>> _history = {};
  final Set<String> _historyRequested = {};
  final _changes = StreamController<Set<String>>.broadcast();
  Future<void> Function()? _unwatch;
  bool _started = false;

  @override
  String get label => 'Live market data';

  @override
  Stream<Set<String>> get changes => _changes.stream;

  /// How many keys have a usable (fresh) live price right now.
  int get liveCount => _latest.keys.where((k) => quote(k) != null).length;

  /// The newest publication time across all rows, for "updated ..." labels.
  DateTime? get lastUpdated =>
      _latest.values.isEmpty ? null : _latest.values.map((r) => r.asOf).reduce((a, b) => a.isAfter(b) ? a : b);

  MarketPriceRow? row(String key) => _latest[key];

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _unwatch = _repo.watch(_apply);
  }

  /// Reloads every latest price (pull-to-refresh, or after reconnecting).
  Future<void> refresh() async {
    final rows = await _repo.fetchLatest();
    if (rows.isEmpty) return;
    for (final r in rows) {
      _latest[r.symbol] = r;
    }
    _emit(rows.map((r) => r.symbol).toSet());
  }

  void _apply(MarketPriceRow row) {
    _latest[row.symbol] = row;
    // Today's point in the chart follows the live price.
    final h = _history[row.symbol];
    if (h != null) {
      final day = DateTime(row.asOf.year, row.asOf.month, row.asOf.day);
      if (h.isNotEmpty && h.last.date == day) h.removeLast();
      if (h.isEmpty || h.last.date.isBefore(day)) h.add(PricePoint(day, row.price));
    }
    _emit({row.symbol});
  }

  void _emit(Set<String> keys) {
    if (!_changes.isClosed) _changes.add(keys);
  }

  bool _fresh(MarketPriceRow r) {
    final maxAge = r.isRate ? kLiveQuoteMaxAgeRates : kLiveQuoteMaxAgeMarket;
    return _now().difference(r.asOf) <= maxAge;
  }

  @override
  PriceQuote? quote(String key) {
    final r = _latest[key];
    if (r == null || !_fresh(r)) return null;
    return PriceQuote(
      key: key,
      price: r.price,
      origin: PriceOrigin.live,
      asOf: r.asOf,
      source: r.source,
      changePct: r.changePct,
    );
  }

  @override
  bool followsSimClock(String key) => false;

  @override
  List<PricePoint> history(String key, {int days = 60}) {
    final h = _history[key];
    if (h == null) return const [];
    final today = _now();
    final from = DateTime(today.year, today.month, today.day - days);
    return h.where((p) => !p.date.isBefore(from)).toList();
  }

  @override
  Future<void> prefetchHistory(Iterable<String> keys, {int days = 120}) async {
    final wanted = keys.where((k) => !_historyRequested.contains(k)).toSet();
    if (wanted.isEmpty) return;
    _historyRequested.addAll(wanted);
    final today = _now();
    final loaded = await _repo.fetchHistory(wanted, DateTime(today.year, today.month, today.day - days));
    for (final e in loaded.entries) {
      _history[e.key] = [...e.value]..sort((a, b) => a.date.compareTo(b.date));
    }
    if (loaded.isNotEmpty) _emit(loaded.keys.toSet());
  }

  @override
  Future<void> dispose() async {
    await _unwatch?.call();
    await _changes.close();
  }
}
