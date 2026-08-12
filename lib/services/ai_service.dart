// lib/services/ai_service.dart
//
// FinBot's brain: wraps Google Gemini (google_generative_ai) and turns it
// into a finance-aware agent by grounding every conversation in a live
// "financial snapshot" — today's CSE market data plus (when available)
// the user's own spending/investment activity — passed in as a system
// instruction. That's what lets FinBot answer things like "how am I
// doing this month?" or "what's moving on the CSE today?" with real
// numbers instead of generic advice, and act like a financial agent
// rather than a plain chatbot.

import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/config/gemini_config.dart';
import '../models/chat_message_model.dart';

class AiService {
  late final GenerativeModel _model;

  /// [financialContext], when provided, is a short text snapshot (live CSE
  /// gainers/losers, index levels, the user's expense/portfolio summary,
  /// etc.) that gets baked into the model's system instruction so every
  /// reply in this chat session is grounded in real, current data.
  AiService({String? financialContext})
    : _model = GenerativeModel(
        model: GeminiConfig.model,
        apiKey: GeminiConfig.apiKey,
        systemInstruction: Content.system(_systemPrompt(financialContext)),
      );

  static String _systemPrompt(String? financialContext) {
    final buffer = StringBuffer()
      ..writeln(
        'You are FinBot, the built-in financial agent for FinSmart, a personal '
        'finance app for users saving, budgeting, and investing via the Colombo '
        'Stock Exchange (CSE) in Sri Lanka. Read the live data snapshot below '
        '(when present) and use it to give specific, numbers-based suggestions '
        'and insights instead of generic advice. Keep replies short — a few '
        'sentences or a few bullet points. Use LKR for currency. Whenever you '
        'suggest a trade, allocation change, or spending cut, add one brief, '
        'balanced risk note. You are not a licensed financial advisor, so frame '
        'suggestions as options to weigh, not instructions.',
      );
    if (financialContext != null && financialContext.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('--- Live data snapshot (ground your answer in this) ---')
        ..writeln(financialContext.trim());
    }
    return buffer.toString();
  }

  Future<String> ask(
    String prompt, {
    List<ChatMessageModel> history = const [],
  }) async {
    if (!GeminiConfig.isConfigured) {
      return "FinBot isn't connected yet - a Gemini API key needs to be "
          'added before I can answer questions.';
    }

    try {
      final List<Content> geminiHistory = [];

      // Convert existing chat history to Gemini Content format
      for (final m in history) {
        if (m.role == ChatRole.user) {
          // Use Content.text for user messages
          geminiHistory.add(Content.text(m.content));
        } else {
          // Use Content.model for assistant responses
          geminiHistory.add(Content.model([TextPart(m.content)]));
        }
      }

      // Start a chat session with the accumulated history
      final chat = _model.startChat(history: geminiHistory);

      // Send the current user prompt
      final response = await chat.sendMessage(Content.text(prompt));

      return response.text ?? "Sorry, I couldn't generate a response.";
    } catch (e) {
      return 'FinBot ran into an error and could not answer just now (Gemini). Error: $e';
    }
  }
}
