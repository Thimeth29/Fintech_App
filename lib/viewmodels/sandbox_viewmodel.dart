import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../models/instrument_model.dart';
import '../services/sandbox_service.dart';

class SandboxViewModel extends ChangeNotifier {
  final SandboxService _sandboxService = SandboxService();

  double virtualBalance = 100000.00;
  bool isLoading = false;
  String? errorMessage;

  final List<Instrument> instruments = [
    Instrument(
      symbol: 'JKH.N',
      name: 'John Keells Holdings',
      type: 'stock',
      currentPrice: 145.50,
    ),
    Instrument(
      symbol: 'COMB.N',
      name: 'Commercial Bank',
      type: 'stock',
      currentPrice: 98.20,
    ),
    Instrument(
      symbol: 'GOLD',
      name: 'Gold (per gram)',
      type: 'gold',
      currentPrice: 22500.00,
    ),
    Instrument(
      symbol: 'FD_12M',
      name: '12-Month Fixed Deposit',
      type: 'fixed_deposit',
      currentPrice: 1.00,
    ),
    Instrument(
      symbol: 'TBOND_5Y',
      name: '5-Year Treasury Bond',
      type: 'treasury_bond',
      currentPrice: 1.00,
    ),
  ];

  final List<Holding> holdings = [];

  /// Loads portfolio virtual balance & holdings from Supabase Cloud
  Future<void> loadSandboxData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final portfolio = await _sandboxService.fetchPortfolio();
      if (portfolio != null && portfolio['virtual_balance'] != null) {
        virtualBalance = (portfolio['virtual_balance'] as num).toDouble();
      }

      final rawHoldings = await _sandboxService.fetchHoldings();
      holdings.clear();

      for (final raw in rawHoldings) {
        final symbol = raw['symbol'] as String?;
        final qty = (raw['quantity'] as num?)?.toDouble() ?? 0.0;
        final avgPrice = (raw['average_price'] as num?)?.toDouble() ?? 0.0;
        final name = raw['name'] as String? ?? symbol ?? 'Asset';
        final type = raw['instrument_type'] as String? ?? 'stock';

        if (symbol != null && qty > 0) {
          final matchedInstrument = instruments.firstWhere(
            (i) => i.symbol == symbol,
            orElse: () => Instrument(
              symbol: symbol,
              name: name,
              type: type,
              currentPrice: avgPrice,
            ),
          );

          holdings.add(
            Holding(
              instrument: matchedInstrument,
              quantity: qty,
              averageBuyPrice: avgPrice,
            ),
          );
        }
      }
    } catch (e) {
      errorMessage = 'Could not sync sandbox data with cloud.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> buy(Instrument instrument, double quantity) async {
    final cost = instrument.currentPrice * quantity;

    if (quantity <= 0) {
      errorMessage = 'Enter a quantity greater than zero';
      notifyListeners();
      return false;
    }
    if (cost > virtualBalance) {
      errorMessage = 'Insufficient virtual balance';
      notifyListeners();
      return false;
    }

    // Local optimistic update
    virtualBalance -= cost;

    final existing = holdings
        .where((h) => h.instrument.symbol == instrument.symbol)
        .firstOrNull;
    if (existing != null) {
      final totalCost = (existing.averageBuyPrice * existing.quantity) + cost;
      existing.quantity += quantity;
      existing.averageBuyPrice = totalCost / existing.quantity;
    } else {
      holdings.add(
        Holding(
          instrument: instrument,
          quantity: quantity,
          averageBuyPrice: instrument.currentPrice,
        ),
      );
    }

    errorMessage = null;
    notifyListeners();

    // Sync to Supabase
    try {
      await _sandboxService.buy(
        symbol: instrument.symbol,
        name: instrument.name,
        instrumentType: instrument.type,
        price: instrument.currentPrice,
        quantity: quantity,
      );
    } catch (_) {
      // Keep optimistic update locally
    }

    return true;
  }

  Future<bool> sell(Instrument instrument, double quantity) async {
    final existing = holdings
        .where((h) => h.instrument.symbol == instrument.symbol)
        .firstOrNull;

    if (existing == null || existing.quantity < quantity) {
      errorMessage = 'You don\'t own enough of this instrument to sell';
      notifyListeners();
      return false;
    }

    final proceeds = instrument.currentPrice * quantity;
    virtualBalance += proceeds;
    existing.quantity -= quantity;

    if (existing.quantity <= 0) {
      holdings.remove(existing);
    }

    errorMessage = null;
    notifyListeners();

    // Sync to Supabase
    try {
      await _sandboxService.sell(
        symbol: instrument.symbol,
        price: instrument.currentPrice,
        quantity: quantity,
      );
    } catch (_) {
      // Keep optimistic update
    }

    return true;
  }

  double get portfolioValue {
    double total = virtualBalance;
    for (final h in holdings) {
      total += h.quantity * h.instrument.currentPrice;
    }
    return total;
  }

  double get totalReturnPercent {
    return ((portfolioValue - 100000.00) / 100000.00) * 100;
  }
}
