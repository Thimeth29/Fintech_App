import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../../views/home/home_screen.dart';
import '../../views/investments/investments_screen.dart';
import '../../views/expenditure/expenditure_screen.dart';
import '../../views/bot/chat_screen.dart';
import '../../views/profile/profile_screen.dart';

enum AppSection { home, investments, expenses, bot, profile }

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final AppSection current;
  final String title;
  final bool showBackButton;

  const TopNavBar({
    super.key,
    required this.current,
    required this.title,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(110);

  void _go(BuildContext context, AppSection section) {
    if (section == current) return;
    Widget page;
    switch (section) {
      case AppSection.home:
        page = const HomeScreen();
        break;
      case AppSection.investments:
        page = const InvestmentsScreen();
        break;
      case AppSection.expenses:
        page = const ExpenditureScreen();
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

  Widget _tab(BuildContext context, String label, IconData icon, AppSection section) {
    final isActive = section == current;
    return GestureDetector(
      onTap: () => _go(context, section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                if (showBackButton)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 18),
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _tab(context, 'Home', Icons.grid_view_rounded, AppSection.home),
                const SizedBox(width: 8),
                _tab(context, 'Investments', Icons.trending_up_rounded, AppSection.investments),
                const SizedBox(width: 8),
                _tab(context, 'Expenses', Icons.account_balance_wallet_rounded, AppSection.expenses),
                const SizedBox(width: 8),
                _tab(context, 'Ask Bot', Icons.smart_toy_rounded, AppSection.bot),
                const SizedBox(width: 8),
                _tab(context, 'Profile', Icons.person_rounded, AppSection.profile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


