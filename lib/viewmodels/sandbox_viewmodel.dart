// lib/viewmodels/sandbox_viewmodel.dart
//
// One SandboxViewModel is provided above MaterialApp (see main.dart), so
// Home's "Sandbox portfolio" card and every Investment Trainer screen read
// the same state and update together after a trade.
//
// Local state only changes after the server accepts a write: every action
// awaits its RPC and applies the row it returns. Failures surface the
// server's error text; nothing is faked.
//
// Prices come from a PriceSource (live market data with a simulated
// fallback, or simulated only) and trading rules from the trading engine;
// this class wires them to the wallets, persistence and gamification.

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;

import '../core/config/supabase_config.dart';
import '../core/sandbox/sandbox_config.dart';
import '../core/utils/money.dart';
import '../models/sandbox_models.dart';
import '../services/sandbox/anchor_service.dart';
import '../services/sandbox/fast_forward.dart';
import '../services/sandbox/gamification.dart';
import '../services/sandbox/lesson_repository.dart';
import '../services/sandbox/live_price_source.dart';
import '../services/sandbox/price_engine.dart';
import '../services/sandbox/price_source.dart';
import '../services/sandbox/simulated_price_source.dart';
import '../services/sandbox/sim_math.dart';
import '../services/sandbox/trading_engine.dart';
import '../services/sandbox_service.dart';

export '../services/sandbox/price_source.dart' show PriceQuote, PriceOrigin;
export '../services/sandbox/trading_engine.dart' show TradeQuote, EarlyWithdrawal, ForexMath, SeettuEngine, TermEngine;

/// Where the trainer's prices come from.
enum PriceMode { live, simulated }

class SandboxCelebration {
  final String kind; // level_up | badge | challenge | maturity | unlock | quiz
  final String title;
  final String? subtitle;
  final IconData icon;
  const SandboxCelebration({required this.kind, required this.title, required this.icon, this.subtitle});
}

class ActionResult {
  final bool ok;
  final String? error;
  final double? realisedPnl;
  final Object? data;
  const ActionResult.ok({this.realisedPnl, this.data})
      : ok = true,
        error = null;
  const ActionResult.fail(this.error)
      : ok = false,
        realisedPnl = null,
        data = null;
}

class FastForwardOutcome {
  final bool ok;
  final String? error;
  final FastForwardPlan? plan;
  final double balanceBefore;
  final double valueBefore;
  const FastForwardOutcome({required this.ok, this.error, this.plan, this.balanceBefore = 0, this.valueBefore = 0});
}

class UpDownRound {
  final String symbol;
  final bool predictedUp;
  final double stake;
  final double startPrice;
  final double endPrice;
  final bool won;
  const UpDownRound({
    required this.symbol,
    required this.predictedUp,
    required this.stake,
    required this.startPrice,
    required this.endPrice,
    required this.won,
  });
  double get net => won ? stake * (kUpDownPayout - 1) : -stake;
}

class ModulePerformance {
  final double totalReturn;
  final double feesPaid;
  final double income;
  final double? best;
  final double? worst;
  final double? winRate;
  final int closedTrades;
  const ModulePerformance({
    required this.totalReturn,
    required this.feesPaid,
    required this.income,
    required this.closedTrades,
    this.best,
    this.worst,
    this.winRate,
  });
}

class SandboxViewModel extends ChangeNotifier implements SimClock {
  SandboxViewModel({
    SandboxService? service,
    LessonRepository? lessons,
    SandboxAnchorService? anchors,
    MarketPriceRepository? market,
    PriceMode? priceMode,
    bool listenToAuth = true,
  })  : _service = service ?? SandboxService(),
        _lessonRepo = lessons ?? LessonRepository(),
        _anchors = anchors ?? SandboxAnchorService(market: market),
        _market = market ?? SupabaseMarketPriceRepository(),
        _priceMode = priceMode ?? (kSandboxPriceModeDefault == 'simulated' ? PriceMode.simulated : PriceMode.live) {
    if (listenToAuth && SupabaseConfig.isConfigured) {
      try {
        _authSub = SupabaseConfig.client.auth.onAuthStateChange.listen(_onAuth);
      } catch (_) {}
    }
    _priceSubs
      ..add(_sim.changes.listen((_) => notifyListeners()))
      ..add(_live.changes.listen((_) => notifyListeners()));
  }

  final SandboxService _service;
  final LessonRepository _lessonRepo;
  final SandboxAnchorService _anchors;
  final MarketPriceRepository _market;
  StreamSubscription<AuthState>? _authSub;
  final List<StreamSubscription<Set<String>>> _priceSubs = [];

  // -------------------------------------------------------------------------
  // Prices and the trading engine
  // -------------------------------------------------------------------------
  late final SimulatedPriceSource _sim = SimulatedPriceSource(engine: () => _engine, clock: this);
  late final LivePriceSource _live = LivePriceSource(repository: _market);
  late final FallbackPriceSource _liveWithFallback = FallbackPriceSource(primary: _live, fallback: _sim);
  PriceMode _priceMode;
  bool _liveStarted = false;

  PriceMode get priceMode => _priceMode;

  /// The PriceSource every price, rate and trade in the trainer reads.
  PriceSource get prices => _priceMode == PriceMode.live ? _liveWithFallback : _sim;

  late final TradableEngine tradable = TradableEngine(() => prices);
  late final TermEngine term = TermEngine(() => prices);

  /// Switches between live market data and simulated prices. Nothing about
  /// trading changes; only where prices come from.
  Future<void> setPriceMode(PriceMode mode) async {
    if (mode == _priceMode) return;
    _priceMode = mode;
    notifyListeners();
    if (mode == PriceMode.live) await _startLive();
  }

  Future<void> _startLive() async {
    if (_priceMode != PriceMode.live) return;
    if (!_liveStarted) {
      _liveStarted = true;
      await _live.start();
    }
    await _live.prefetchHistory(_historyKeys());
  }

  /// Reloads live prices (pull-to-refresh).
  Future<void> refreshPrices() async {
    if (_priceMode == PriceMode.live) await _live.refresh();
  }

  List<String> _historyKeys() => [
        for (final m in SandboxModule.values)
          for (final spec in instrumentsForModule(m))
            if (spec.hasMarketData) spec.priceKey,
        tbondAnchorKey(5),
      ];

  /// How many live prices are in use, and when the newest was published.
  int get liveQuoteCount => _priceMode == PriceMode.live ? _live.liveCount : 0;
  DateTime? get liveUpdatedAt => _priceMode == PriceMode.live ? _live.lastUpdated : null;

  PriceQuote? quoteFor(InstrumentSpec spec) => prices.quote(spec.priceKey);

