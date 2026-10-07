// lib/views/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import 'verification_code_screen.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/labeled_text_field.dart';
import 'widgets/primary_action_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendCode() async {
    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isSending = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            VerificationCodeScreen(email: _emailController.text.trim()),
      ),
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
                        child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter the email address associated with your account and we'll send you a verification code to reset your password.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      padding: const EdgeInsets.all(22),
                      backgroundColor: Colors.white,
                      child: Column(
                        children: [
                          LabeledTextField(
                            label: 'Email Address',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            hintText: 'name@example.com',
                          ),
                          const SizedBox(height: 24),
                          PrimaryActionButton(
                            label: 'Send Code',
                            isLoading: _isSending,
                            onPressed: _sendCode,
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

