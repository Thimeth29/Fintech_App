import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'core/config/supabase_config.dart';
import 'viewmodels/sandbox_viewmodel.dart';
import 'views/guest/guest_sandbox_screen.dart';
import 'views/home/home_screen.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => SandboxViewModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financial Coaching App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(), // decides guest vs login vs home
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    return session == null
        ? const GuestSandboxScreen()   // no login required to try the app
        : const HomeScreen();          // logged-in users go straight to their dashboard
  }
}