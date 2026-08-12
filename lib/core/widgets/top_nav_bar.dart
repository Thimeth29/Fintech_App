import 'package:flutter/material.dart';
import '../../views/home/home_screen.dart';
import '../../views/investments/investments_screen.dart';
import '../../views/expenditure/expenditure_screen.dart';
import '../../views/bot/chat_screen.dart';

enum AppSection { home, investments, expenses, bot }

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
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  Widget _tab(BuildContext context, String label, AppSection section) {
    final isActive = section == current;
    return GestureDetector(
      onTap: () => _go(context, section),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: Colors.black87,
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
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
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
                      color: Colors.black87,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
