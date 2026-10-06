// lib/views/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../home/home_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'widgets/labeled_text_field.dart';
import 'widgets/primary_action_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Pure UI for now — always "succeeds" and moves on to Home. Real
  // Supabase auth gets wired back in during the backend phase.
  void _handleLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 420,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 72),
            Text(
              'Log In',
              style: GoogleFonts.rubik(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Welcome back — enter your details to continue.',
              style: GoogleFonts.rubik(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 28),
            LabeledTextField(
              label: 'Email Id',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 19),
            LabeledTextField(
              label: 'Password',
              controller: _passwordController,
              isPassword: true,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen()),
                ),
                child: Text(
                  'Forget Password ?',
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 29),
            PrimaryActionButton(
              label: 'Login',
              onPressed: _handleLogin,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: Divider(color: Colors.white.withValues(alpha: 0.4))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Or',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SocialIconButton(asset: 'assets/icons/social_facebook.svg'),
                SizedBox(width: 9),
                _SocialIconButton(asset: 'assets/icons/social_google.svg'),
                SizedBox(width: 9),
                _SocialIconButton(asset: 'assets/icons/social_instagram.svg'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.rubik(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String asset;

  const _SocialIconButton({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(asset),
      ),
    );
  }
}
