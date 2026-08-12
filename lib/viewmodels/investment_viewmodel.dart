// lib/viewmodels/investment_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';
import '../models/investment_action_model.dart';
import '../models/market_data_model.dart';
import '../services/cse_service.dart';
import '../services/expense_service.dart';
import '../services/financial_insight_service.dart';
import '../services/investment_service.dart';

/// One of the four investment categories shown on the "My Investments"
/// hub page. Each links through to an AssetAnalyticsScreen for that type.
class AssetCategory {
  final String code; // 'CSE' | 'SEC' | 'FD' | 'GOLD'
  final String label;
  const AssetCategory(this.code, this.label);
}

class InvestmentViewModel extends ChangeNotifier {
  final InvestmentService _service = InvestmentService();
  final CseService _cse = CseService();
  final FinancialInsightService _insightService = FinancialInsightService();

  static const List<AssetCategory> categories = [
    AssetCategory('CSE', 'CSE'),
    AssetCategory('SEC', 'SEC'),
    AssetCategory('FD', 'FD'),
    AssetCategory('GOLD', 'GOLD'),
  ];

  bool isLoading = false;
  List<InvestmentActionModel> recentActions = [];

  // Live "Market Pulse" — ASPI / S&P SL20 index levels.
  bool isLoadingIndices = false;
  List<MarketIndex> indices = [];

  // AI-agent-generated daily insight, grounded in live CSE data plus
  // (when logged in) the user's own spending and investment activity.
  bool isLoadingInsight = false;
  String? aiInsight;

  Future<void> loadHistory(String? userId) async {
    if (userId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      recentActions = await _service.fetchActions(userId);
    } catch (_) {
      recentActions = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMarketPulse() async {
    isLoadingIndices = true;
    notifyListeners();
    try {
      indices = await _cse.fetchIndices();
    } catch (_) {
      indices = [];
    } finally {
      isLoadingIndices = false;
      notifyListeners();
    }
  }

  /// Asks FinBot (as a financial agent, not just a chatbot) to summarise
  /// what the user should know today, grounded in live CSE data plus
  /// their own expenses/investment history when they're logged in.
  Future<void> loadAiInsight(String? userId) async {
    isLoadingInsight = true;
    aiInsight = null;
    notifyListeners();
    try {
      List<ExpenseModel>? expenses;
      if (userId != null) {
        try {
          expenses = await ExpenseService().fetchExpenses(userId);
        } catch (_) {
          expenses = null;
        }
      }
      aiInsight = await _insightService.generateDailyInsight(
        expenses: expenses,
        investmentActions: recentActions,
      );
    } catch (_) {
      aiInsight = "FinBot couldn't generate an insight right now — try again in a moment.";
    } finally {
      isLoadingInsight = false;
      notifyListeners();
    }
  }
}
