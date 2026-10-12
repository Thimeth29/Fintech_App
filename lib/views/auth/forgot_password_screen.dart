// lib/views/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_backgrounds.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'verification_code_screen.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/labeled_text_field.dart';
import 'widgets/primary_action_button.dart';
import '../../core/theme/app_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!AuthService.looksLikeEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await AuthService().sendPasswordResetOtp(email);
      if (!mounted) return;
      setState(() => _isSending = false);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerificationCodeScreen(email: email)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = 'Could not send a code: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      background: AppBackgroundKind.welcome,
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
                          color: AppColors.glassFillStrong,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.accentCyan),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: AppFonts.text(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onGlass,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter the email address associated with your account and we'll send you a verification code to reset your password.",
                      textAlign: TextAlign.center,
                      style: AppFonts.text(
                        fontSize: 13,
                        color: AppColors.onGlass,
                        height: 1.5,
                        shadows: kTitleShadow,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          LabeledTextField(
                            label: 'Email Address',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            hintText: 'name@example.com',
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: AppFonts.text(
                                color: AppColors.loss,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

