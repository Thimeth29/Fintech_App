// lib/services/market_rates_service.dart
//
// Live USD/LKR exchange rate for the Home dashboard's "Market today" card,
// from open.er-api.com (free, no API key required, updates daily).

import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketRatesService {
  static const Duration _timeout = Duration(seconds: 8);

  Future<double?> fetchUsdLkr() async {
    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = decoded['rates'] as Map<String, dynamic>?;
      final rate = rates?['LKR'];
      return (rate as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }
}
