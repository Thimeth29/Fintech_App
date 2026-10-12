import 'dart:ui';
import 'package:flutter/material.dart';
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
import '../theme/app_fonts.dart';

enum AppSection { home, investments, expenses, sandbox, community, bot, profile }

/// Opens [section] as the new root of the stack. Tapping the section you're
/// already in does nothing on its root page, and returns to the root from
/// a page inside it (e.g. FD rates under Investments).
void _goToSection(BuildContext context, AppSection current, AppSection section,
    {bool isSectionRoot = true}) {
  if (section == current && isSectionRoot) return;
  final Widget page = switch (section) {
    AppSection.home => const HomeScreen(),
    AppSection.investments => const InvestingOptionsScreen(),
    AppSection.expenses => const ExpenditureScreen(),
    AppSection.sandbox => const SandboxScreen(),
    AppSection.community => const CommunityScreen(),
    AppSection.bot => const ChatScreen(),
    AppSection.profile => const ProfileScreen(),
  };
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

/// Whether the app window is desktop-width. For [PreferredSizeWidget]s,
/// which have to report a height without a [BuildContext].
bool get _windowIsDesktop {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view == null) return false;
  return view.physicalSize.width / view.devicePixelRatio >= Responsive.desktop;
}

/// Page header. On desktop it also carries the section navigation; on
/// phones and tablets navigation lives in [AppBottomNav] and this is just
/// the back button and title.
class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final AppSection current;
  final String title;
  final bool showBackButton;

  /// False on pages *inside* a section (e.g. FD rates under Investments):
  /// tapping the highlighted tab then returns to that section's main page
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
  Size get preferredSize => _windowIsDesktop
      ? Size.fromHeight(_hasTitleRow ? 110 : 66)
      : Size.fromHeight(_hasTitleRow ? 56 : 0);

  void _go(BuildContext context, AppSection section) =>
      _goToSection(context, current, section, isSectionRoot: isSectionRoot);

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

  static const _mainTabs = [
    ('Home', Icons.home_rounded, AppSection.home),
    ('Investments', Icons.trending_up_rounded, AppSection.investments),
    ('Expenses', Icons.account_balance_wallet_rounded, AppSection.expenses),
    ('Sand Box', Icons.science_rounded, AppSection.sandbox),
    ('Community', Icons.groups_rounded, AppSection.community),
  ];
  static const _sideTabs = [
    ('FinBot', Icons.smart_toy_rounded, AppSection.bot),
    ('Profile', Icons.person_rounded, AppSection.profile),
  ];

  List<Widget> _tabs(BuildContext context, List<(String, IconData, AppSection)> tabs, double gap,
          {required bool inBar}) =>
      [
        for (final (i, (label, icon, section)) in tabs.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          _NavPill(
            label: label,
            icon: icon,
            active: section == current,
            inBar: inBar,
            onTap: () => _go(context, section),
          ),
        ],
      ];

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
            style: AppFonts.text(
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
    if (!_hasTitleRow) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: _title(context),
    );
  }

  /// Landing-page style: logo left, a centered frosted pill holding the
  /// main sections, FinBot / Profile on the right, page title underneath.
  Widget _desktop(BuildContext context) {
    final pillBar = _FrostedBar(
      radius: 30,
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tabs(context, _mainTabs, 4, inBar: true),
      ),
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
                        children: _tabs(context, _sideTabs, 8, inBar: false),
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
      bottom: false,
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

/// Floating frosted-glass tab bar for phones and tablets. Put it in the
/// page's `Scaffold.bottomNavigationBar`; it renders nothing on desktop,
/// where [TopNavBar] carries the navigation instead.
///
/// Expenses, Sand Box and Profile are reached from Home's tiles and avatar.
class AppBottomNav extends StatelessWidget {
  final AppSection current;
  final bool isSectionRoot;

  const AppBottomNav({super.key, required this.current, this.isSectionRoot = true});

  static const _tabs = [
    ('Home', Icons.home_rounded, AppSection.home),
    ('Community', Icons.groups_rounded, AppSection.community),
    ('Investments', Icons.trending_up_rounded, AppSection.investments),
    ('FinBot', Icons.smart_toy_rounded, AppSection.bot),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _FrostedBar(
              radius: 34,
              glow: true,
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    for (final (label, icon, section) in _tabs)
                      Expanded(
                        child: _BottomNavItem(
                          label: label,
                          icon: icon,
                          active: section == current,
                          emphasised: section == AppSection.bot,
                          onTap: () => _goToSection(context, current, section,
                              isSectionRoot: isSectionRoot),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurred glass capsule shared by the bottom bar and the desktop pill.
class _FrostedBar extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool glow;

  const _FrostedBar({
    required this.child,
    required this.radius,
    required this.padding,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final useBlur = AppGlass.useBlur(context);
    final shape = BorderRadius.circular(radius);
    Widget bar = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: shape,
        color: useBlur ? null : AppColors.glassFillNoBlur,
        gradient: useBlur
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x66FFFFFF), Color(0x7A304168), Color(0x8C1E3A8A)],
                stops: [0, 0.45, 1],
              )
            : null,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
      ),
      child: child,
    );
    if (useBlur) {
      bar = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: bar,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          const BoxShadow(color: AppColors.glassShadow, blurRadius: 24, offset: Offset(0, 8)),
          if (glow)
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.28),
              blurRadius: 22,
              spreadRadius: -2,
            ),
        ],
      ),
      child: ClipRRect(borderRadius: shape, child: bar),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;

  /// FinBot gets a round dark badge, like a floating action.
  final bool emphasised;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.emphasised,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onGlass : AppColors.onGlassMuted;
    final iconWidget = emphasised
        ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.deepNavy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: active ? 0.6 : 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          )
        : Icon(icon, color: fg, size: 23);

    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: active ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(
                color: active ? Colors.white.withValues(alpha: 0.45) : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 32, child: Center(child: iconWidget)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
              style: AppFonts.text(
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

/// Desktop tab. Inside the frosted bar ([inBar]) idle tabs are bare text so
/// the bar reads as one surface; the active tab is a brighter glass chip.
class _NavPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool inBar;
  final VoidCallback onTap;

  const _NavPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.inBar,
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
    final fg = active ? AppColors.onGlass : AppColors.onGlassMuted;

    final Color fill;
    if (active) {
      fill = Colors.white.withValues(alpha: 0.24);
    } else if (_hover) {
      fill = Colors.white.withValues(alpha: 0.12);
    } else {
      fill = widget.inBar ? Colors.transparent : AppColors.glassFill;
    }

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
            color: fill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.6)
                  : (widget.inBar ? Colors.transparent : AppColors.glassBorder),
              width: 1.2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppFonts.text(
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
