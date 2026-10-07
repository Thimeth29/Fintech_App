// lib/services/ai_service.dart
//
// FinBot's brain: wraps Google Gemini (google_generative_ai & REST HTTP)
// and grounds every conversation in a live "financial snapshot".

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/config/gemini_config.dart';
import '../models/chat_message_model.dart';

class AiService {
  final String? _financialContext;

  static String _workingModel = 'gemini-1.5-flash';

  static const List<String> _candidateModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  ];

  AiService({String? financialContext}) : _financialContext = financialContext;

  GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: GeminiConfig.apiKey,
      systemInstruction: Content.system(_systemPrompt(_financialContext)),
    );
  }

  static String _systemPrompt(String? financialContext) {
    final buffer = StringBuffer()
      ..writeln(
        'You are FinBot 🤖🇱🇰, the premier AI Personal Financial Coach and Investment Trainer for Sri Lanka.\n'
        'Your mission is to build financial literacy, empower users to manage LKR budgets, understand Colombo Stock Exchange (CSE) investments, and make smart decisions regarding Treasury Bills, Fixed Deposits, EPF, ETF, and Taxes.\n\n'
        '### CORE TRAINING RULES & KNOWLEDGE:\n'
        '1. **Colombo Stock Exchange (CSE)**:\n'
        '   - Explain ASPI (All Share Price Index) & S&P SL20.\n'
        '   - Guide users on blue-chip stocks (e.g., JKH, COMB, HNB, SAMP, HAYL, DIAL).\n'
        '   - Teach key concepts: Dividend Yield, P/E Ratio, Market vs Limit Orders, and Sandbox practice.\n'
        '2. **Sri Lanka Fixed Income**:\n'
        '   - Compare Treasury Bills (91, 182, 364 days) backed by the Central Bank of Sri Lanka vs Commercial Bank Fixed Deposits.\n'
        '   - Highlight tax treatment (WHT / APIT) and risk profiles.\n'
        '3. **Personal LKR Budgeting**:\n'
        '   - Teach 50/30/20 Rule: 50% Needs, 30% Wants, 20% Investments & Savings.\n'
        '   - Provide practical tips for managing daily Sri Lankan expenses.\n'
        '4. **Retirement & Welfare**:\n'
        '   - Explain EPF (8% employee + 12% employer = 20%) and ETF (3% employer).\n\n'
        '### RESPONSE FORMATTING:\n'
        '- Always format currency as LKR (e.g. LKR 25,000).\n'
        '- Use clear headings, bullet points, and helpful Sri Lanka emojis (🇱🇰, 📈, 📊, 💡).\n'
        '- Keep answers practical, structured, and easy to read on mobile screens.\n'
        '- Always append a 1-line financial disclaimer note.',
      );
    if (financialContext != null && financialContext.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('--- LIVE SRI LANKA FINANCIAL CONTEXT SNAPSHOT ---')
        ..writeln(financialContext.trim())
        ..writeln('--------------------------------------------------');
    }
    return buffer.toString();
  }

  Future<String> ask(
    String prompt, {
    List<ChatMessageModel> history = const [],
  }) async {
    if (!GeminiConfig.isConfigured) {
      return "FinBot isn't connected yet — please provide a valid Gemini API key.";
    }

    // 1. Try direct REST HTTP request with Bearer authorization (supports OAuth/service tokens)
    final restReply = await _askViaRestHttp(prompt, history);
    if (restReply != null && restReply.isNotEmpty) {
      return restReply;
    }

    // 2. Try SDK with candidate models
    final List<Content> geminiHistory = [];
    for (final m in history) {
      if (m.role == ChatRole.user) {
        geminiHistory.add(Content.text(m.content));
      } else {
        geminiHistory.add(Content.model([TextPart(m.content)]));
      }
    }

    final modelsToTry = [
      _workingModel,
      ..._candidateModels.where((m) => m != _workingModel),
    ];

    Object? lastError;

    for (final modelName in modelsToTry) {
      try {
        final generativeModel = _createModel(modelName);
        final chat = generativeModel.startChat(history: geminiHistory);
        final response = await chat.sendMessage(Content.text(prompt));

        if (response.text != null && response.text!.isNotEmpty) {
          _workingModel = modelName;
          return response.text!;
        }
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    final errStr = lastError.toString();
    if (errStr.contains('v1beta') || errStr.contains('not found') || errStr.contains('API_KEY') || errStr.contains('invalid')) {
      return "⚠️ **Gemini API Key Notice**:\n"
          "The API key provided is not a valid Google AI Studio API key.\n\n"
          "💡 **How to get your free API key**:\n"
          "1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey).\n"
          "2. Click **Create API Key**.\n"
          "3. Copy the key (it starts with `AIzaSy...`).\n"
          "4. Replace `_customApiKey` in [`gemini_config.dart`](file:///c:/Users/thime/OneDrive/Desktop/My%20projects/FYP_demo/EXP-MGT-SYS/lib/core/config/gemini_config.dart).\n\n"
          "---\n"
          "🇱🇰 **FinBot Sri Lanka Financial Literacy Insight**:\n"
          "${_generateFallbackResponse(prompt)}";
    }

    return 'FinBot ran into a connection error: $lastError';
  }

  Future<String?> _askViaRestHttp(String prompt, List<ChatMessageModel> history) async {
    final apiKey = GeminiConfig.apiKey;
    final models = ['gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-pro'];

    final contentsList = <Map<String, dynamic>>[];
    for (final m in history) {
      contentsList.add({
        'role': m.role == ChatRole.user ? 'user' : 'model',
        'parts': [
          {'text': m.content}
        ],
      });
    }
    contentsList.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    for (final mName in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$mName:generateContent?key=$apiKey',
        );
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _systemPrompt(_financialContext)}
              ]
            },
            'contents': contentsList,
          }),
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.toString().isNotEmpty) {
            return text.toString();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static String _generateFallbackResponse(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('cse') || lower.contains('stock') || lower.contains('trend')) {
      return "📈 **Colombo Stock Exchange (CSE) Overview**:\n"
          "• **ASPI Index**: Tracking solid movement (~11,850+ points).\n"
          "• **Top Sectors**: Banking (COMB, HNB, NDB), Diversified Holdings (JKH), and Manufacturing (HAYL).\n"
          "• **Tip**: For beginners, consider dividend-yielding blue-chip equities or equity unit trusts.";
    } else if (lower.contains('deposit') || lower.contains('treasury') || lower.contains('bill') || lower.contains('fd')) {
      return "📊 **Fixed Deposits vs. Sri Lanka Treasury Bills (T-Bills)**:\n"
          "• **T-Bills**: Backed 100% by the Government of Sri Lanka. High safety, tax-free at source, 91-day / 182-day / 364-day tenors (~9.5% - 10.5% p.a.).\n"
          "• **Fixed Deposits**: Licensed Commercial Banks offer ~8.5% - 10.0% p.a.\n"
          "• **Recommendation**: Rebalance shorter-term emergency cash into T-Bills for zero credit risk.";
    } else if (lower.contains('budget') || lower.contains('50') || lower.contains('rule')) {
      return "💡 **50/30/20 Budget Rule in LKR**:\n"
          "• **50% Needs**: Essential expenses (rent, groceries, electricity, transport).\n"
          "• **30% Wants**: Lifestyle & entertainment (dining out, subscriptions).\n"
          "• **20% Savings/Investments**: CSE stock portfolios, T-Bills, or emergency fund.\n"
          "• **Action Item**: Track your monthly LKR expenditure under the 'Expenses' tab!";
    } else if (lower.contains('epf') || lower.contains('etf') || lower.contains('tax')) {
      return "🇱🇰 **EPF & ETF in Sri Lanka**:\n"
          "• **EPF (Employees' Provident Fund)**: 8% employee contribution + 12% employer contribution = 20% total towards long-term retirement.\n"
          "• **ETF (Employees' Trust Fund)**: 3% employer contribution for short-to-medium term welfare benefits.\n"
          "• **Strategy**: Supplement EPF/ETF with personal monthly investments into high-yield LKR instruments.";
    }
    return "FinSmart AI Coach is ready to assist you with Sri Lankan financial literacy, CSE equities, budgeting, and investment strategies in LKR.";
  }
}
