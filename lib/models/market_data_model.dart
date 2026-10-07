// lib/models/market_data_model.dart
//
// Lightweight model for a single CSE (Colombo Stock Exchange) quote,
// as returned by the unofficial cse.lk/api endpoints (topGainers,
// topLooses, tradeSummary, todaySharePrice).

class StockQuote {
  final String symbol;
  final String name;
  final double price;
  final double changePercentage;
  final double volume;

  StockQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercentage,
    required this.volume,
  });

  bool get isUp => changePercentage >= 0;

  // The CSE API responses use slightly different key names across
  // endpoints (e.g. "changePercentage" vs "percentageChange"), so we
  // read defensively with fallbacks instead of assuming one shape.
  factory StockQuote.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return StockQuote(
      symbol: (json['symbol'] ?? json['securityId'] ?? '').toString(),
      name: (json['name'] ?? json['securityName'] ?? '').toString(),
      price: asDouble(json['price'] ?? json['lastTradedPrice']),
      changePercentage: asDouble(
        json['changePercentage'] ?? json['percentageChange'],
      ),
      volume: asDouble(json['tradeVolume'] ?? json['volume']),
    );
  }
}

/// A single CSE market index reading (e.g. ASPI, S&P SL20), as returned by
/// the unofficial cse.lk/api "aspiData" / "snpData" endpoints. Used to power
/// the live "Market Pulse" strip on the Investments hub.
class MarketIndex {
  final String name;
  final double value;
  final double change;
  final double changePercentage;

  MarketIndex({
    required this.name,
    required this.value,
    required this.change,
    required this.changePercentage,
  });

  bool get isUp => changePercentage >= 0;

  factory MarketIndex.fromJson(String name, Map<String, dynamic> json) {
    double asDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return MarketIndex(
      name: name,
      value: asDouble(json['value'] ?? json['indexValue']),
      change: asDouble(json['change']),
      changePercentage: asDouble(
        json['changePercentage'] ?? json['percentageChange'],
      ),
    );
  }
}
