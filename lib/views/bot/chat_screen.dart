import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/ai_service.dart';
import '../../core/config/gemini_config.dart';

const List<String> _suggestedPrompts = [
  "🇱🇰 Current CSE Stock Trends",
  "📈 Fixed Deposit vs Treasury Bills",
  "📊 How to create a 50/30/20 Budget",
  "💡 Explain EPF & ETF in Sri Lanka",
];

class ChatScreen extends StatefulWidget {
  final String title;
  final String? seedContext;

  const ChatScreen({super.key, this.title = 'Ask FinBot AI', this.seedContext});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final List<ChatMessageModel> _messages;
  late final AiService _aiService;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _aiService = AiService(financialContext: widget.seedContext);
    _messages = [
      ChatMessageModel(
        role: ChatRole.bot,
        content: widget.seedContext == null || widget.seedContext!.isEmpty
            ? "Hello! I'm FinBot, your Gemini-powered AI financial advisor for Sri Lanka. Ask me about investments, CSE stocks, fixed deposits, or budgeting!"
            : "Hello! I see you are exploring: ${widget.seedContext}. What financial insights can I generate for you?",
      ),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isGenerating) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessageModel(role: ChatRole.user, content: query));
      _isGenerating = true;
    });
    _scrollToBottom();

    final response = await _aiService.ask(query, history: _messages);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessageModel(role: ChatRole.bot, content: response));
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    _scrollToBottom();
    final isConfigured = GeminiConfig.isConfigured;

    return GradientScaffold(
      maxContentWidth: 760,
      appBar: TopNavBar(current: AppSection.bot, title: widget.title, showBackButton: true),
      body: Column(
        children: [
          // AI Status Card Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: AppColors.mintBg,
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isConfigured ? const Color(0xFF16A34A) : Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FinBot AI • Sri Lanka Advisor',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          isConfigured
                              ? 'Online • Powered by Google Gemini AI'
                              : 'Local Fallback • Connect GEMINI_API_KEY for live responses',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isConfigured ? AppColors.primary : Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isGenerating ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _messages.length) {
                  return _Bubble(message: _messages[i]);
                }
                return const _TypingBubble();
              },
            ),
          ),

          // Quick Suggested Prompts Pill Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _suggestedPrompts
                  .map(
                    (prompt) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _send(prompt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            prompt,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          // Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      enabled: !_isGenerating,
                      style: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask FinBot about stocks, budget, or taxes...',
                        hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textMuted, size: 18),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isGenerating ? null : () => _send(_controller.text),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isGenerating ? AppColors.textMuted : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isGenerating
                        ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageModel message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14),
              ),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: Border.all(
                    color: isUser ? AppColors.primary : AppColors.borderLight,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  message.content,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isUser ? Colors.white : AppColors.textDark,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'FinBot is generating AI response...',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


