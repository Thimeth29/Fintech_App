// lib/services/sandbox/price_source.dart
//
// Where the Investment Trainer's prices come from, kept apart from how
// trading works. A PriceSource only answers "what is X worth now?" (and
// "what was it worth recently?"). The trading engine
// (trading_engine.dart) asks a PriceSource and never knows which one is
// plugged in:
//
//   SimulatedPriceSource  realistic mock prices from the seeded random-walk
//                         engine: offline, demos and tests
//   LivePriceSource       real Sri Lankan prices the scraper wrote to the
//                         market_prices table, pushed by Supabase Realtime
//   FallbackPriceSource   live where a fresh quote exists, simulated for
//                         everything else (fictional instruments, a source
//                         that failed today, no connection)
//
// Keys are shared by every source and by the market_prices table:
//   instruments  InstrumentSpec.priceKey   e.g. JKH.N, USDLKR, GOLD24K
//   rates        fdAnchorKey(bank, months), tbillAnchorKey(days),
//                tbondAnchorKey(years)      (% per year)

import 'dart:async';

enum PriceOrigin { live, simulated }

/// One price (LKR) or rate (% p.a.) at one moment.
class PriceQuote {
  final String key;
  final double price;
  final PriceOrigin origin;

  /// When the source published this value (live quotes only).
  final DateTime? asOf;

  /// Who published it, e.g. 'CBSL', 'CSE', 'Bank of Ceylon'.
  final String? source;

  /// Change since the previous close, in %, when the source reports it.
  final double? changePct;

  const PriceQuote({
    required this.key,
    required this.price,
    required this.origin,
    this.asOf,
    this.source,
    this.changePct,
  });

  bool get isLive => origin == PriceOrigin.live;
}

/// One daily close.
class PricePoint {
  final DateTime date;
  final double price;
  const PricePoint(this.date, this.price);
}

abstract class PriceSource {
  /// Short name for the UI, e.g. 'Live market data'.
  String get label;

  /// The current price of [key], or null if this source doesn't have one.
  /// Synchronous on purpose: sources keep their latest prices in memory so
  /// screens can ask as often as they rebuild.
  PriceQuote? quote(String key);

  /// Daily prices for the last [days] days, oldest first. May be shorter
  /// (or empty) when the source has less history.
  List<PricePoint> history(String key, {int days = 60});

  /// True when [key]'s price moves with the trainer's fast-forward clock
  /// (simulated prices do; real prices only move when the market does).
  bool followsSimClock(String key);

  /// Emits the keys whose prices changed, so the UI can refresh.
  Stream<Set<String>> get changes;

  /// Starts any background work (loading, realtime subscriptions).
  Future<void> start() async {}

  /// Asks the source to have history for [keys] ready (async sources fetch
  /// it; [changes] fires when it arrives).
  Future<void> prefetchHistory(Iterable<String> keys, {int days = 120}) async {}

  Future<void> dispose() async {}
}

/// Live where possible, simulated otherwise — per key, so one failed
/// scrape or a fictional instrument never blanks the whole trainer.
class FallbackPriceSource extends PriceSource {
  final PriceSource primary;
  final PriceSource fallback;

  FallbackPriceSource({required this.primary, required this.fallback});

  @override
  String get label => primary.label;

  @override
  PriceQuote? quote(String key) => primary.quote(key) ?? fallback.quote(key);

  @override
  List<PricePoint> history(String key, {int days = 60}) =>
      primary.quote(key) != null ? primary.history(key, days: days) : fallback.history(key, days: days);

  @override
  bool followsSimClock(String key) =>
      primary.quote(key) != null ? primary.followsSimClock(key) : fallback.followsSimClock(key);

  @override
  Stream<Set<String>> get changes {
    late final StreamController<Set<String>> out;
    final subs = <StreamSubscription<Set<String>>>[];
    out = StreamController<Set<String>>.broadcast(
      onListen: () {
        subs
          ..add(primary.changes.listen(out.add))
          ..add(fallback.changes.listen(out.add));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
      },
    );
    return out.stream;
  }

  @override
  Future<void> start() async {
    await fallback.start();
    await primary.start();
  }

  @override
  Future<void> prefetchHistory(Iterable<String> keys, {int days = 120}) async {
    final list = keys.toList();
    await Future.wait([
      primary.prefetchHistory(list, days: days),
      fallback.prefetchHistory(list, days: days),
    ]);
  }

  @override
  Future<void> dispose() async {
    await primary.dispose();
    await fallback.dispose();
  }
}
