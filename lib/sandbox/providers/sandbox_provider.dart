import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_instruments.dart';
import '../models/holding.dart';
import '../models/instrument.dart';
import '../services/live_price_source.dart';
import '../services/price_simulator.dart';
import '../services/sandbox_engine.dart';

/// Thin reactive wrapper around [SandboxEngine] for use with `provider`.
///
/// Two ways to construct it:
/// - `SandboxProvider.live(client: Supabase.instance.client)` — trades
///   execute against real CBSL/CSE/bank prices from your scraper's
///   Supabase table, with virtual money.
/// - `SandboxProvider.simulated()` — offline/demo mode with a mock
///   random-walk price feed. Useful for development or if a user opts
///   into the sandbox before their data connection is ready.
///
/// Wire it up once near the app root:
/// ```dart
/// ChangeNotifierProvider(create: (_) => SandboxProvider.live(client: Supabase.instance.client));
/// ```
/// then anywhere in the tree: `context.watch<SandboxProvider>()`.
class SandboxProvider extends ChangeNotifier {
  final SandboxEngine engine;
  final bool isLive;
  StreamSubscription<void>? _priceSub;
  bool _started = false;

  SandboxProvider._(this.engine, {required this.isLive});

  factory SandboxProvider.live({
    required SupabaseClient client,
    List<Instrument>? instruments,
    double startingBalance = kSandboxStartingBalance,
  }) {
    final source = LiveSupabasePriceSource(client: client);
    final engine = SandboxEngine(
      instruments: instruments ?? mockInstruments,
      priceSource: source,
      startingBalance: startingBalance,
    );
    return SandboxProvider._(engine, isLive: true);
  }

  factory SandboxProvider.simulated({
    List<Instrument>? instruments,
    double startingBalance = kSandboxStartingBalance,
  }) {
    final engine = SandboxEngine(
      instruments: instruments ?? mockInstruments,
      priceSource: SimulatedPriceSource(),
      startingBalance: startingBalance,
    );
    return SandboxProvider._(engine, isLive: false);
  }

  /// Starts the price feed (Supabase fetch + realtime subscribe, or the
  /// simulator's tick loop) and begins forwarding updates as
  /// `notifyListeners()` calls. Call once, e.g. right after construction.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await engine.start();
    _priceSub = engine.priceSource.updates.listen((_) => notifyListeners());
  }

  List<Instrument> get instruments => engine.instruments;
  double get cashBalance => engine.portfolio.cashBalance;
  double get totalValue => engine.totalPortfolioValue();
  Map<String, Holding> get holdings => engine.portfolio.holdings;

  double priceOf(String instrumentId) => engine.priceSource.priceOf(instrumentId);
  double dailyChangePctOf(String instrumentId) => engine.priceSource.dailyChangePctOf(instrumentId);
  DateTime? lastPriceUpdate(String instrumentId) => engine.priceSource.lastUpdatedAt(instrumentId);

  String? _lastError;
  String? get lastError => _lastError;

  /// Runs [action], catches [SandboxException] so the UI can show a
  /// friendly message instead of crashing, and always notifies listeners.
  bool _runGuarded(void Function() action) {
    try {
      action();
      _lastError = null;
      return true;
    } on SandboxException catch (e) {
      _lastError = e.message;
      return false;
    } finally {
      notifyListeners();
    }
  }

  bool buyTradable(String instrumentId, double lkrAmount) =>
      _runGuarded(() => engine.buyTradable(instrumentId, lkrAmount));

  bool sellTradable(String instrumentId, double quantity) =>
      _runGuarded(() => engine.sellTradable(instrumentId, quantity));

  bool openTermPosition(String instrumentId, double principal) =>
      _runGuarded(() => engine.openTermPosition(instrumentId, principal));

  bool withdrawTermPosition(String positionId) =>
      _runGuarded(() => engine.withdrawTermPosition(positionId));

  bool joinCommunityFund(String instrumentId) =>
      _runGuarded(() => engine.joinCommunityFund(instrumentId));

  bool contributeToCommunityRound(String positionId) =>
      _runGuarded(() => engine.contributeToCommunityRound(positionId));

  bool receiveCommunityPayout(String positionId) =>
      _runGuarded(() => engine.receiveCommunityPayout(positionId));

  /// Clears all mock holdings/positions and restores the starting
  /// virtual balance. Prices themselves are untouched — only the
  /// player's fake money and trades reset.
  void resetSandbox() => _runGuarded(() => engine.resetSandbox());

  @override
  void dispose() {
    _priceSub?.cancel();
    engine.dispose();
    super.dispose();
  }
}
