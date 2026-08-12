// lib/models/instrument_model.dart
class Instrument {
  final String symbol;
  final String name;
  final String
  type; // 'stock', 'fixed_deposit', 'gold', 'forex', 'treasury_bond'
  double currentPrice;

  Instrument({
    required this.symbol,
    required this.name,
    required this.type,
    required this.currentPrice,
  });
}

class Holding {
  final Instrument instrument;
  double quantity;
  double averageBuyPrice;

  Holding({
    required this.instrument,
    required this.quantity,
    required this.averageBuyPrice,
  });
}
