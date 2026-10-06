import 'package:flutter/material.dart';
import '../../views/home/home_screen.dart';
import '../../views/investments/investments_screen.dart';
import '../../views/expenditure/expenditure_screen.dart';
import '../../views/bot/chat_screen.dart';
import '../../views/profile/profile_screen.dart';

enum AppSection { home, investments, expenses, bot, profile }

/// The "Home | My Investments | My Expenses | Ask Bot" bar shown at the
/// top of every logged-in-area screen. Tapping a section replaces the
/// current screen so the nav bar always represents where you are, while
/// screens pushed *within* a section (e.g. CSE Analytics) still get a
/// normal back arrow from the AppBar.
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
  Size get preferredSize => const Size.fromHeight(96);

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
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  Widget _tab(BuildContext context, String label, AppSection section) {
    final isActive = section == current;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => _go(context, section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? primary : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _tab(context, 'Home', AppSection.home),
                const SizedBox(width: 6),
                _tab(context, 'My Investments', AppSection.investments),
                const SizedBox(width: 6),
                _tab(context, 'My Expenses', AppSection.expenses),
                const SizedBox(width: 6),
                _tab(context, 'Ask Bot', AppSection.bot),
                const SizedBox(width: 6),
                _tab(context, 'Profile', AppSection.profile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
