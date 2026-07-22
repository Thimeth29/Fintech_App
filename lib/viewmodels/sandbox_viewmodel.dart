// lib/viewmodels/sandbox_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../models/instrument_model.dart';

class SandboxViewModel extends ChangeNotifier {
  double virtualBalance = 100000.00;

  // Dummy instruments for now — replace with a Supabase fetch from `instruments` table later
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

  String? errorMessage;

  bool buy(Instrument instrument, double quantity) {
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
    return true;
  }

  bool sell(Instrument instrument, double quantity) {
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
