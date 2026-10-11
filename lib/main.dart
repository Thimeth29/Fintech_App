import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/supabase_config.dart';
import 'core/responsive.dart';
import 'core/theme/app_backgrounds.dart';
import 'core/theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/sandbox_viewmodel.dart';
import 'views/auth/welcome_screen.dart';
import 'views/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        // One trainer state for Home's sandbox card and every trainer
        // screen, so a trade shows up everywhere at once.
        ChangeNotifierProvider(create: (_) => SandboxViewModel()),
      ],
      child: MaterialApp(
        title: 'Mobile SAP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        builder: (context, child) =>
            ClampedTextScale(child: child ?? const SizedBox.shrink()),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decides where the app opens. In practice this now always lands on the
/// Welcome screen, since SupabaseConfig disables session persistence
/// (see supabase_config.dart) — there's never a session to resume. Kept as
/// a real check (not hardcoded) so persistence can be turned back on later
/// without touching this gate at all.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Decode both backgrounds once, up front, so the first screen
    // transition doesn't flash the fallback gradient.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        AppBackgrounds.precache(context);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const WelcomeScreen();
    }
    try {
      final session = SupabaseConfig.client.auth.currentSession;
      return session == null ? const WelcomeScreen() : const HomeScreen();
    } catch (_) {
      return const WelcomeScreen();
    }
  }
}

