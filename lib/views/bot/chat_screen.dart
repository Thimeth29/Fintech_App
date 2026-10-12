import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../core/config/gemini_config.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import '../../core/theme/app_fonts.dart';

const List<String> _suggestedPrompts = [
  "🇱🇰 Current CSE Stock Trends",
  "📈 Fixed Deposit vs Treasury Bills",
  "📊 How to create a 50/30/20 Budget",
  "💡 Explain EPF & ETF in Sri Lanka",
];

class ChatScreen extends StatefulWidget {
  final String title;
  final String? seedContext;

  /// Pre-filled into the message box (e.g. from the trainer's Ask FinBot).
  final String? initialPrompt;

  const ChatScreen({super.key, this.title = 'Ask FinBot AI', this.seedContext, this.initialPrompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatViewModel _chatViewModel;

  @override
  void initState() {
    super.initState();
    _chatViewModel = ChatViewModel();
    final contextNote = widget.seedContext == null || widget.seedContext!.isEmpty
        ? ''
        : "I see you're exploring: ${widget.seedContext}.";
    _chatViewModel.seed(contextNote);
    _controller.text = widget.initialPrompt ?? '';
    String? sandbox;
    try {
      sandbox = context.read<SandboxViewModel>().finBotSummary();
    } catch (_) {
      sandbox = null; // no trainer state provided (e.g. widget tests)
    }
    _chatViewModel.loadFinancialContext(userId: AuthService().currentUser?.id, sandboxSummary: sandbox);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _chatViewModel.dispose();
    super.dispose();
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
    if (query.isEmpty || _chatViewModel.isSending) return;

    _controller.clear();
    _scrollToBottom();
    await _chatViewModel.send(query);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _chatViewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, vm, _) => _buildScaffold(context, vm),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, ChatViewModel vm) {
    _scrollToBottom();
    final isConfigured = GeminiConfig.isConfigured;

    return GradientScaffold(
      maxContentWidth: 760,
      appBar: TopNavBar(current: AppSection.bot, title: widget.title, showBackButton: true),
      bottomNavigationBar: const AppBottomNav(current: AppSection.bot),
      body: Column(
        children: [
          // AI Status Card Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderColor: AppColors.accentCyan.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: AppGradients.action,
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
                            color: isConfigured ? AppColors.accentCyan : AppColors.warning,
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
                          style: AppFonts.text(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onGlass,
                          ),
                        ),
                        if (isConfigured)
                          Text(
                            'Online • Powered by Google Gemini AI',
                            style: AppFonts.text(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accentCyan,
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
              itemCount: vm.messages.length + (vm.isSending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < vm.messages.length) {
                  return _Bubble(message: vm.messages[i]);
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
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          borderRadius: 20,
                          child: Text(
                            prompt,
                            style: AppFonts.text(
                              fontSize: 13,
                              color: AppColors.onGlass,
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
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: TextField(
                      controller: _controller,
                      enabled: !vm.isSending,
                      style: AppFonts.text(color: AppColors.onGlass, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask FinBot about stocks, budget, or taxes...',
                        hintStyle: AppFonts.text(color: AppColors.onGlassMuted, fontSize: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.onGlassMuted, size: 18),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: vm.isSending ? null : () => _send(_controller.text),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: vm.isSending ? AppColors.glassFillStrong : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassBorderStrong),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: vm.isSending ? 0 : 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: vm.isSending
                        ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: AppColors.onLight, size: 20),
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
                  gradient: AppGradients.action,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14),
              ),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? null : AppColors.glassFill,
                  gradient: isUser ? AppGradients.primary : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: Border.all(
                    color: isUser ? AppColors.glassBorderStrong : AppColors.glassBorder,
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.glassShadow,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  message.content,
                  style: AppFonts.text(
                    fontSize: 14,
                    color: isUser ? Colors.white : AppColors.onGlass,
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
          color: AppColors.glassFill,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentCyan,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'FinBot is generating AI response...',
              style: AppFonts.text(
                fontSize: 13,
                color: AppColors.onGlassMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


