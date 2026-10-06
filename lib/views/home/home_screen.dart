import 'package:flutter/material.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive.dart';
import '../investments/investments_screen.dart';
import '../expenditure/expenditure_screen.dart';
import '../bot/chat_screen.dart';
import '../sandbox/sandbox_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 820,
      appBar: const TopNavBar(current: AppSection.home, title: 'Home'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hello, there',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              "Let's Manage Your Finances",
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: GridView.count(
                crossAxisCount: Responsive.gridColumns(context),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  BlockButton(
                    label: 'My\nInvestments',
                    icon: Icons.show_chart,
                    entranceDelay: const Duration(milliseconds: 0),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InvestmentsScreen()),
                    ),
                  ),
                  BlockButton(
                    label: 'My\nExpenditures',
                    icon: Icons.pie_chart_outline,
                    entranceDelay: const Duration(milliseconds: 80),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
                    ),
                  ),
                  BlockButton(
                    label: 'ASK THE BOT',
                    icon: Icons.smart_toy_outlined,
                    entranceDelay: const Duration(milliseconds: 160),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(title: 'My AI Analyst'),
                      ),
                    ),
                  ),
                  BlockButton(
                    label: 'Sandbox',
                    icon: Icons.science_outlined,
                    entranceDelay: const Duration(milliseconds: 240),
                    gradient: AppGradients.action,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SandboxScreen()),
                    ),
                  ),
                  BlockButton(
                    label: 'My\nProfile',
                    icon: Icons.person_outline,
                    entranceDelay: const Duration(milliseconds: 320),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log out'),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
