import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _keepLoggedIn = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailHasError = false;
  bool _passwordHasError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showDemoOrSignupDialog(String inputEmail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_search_rounded,
                  color: Color(0xFF0D653E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Account Not Found',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'No registered Supabase account was found for "$inputEmail".\n\n'
          'Would you like to log in with Demo Mode to test the app, or create a new account?',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF4A5568),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              );
            },
            child: Text(
              'Create Account',
              style: GoogleFonts.outfit(
                color: const Color(0xFF718096),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D653E),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToHome();
            },
            child: Text(
              'Log in as Demo User',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _errorMessage = null;
      _emailHasError = false;
      _passwordHasError = false;
    });

    if (email.isEmpty && password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
        _emailHasError = true;
        _passwordHasError = true;
      });
      _showSnackBar('Please enter your email and password.');
      return;
    }

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email.';
        _emailHasError = true;
      });
      _showSnackBar('Please enter your email.');
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password.';
        _passwordHasError = true;
      });
      _showSnackBar('Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.signIn(
        email: email,
        password: password,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate to dashboard on successful Supabase authentication
        _navigateToHome();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
          _emailHasError = true;
          _passwordHasError = true;
        });
        _showSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        _showDemoOrSignupDialog(email);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Color(0xFF1A1D1E)),
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Welcome back',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1D1E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Log in to see your money, your sandbox and today's tips.",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF5A6578),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Inline Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF8B4B4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFF9B1C1C), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF9B1C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email
                        _buildInputFieldLabel('Email'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'you@email.com',
                          keyboardType: TextInputType.emailAddress,
                          hasError: _emailHasError,
                          onChanged: (_) {
                            if (_emailHasError || _errorMessage != null) {
                              setState(() {
                                _emailHasError = false;
                                _errorMessage = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // Password
                        _buildInputFieldLabel('Password'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _passwordController,
                          hintText: 'Your password',
                          obscureText: _obscurePassword,
                          hasError: _passwordHasError,
                          onChanged: (_) {
                            if (_passwordHasError || _errorMessage != null) {
                              setState(() {
                                _passwordHasError = false;
                                _errorMessage = null;
                              });
                            }
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: const Color(0xFF718096),
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Checkbox & Forgot Password Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _keepLoggedIn,
                                    activeColor: const Color(0xFF0D653E),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) => setState(
                                        () => _keepLoggedIn = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Keep me logged in',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: const Color(0xFF4A5568)),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen()),
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D653E),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Log in Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D653E),
                              disabledBackgroundColor:
                                  const Color(0xFF0D653E).withValues(alpha: 0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Log in',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Explore with Demo Account Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.flash_on_rounded,
                                color: Color(0xFF0D653E), size: 20),
                            label: Text(
                              'Explore with Demo Account',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D653E),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFEBF4EE),
                              side: const BorderSide(
                                  color: Color(0xFF0D653E), width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _navigateToHome,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Use fingerprint Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.fingerprint_rounded,
                                color: Color(0xFF0D653E), size: 22),
                            label: Text(
                              'Use fingerprint',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1D1E),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              _showSnackBar(
                                  'Fingerprint authentication is not enabled for this account.');
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Divider OR
                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Color(0xFFE2E8F0))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: const Color(0xFF718096)),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: Color(0xFFE2E8F0))),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Continue with Google Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            icon: Image.network(
                              'https://lh3.googleusercontent.com/COxitJu2yaJnseERlu3rE4nMTBUkoAkKfiR2HTXvW5md_3gE1KKOd72ReOmj53zznl8',
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: Colors.black87),
                            ),
                            label: Text(
                              'Continue with Google',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1D1E),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              _showSnackBar('Google Sign-In is coming soon!');
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Log in with a one-time code instead
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              _showSnackBar(
                                  'One-time code login is coming soon!');
                            },
                            child: Text(
                              'Log in with a one-time code instead',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D653E),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Footer: New to FinOps? Create an account
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'New to FinOps? ',
                                style: GoogleFonts.outfit(
                                    fontSize: 14, color: const Color(0xFF4A5568)),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const SignupScreen()),
                                ),
                                child: Text(
                                  'Create an account',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0D653E),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1D1E),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool hasError = false,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF1A1D1E)),
      cursorColor: const Color(0xFF0D653E),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: hintText,
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFA0AEC0)),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE53E3E) : const Color(0xFFE2E8F0),
            width: hasError ? 1.5 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE53E3E) : const Color(0xFF0D653E),
            width: 1.8,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE53E3E) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }
}

