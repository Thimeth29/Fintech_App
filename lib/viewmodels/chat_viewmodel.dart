import 'package:flutter/foundation.dart';
import '../core/config/supabase_config.dart';
import '../models/chat_message_model.dart';
import '../models/expense_model.dart';
import '../models/investment_action_model.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../services/financial_insight_service.dart';
import '../services/investment_service.dart';

class ChatViewModel extends ChangeNotifier {
  AiService _aiService = AiService();
  bool _contextReady = false;
  bool _loadingContext = false;

  /// Active conversation session
  ChatSessionModel? currentSession;

  /// All past chat sessions grouped by conversation
  List<ChatSessionModel> sessions = [];
  bool isLoadingHistory = false;

  /// Messages in the active session
  List<ChatMessageModel> get messages => currentSession?.messages ?? [];
  bool isSending = false;

  /// Starts a fresh, clean chat session without loading past conversation messages into the view
  void startNewChat([String? contextNote]) {
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final greeting = (contextNote != null && contextNote.isNotEmpty)
        ? "Hi, I'm FinBot 👋 $contextNote\nAsk me anything about investing on the CSE, budgeting, or your finances."
        : "Hi, I'm FinBot 👋 your AI Personal Financial Coach for Sri Lanka 🇱🇰\n\nAsk me anything about Colombo Stock Exchange (CSE), Fixed Deposits, Treasury Bills, 50/30/20 Budgeting, or EPF/ETF.";

    currentSession = ChatSessionModel(
      id: newId,
      title: 'New Chat',
      category: 'General Advisory',
      updatedAt: DateTime.now(),
      messages: [
        ChatMessageModel(
          role: ChatRole.bot,
          content: greeting,
        ),
      ],
    );
    notifyListeners();
  }

  /// Switch the active chat view to a past conversation from history
  void selectSession(ChatSessionModel session) {
    currentSession = session;
    notifyListeners();
  }

  /// Delete a past session from history
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((s) => s.id == sessionId);
    if (currentSession?.id == sessionId) {
      startNewChat();
    } else {
      notifyListeners();
    }
  }

  /// Legacy helper for initial seed
  void seed(String contextNote) {
    if (currentSession == null) {
      startNewChat(contextNote);
    }
  }

  /// Loads past chat history from Supabase and groups them into categorized conversation sessions
  Future<void> loadChatHistory(String userId) async {
    if (!SupabaseConfig.isConfigured || isLoadingHistory) return;
    isLoadingHistory = true;
    try {
      final client = SupabaseConfig.client;
      final rows = await client
          .from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (rows.isNotEmpty) {
        final allMsgs = <ChatMessageModel>[];
        for (final row in rows) {
          final roleStr = row['role'] as String?;
          final content = row['content'] as String?;
          final createdAt = row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null;
          if (content != null) {
            allMsgs.add(
              ChatMessageModel(
                role: roleStr == 'user' ? ChatRole.user : ChatRole.bot,
                content: content,
                timestamp: createdAt,
              ),
            );
          }
        }

        // Group messages into distinct sessions if separated by more than 35 minutes
        final reconstructedSessions = <ChatSessionModel>[];
        if (allMsgs.isNotEmpty) {
          var currentChunk = <ChatMessageModel>[allMsgs.first];
          for (int i = 1; i < allMsgs.length; i++) {
            final prev = allMsgs[i - 1];
            final curr = allMsgs[i];
            final gap = curr.timestamp.difference(prev.timestamp).inMinutes.abs();

            if (gap > 35) {
              _addReconstructedSession(reconstructedSessions, currentChunk);
              currentChunk = [curr];
            } else {
              currentChunk.add(curr);
            }
          }
          if (currentChunk.isNotEmpty) {
            _addReconstructedSession(reconstructedSessions, currentChunk);
          }
        }

        // Sort sessions with newest first
        reconstructedSessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        sessions = reconstructedSessions;
        notifyListeners();
      }
    } catch (_) {
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  void _addReconstructedSession(
    List<ChatSessionModel> list,
    List<ChatMessageModel> chunk,
  ) {
    if (chunk.isEmpty) return;
    final firstUserMsg = chunk.firstWhere(
      (m) => m.role == ChatRole.user,
      orElse: () => chunk.first,
    );
    final title = firstUserMsg.content.length > 36
        ? '${firstUserMsg.content.substring(0, 36)}...'
        : firstUserMsg.content;
    final category = ChatSessionModel.detectCategory(firstUserMsg.content);
    final lastTime = chunk.last.timestamp;

    list.add(
      ChatSessionModel(
        id: 'hist_${lastTime.millisecondsSinceEpoch}',
        title: title,
        category: category,
        updatedAt: lastTime,
        messages: List.from(chunk),
      ),
    );
  }

  /// Loads live CSE market data (and user's financial history) into FinBot
  Future<void> loadFinancialContext({String? userId, String? sandboxSummary}) async {
    if (_contextReady || _loadingContext) return;
    _loadingContext = true;
    try {
      List<ExpenseModel>? expenses;
      List<InvestmentActionModel>? actions;
      Map<String, dynamic>? profile;
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
        try {
          profile = await AuthService().fetchProfile();
        } catch (_) {
          profile = null;
        }
        // Load past history in background without blowing away the active screen
        loadChatHistory(userId);
      }
      final snapshot = await FinancialInsightService().buildSnapshot(
        expenses: expenses,
        investmentActions: actions,
        profile: profile,
        userId: userId,
        sandboxSummary: sandboxSummary,
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

    if (currentSession == null) {
      startNewChat();
    }

    final session = currentSession!;
    final isFirstUserTurn = !session.messages.any((m) => m.role == ChatRole.user);

    if (isFirstUserTurn) {
      session.title = userText.length > 36 ? '${userText.substring(0, 36)}...' : userText;
      session.category = ChatSessionModel.detectCategory(userText);
    }
    session.updatedAt = DateTime.now();

    // Ensure session is in session history list
    if (!sessions.any((s) => s.id == session.id)) {
      sessions.insert(0, session);
    }

    session.messages.add(ChatMessageModel(role: ChatRole.user, content: userText));
    isSending = true;
    notifyListeners();

    _saveMessageToCloud(role: 'user', content: userText);

    if (!_contextReady) {
      await loadFinancialContext();
    }

    final reply = await _aiService.ask(userText, history: session.messages);
    session.messages.add(ChatMessageModel(role: ChatRole.bot, content: reply));
    session.updatedAt = DateTime.now();

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
