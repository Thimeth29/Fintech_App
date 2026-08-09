import '../models/instrument.dart';

/// Anything that can answer "what's the current price of X" and notify
/// listeners when prices change. [SandboxEngine] depends on this
/// abstraction, not on where the numbers actually come from — so the
/// same trading logic works identically whether you're using
/// [SimulatedPriceSource] (offline/demo) or [LiveSupabasePriceSource]
/// (real market data via your scraper -> Supabase pipeline).
///
/// Trading itself always stays 100% virtual money — this interface only
/// controls where *prices* come from, never account balances.
abstract class PriceSource {
  /// Current price for a tradable instrument. Returns 0 if unknown.
  double priceOf(String instrumentId);

  /// Percent change since the trading day/session began.
  double dailyChangePctOf(String instrumentId);

  /// When this instrument's price was last updated, if known.
  DateTime? lastUpdatedAt(String instrumentId);

  /// Snapshot of all known prices, e.g. for portfolio valuation.
  Map<String, double> snapshot();

  /// Fires (with no payload) whenever one or more prices change.
  /// The provider listens to this and calls notifyListeners().
  Stream<void> get updates;

  /// Begin fetching/streaming prices for [instruments].
  Future<void> start(List<Instrument> instruments);

  /// Stop streaming and release resources (timers, realtime channels).
  Future<void> dispose();
}
