import 'dart:async';
import 'dart:math';
import '../models/instrument.dart';
import 'price_source.dart';

/// Offline/demo price source using a bounded random walk. Useful for
/// development, screenshots, and unit tests when you don't want to hit
/// Supabase — swap for [LiveSupabasePriceSource] to trade against real
/// scraped market data. Account balances stay virtual either way.
class SimulatedPriceSource implements PriceSource {
  final Random _rng;
  final Map<String, double> _prices = {};
  final Map<String, double> _dayOpenPrices = {};
  final Map<String, DateTime> _updatedAt = {};
  final StreamController<void> _controller = StreamController<void>.broadcast();
  Timer? _timer;
  List<Instrument> _instruments = [];

  SimulatedPriceSource({int? seed}) : _rng = seed != null ? Random(seed) : Random();

  @override
  Stream<void> get updates => _controller.stream;

  @override
  Future<void> start(List<Instrument> instruments) async {
    _instruments = instruments;
    for (final i in instruments) {
      _prices.putIfAbsent(i.id, () => i.basePrice);
      _dayOpenPrices.putIfAbsent(i.id, () => i.basePrice);
      _updatedAt[i.id] = DateTime.now();
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  void _tick() {
    for (final instrument in _instruments) {
      if (instrument.category != InstrumentCategory.tradable) continue;
      final current = _prices[instrument.id] ?? instrument.basePrice;
      // Gaussian-ish drift via sum of two uniforms, scaled by volatility.
      final noise = (_rng.nextDouble() + _rng.nextDouble() - 1);
      final drift = current * instrument.volatility * noise;
      final next = (current + drift).clamp(current * 0.5, current * 1.5);
      _prices[instrument.id] = next;
      _updatedAt[instrument.id] = DateTime.now();
    }
    if (!_controller.isClosed) _controller.add(null);
  }

  /// Call once per simulated trading day to reset the "daily change" baseline.
  void rollDay() {
    _dayOpenPrices
      ..clear()
      ..addAll(_prices);
  }

  @override
  double priceOf(String instrumentId) => _prices[instrumentId] ?? 0;

  @override
  double dailyChangePctOf(String instrumentId) {
    final open = _dayOpenPrices[instrumentId];
    final current = _prices[instrumentId];
    if (open == null || current == null || open == 0) return 0;
    return ((current - open) / open) * 100;
  }

  @override
  DateTime? lastUpdatedAt(String instrumentId) => _updatedAt[instrumentId];

  @override
  Map<String, double> snapshot() => Map.unmodifiable(_prices);

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
