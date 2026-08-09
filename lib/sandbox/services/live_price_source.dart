import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/instrument.dart';
import 'price_source.dart';

/// Reads real market prices from a Supabase table that your scraper job
/// keeps updated (CBSL exchange rates, CSE stock prices, bank FD/gold
/// rates — see the scraping pipeline). Trades are still executed with
/// virtual sandbox money in [SandboxEngine]; this class only supplies
/// the *prices* those virtual trades happen at.
///
/// Expected table shape (see README for the full SQL):
///
/// ```sql
/// create table market_prices (
///   instrument_id text primary key,
///   price numeric not null,
///   daily_change_pct numeric not null default 0,
///   updated_at timestamptz not null default now()
/// );
/// ```
class LiveSupabasePriceSource implements PriceSource {
  final SupabaseClient client;
  final String table;

  final Map<String, double> _prices = {};
  final Map<String, double> _dailyChange = {};
  final Map<String, DateTime> _updatedAt = {};
  final StreamController<void> _controller = StreamController<void>.broadcast();

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  List<Instrument> _instruments = [];

  LiveSupabasePriceSource({required this.client, this.table = 'market_prices'});

  @override
  Stream<void> get updates => _controller.stream;

  @override
  Future<void> start(List<Instrument> instruments) async {
    _instruments = instruments;
    await _fetchOnce();
    _subscribeRealtime();

    // Realtime covers most cases, but a slow poll as a safety net means a
    // dropped websocket never leaves prices silently stale for long.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => _fetchOnce());
  }

  Future<void> _fetchOnce() async {
    try {
      final tradableIds = _instruments
          .where((i) => i.category == InstrumentCategory.tradable)
          .map((i) => i.id)
          .toList();
      if (tradableIds.isEmpty) return;

      final rows = await client.from(table).select().inFilter('instrument_id', tradableIds);
      for (final row in rows as List) {
        _applyRow(row as Map<String, dynamic>);
      }
      if (!_controller.isClosed) _controller.add(null);
    } catch (_) {
      // Swallow errors here — the UI falls back to the last known price
      // (or the instrument's base price) rather than crashing. Log this
      // via your app's normal error reporting in production.
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = client
        .channel('public:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isNotEmpty) _applyRow(row);
            if (!_controller.isClosed) _controller.add(null);
          },
        )
        .subscribe();
  }

  void _applyRow(Map<String, dynamic> row) {
    final id = row['instrument_id'] as String?;
    if (id == null) return;
    final price = (row['price'] as num?)?.toDouble();
    final change = (row['daily_change_pct'] as num?)?.toDouble();
    final updated = row['updated_at'] != null ? DateTime.tryParse(row['updated_at'] as String) : null;

    if (price != null) _prices[id] = price;
    if (change != null) _dailyChange[id] = change;
    _updatedAt[id] = updated ?? DateTime.now();
  }

  @override
  double priceOf(String instrumentId) => _prices[instrumentId] ?? 0;

  @override
  double dailyChangePctOf(String instrumentId) => _dailyChange[instrumentId] ?? 0;

  @override
  DateTime? lastUpdatedAt(String instrumentId) => _updatedAt[instrumentId];

  @override
  Map<String, double> snapshot() => Map.unmodifiable(_prices);

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _channel?.unsubscribe();
    await _controller.close();
  }
}
