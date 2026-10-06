// lib/views/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import 'verification_code_screen.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/labeled_text_field.dart';
import 'widgets/primary_action_button.dart';

/// The Figma frame for this step ("Email for forget password") only
/// contains a back arrow — its content is built here to match the same
/// field/button language used on the Login screen for consistency.
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
                  const SizedBox(height: 16),
                  Text(
                    'Forget Password',
                    style: GoogleFonts.rubik(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Enter the email address associated with your account and we'll send you a code to reset your password.",
                    style: GoogleFonts.rubik(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  LabeledTextField(
                    label: 'Email Id',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 32),
                  PrimaryActionButton(
                    label: 'Send Code',
                    isLoading: _isSending,
                    onPressed: _sendCode,
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