  /// True when [spec]'s price right now is real market data.
  bool isLivePrice(InstrumentSpec spec) => quoteFor(spec)?.isLive ?? false;

  /// The rate keys a term module reads.
  static List<String> _rateKeys(SandboxModule m) => switch (m) {
        SandboxModule.fd => [
            for (final bank in kFdFallbackRates.keys)
              for (final t in kFdTenures) fdAnchorKey(bank, t),
          ],
        SandboxModule.govSecurities => [
            for (final d in kTbillTenures) tbillAnchorKey(d),
            for (final y in kTbondTenureYears) tbondAnchorKey(y),
          ],
        _ => const [],
      };

  /// True when any price or rate the module shows is live market data.
  bool usesLivePrices(SandboxModule m) =>
      instrumentsForModule(m).any(isLivePrice) || _rateKeys(m).any((k) => prices.quote(k)?.isLive ?? false);

  /// Fast-forward makes simulated prices move. Live prices only move when
  /// the real market does, so tradable modules on live prices run on real
  /// time instead (term modules and the seettu still fast-forward: their
  /// rates are locked in when you open them).
  bool canFastForward(SandboxModule m) => m.hasSimClock && !(m.isTradable && usesLivePrices(m));

  // SimClock (what the simulated prices need from the wallets).
  @override
  int dayFor(SandboxModule m) => m == SandboxModule.trading ? tradingDay : simDay(m);

  @override
  DateTime startDateFor(SandboxModule m) => wallets[m]?.startDate ?? dateOnly(DateTime.now());

  @override
  double? anchorFor(SandboxModule m, String key) => wallets[m]?.anchors[key];

  @override
  double? intradayPrice(String symbol) => liveTradingPrices[symbol];

  bool loading = false;
  bool loaded = false;
  bool busy = false;
  String? error;
  String? _loadedFor;

  Map<SandboxModule, SandboxWallet> wallets = {};
  List<SandboxHolding> holdings = [];
  List<SandboxPosition> positions = [];
  SandboxProgress progress = const SandboxProgress();
  final Map<String, LessonProgress> _lessonState = {};
  Set<String> badges = {};
  Map<String, ChallengeState> challenges = {};
  List<SandboxTrade> recentTrades = [];
  List<SandboxCircle> circles = [];
  Map<SandboxModule, List<Lesson>> lessonCatalogue = {};

  SandboxPriceEngine _engine = SandboxPriceEngine('demo');
  SandboxPriceEngine get engine => _engine;

  final _celebrations = StreamController<SandboxCelebration>.broadcast();
  Stream<SandboxCelebration> get celebrations => _celebrations.stream;

  // Trading session state (kept here so it survives leaving the screen).
  final Map<String, double> liveTradingPrices = {};
  int tradingTickOffset = 0;
  DateTime? _sessionDay;
  double? sessionStartEquity;
  DateTime? sessionStartedAt;
  bool lossLimitHit = false;
  bool _lossLimitXpAwarded = false;
  int sessionTrades = 0;
  final List<UpDownRound> upDownRounds = [];
  bool upDownStatsSeen = false;

