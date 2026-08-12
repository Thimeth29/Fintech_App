// lib/viewmodels/asset_analytics_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../models/market_data_model.dart';
import '../models/investment_action_model.dart';
import '../services/asset_data_service.dart';
import '../services/investment_service.dart';

/// Powers the analytics page for a single asset type (CSE / SEC / FD /
/// GOLD). Same shape for every asset class so the UI, charts, and
/// insight logic are fully reused — only the data source differs.
class AssetAnalyticsViewModel extends ChangeNotifier {
  final String assetType;
  final AssetDataService _dataService;
  final InvestmentService _investmentService = InvestmentService();

  AssetAnalyticsViewModel(this.assetType)
    : _dataService = assetDataServiceFor(assetType);

  bool isLoading = false;
  bool get isLiveData => _dataService.isLiveData;

  List<StockQuote> gainers = [];
  List<StockQuote> losers = [];
  List<String> insights = [];
  String suggestedAction = '';
  List<InvestmentActionModel> history = [];

  Future<void> load({String? userId}) async {
    isLoading = true;
    notifyListeners();

    gainers = await _dataService.fetchTopGainers();
    losers = await _dataService.fetchTopLosers();
    insights = _buildInsights();
    suggestedAction = _buildSuggestedAction();

    if (userId != null) {
      try {
        history = (await _investmentService.fetchActions(userId))
            .where((a) => a.assetType == assetType)
            .toList();
      } catch (_) {
        history = [];
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> logAction({
    required String userId,
    required String symbol,
    required String action,
    required double amount,
  }) async {
    try {
      await _investmentService.logAction(
        InvestmentActionModel(
          userId: userId,
          assetType: assetType,
          symbol: symbol,
          action: action,
          amount: amount,
        ),
      );
      await load(userId: userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<String> _buildInsights() {
    final list = <String>[];
    if (gainers.isNotEmpty) {
      final top = gainers.first;
      list.add(
        '${top.name} (${top.symbol}) leads today at '
        '${top.changePercentage >= 0 ? "+" : ""}${top.changePercentage.toStringAsFixed(2)}%.',
      );
    }
    if (losers.isNotEmpty) {
      final worst = losers.first;
      list.add(
        '${worst.name} (${worst.symbol}) is the weakest at '
        '${worst.changePercentage.toStringAsFixed(2)}% — worth a closer look before acting.',
      );
    }
    if (!isLiveData) {
      list.add(
        'These are reference figures, not a live feed — treat them as a '
        'starting point and confirm current rates with your bank/broker.',
      );
    }
    return list;
  }

  String _buildSuggestedAction() {
    switch (assetType) {
      case 'CSE':
        return gainers.isNotEmpty
            ? 'Research ${gainers.first.name} fundamentals before buying into '
                  "today's momentum — don't chase the price alone."
            : 'Check the market snapshot again once trading data is available.';
      case 'SEC':
        return 'Government securities suit capital preservation — consider laddering '
            'maturities (3M/6M/1Y) instead of locking everything into one tenor.';
      case 'FD':
        return 'Compare fixed deposit rates across a few licensed banks before committing, '
            'and match the tenor to when you\'ll actually need the money.';
      case 'GOLD':
        return 'Gold works best as a small hedge (5-10% of a portfolio) rather than a '
            'primary holding — avoid buying purely because the price just moved.';
      default:
        return 'Review the data above before making a decision.';
    }
  }
}
