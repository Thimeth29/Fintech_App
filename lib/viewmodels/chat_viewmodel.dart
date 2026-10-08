import 'package:flutter/foundation.dart';
import '../core/config/supabase_config.dart';
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

  /// Loads past chat messages from Supabase `chat_messages` table
  Future<void> loadChatHistory(String userId) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client;
      final rows = await client
          .from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (rows.isNotEmpty) {
        messages.clear();
        for (final row in rows) {
          final roleStr = row['role'] as String?;
          final content = row['content'] as String?;
          if (content != null) {
            messages.add(
              ChatMessageModel(
                role: roleStr == 'user' ? ChatRole.user : ChatRole.bot,
                content: content,
              ),
            );
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Loads live CSE market data (and user's financial history) into FinBot
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
        // Also load past chat history
        await loadChatHistory(userId);
      }
      final snapshot = await FinancialInsightService().buildSnapshot(
        expenses: expenses,
        investmentActions: actions,
      );
      _aiService = AiService(financialContext: snapshot);
      _contextReady = true;
    } catch (_) {
    } finally {
      _loadingContext = false;
    }
  }

  Future<void> send(String text) async {
    final userText = text.trim();
    if (userText.isEmpty) return;

    messages.add(ChatMessageModel(role: ChatRole.user, content: userText));
    isSending = true;
    notifyListeners();

    _saveMessageToCloud(role: 'user', content: userText);

    if (!_contextReady) {
      await loadFinancialContext();
    }

    final reply = await _aiService.ask(userText, history: messages);
    messages.add(ChatMessageModel(role: ChatRole.bot, content: reply));

    _saveMessageToCloud(role: 'bot', content: reply);

    isSending = false;
    notifyListeners();
  }

  void _saveMessageToCloud({required String role, required String content}) async {
    if (!SupabaseConfig.isConfigured) return;
    final client = SupabaseConfig.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('chat_messages').insert({
        'user_id': user.id,
        'role': role,
        'content': content,
      });
    } catch (_) {}
  }
}
