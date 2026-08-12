import 'package:flutter/material.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/block_button.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import '../sandbox/sandbox_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome To The Personal Finance Management',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 56),
            BlockButton(
              label: 'Sign UP Now',
              entranceDelay: const Duration(milliseconds: 0),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
            ),
            const SizedBox(height: 20),
            BlockButton(
              label: 'Login',
              entranceDelay: const Duration(milliseconds: 100),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
            const SizedBox(height: 20),
            BlockButton(
              label: 'TRY SandBox',
              entranceDelay: const Duration(milliseconds: 200),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SandboxScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
