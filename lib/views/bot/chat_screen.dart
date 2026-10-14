import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../core/config/gemini_config.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/sandbox_viewmodel.dart';

const List<(String, String, String, IconData, Color)> _starterPrompts = [
  (
    'CSE Market Trends',
    'What are the top blue-chip dividend stocks on the Colombo Stock Exchange (CSE)?',
    'CSE & Stocks',
    Icons.trending_up_rounded,
    AppColors.primary,
  ),
  (
    'Fixed Deposits vs T-Bills',
    'Compare Commercial Bank Fixed Deposits with Central Bank Treasury Bills in Sri Lanka.',
    'Fixed Income & Rates',
    Icons.account_balance_rounded,
    AppColors.accentCyan,
  ),
  (
    '50/30/20 LKR Budget',
    'How should I allocate a monthly income in Sri Lanka using the 50/30/20 budgeting rule?',
    'Budget & Expenses',
    Icons.pie_chart_rounded,
    AppColors.gold,
  ),
  (
    'EPF, ETF & Taxes',
    'Explain employee and employer EPF/ETF contributions and APIT tax deductions.',
    'EPF, ETF & Taxes',
    Icons.verified_user_rounded,
    AppColors.accentLavender,
  ),
  (
    'Emergency Cash Buffer',
    'How many months of living expenses should I keep in an emergency fund, and where to hold it?',
    'Budget & Expenses',
    Icons.shield_rounded,
    AppColors.accentTeal,
  ),
  (
    'Seettu Group Safety',
    'How does a rotating savings Seettu work, and what are the main financial risks?',
    'General Advisory',
    Icons.groups_rounded,
    AppColors.accentViolet,
  ),
];

class ChatScreen extends StatefulWidget {
  final String title;
  final String? seedContext;
  final String? initialPrompt;

