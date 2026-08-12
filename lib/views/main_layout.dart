import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../viewmodels/app_viewmodel.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'onboard/onboard_screen.dart';
import 'home/home_screen.dart';
import 'expenses/expenses_screen.dart';
import 'sandbox/sandbox_invest_screen.dart';
import 'guidance/advisor_screen.dart';
import 'literacy/learn_screen.dart';
import 'profile/profile_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 750;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Sidebar
              _buildSidebar(context, vm),
              const VerticalDivider(width: 1, color: AppTheme.line),
              // Right Phone Simulator
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: _buildPhoneSimulator(context, vm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile Layout - just the simulated screen inside a Scaffold
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.paper,
          elevation: 0,
          leading: Builder(
            builder: (scaffoldContext) => IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.ink),
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
            ),
          ),
          actions: [
            if (!_isNoChipScreen(vm.currentScreen))
              GestureDetector(
                onTap: () => vm.setScreen('profile'),
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Color(int.parse(vm.currentPersona.color.replaceAll('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    vm.currentPersona.init,
                    style: GoogleFonts.ibmPlexMono(
                      color: AppTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: AppTheme.paper,
          child: SafeArea(
            child: _buildSidebar(context, vm, showTitle: false),
          ),
        ),
        body: Container(
          color: AppTheme.paper,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 80.0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _getScreenWidget(vm.currentScreen),
                ),
              ),
              if (_isBottomNavScreen(vm.currentScreen))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomNav(vm),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSidebar(BuildContext context, AppViewModel vm, {bool showTitle = true}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      color: AppTheme.paper,
      child: ListView(
        children: [
          if (showTitle) ...[
            Text(
              'Prototype · Sahurada',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                letterSpacing: 0.14,
                fontWeight: FontWeight.w600,
                color: AppTheme.sage,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Financial confidence, explained.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 10),
            Text(
              'Interactive walkthrough of the core screens across all four user groups from the proposal. Switch persona or screen — the phone updates with tailored mock data.',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF3A453F), fontSize: 13.5, height: 1.55),
            ),
            const SizedBox(height: 22),
          ],
          // Persona List
          ...vm.personas.entries.map((entry) {
            final key = entry.key;
            final p = entry.value;
            final active = key == vm.currentPersonaId;
            final pColor = Color(int.parse(p.color.replaceAll('#', '0xFF')));

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => vm.setPersona(key),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.ink : AppTheme.white,
                    border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: pColor,
                        child: Text(
                          p.init,
                          style: GoogleFonts.newsreader(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: active ? AppTheme.white : AppTheme.ink,
                              ),
                            ),
                            Text(
                              p.role,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                color: active ? AppTheme.white.withAlpha(179) : AppTheme.sage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 26),
          // Screen tabs
          ...[
            'login', 'signup', 'onboard', 'dashboard', 'expenses', 'invest', 'advisor', 'learn', 'profile'
          ].asMap().entries.map((entry) {
            final index = entry.key;
            final s = entry.value;
            final active = s == vm.currentScreen;
            final label = _getScreenLabel(s);

            return InkWell(
              onTap: () => vm.setScreen(s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: active ? AppTheme.gold : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      '${(index + 1).toString().padLeft(2, '0')} ',
                      style: GoogleFonts.ibmPlexMono(color: AppTheme.sage, fontSize: 10.5),
                    ),
                    Text(
                      label,
                      style: GoogleFonts.ibmPlexSans(
                        color: active ? AppTheme.ink : const Color(0xFF5A655E),
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPhoneSimulator(BuildContext context, AppViewModel vm) {
    return Container(
      width: 375,
      height: 780,
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(46),
        boxShadow: const [
          BoxShadow(
            color: Color(0x730F3B34),
            blurRadius: 60,
            offset: Offset(0, 30),
            spreadRadius: -20,
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Container(
          color: AppTheme.paper,
          child: Stack(
            children: [
              // StatusBar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '9:41',
                        style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.ink),
                      ),
                      Text(
                        '●●● LKR',
                        style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.ink),
                      ),
                    ],
                  ),
                ),
              ),
              // Profile Chip
              if (!_isNoChipScreen(vm.currentScreen))
                Positioned(
                  top: 14,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => vm.setScreen('profile'),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(int.parse(vm.currentPersona.color.replaceAll('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        vm.currentPersona.init,
                        style: GoogleFonts.ibmPlexMono(
                          color: AppTheme.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              // Content Area
              Positioned.fill(
                top: 50,
                bottom: _isBottomNavScreen(vm.currentScreen) ? 75 : 0,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _getScreenWidget(vm.currentScreen),
                ),
              ),
              // Bottom Nav
              if (_isBottomNavScreen(vm.currentScreen))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomNav(vm),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(AppViewModel vm) {
    final navItems = [
      {'screen': 'dashboard', 'label': 'Home', 'icon': Icons.home_outlined},
      {'screen': 'expenses', 'label': 'Wallet', 'icon': Icons.account_balance_wallet_outlined},
      {'screen': 'invest', 'label': 'Sandbox', 'icon': Icons.show_chart},
      {'screen': 'advisor', 'label': 'Advisor', 'icon': Icons.lightbulb_outline},
      {'screen': 'learn', 'label': 'Learn', 'icon': Icons.book_outlined},
    ];

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.line, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.map((item) {
          final active = vm.currentScreen == item['screen'];
          return GestureDetector(
            onTap: () => vm.setScreen(item['screen'] as String),
            child: Opacity(
              opacity: active ? 1.0 : 0.45,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: AppTheme.ink,
                    size: 19,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _getScreenWidget(String screen) {
    switch (screen) {
      case 'login':
        return const LoginScreen();
      case 'signup':
        return const SignupScreen();
      case 'onboard':
        return const OnboardScreen();
      case 'dashboard':
        return const HomeScreen();
      case 'expenses':
        return const ExpensesScreen();
      case 'invest':
        return const SandboxInvestScreen();
      case 'advisor':
        return const AdvisorScreen();
      case 'learn':
        return const LearnScreen();
      case 'profile':
        return const ProfileScreen();
      default:
        return const LoginScreen();
    }
  }

  String _getScreenLabel(String screen) {
    final labels = {
      'login': 'Log In',
      'signup': 'Sign Up',
      'onboard': 'Onboarding',
      'dashboard': 'Dashboard',
      'expenses': 'Expense Tracker',
      'invest': 'Sandbox Investing',
      'advisor': 'AI Advisor',
      'learn': 'Literacy & Language',
      'profile': 'Profile',
    };
    return labels[screen] ?? screen;
  }

  bool _isNoChipScreen(String screen) {
    return ['login', 'signup', 'profile'].contains(screen);
  }

  bool _isBottomNavScreen(String screen) {
    return ['dashboard', 'expenses', 'invest', 'advisor', 'learn'].contains(screen);
  }
}
