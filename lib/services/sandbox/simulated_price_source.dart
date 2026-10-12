// lib/services/sandbox/simulated_price_source.dart
//
// PriceSource backed by the seeded random-walk engine (price_engine.dart).
// Each module's prices start from its wallet's anchors (real prices
// captured when the module was unlocked) and move with that module's
// fast-forward clock; the trading module runs on its intraday ticks.
// Works with no network at all, so it doubles as the offline / demo mode
// and as the fallback behind live prices.

import 'dart:async';

import '../../core/sandbox/sandbox_config.dart';
import '../../models/sandbox_models.dart';
import 'price_engine.dart';
import 'price_source.dart';

/// What the simulation needs to know about the trainer's state. The view
/// model implements this from its wallets.
abstract class SimClock {
  /// Day index on the module's price path (0 = the day it started).
  int dayFor(SandboxModule m);

  /// The calendar date of day 0 for the module.
  DateTime startDateFor(SandboxModule m);

  /// The module's starting value for [key] (an instrument's price or a
  /// rate), or null when none was captured.
  double? anchorFor(SandboxModule m, String key);

  /// The latest intraday tick for a trading-module symbol, if the trading
  /// screen is running one.
  double? intradayPrice(String symbol);
}

class SimulatedPriceSource extends PriceSource {
  SimulatedPriceSource({required SandboxPriceEngine Function() engine, required this.clock}) : _engine = engine;

  final SandboxPriceEngine Function() _engine;
  final SimClock clock;
  final _changes = StreamController<Set<String>>.broadcast();

  /// Instruments by price key (and by symbol, for older callers). Both gold
  /// products share GOLD24K; the bullion spec is the reference.
  static final Map<String, InstrumentSpec> _byKey = () {
    final map = <String, InstrumentSpec>{};
    for (final m in SandboxModule.values) {
      for (final spec in instrumentsForModule(m)) {
        map.putIfAbsent(spec.priceKey, () => spec);
        map.putIfAbsent(spec.symbol, () => spec);
      }
    }
    map[kGold24kKey] = kGoldBullion;
    return map;
  }();

  @override
  String get label => 'Simulated prices';

  @override
  Stream<Set<String>> get changes => _changes.stream;

  /// Tell listeners prices moved (fast-forward, a reset, a new tick).
  void notifyChanged([Set<String> keys = const {}]) {
    if (!_changes.isClosed) _changes.add(keys);
  }

  @override
  bool followsSimClock(String key) => true;

  @override
  PriceQuote? quote(String key) {
    final v = _valueOn(key, null);
    return v == null ? null : PriceQuote(key: key, price: v, origin: PriceOrigin.simulated);
  }

  @override
  List<PricePoint> history(String key, {int days = 60}) {
    final module = moduleForKey(key);
    if (module == null) return const [];
    final today = clock.dayFor(module);
    final start = clock.startDateFor(module);
    return [
      for (var d = today - days; d <= today; d++)
        if (_valueOn(key, d) case final v?) PricePoint(addDays(start, d), v),
    ];
  }

  /// Which module [key] belongs to (null for unknown keys).
  static SandboxModule? moduleForKey(String key) {
    if (_byKey[key] case final spec?) return spec.module;
    if (key.startsWith('FD|')) return SandboxModule.fd;
    if (key.startsWith('TBILL_') || key.startsWith('TBOND_')) return SandboxModule.govSecurities;
    return null;
  }

  /// The simulated value of [key] on sim [day] (today when null).
  double? _valueOn(String key, int? day) {
    final engine = _engine();
    final spec = _byKey[key];
    if (spec != null) {
      final anchor = clock.anchorFor(spec.module, spec.symbol) ?? spec.fallbackPrice;
      if (spec.module == SandboxModule.trading && day == null) {
        return clock.intradayPrice(spec.symbol) ?? engine.priceOn(spec, anchor, clock.dayFor(spec.module));
      }
      return engine.priceOn(spec, anchor, day ?? clock.dayFor(spec.module));
    }
    final module = moduleForKey(key);
    if (module == null) return null;
    final base = clock.anchorFor(module, key) ?? fallbackRate(key);
    if (base == null) return null;
    return engine.rateOn(module, base, day ?? clock.dayFor(module));
  }

  /// The configured fallback for a rate key (FD|bank|m, TBILL_d, TBOND_yY).
  static double? fallbackRate(String key) {
    if (key.startsWith('FD|')) {
      final parts = key.split('|');
      if (parts.length != 3) return null;
      return kFdFallbackRates[parts[1]]?[int.tryParse(parts[2])] ?? 8.0;
    }
    final bill = RegExp(r'^TBILL_(\d+)$').firstMatch(key);
    if (bill != null) return kTbillFallbackYields[int.parse(bill.group(1)!)] ?? 8.5;
    final bond = RegExp(r'^TBOND_(\d+)Y$').firstMatch(key);
    if (bond != null) return kTbondFallbackYields[int.parse(bond.group(1)!)] ?? 10.0;
    return null;
  }

  @override
  Future<void> dispose() async => _changes.close();
}
