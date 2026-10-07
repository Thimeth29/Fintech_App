// lib/views/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
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
      maxContentWidth: 440,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthBackButton(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: AppColors.mintBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.key_rounded, size: 36, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Reset Password',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a strong new password for your account.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      padding: const EdgeInsets.all(22),
                      backgroundColor: Colors.white,
                      child: Column(
                        children: [
                          LabeledTextField(
                            label: 'New Password',
                            controller: _passwordController,
                            isPassword: true,
                            hintText: 'Minimum 8 characters',
                          ),
                          const SizedBox(height: 16),
                          LabeledTextField(
                            label: 'Confirm New Password',
                            controller: _confirmController,
                            isPassword: true,
                            hintText: 'Re-enter new password',
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.outfit(
                                color: AppColors.rose,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          PrimaryActionButton(
                            label: 'Set New Password',
                            isLoading: _isSubmitting,
                            onPressed: _confirm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

