import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../platform/app_platform.dart';
import '../responsive.dart';
import '../theme/app_theme.dart';
import '../../views/home/home_screen.dart';
import '../../views/investments/investing_options_screen.dart';
import '../../views/expenditure/expenditure_screen.dart';
import '../../views/bot/chat_screen.dart';
import '../../views/community/community_screen.dart';
import '../../views/sandbox/sandbox_screen.dart';
import '../../views/profile/profile_screen.dart';
import 'glass_icon_button.dart';

enum AppSection { home, investments, expenses, sandbox, community, bot, profile }

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final AppSection current;
  final String title;
  final bool showBackButton;

  /// False on pages *inside* a section (e.g. FD rates under Investments):
  /// tapping the highlighted pill then returns to that section's main page
  /// instead of doing nothing.
  final bool isSectionRoot;

  /// An empty [title] with no back button hides the title row, leaving just
  /// the navigation (used by Home, which has its own greeting header).
  bool get _hasTitleRow => title.isNotEmpty || showBackButton;

  const TopNavBar({
    super.key,
    required this.current,
    required this.title,
    this.showBackButton = false,
    this.isSectionRoot = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(_hasTitleRow ? 110 : 66);

  void _go(BuildContext context, AppSection section) {
    if (section == current && isSectionRoot) return;
    Widget page;
    switch (section) {
      case AppSection.home:
        page = const HomeScreen();
        break;
      case AppSection.investments:
        page = const InvestingOptionsScreen();
        break;
      case AppSection.expenses:
        page = const ExpenditureScreen();
        break;
      case AppSection.sandbox:
        page = const SandboxScreen();
        break;
      case AppSection.community:
        page = const CommunityScreen();
        break;
      case AppSection.bot:
        page = const ChatScreen();
        break;
      case AppSection.profile:
        page = const ProfileScreen();
        break;
    }
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => page,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
      (route) => false,
    );
  }

  /// Tabs replace the whole stack, so a page opened from the nav bar has
  /// nothing to pop back to — fall back to Home instead of doing nothing.
  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else if (current != AppSection.home) {
      _go(context, AppSection.home);
    }
  }

  /// Order shared by the phone row and the desktop bar.
  static const _mainTabs = [
    ('Home', Icons.grid_view_rounded, AppSection.home),
    ('Investments', Icons.trending_up_rounded, AppSection.investments),
    ('Expenses', Icons.account_balance_wallet_rounded, AppSection.expenses),
    ('Sand Box', Icons.science_rounded, AppSection.sandbox),
    ('Community', Icons.groups_rounded, AppSection.community),
  ];
  static const _sideTabs = [
    ('Fin Bot', Icons.smart_toy_rounded, AppSection.bot),
    ('Profile', Icons.person_rounded, AppSection.profile),
  ];

  List<Widget> _tabs(BuildContext context, List<(String, IconData, AppSection)> tabs, double gap) => [
        for (final (i, (label, icon, section)) in tabs.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          _tab(context, label, icon, section),
        ],
      ];

  Widget _tab(BuildContext context, String label, IconData icon, AppSection section) {
    return _NavPill(
      label: label,
      icon: icon,
      active: section == current,
      onTap: () => _go(context, section),
    );
  }

  Widget _title(BuildContext context) {
    return Row(
      children: [
        if (showBackButton)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GlassIconButton(
              icon: Icons.arrow_back,
              size: 36,
              tooltip: 'Back',
              onPressed: () => _back(context),
            ),
          ),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.onGlass,
              letterSpacing: -0.3,
              shadows: kTitleShadow,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _mobile(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasTitleRow)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: _title(context),
          )
        else
          const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _tabs(context, [..._mainTabs, ..._sideTabs], 8),
          ),
        ),
      ],
    );
  }

  /// Landing-page style: logo left, a centered glass pill holding the main
  /// sections, Ask Bot / Profile on the right, page title underneath.
  Widget _desktop(BuildContext context) {
    final useBlur = AppGlass.useBlur(context);
    Widget pillBar = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: useBlur ? AppColors.glassFill : AppColors.glassFillNoBlur,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tabs(context, _mainTabs, 4),
      ),
    );
    pillBar = ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppGlass.blurSigma, sigmaY: AppGlass.blurSigma),
              child: pillBar,
            )
          : pillBar,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Responsive.desktopMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 54,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Brand(onTap: () => _go(context, AppSection.home)),
                      ),
                    ),
                    pillBar,
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: _tabs(context, _sideTabs, 8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasTitleRow) ...[
                const SizedBox(height: 8),
                _title(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bar = SafeArea(
      child: context.isDesktop ? _desktop(context) : _mobile(context),
    );
    // Android's system back on a tab page would otherwise close the app.
    if (current == AppSection.home || Navigator.of(context).canPop()) return bar;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(context, AppSection.home);
      },
      child: bar,
    );
  }
}

class _Brand extends StatelessWidget {
  final VoidCallback onTap;
  const _Brand({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorderStrong),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/branding/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary,
                  child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Mobile SAP',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onGlass,
                shadows: kTitleShadow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final hasHover = AppPlatform.hasHover(context);
    final fg = active ? AppColors.onLight : AppColors.onGlass;

    return MouseRegion(
      cursor: hasHover ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: hasHover ? (_) => setState(() => _hover = true) : null,
      onExit: hasHover ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : (_hover ? AppColors.glassFillStrong : AppColors.glassFill),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? Colors.white : AppColors.glassBorder,
              width: 1.2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: active ? fg : AppColors.onGlassMuted),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