  bool get isLoggedIn => _service.isSignedIn;

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------
  void _onAuth(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      _clearData();
      notifyListeners();
    } else if (state.event == AuthChangeEvent.signedIn) {
      load(force: true);
    }
  }

  Future<void> load({bool force = false}) async {
    if (lessonCatalogue.isEmpty) {
      lessonCatalogue = await _lessonRepo.loadAll();
    }
    final uid = _service.userId;
    if (uid == null) {
      _clearData();
      loaded = true;
      notifyListeners();
      return;
    }
    if (loading) return;
    if (!force && loaded && _loadedFor == uid) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final snap = await _service.load();
      if (_engine.seed != uid) _engine = SandboxPriceEngine(uid);
      wallets = {for (final w in snap.wallets) w.module: w};
      holdings = [...snap.holdings];
      positions = [...snap.positions];
      progress = snap.progress;
      _lessonState
        ..clear()
        ..addAll({for (final l in snap.lessons) _lk(l.module, l.lessonId): l});
      badges = snap.badges;
      challenges = {for (final c in snap.challenges) c.id: c};
      recentTrades = [...snap.recentTrades];
      circles = [...snap.circles];
      _loadedFor = uid;
      loaded = true;
      unawaited(_startLive());
      await _ensureAnchors();
      unawaited(_evaluateChallenges());
    } on SandboxException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _clearData() {
    wallets = {};
    holdings = [];
    positions = [];
    progress = const SandboxProgress();
    _lessonState.clear();
    badges = {};
    challenges = {};
    recentTrades = [];
    circles = [];
    upDownRounds.clear();
    liveTradingPrices.clear();
    _loadedFor = null;
    loaded = false;
    error = null;
  }

  /// Wallets whose anchors are missing (migrated, or just reset) get
  /// today's real data. Existing anchors are never overwritten.
  Future<void> _ensureAnchors() async {
    for (final w in wallets.values.toList()) {
      final needed = _requiredAnchorKeys(w.module);
      if (needed.every(w.anchors.containsKey)) continue;
      try {
        final fresh = await _anchors.anchorsFor(w.module);
        wallets[w.module] = await _service.unlockModule(w.module, fresh);
      } catch (_) {}
    }
  }

  List<String> _requiredAnchorKeys(SandboxModule m) => switch (m) {
        SandboxModule.cse => [for (final i in kCseInstruments) i.symbol],
        SandboxModule.gold => [for (final i in kGoldInstruments) i.symbol],
        SandboxModule.trading => [for (final i in kTradingInstruments) i.symbol],
        SandboxModule.fd => [fdAnchorKey(kFdFallbackRates.keys.first, 12)],
        SandboxModule.govSecurities => [tbillAnchorKey(364), tbondAnchorKey(5)],
        SandboxModule.forex => [for (final i in kForexInstruments) i.symbol],
        SandboxModule.communityFund => const [],
      };

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in _priceSubs) {
      s.cancel();
    }
    _live.dispose();
    _sim.dispose();
    _celebrations.close();
    super.dispose();
  }

  void _celebrate(SandboxCelebration c) {
    if (!_celebrations.isClosed) _celebrations.add(c);
  }

  /// Called by the trading screen when it closes, so Home picks up the
  /// latest simulated prices.
  void refreshViews() => notifyListeners();

  // -------------------------------------------------------------------------
  // Modules and wallets
  // -------------------------------------------------------------------------
  bool isUnlocked(SandboxModule m) => wallets.containsKey(m);
  List<SandboxModule> get unlockedModules => SandboxModule.values.where(isUnlocked).toList();

  List<InstrumentSpec> instrumentsFor(SandboxModule m) => instrumentsForModule(m);

  DateTime simDate(SandboxModule m) => wallets[m]?.simDate ?? dateOnly(DateTime.now());
  int simDay(SandboxModule m) => wallets[m]?.simDay ?? 0;
  double balance(SandboxModule m) => wallets[m]?.balance ?? 0;

  List<SandboxHolding> holdingsFor(SandboxModule m) => holdings.where((h) => h.module == m).toList();
  List<SandboxPosition> openPositions(SandboxModule m) =>
      positions.where((p) => p.module == m && p.isOpen).toList();
  List<SandboxPosition> closedPositions(SandboxModule m) =>
      positions.where((p) => p.module == m && !p.isOpen).toList();

  // -------------------------------------------------------------------------
  // Prices and rates
  // -------------------------------------------------------------------------
  double anchorOf(InstrumentSpec spec) => wallets[spec.module]?.anchors[spec.symbol] ?? spec.fallbackPrice;

  /// Day index for the trading module (real calendar days since start).
  int get tradingDay {
    final w = wallets[SandboxModule.trading];
    return w == null ? 0 : daysBetween(w.startDate, DateTime.now());
  }

  double tradingDayOpen(InstrumentSpec spec) => _engine.priceOn(spec, anchorOf(spec), tradingDay);

  /// The market (mid) price of [spec] from the current PriceSource.
  double priceOf(InstrumentSpec spec) => tradable.midPrice(spec);

  /// Daily prices for the last [days] days, ending today.
  List<double> priceHistory(InstrumentSpec spec, {int days = 60}) =>
      [for (final p in prices.history(spec.priceKey, days: days)) p.price];

  /// Daily values of a rate key (FD, T-bill, T-bond) for the last [days] days.
  List<double> rateHistory(String key, {int days = 180}) => [for (final p in prices.history(key, days: days)) p.price];

  /// Price change since the previous close, as %.
  double dayChangePct(InstrumentSpec spec) {
    final q = quoteFor(spec);
    if (q?.changePct case final c?) return c;
    final h = prices.history(spec.priceKey, days: 1);
    if (h.length < 2 || h[h.length - 2].price == 0) return 0;
    return (priceOf(spec) / h[h.length - 2].price - 1) * 100;
  }

  double get gold24kMid => tradable.gold24kMid;

  /// Simulated news that moved simulated prices. Live prices are moved by
  /// real news, so there is none to show for a module on live prices.
  List<NewsEvent> recentNews(SandboxModule m, {int days = 90}) {
    if (usesLivePrices(m)) return const [];
    final d = simDay(m);
    return _engine.newsBetween(m, d - days, d).reversed.toList();
  }

  /// Rates (% p.a.) from the PriceSource. [day] asks the simulation for a
  /// past sim-day instead (used for charts in simulated mode).
  double fdRate(String bank, int months, {int? day}) =>
      day == null ? term.fdRate(bank, months) : _simRate(SandboxModule.fd, fdAnchorKey(bank, months), day);

  double tbillYield(int days, {int? day}) => day == null
      ? term.tbillYield(days)
      : _simRate(SandboxModule.govSecurities, tbillAnchorKey(days), day);

  double tbondYield(int years, {int? day}) => day == null
      ? term.tbondYield(years)
      : _simRate(SandboxModule.govSecurities, tbondAnchorKey(years), day);

  double _simRate(SandboxModule m, String key, int day) => _engine.rateOn(
      m, wallets[m]?.anchors[key] ?? SimulatedPriceSource.fallbackRate(key) ?? 8.0, day);

  /// Current market yield for a T-bond position's remaining life.
  double marketYieldFor(SandboxPosition p) {
    final years = ((p.tenureMonths ?? 60) / 12).round();
    final nearest = kTbondTenureYears.reduce((a, b) => (a - years).abs() <= (b - years).abs() ? a : b);
    return tbondYield(nearest);
  }

  // -------------------------------------------------------------------------
  // Values
  // -------------------------------------------------------------------------
  double holdingPrice(SandboxHolding h) => tradable.holdingPrice(h);

  double holdingValue(SandboxHolding h) => tradable.holdingValue(h);

  double holdingPnl(SandboxHolding h) => tradable.holdingPnl(h);

  /// What an FD / T-bill / T-bond is worth today: what withdrawing it now
  /// would pay (principal plus interest accrued so far).
  double positionValue(SandboxPosition p) => TermEngine.value(p, simDate(p.module));

  List<SandboxCircle> get openCircles => circles.where((c) => c.isOpen).toList();

  double moduleValue(SandboxModule m) {
    final w = wallets[m];
    if (w == null) return 0;
    var v = w.balance;
    for (final h in holdingsFor(m)) {
      v += holdingValue(h);
    }
    for (final p in openPositions(m)) {
      v += positionValue(p);
    }
    if (m == SandboxModule.communityFund) {
      for (final c in openCircles) {
        v += SeettuEngine.value(c);
      }
    }
    return v;
  }

  double moduleReturnPct(SandboxModule m) =>
      isUnlocked(m) ? (moduleValue(m) - kSandboxStartingBalance) / kSandboxStartingBalance * 100 : 0;

  double get totalValue => wallets.keys.fold(0.0, (s, m) => s + moduleValue(m));

  /// Rs 100,000 per unlocked module.
  double get startingTotal => kSandboxStartingBalance * wallets.length;

  double get totalReturnPercent => startingTotal == 0 ? 0 : (totalValue - startingTotal) / startingTotal * 100;

  /// Value by instrument type across every module, for Home's allocation
  /// bar. Keys match the colours Home already uses.
  Map<String, double> get allocationByType {
    // A seettu's net position (owed to you, or by you) counts as cash.
    final map = <String, double>{
      'cash': wallets.values.fold(0.0, (s, w) => s + w.balance) +
          openCircles.fold(0.0, (s, c) => s + SeettuEngine.value(c)),
    };
    for (final h in holdings) {
      final key = h.module == SandboxModule.trading ? 'trading' : h.type;
      map[key] = (map[key] ?? 0) + holdingValue(h);
    }
    for (final p in positions.where((p) => p.isOpen)) {
      final key = p.isFd ? 'fixed_deposit' : 'treasury_bond';
      map[key] = (map[key] ?? 0) + positionValue(p);
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // Trading (cse, gold, trading)
  // -------------------------------------------------------------------------
  TradeQuote quoteTrade(InstrumentSpec spec, String side, double quantity) => tradable.quote(spec, side, quantity);

  SandboxHolding? holdingOf(InstrumentSpec spec) =>
      holdings.firstWhereOrNull((h) => h.module == spec.module && h.symbol == spec.symbol);

  /// Validates input locally (for instant feedback), then calls the
  /// server, which re-checks everything under a wallet lock.
  Future<ActionResult> trade({
    required InstrumentSpec spec,
    required String side,
    required double quantity,
    double? stopLoss,
    double? takeProfit,
    String? note,
  }) async {
    final m = spec.module;
    if (!isLoggedIn) return const ActionResult.fail('Log in to start training.');
    if (!quantity.isFinite || quantity <= 0) return ActionResult.fail(sandboxErrorText('invalid_quantity'));
    if (m == SandboxModule.cse && quantity != quantity.roundToDouble()) {
      return ActionResult.fail(sandboxErrorText('whole_shares_only'));
    }
    if (!isUnlocked(m)) return ActionResult.fail(sandboxErrorText('module_locked'));
    final opening = isOpeningSide(side);
    if (m == SandboxModule.trading && opening && lossLimitHit) {
      return const ActionResult.fail('Trading is paused for today: you reached your daily loss limit.');
    }
    if (side == 'short' && progress.level < kShortSellingLevel) {
      return ActionResult.fail(sandboxErrorText('short_locked'));
    }
    final quote = quoteTrade(spec, side, quantity);
    final held = holdingOf(spec);
    final problem = tradable.check(spec: spec, side: side, quantity: quantity, cash: balance(m), held: held);
    if (problem != null) return ActionResult.fail(sandboxErrorText(problem));

    busy = true;
    notifyListeners();
    try {
      final res = await _service.trade(
        module: m,
        spec: spec,
        side: side,
        quantity: quantity,
        price: quote.price,
        fee: quote.fee,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        note: note,
      );
      _applyWallet(res['wallet']);
      holdings.removeWhere((h) => h.module == m && h.symbol == spec.symbol);
      if (res['holding'] is Map) holdings.add(SandboxHolding.fromJson(Map<String, dynamic>.from(res['holding'] as Map)));
      final pnl = (res['realised_pnl'] as num?)?.toDouble();
      recentTrades.insert(
        0,
        SandboxTrade(
          id: '${res['trade_id']}',
          module: m,
          symbol: spec.symbol,
          side: side,
          quantity: quantity,
          price: quote.price,
          fee: quote.fee,
          cashDelta: opening ? -quote.total : quote.total,
          realisedPnl: pnl,
          note: note,
          simDate: m == SandboxModule.trading ? dateOnly(DateTime.now()) : simDate(m),
          resetBatch: wallets[m]?.resetBatch ?? '',
          createdAt: DateTime.now(),
        ),
      );
      if (m == SandboxModule.trading) {
        sessionTrades++;
        if (opening) unawaited(_tradingHabits(spec, quote.price, quantity, side == 'short', stopLoss));
      }
      unawaited(_evaluateChallenges());
      return ActionResult.ok(realisedPnl: pnl);
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _tradingHabits(InstrumentSpec spec, double entry, double qty, bool isShort, double? stopLoss) async {
    if (stopLoss == null) return;
    await _setChallenge('tr_stop_loss', 1);
    await awardHabitXp('stop_loss_used', 5);
    final equity = moduleValue(SandboxModule.trading);
    final risk = TradeMath.riskShare(entry: entry, stopLoss: stopLoss, quantity: qty, equity: equity, isShort: isShort);
    if (risk <= kMaxRiskPerTrade) {
      await _setChallenge('tr_risk10', (challenges['tr_risk10']?.progress ?? 0) + 1);
      await awardHabitXp('low_risk_trade', 5);
    }
  }

  Future<ActionResult> setRiskLevels(SandboxHolding h, {double? stopLoss, double? takeProfit}) async {
    try {
      final res = await _service.setRiskLevels(h.symbol, stopLoss, takeProfit);
      final updated = SandboxHolding.fromJson(res);
      final i = holdings.indexWhere((x) => x.id == updated.id);
      if (i >= 0) holdings[i] = updated;
      notifyListeners();
      return const ActionResult.ok();
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    }
  }

  void _applyWallet(dynamic raw) {
    if (raw is Map) {
      final w = SandboxWallet.fromJson(Map<String, dynamic>.from(raw));
      wallets[w.module] = w;
    }
  }

  // -------------------------------------------------------------------------
  // Positions (FD, T-bills, T-bonds)
  // -------------------------------------------------------------------------
  Future<ActionResult> _open(Future<Map<String, dynamic>> Function() call) async {
    if (!isLoggedIn) return const ActionResult.fail('Log in to start training.');
    busy = true;
    notifyListeners();
    try {
      final res = await call();
      _applyWallet(res['wallet']);
      final p = SandboxPosition.fromJson(Map<String, dynamic>.from(res['position'] as Map));
      positions.add(p);
      unawaited(_evaluateChallenges());
      return ActionResult.ok(data: p);
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<ActionResult> openFd({
    required String bank,
    required int months,
    required double amount,
    required bool monthly,
    bool autoRenew = false,
  }) {
    if (!amount.isFinite || amount <= 0) return Future.value(ActionResult.fail(sandboxErrorText('invalid_amount')));
    if (amount > balance(SandboxModule.fd)) {
      return Future.value(ActionResult.fail(sandboxErrorText('insufficient_balance')));
    }
    var rate = term.fdRate(bank, months);
    if (monthly) rate = FdMath.monthlyPayoutRate(rate);
    return _open(() => _service.openPosition(
          module: SandboxModule.fd,
          type: 'fd',
          label: bank,
          principal: roundRs(amount),
          cost: roundRs(amount),
          rate: _r4(rate),
          payoutType: monthly ? 'monthly' : 'maturity',
          tenureMonths: months,
          autoRenew: autoRenew,
        ));
  }

  Future<ActionResult> buyTbill({required int days, required double face}) {
    if (!face.isFinite || face <= 0) return Future.value(ActionResult.fail(sandboxErrorText('invalid_amount')));
    final y = _r4(term.tbillYield(days));
    final cost = GovMath.tbillPrice(face, y, days);
    if (cost > balance(SandboxModule.govSecurities)) {
      return Future.value(ActionResult.fail(sandboxErrorText('insufficient_balance')));
    }
    return _open(() => _service.openPosition(
          module: SandboxModule.govSecurities,
          type: 'tbill',
          label: '$days-day T-Bill',
          principal: roundRs(face),
          cost: cost,
          rate: y,
          payoutType: 'discount',
          tenureDays: days,
        ));
  }

  Future<ActionResult> buyTbond({required int years, required double face}) {
    if (!face.isFinite || face <= 0) return Future.value(ActionResult.fail(sandboxErrorText('invalid_amount')));
    if (face > balance(SandboxModule.govSecurities)) {
      return Future.value(ActionResult.fail(sandboxErrorText('insufficient_balance')));
    }
    // New bonds are issued at face value with a coupon equal to the market
    // yield, rounded to 0.25%.
    final y = term.tbondYield(years);
    final coupon = TermEngine.couponFor(y);
    return _open(() => _service.openPosition(
          module: SandboxModule.govSecurities,
          type: 'tbond',
          label: '$years-year T-Bond',
          principal: roundRs(face),
          cost: roundRs(face),
          rate: _r4(y),
          couponRate: coupon,
          payoutType: 'semi_annual',
          tenureMonths: years * 12,
        ));
  }

  /// What withdrawing [p] now would pay: principal plus interest accrued so
  /// far at the locked rate.
  double closeValue(SandboxPosition p) => TermEngine.withdrawalAmount(p, simDate(p.module));

  /// The full early-withdrawal picture for the position sheet.
  EarlyWithdrawal earlyWithdrawal(SandboxPosition p) => TermEngine.earlyWithdrawal(p, simDate(p.module));

  Future<ActionResult> closePosition(SandboxPosition p) async {
    final estimate = closeValue(p);
    busy = true;
    notifyListeners();
    try {
      final res = await _service.closePosition(p.id, estimate);
      // The server computes the payout; use its figure.
      final amount = (res['amount'] as num?)?.toDouble() ?? estimate;
      _applyWallet(res['wallet']);
      final updated = SandboxPosition.fromJson(Map<String, dynamic>.from(res['position'] as Map));
      final i = positions.indexWhere((x) => x.id == p.id);
      if (i >= 0) positions[i] = updated;
      final pnl = (res['realised_pnl'] as num?)?.toDouble();
      recentTrades.insert(
        0,
        SandboxTrade(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          module: p.module,
          symbol: p.label,
          side: p.isFd ? 'fd_break' : (p.isTbill ? 'tbill_break' : 'tbond_sell'),
          quantity: p.principal,
          price: amount / p.principal * 100,
          fee: 0,
          cashDelta: amount,
          realisedPnl: pnl,
          refId: p.id,
          simDate: simDate(p.module),
          resetBatch: p.resetBatch,
          createdAt: DateTime.now(),
        ),
      );
      if (p.isFd) unawaited(_setChallenge('fd_early_cost', 1));
      if (p.isTbond) unawaited(_setChallenge('gov_sell_after_rise', 1));
      return ActionResult.ok(realisedPnl: pnl);
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Fast-forward
  // -------------------------------------------------------------------------
  Future<FastForwardOutcome> fastForward(SandboxModule m, int days) async {
    final w = wallets[m];
    if (w == null || !m.hasSimClock) return FastForwardOutcome(ok: false, error: sandboxErrorText('module_locked'));
    if (!canFastForward(m)) {
      return const FastForwardOutcome(
          ok: false, error: 'Prices here are live market data, so they move in real time. Switch to simulated prices to fast-forward.');
    }
    final plan = FastForwardPlanner(_engine)
        .plan(wallet: w, days: days, positions: positions, holdings: holdings, circles: openCircles);
    final before = w.balance;
    final valueBefore = moduleValue(m);
    busy = true;
    notifyListeners();
    try {
      final res = await _service.fastForward(m, days, plan.events);
      _applyWallet(res['wallet']);
      _applyEventsLocally(m, plan);
      _sim.notifyChanged();
      for (final e in plan.events.where((e) => e.isMaturity || e.kind == 'seettu_pot')) {
        _celebrate(SandboxCelebration(
          kind: 'maturity',
          title: e.label,
          subtitle: e.kind == 'seettu_pot' ? '${formatRs(e.amount)} pot paid to you' : '${formatRs(e.amount)} back in your wallet',
          icon: Icons.celebration_outlined,
        ));
      }
      unawaited(_evaluateChallenges());
      return FastForwardOutcome(ok: true, plan: plan, balanceBefore: before, valueBefore: valueBefore);
    } on SandboxException catch (e) {
      return FastForwardOutcome(ok: false, error: e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Mirrors what sandbox_fast_forward() did on the server.
  void _applyEventsLocally(SandboxModule m, FastForwardPlan plan) {
    for (final e in plan.events) {
      if (e.circleId != null) {
        final i = circles.indexWhere((c) => c.id == e.circleId);
        if (i >= 0) {
          var c = circles[i];
          c = e.kind == 'seettu_pay'
              ? c.copyWith(roundsPaid: c.roundsPaid + 1, totalPaid: roundRs(c.totalPaid + e.amount))
              : c.copyWith(potReceived: e.amount, potSimDate: e.simDate);
          if (c.roundsPaid >= c.members && c.potTaken) c = c.copyWith(status: 'completed');
          circles[i] = c;
        }
      } else if (e.positionId != null) {
        final i = positions.indexWhere((p) => p.id == e.positionId);
        if (i < 0) continue;
        final p = positions[i];
        positions[i] = switch (e.kind) {
          'fd_interest' || 'tbond_coupon' => p.copyWith(
              totalPaid: p.totalPaid + e.amount, payoutsCount: p.payoutsCount + 1, lastPayoutSimDate: e.simDate),
          'fd_renew' => p.copyWith(
              principal: roundRs(p.principal + e.amount),
              startSimDate: e.simDate,
              maturitySimDate: addMonths(e.simDate, p.tenureMonths ?? 12),
              renewCount: p.renewCount + 1,
              lastPayoutSimDate: e.simDate),
          _ => p.copyWith(status: 'matured', closedAmount: e.amount, closedSimDate: e.simDate),
        };
      }
      recentTrades.insert(
        0,
        SandboxTrade(
          id: 'local-${e.hashCode}-${e.simDate.millisecondsSinceEpoch}',
          module: m,
          symbol: e.symbol ?? e.label,
          side: e.kind,
          quantity: 1,
          price: e.amount,
          fee: 0,
          cashDelta: e.kind == 'fd_renew' ? 0 : (e.isOutflow ? -e.amount : e.amount),
          refId: e.positionId ?? e.circleId,
          simDate: e.simDate,
          resetBatch: wallets[m]?.resetBatch ?? '',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Community fund (seettu)
  // -------------------------------------------------------------------------
  /// Whether the community wallet could keep paying every round of every
  /// circle, plus this one.
  bool canJoinCircle({required int members, required double contribution}) => SeettuEngine.canJoin(
      balance: balance(SandboxModule.communityFund), open: openCircles, members: members, contribution: contribution);

  /// The simulated default in [c], once it has happened.
  SeettuDefault? visibleDefault(SandboxCircle c) =>
      SeettuEngine.visibleDefault(c, _engine.seed, simDate(SandboxModule.communityFund));

  Future<ActionResult> joinCircle({
    required String name,
    required int members,
    required double contribution,
    required int myTurn,
    required String trust,
  }) async {
    if (!isLoggedIn) return const ActionResult.fail('Log in to start training.');
    if (!isUnlocked(SandboxModule.communityFund)) return ActionResult.fail(sandboxErrorText('module_locked'));
    if (!contribution.isFinite || contribution <= 0) return ActionResult.fail(sandboxErrorText('invalid_amount'));
    if (myTurn < 1 || myTurn > members) return ActionResult.fail(sandboxErrorText('invalid_turn'));
    if (!canJoinCircle(members: members, contribution: contribution)) {
      return ActionResult.fail(sandboxErrorText('seettu_unaffordable'));
    }
    busy = true;
    notifyListeners();
    try {
      final res = await _service.joinCircle(
          name: name, members: members, contribution: roundRs(contribution), myTurn: myTurn, trust: trust);
      _applyWallet(res['wallet']);
      final c = SandboxCircle.fromJson(Map<String, dynamic>.from(res['circle'] as Map));
      circles.add(c);
      SandboxTrade row(String side, double cash) => SandboxTrade(
            id: 'local-$side-${c.id}',
            module: SandboxModule.communityFund,
            symbol: c.name,
            side: side,
            quantity: 1,
            price: cash.abs(),
            fee: 0,
            cashDelta: cash,
            refId: c.id,
            simDate: c.startSimDate,
            resetBatch: c.resetBatch,
            createdAt: DateTime.now(),
          );
      recentTrades.insert(0, row('seettu_pay', -c.contribution));
      if (c.potTaken) recentTrades.insert(0, row('seettu_pot', c.potReceived!));
      unawaited(_evaluateChallenges());
      return ActionResult.ok(data: c);
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Up-or-Down
  // -------------------------------------------------------------------------
  Future<ActionResult> startUpDown(String symbol, double stake, {required bool predictUp}) async {
    if (!stake.isFinite || stake <= 0) return ActionResult.fail(sandboxErrorText('invalid_amount'));
    if (lossLimitHit) return const ActionResult.fail('Trading is paused for today: you reached your daily loss limit.');
    if (stake > balance(SandboxModule.trading)) return ActionResult.fail(sandboxErrorText('insufficient_balance'));
    try {
      final res = await _service.updownStake(symbol, roundRs(stake), predictUp ? 'up' : 'down');
      _applyWallet(res['wallet']);
      notifyListeners();
      return ActionResult.ok(data: '${res['stake_id']}');
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    }
  }

  Future<ActionResult> settleUpDown(String stakeId, UpDownRound round) async {
    try {
      final res = await _service.updownSettle(stakeId, round.won);
      _applyWallet(res['wallet']);
      upDownRounds.add(round);
      if (upDownRounds.length <= kUpDownStatsRounds) {
        unawaited(_setChallenge('tr_updown10', math.min(upDownRounds.length, kUpDownStatsRounds - 1)));
      }
      notifyListeners();
      return const ActionResult.ok();
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    }
  }

  /// The stats screen was read after 10 rounds: that's the lesson.
  Future<void> markUpDownStatsRead() async {
    upDownStatsSeen = true;
    await _setChallenge('tr_updown10', kUpDownStatsRounds);
    await awardHabitXp('read_stats', 10);
  }

  // -------------------------------------------------------------------------
  // Trading safety rules
  // -------------------------------------------------------------------------
  void beginTradingSession() {
    final today = dateOnly(DateTime.now());
    if (_sessionDay != today) {
      _sessionDay = today;
      sessionStartEquity = moduleValue(SandboxModule.trading);
      lossLimitHit = false;
      _lossLimitXpAwarded = false;
      sessionTrades = 0;
    }
    sessionStartedAt ??= DateTime.now();
  }

  double get sessionLoss => math.max(0, (sessionStartEquity ?? 0) - moduleValue(SandboxModule.trading));
  double get sessionLossLimit => (sessionStartEquity ?? kSandboxStartingBalance) * kDailyLossLimitShare;

  /// Returns true the moment the daily limit is first reached.
  bool checkLossLimit() {
    if (lossLimitHit || sessionStartEquity == null) return false;
    if (sessionLoss >= sessionLossLimit) {
      lossLimitHit = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Stopping when the limit hits is the habit we reward.
  Future<void> acknowledgeLossLimit() async {
    if (_lossLimitXpAwarded) return;
    _lossLimitXpAwarded = true;
    await awardHabitXp('respected_loss_limit', 15);
  }

  Future<void> endTradingSession({bool tookBreak = false}) async {
    final started = sessionStartedAt;
    sessionStartedAt = null;
    if (sessionTrades > 0 && !lossLimitHit) await _setChallenge('tr_session_limit', 1);
    if (tookBreak && started != null) await awardHabitXp('took_break', 10);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------
  Future<ActionResult> reset({SandboxModule? module, bool resetLearning = false}) async {
    busy = true;
    notifyListeners();
    try {
      await _service.reset(module: module, resetLearning: resetLearning);
      if (module == null || module == SandboxModule.trading) {
        upDownRounds.clear();
        upDownStatsSeen = false;
        liveTradingPrices.clear();
        tradingTickOffset = 0;
        _sessionDay = null;
      }
      busy = false;
      await load(force: true);
      return const ActionResult.ok();
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Lessons and quizzes
  // -------------------------------------------------------------------------
  static String _lk(SandboxModule m, String id) => '${m.id}|$id';

  List<Lesson> lessonsFor(SandboxModule m) => lessonCatalogue[m] ?? const [];
  LessonProgress? lessonState(SandboxModule m, String id) => _lessonState[_lk(m, id)];
  bool isLessonRead(SandboxModule m, String id) => lessonState(m, id)?.isRead ?? false;
  bool isLessonPassed(SandboxModule m, String id) => lessonState(m, id)?.isPassed ?? false;

  bool isLessonUnlocked(SandboxModule m, int index) {
    if (index <= 0) return true;
    final lessons = lessonsFor(m);
    return index < lessons.length && isLessonPassed(m, lessons[index - 1].id);
  }

  bool firstLessonPassed(SandboxModule m) {
    final lessons = lessonsFor(m);
    return lessons.isNotEmpty && isLessonPassed(m, lessons.first.id);
  }

  int lessonsPassed(SandboxModule m) => lessonsFor(m).where((l) => isLessonPassed(m, l.id)).length;

  /// 0..1 across lessons and challenges.
  double moduleProgress(SandboxModule m) {
    final lessons = lessonsFor(m);
    final ch = challengesFor(m);
    final total = lessons.length + ch.length;
    if (total == 0) return 0;
    final done = lessonsPassed(m) + ch.where((c) => challenges[c.id]?.isDone ?? false).length;
    return done / total;
  }

  Future<ActionResult> markLessonRead(SandboxModule m, String lessonId) async {
    if (!isLoggedIn) return const ActionResult.fail('Log in to start training.');
    // Having read the cards opens the quiz locally even if saving fails:
    // it's navigation, not money, and the quiz submission records the read.
    final old = lessonState(m, lessonId);
    _lessonState[_lk(m, lessonId)] = LessonProgress(
      module: m,
      lessonId: lessonId,
      readAt: old?.readAt ?? DateTime.now(),
      quizScore: old?.quizScore,
      attempts: old?.attempts ?? 0,
      completedAt: old?.completedAt,
    );
    notifyListeners();
    try {
      _applyProgress(await _service.lessonRead(m, lessonId));
      notifyListeners();
      return const ActionResult.ok();
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    }
  }

  /// Records a quiz attempt; unlocks the simulator after the module's first
  /// passed quiz. Returns whether it passed.
  Future<ActionResult> submitQuiz(SandboxModule m, String lessonId, int correct, int total) async {
    if (!isLoggedIn) return const ActionResult.fail('Log in to start training.');
    final score = total == 0 ? 0.0 : (correct / total * 100);
    try {
      final res = await _service.submitQuiz(m, lessonId, double.parse(score.toStringAsFixed(2)));
      final passed = res['passed'] == true;
      final old = lessonState(m, lessonId);
      _lessonState[_lk(m, lessonId)] = LessonProgress(
        module: m,
        lessonId: lessonId,
        readAt: old?.readAt ?? DateTime.now(),
        quizScore: math.max(old?.quizScore ?? 0, score),
        attempts: (old?.attempts ?? 0) + 1,
        completedAt: passed ? (old?.completedAt ?? DateTime.now()) : old?.completedAt,
      );
      _applyProgress(res);
      if (passed && !isUnlocked(m)) await unlock(m);
      if (passed && lessonsPassed(m) == lessonsFor(m).length) await _awardBadge('scholar');
      notifyListeners();
      return ActionResult.ok(data: passed);
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    }
  }

  Future<ActionResult> unlock(SandboxModule m) async {
    try {
      final anchors = await _anchors.anchorsFor(m);
      wallets[m] = await _service.unlockModule(m, anchors);
      _celebrate(SandboxCelebration(
        kind: 'unlock',
        title: '${m.shortTitle} simulator unlocked',
        subtitle: '${formatRs(kSandboxStartingBalance)} of virtual money to practise with',
        icon: Icons.lock_open_rounded,
      ));
      notifyListeners();
      return const ActionResult.ok();
    } on SandboxException catch (e) {
      return ActionResult.fail(e.message);
    }
  }

  void _applyProgress(Map<String, dynamic> res) {
    if (!res.containsKey('xp')) return;
    final before = progress.level;
    progress = SandboxProgress.fromJson(res);
    if (res['leveled_up'] == true || progress.level > before) {
      _celebrate(SandboxCelebration(
        kind: 'level_up',
        title: 'Level ${progress.level}: ${LevelMath.titleFor(progress.level)}',
        subtitle: progress.level == kShortSellingLevel ? 'Short selling unlocked in Trading' : null,
        icon: Icons.military_tech_outlined,
      ));
    }
    if (progress.streak >= 7 && !badges.contains('on_fire')) unawaited(_awardBadge('on_fire'));
  }

  Future<void> awardHabitXp(String reason, int amount) async {
    if (!isLoggedIn) return;
    try {
      _applyProgress(await _service.awardHabitXp(reason, amount));
      notifyListeners();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Challenges and badges
  // -------------------------------------------------------------------------
  /// For challenges completed by doing something in the UI (opening a
  /// comparison, a quote, ...).
  Future<void> markChallengeEvent(String id) async {
    final spec = challengeById(id);
    if (spec == null) return;
    await _setChallenge(id, spec.target);
  }

  final Set<String> _inFlight = {};

  Future<void> _setChallenge(String id, int value) async {
    final spec = challengeById(id);
    if (spec == null || !isLoggedIn || _inFlight.contains(id)) return;
    final current = challenges[id];
    if (current?.isDone ?? false) return;
    final v = math.min(value, spec.target);
    if (v <= (current?.progress ?? 0)) return;
    _inFlight.add(id);
    try {
      final res = await _service.challengeProgress(id, v, spec.target);
      if (res['challenge'] is Map) {
        challenges[id] = ChallengeState.fromJson(Map<String, dynamic>.from(res['challenge'] as Map));
      }
      _applyProgress(res);
      if (res['completed_now'] == true) {
        _celebrate(SandboxCelebration(
          kind: 'challenge',
          title: 'Challenge complete: ${spec.title}',
          subtitle: '+50 XP',
          icon: Icons.flag_circle_outlined,
        ));
        if (spec.badgeId != null) await _awardBadge(spec.badgeId!);
      }
      notifyListeners();
    } catch (_) {
      // Progress is retried on the next evaluation.
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> _awardBadge(String id) async {
    if (badges.contains(id) || !isLoggedIn) return;
    try {
      final res = await _service.awardBadge(id);
      badges = {...badges, id};
      _applyProgress(res);
      final b = badgeById(id);
      if (res['new_badge'] == true && b != null) {
        _celebrate(SandboxCelebration(kind: 'badge', title: 'Badge earned: ${b.title}', subtitle: b.description, icon: b.icon));
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Progress for the challenges that can be read straight off the state.
  @visibleForTesting
  Map<String, int> derivedChallengeProgress() {
    final out = <String, int>{};
    final cse = holdingsFor(SandboxModule.cse);
    bool traded(SandboxModule m, Set<String> sides, [String? symbol]) => recentTrades
        .any((t) => t.module == m && sides.contains(t.side) && (symbol == null || t.symbol == symbol));

    if (isUnlocked(SandboxModule.cse)) {
      out['cse_first_share'] = cse.isNotEmpty || traded(SandboxModule.cse, {'buy'}) ? 1 : 0;
      out['cse_three_sectors'] = cse.map((h) => instrumentBySymbol(h.symbol)?.sector ?? h.symbol).toSet().length;
      out['cse_first_dividend'] = traded(SandboxModule.cse, {'dividend'}) ? 1 : 0;
      final now = simDate(SandboxModule.cse);
      out['cse_hold_year'] = cse.fold(0, (best, h) => math.max(best, daysBetween(h.openedSimDate, now)));
      out['cse_no_panic'] = cse.any((h) => _heldThroughDip(h, now)) ? 1 : 0;
    }
    if (isUnlocked(SandboxModule.fd)) {
      final fds = positions.where((p) => p.module == SandboxModule.fd);
      out['fd_first'] = fds.isNotEmpty ? 1 : 0;
      out['fd_ladder'] = fds.where((p) => p.isOpen).map((p) => p.maturitySimDate).toSet().length;
    }
    if (isUnlocked(SandboxModule.gold)) {
      final gold = holdingsFor(SandboxModule.gold);
      out['gold_first_gram'] = gold.fold(0.0, (s, h) => s + h.quantity) >= 1 ? 1 : 0;
      out['gold_jewel_vs_bullion'] = (traded(SandboxModule.gold, {'sell'}, kGoldBullion.symbol) ? 1 : 0) +
          (traded(SandboxModule.gold, {'sell'}, kGoldJewellery.symbol) ? 1 : 0);
      final w = wallets[SandboxModule.gold]!;
      out['gold_inflation'] = gold.any((h) => _engine
              .newsBetween(SandboxModule.gold, daysBetween(w.startDate, h.openedSimDate), w.simDay)
              .any((n) => n.kind == 'inflation'))
          ? 1
          : 0;
    }
    if (isUnlocked(SandboxModule.govSecurities)) {
      final gov = positions.where((p) => p.module == SandboxModule.govSecurities);
      out['gov_first_tbill'] = gov.any((p) => p.isTbill) ? 1 : 0;
      out['gov_two_coupons'] = gov.where((p) => p.isTbond).fold(0, (best, p) => math.max(best, p.payoutsCount));
    }
    if (isUnlocked(SandboxModule.forex)) {
      final fx = holdingsFor(SandboxModule.forex);
      out['fx_first'] = fx.isNotEmpty || traded(SandboxModule.forex, {'buy'}) ? 1 : 0;
      out['fx_two_currencies'] = fx.length;
      out['fx_profit'] = recentTrades
              .any((t) => t.module == SandboxModule.forex && t.side == 'sell' && (t.realisedPnl ?? 0) > 0)
          ? 1
          : 0;
    }
    if (isUnlocked(SandboxModule.communityFund)) {
      out['cf_join'] = circles.isNotEmpty ? 1 : 0;
      out['cf_pot'] = circles.any((c) => c.potTaken) ? 1 : 0;
      out['cf_complete'] = circles.any((c) => c.status == 'completed') ? 1 : 0;
    }
    return out;
  }

  /// Price fell 10% below cost at some point, and the user kept holding
  /// for at least 30 sim-days afterwards.
  bool _heldThroughDip(SandboxHolding h, DateTime now) {
    final spec = instrumentBySymbol(h.symbol);
    final w = wallets[SandboxModule.cse];
    if (spec == null || w == null) return false;
    final from = daysBetween(w.startDate, h.openedSimDate);
    final to = w.simDay - 30;
    for (var d = from; d <= to; d++) {
      if (_engine.priceOn(spec, anchorOf(spec), d) <= h.averagePrice * 0.9) return true;
    }
    return false;
  }

  Future<void> _evaluateChallenges() async {
    for (final e in derivedChallengeProgress().entries) {
      if (e.value > 0) await _setChallenge(e.key, e.value);
    }
  }

  // -------------------------------------------------------------------------
  // Hub helpers
  // -------------------------------------------------------------------------
  String get levelTitle => LevelMath.titleFor(progress.level);

  /// The module touched most recently (trade, lesson or quiz).
  SandboxModule? get continueModule {
    DateTime? best;
    SandboxModule? module;
    void consider(SandboxModule m, DateTime? t) {
      if (t != null && (best == null || t.isAfter(best!))) {
        best = t;
        module = m;
      }
    }

    for (final t in recentTrades.take(20)) {
      consider(t.module, t.createdAt);
    }
    for (final l in _lessonState.values) {
      consider(l.module, l.completedAt ?? l.readAt);
    }
    return module;
  }

  /// "Lesson 3: Dividends and P/E" or "Practise in the simulator".
  String nextStepFor(SandboxModule m) {
    final lessons = lessonsFor(m);
    for (final l in lessons) {
      if (!isLessonPassed(m, l.id)) return isLessonRead(m, l.id) ? 'Quiz: ${l.title}' : 'Lesson: ${l.title}';
    }
    final open = challengesFor(m).where((c) => !(challenges[c.id]?.isDone ?? false)).toList();
    if (open.isNotEmpty) return 'Challenge: ${open.first.title}';
    return 'Practise in the simulator';
  }

  // -------------------------------------------------------------------------
  // History
  // -------------------------------------------------------------------------
  /// Full history for [m] (all reset batches), newest first.
  Future<List<SandboxTrade>> loadHistory(SandboxModule m) => _service.fetchTrades(m);

  /// Performance numbers for the portfolio tab, from current-batch trades.
  ModulePerformance performance(SandboxModule m) {
    final batch = wallets[m]?.resetBatch;
    final trades = recentTrades.where((t) => t.module == m && t.resetBatch == batch).toList();
    final pnls = [
      for (final t in trades)
        if (t.realisedPnl != null && t.side != 'updown_payout') t.realisedPnl!,
    ];
    return ModulePerformance(
      totalReturn: moduleValue(m) - kSandboxStartingBalance,
      feesPaid: trades.fold(0.0, (s, t) => s + t.fee),
      income: trades.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.cashDelta),
      best: pnls.isEmpty ? null : pnls.reduce(math.max),
      worst: pnls.isEmpty ? null : pnls.reduce(math.min),
      winRate: pnls.isEmpty ? null : pnls.where((p) => p > 0).length / pnls.length,
      closedTrades: pnls.length,
    );
  }

  // -------------------------------------------------------------------------
  // FinBot
  // -------------------------------------------------------------------------
  /// One compact, clearly-labelled line for FinBot's context. Null when the
  /// user hasn't unlocked anything.
  String? finBotSummary() {
    if (!isLoggedIn || (wallets.isEmpty && _lessonState.isEmpty)) return null;
    final parts = [
      for (final m in unlockedModules)
        '${m.shortTitle} ${formatRs(moduleValue(m), decimals: 0)} '
            '(${moduleReturnPct(m) >= 0 ? '+' : ''}${moduleReturnPct(m).toStringAsFixed(1)}%)',
    ];
    final recent = _lessonState.values.where((l) => l.isPassed).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final titles = [
      for (final l in recent.take(3))
        lessonsFor(l.module).firstWhereOrNull((x) => x.id == l.lessonId)?.title ?? l.lessonId,
    ];
    return 'Investment Trainer (SIMULATED practice with virtual money — not the user\'s real money or real '
        'holdings; prices: ${_priceMode == PriceMode.live ? 'real Sri Lankan market data where available' : 'simulated'}): '
        'level ${progress.level} "$levelTitle", ${progress.xp} XP'
        '${parts.isEmpty ? '' : '; modules: ${parts.join(', ')}'}'
        '${titles.isEmpty ? '' : '; recently completed lessons: ${titles.join(', ')}'}.';
  }

  static double _r4(double v) => (v * 10000).roundToDouble() / 10000;
}
