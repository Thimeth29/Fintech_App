// lib/services/asset_data_service.dart
//
// A common interface so the Asset Analytics page can render CSE stocks,
// Government Securities (treasury bonds/bills), Fixed Deposits, and Gold
// with the exact same UI. CSE data is live (see cse_service.dart); the
// other three don't have a free public live-data API, so this ships with
// clearly-labelled reference figures that are easy to swap for a live
// feed later (e.g. CBSL's published rates, a bank-rate scraper, or a
// gold price API) once you have a data source/API key for them.

import '../models/market_data_model.dart';
import 'cse_service.dart';

abstract class AssetDataService {
  String get assetLabel;
  bool get isLiveData;
  Future<List<StockQuote>> fetchTopGainers();
  Future<List<StockQuote>> fetchTopLosers();
}

class CseAssetDataService implements AssetDataService {
  final CseService _cse = CseService();

  @override
  String get assetLabel => 'CSE';

  @override
  bool get isLiveData => true;

  @override
  Future<List<StockQuote>> fetchTopGainers() => _cse.fetchTopGainers();

  @override
  Future<List<StockQuote>> fetchTopLosers() => _cse.fetchTopLosers();
}

class SecuritiesAssetDataService implements AssetDataService {
  @override
  String get assetLabel => 'SEC';

  @override
  bool get isLiveData => false;

  @override
  Future<List<StockQuote>> fetchTopGainers() async => [
    StockQuote(symbol: '3M T-Bill', name: '3-Month Treasury Bill', price: 8.95, changePercentage: 0.15, volume: 0),
    StockQuote(symbol: '6M T-Bill', name: '6-Month Treasury Bill', price: 9.40, changePercentage: 0.10, volume: 0),
    StockQuote(symbol: '5Y T-Bond', name: '5-Year Treasury Bond', price: 10.85, changePercentage: 0.05, volume: 0),
  ];

  @override
  Future<List<StockQuote>> fetchTopLosers() async => [
    StockQuote(symbol: '1Y T-Bill', name: '1-Year Treasury Bill', price: 9.10, changePercentage: -0.08, volume: 0),
  ];
}

class FixedDepositAssetDataService implements AssetDataService {
  @override
  String get assetLabel => 'FD';

  @override
  bool get isLiveData => false;

  @override
  Future<List<StockQuote>> fetchTopGainers() async => [
    StockQuote(symbol: '12M FD', name: 'Avg. 12-Month Fixed Deposit', price: 10.50, changePercentage: 0.25, volume: 0),
    StockQuote(symbol: '24M FD', name: 'Avg. 24-Month Fixed Deposit', price: 11.00, changePercentage: 0.10, volume: 0),
  ];

  @override
  Future<List<StockQuote>> fetchTopLosers() async => [
    StockQuote(symbol: '3M FD', name: 'Avg. 3-Month Fixed Deposit', price: 8.25, changePercentage: -0.20, volume: 0),
  ];
}

class GoldAssetDataService implements AssetDataService {
  @override
  String get assetLabel => 'GOLD';

  @override
  bool get isLiveData => false;

  @override
  Future<List<StockQuote>> fetchTopGainers() async => [
    StockQuote(symbol: 'XAU/g', name: 'Gold, per gram (LKR, reference)', price: 24800, changePercentage: 1.20, volume: 0),
  ];

  @override
  Future<List<StockQuote>> fetchTopLosers() async => [
    StockQuote(symbol: 'XAU/oz', name: 'Gold, per ounce (LKR, reference)', price: 771000, changePercentage: -0.40, volume: 0),
  ];
}

AssetDataService assetDataServiceFor(String assetType) {
  switch (assetType) {
    case 'CSE':
      return CseAssetDataService();
    case 'SEC':
      return SecuritiesAssetDataService();
    case 'FD':
      return FixedDepositAssetDataService();
    case 'GOLD':
      return GoldAssetDataService();
    default:
      return CseAssetDataService();
  }
}
