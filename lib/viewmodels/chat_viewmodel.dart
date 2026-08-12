import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../models/expense_model.dart';
import '../models/investment_action_model.dart';
import '../services/ai_service.dart';
import '../services/expense_service.dart';
import '../services/financial_insight_service.dart';
import '../services/investment_service.dart';

class ChatViewModel extends ChangeNotifier {
  AiService _aiService = AiService();
  bool _contextReady = false;
  bool _loadingContext = false;

  final List<ChatMessageModel> messages = [];
  bool isSending = false;

  void seed(String contextNote) {
    if (messages.isEmpty) {
      messages.add(
        ChatMessageModel(
          role: ChatRole.bot,
          content:
              "Hi, I'm FinBot 👋 $contextNote\nAsk me anything about "
              'investing on the CSE, budgeting, or your finances.',
        ),
      );
    }
  }

  /// Loads live CSE market data (and, when [userId] is given, the user's
  /// own spending/investment history) and re-grounds FinBot's system
  /// instruction in it. This is what turns FinBot from a generic chatbot
  /// into an agent that reasons over real, current numbers — call it as
  /// soon as the chat screen opens so context is ready before the user
  /// sends their first message.
  Future<void> loadFinancialContext({String? userId}) async {
    if (_contextReady || _loadingContext) return;
    _loadingContext = true;
    try {
      List<ExpenseModel>? expenses;
      List<InvestmentActionModel>? actions;
      if (userId != null) {
        try {
          expenses = await ExpenseService().fetchExpenses(userId);
        } catch (_) {
          expenses = null;
        }
        try {
          actions = await InvestmentService().fetchActions(userId);
        } catch (_) {
          actions = null;
        }
      }
      final snapshot = await FinancialInsightService().buildSnapshot(
        expenses: expenses,
        investmentActions: actions,
      );
      _aiService = AiService(financialContext: snapshot);
      _contextReady = true;
    } catch (_) {
      // Keep the default, context-free AiService() if the snapshot
      // couldn't be built (e.g. fully offline) — FinBot still works,
      // just without live-data grounding.
    } finally {
      _loadingContext = false;
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    messages.add(ChatMessageModel(role: ChatRole.user, content: text.trim()));
    isSending = true;
    notifyListeners();

    if (!_contextReady) {
      await loadFinancialContext();
    }

    final reply = await _aiService.ask(text.trim(), history: messages);
    messages.add(ChatMessageModel(role: ChatRole.bot, content: reply));

    isSending = false;
    notifyListeners();
  }
}
