// lib/views/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../home/home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleLogin(AuthViewModel vm) async {
    final success = await vm.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: Consumer<AuthViewModel>(
        builder: (context, vm, _) {
          return GradientScaffold(
            appBar: AppBar(leading: const BackButton()),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  // Supabase authenticates by email; the mockup's "Name"
                  // field is used here as the email/sign-in identifier.
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 24),
                  if (vm.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: vm.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _handleLogin(vm),
                            child: const Text('Login'),
                          ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: const Text("Don't have an account? Sign up"),
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