  const ChatScreen({
    super.key,
    this.title = 'FinBot AI',
    this.seedContext,
    this.initialPrompt,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatViewModel _chatViewModel;
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _chatViewModel = ChatViewModel();

    final contextNote = widget.seedContext == null || widget.seedContext!.isEmpty
        ? ''
        : "I see you're exploring: ${widget.seedContext}.";
    _chatViewModel.startNewChat(contextNote.isNotEmpty ? contextNote : null);

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _controller.text = widget.initialPrompt!;
    }

    String? sandbox;
    try {
      sandbox = context.read<SandboxViewModel>().finBotSummary();
    } catch (_) {
      sandbox = null;
    }
    _chatViewModel.loadFinancialContext(
      userId: AuthService().currentUser?.id,
      sandboxSummary: sandbox,
    );
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
    final isConfigured = GeminiConfig.isConfigured;

    return GradientScaffold(
      maxContentWidth: 760,
      appBar: TopNavBar(
        current: AppSection.bot,
        title: vm.currentSession?.title == 'New Chat' ? widget.title : (vm.currentSession?.title ?? widget.title),
        showBackButton: true,
        actions: [
          // "+ New Chat" — vivid gradient pill button
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  _controller.clear();
                  vm.startNewChat();
                  _scrollToBottom();
                },
                splashColor: Colors.white.withValues(alpha: 0.2),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppGradients.action,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_comment_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'New Chat',
                          style: AppFonts.text(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Categorized History Drawer Button
          Builder(
            builder: (ctx) => Stack(
              clipBehavior: Clip.none,
              children: [
                GlassIconButton(
                  icon: Icons.history_rounded,
                  size: 36,
                  tooltip: 'Chat History',
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
                if (vm.sessions.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accentCyan,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${vm.sessions.length}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      endDrawer: _buildHistoryDrawer(context, vm),
      bottomNavigationBar: const AppBottomNav(current: AppSection.bot),
      body: Column(
        children: [
          // Status Sub-Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderColor: AppColors.accentCyan.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConfigured ? AppColors.accentCyan : AppColors.warning,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isConfigured ? AppColors.accentCyan : AppColors.warning).withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isConfigured
                          ? 'FinBot Online • Sri Lanka LKR Grounding • Gemini 3.5'
                          : 'FinBot Offline • Add GEMINI_API_KEY to connect',
                      style: AppFonts.text(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isConfigured ? AppColors.accentCyan : AppColors.warning,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (vm.currentSession != null && vm.currentSession!.category != 'General Advisory')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: vm.currentSession!.categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: vm.currentSession!.categoryColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(vm.currentSession!.categoryIcon, size: 12, color: vm.currentSession!.categoryColor),
                          const SizedBox(width: 4),
                          Text(
                            vm.currentSession!.category,
                            style: AppFonts.text(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: vm.currentSession!.categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Messages View
          Expanded(
            child: vm.messages.length <= 1
                ? _buildEmptyWelcome(context, vm)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: vm.messages.length + (vm.isSending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i < vm.messages.length) {
                        return _Bubble(
                          message: vm.messages[i],
                          category: vm.currentSession?.category,
                        );
                      }
                      return const _TypingBubble();
                    },
                  ),
          ),

          // Horizontal Quick Prompt Suggestions (when active)
          if (vm.messages.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _starterPrompts
                    .take(4)
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _send(p.$2),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            borderRadius: 16,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.$4, size: 13, color: p.$5),
                                const SizedBox(width: 6),
                                Text(
                                  p.$1,
                                  style: AppFonts.text(
                                    fontSize: 12,
                                    color: AppColors.onGlass,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Bottom Input Bar
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
                        hintStyle: AppFonts.text(color: AppColors.onGlassMuted, fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.onGlassMuted,
                          size: 18,
                        ),
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
                      gradient: vm.isSending ? null : AppGradients.action,
                      color: vm.isSending ? AppColors.glassFillStrong : null,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassBorderStrong),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: vm.isSending ? 0 : 0.35),
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
                        : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Categorized Chat History Drawer (ChatGPT / Gemini style)
  Widget _buildHistoryDrawer(BuildContext context, ChatViewModel vm) {
    const categories = [
      'All',
      'CSE & Stocks',
      'Fixed Income & Rates',
      'Budget & Expenses',
      'EPF, ETF & Taxes',
      'General Advisory',
    ];

    final filtered = _selectedCategoryFilter == 'All'
        ? vm.sessions
        : vm.sessions.where((s) => s.category == _selectedCategoryFilter).toList();

    // Group by time category
    final grouped = <String, List<ChatSessionModel>>{};
    for (final s in filtered) {
      grouped.putIfAbsent(s.timeCategory, () => []).add(s);
    }

    return Drawer(
      backgroundColor: Colors.black.withValues(alpha: 0.88),
      elevation: 16,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: AppGradients.action,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat History',
                          style: AppFonts.text(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onGlass,
                          ),
                        ),
                        Text(
                          '${vm.sessions.length} saved conversations',
                          style: AppFonts.text(
                            fontSize: 12,
                            color: AppColors.onGlassMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.onGlassMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Start New Chat Prominent Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _controller.clear();
                  vm.startNewChat();
                  _scrollToBottom();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: AppGradients.action,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_comment_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Start New Conversation',
                        style: AppFonts.text(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Category Filter Pills
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: categories.map((cat) {
                  final selected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: AppFonts.text(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.onGlassMuted,
                        ),
                      ),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.glassBorder,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryFilter = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 20),

            // Grouped Sessions List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 42, color: AppColors.onGlassMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No chats in this category',
                              style: AppFonts.text(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onGlassMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ask FinBot a question and your conversations will appear here.',
                              textAlign: TextAlign.center,
                              style: AppFonts.text(
                                fontSize: 12,
                                color: AppColors.onGlassMuted.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: grouped.entries.map((entry) {
                        final timeGroup = entry.key;
                        final groupSessions = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                              child: Text(
                                timeGroup.toUpperCase(),
                                style: AppFonts.text(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentCyan,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            ...groupSessions.map((session) {
                              final isActive = session.id == vm.currentSession?.id;
                              final lastMsg = session.messages.isNotEmpty
                                  ? session.messages.last.content
                                  : 'Empty conversation';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary.withValues(alpha: 0.22)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive ? AppColors.primary : AppColors.glassBorder,
                                    width: isActive ? 1.5 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: session.categoryColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(session.categoryIcon, size: 16, color: session.categoryColor),
                                  ),
                                  title: Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.text(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                      color: AppColors.onGlass,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.text(
                                            fontSize: 11,
                                            color: AppColors.onGlassMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                session.category,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppFonts.text(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: session.categoryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '• ${session.messages.length} msgs',
                                              style: AppFonts.text(
                                                fontSize: 10,
                                                color: AppColors.onGlassMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.onGlassMuted),
                                    tooltip: 'Delete Chat',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppColors.deepNavy,
                                          title: const Text('Delete this chat?'),
                                          content: Text('Remove "${session.title}" from your history?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                vm.deleteSession(session.id);
                                              },
                                              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    vm.selectSession(session);
                                    Navigator.of(context).pop();
                                    _scrollToBottom();
                                  },
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modern Empty / Starter Welcome Interface (when no active messages yet)
  Widget _buildEmptyWelcome(BuildContext context, ChatViewModel vm) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // FinBot Hero Banner
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderColor: AppColors.accentCyan.withValues(alpha: 0.45),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: AppGradients.action,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                'Ayubowan! I am FinBot 🇱🇰',
                style: AppFonts.text(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onGlass,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your AI Personal Financial Coach and Investment Trainer for Sri Lanka. Grounded in CSE markets, Treasury Bills, bank FDs, and 50/30/20 LKR budgets.',
                textAlign: TextAlign.center,
                style: AppFonts.text(
                  fontSize: 13,
                  color: AppColors.onGlassMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Text(
          'CHOOSE A TOPIC TO EXPLORE',
          style: AppFonts.text(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.accentCyan,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // 6 Interactive Topic Starter Cards Grid
        ..._starterPrompts.map((item) {
          final title = item.$1;
          final prompt = item.$2;
          final category = item.$3;
          final icon = item.$4;
          final color = item.$5;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _send(prompt),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppFonts.text(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onGlass,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  category,
                                  style: AppFonts.text(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prompt,
                            style: AppFonts.text(
                              fontSize: 12,
                              color: AppColors.onGlassMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.onGlassMuted),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageModel message;
  final String? category;
  const _Bubble({required this.message, this.category});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
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
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      message.content,
                      style: AppFonts.text(
                        fontSize: 14,
                        color: isUser ? Colors.white : AppColors.onGlass,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUser) ...[
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: message.content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied response to clipboard!'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.copy_rounded, size: 12, color: AppColors.onGlassMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: AppFonts.text(fontSize: 10, color: AppColors.onGlassMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          _formatTime(message.timestamp),
                          style: AppFonts.text(
                            fontSize: 10,
                            color: isUser ? Colors.white70 : AppColors.onGlassMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
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
