import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../investments/investments_screen.dart';
import '../expenditure/expenditure_screen.dart';
import '../bot/chat_screen.dart';
import '../sandbox/sandbox_screen.dart';
import '../auth/welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel()..loadDisplayName(),
      child: Consumer<AuthViewModel>(
        builder: (context, auth, _) {
          return GradientScaffold(
            appBar: TopNavBar(current: AppSection.home, title: 'Home'),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      'Hello, ${auth.displayName.isEmpty ? "there" : auth.displayName}',
                      key: ValueKey(auth.displayName),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text("Let's Manage Your Finances", style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 28),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: [
                        BlockButton(
                          label: 'My\nInvestments',
                          entranceDelay: const Duration(milliseconds: 0),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const InvestmentsScreen()),
                          ),
                        ),
                        BlockButton(
                          label: 'My\nExpenditures',
                          entranceDelay: const Duration(milliseconds: 80),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
                          ),
                        ),
                        BlockButton(
                          label: 'ASK THE BOT',
                          icon: Icons.settings,
                          entranceDelay: const Duration(milliseconds: 160),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ChatScreen(title: 'My AI Analyst'),
                            ),
                          ),
                        ),
                        BlockButton(
                          label: 'Sandbox',
                          entranceDelay: const Duration(milliseconds: 240),
                          gradient: AppGradients.action,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SandboxScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log out'),
                    onPressed: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
