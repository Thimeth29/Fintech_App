// lib/views/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import 'login_screen.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/labeled_text_field.dart';
import 'widgets/primary_action_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;

  Future<void> _confirm() async {
    if (_passwordController.text.isEmpty ||
        _passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 420,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthBackButton(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'Reset Password',
                    style: GoogleFonts.rubik(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose a new password for your account.',
                    style: GoogleFonts.rubik(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 24),
                  LabeledTextField(
                    label: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),
                  LabeledTextField(
                    label: 'Confirm Password',
                    controller: _confirmController,
                    isPassword: true,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.rubik(
                          color: Colors.yellowAccent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 32),
                  PrimaryActionButton(
                    label: 'Confirm',
                    isLoading: _isSubmitting,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
