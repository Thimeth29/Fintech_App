import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 1; // 1: Account, 2: Verify, 22: Guardian (2b), 3: About You, 4: Money Profile, 5: Complete
  bool _isUnder18 = false;

  // Step 1 Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  // Step 2 OTP Controllers
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Step 2b Guardian Controllers
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  String? _guardianRelation = 'Parent';

  // Step 3 About You State
  String _userRole = 'Employee'; // Student, Employee, Business owner, Other adult
  final _occupationController = TextEditingController();
  String? _selectedDistrict = 'Colombo';
  String _selectedLanguage = 'English'; // Sinhala, Tamil, English

  // Step 4 Money Profile State
  String _monthlyIncome = '50,000–100,000';
  String _incomeSource = 'Salary';
  final _spendingController = TextEditingController(text: '65,000');
  String _emergencySavings = 'Under 1 month of spending';
  String _dependents = '1–2';
  final Set<String> _selectedAssets = {'Savings account', 'Gold'};

  final List<String> _districts = const [
    'Colombo',
    'Gampaha',
    'Kalutara',
    'Kandy',
    'Matale',
    'Nuwara Eliya',
    'Galle',
    'Matara',
    'Hambantota',
    'Jaffna',
    'Kilinochchi',
    'Mannar',
    'Vavuniya',
    'Mullaitivu',
    'Batticaloa',
    'Ampara',
    'Trincomalee',
    'Kurunegala',
    'Puttalam',
    'Anuradhapura',
    'Polonnaruwa',
    'Badulla',
    'Moneragala',
    'Ratnapura',
    'Kegalle',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    _occupationController.dispose();
    _spendingController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_currentStep == 22) {
        _currentStep = 3;
      } else if (_currentStep == 3) {
        _currentStep = 4;
      } else if (_currentStep == 4) {
        _finishOnboarding();
      }
    });
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_currentStep == 22) {
        _currentStep = 2;
      } else if (_currentStep > 1) {
        _currentStep--;
      } else {
        Navigator.of(context).maybePop();
      }
    });
  }

  bool _isFinishing = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isResending = false;
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSecondsLeft <= 1) {
          _resendSecondsLeft = 0;
          timer.cancel();
        } else {
          _resendSecondsLeft--;
        }
      });
    });
  }

  // Step 1 -> Step 2. Verification is email-only: a real 6-digit code is
  // sent via Supabase to the email address. The mobile number collected in
  // Step 1 is contact info only — it's never used to sign in or verified.
  Future<void> _handleStep1Continue() async {
    FocusScope.of(context).unfocus();
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        _dobController.text.isEmpty ||
        password.isEmpty) {
      _showSnackBar('Please fill in your name, email, mobile number, date of birth and password.');
      return;
    }
    if (!AuthService.looksLikeEmail(email)) {
      _showSnackBar('Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showSnackBar('Password must be at least 8 characters.');
      return;
    }
    if (!_agreedToTerms) {
      _showSnackBar('Please agree to the Terms and Privacy Policy to continue.');
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      await AuthService().sendEmailOtp(email: email, name: name);
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _currentStep = 2;
      });
      _startResendCountdown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      _showSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      _showSnackBar('Could not send a verification code: ${e.toString()}');
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendSecondsLeft > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      final name = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      await AuthService().sendEmailOtp(email: email, name: name);
      if (!mounted) return;
      _showSnackBar('A new code is on its way.', isError: false);
      _startResendCountdown();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not resend the code: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      _showSnackBar('Enter the 6-digit code we sent you.');
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final email = _emailController.text.trim();
      final authService = AuthService();
      final response = await authService.verifyEmailOtp(email: email, token: code);
      if (response?.session == null) {
        throw const AuthException('That code did not work — please try again.');
      }
      await authService.setPassword(_passwordController.text.trim());
      if (!mounted) return;
      _resendTimer?.cancel();
      setState(() {
        _isVerifyingOtp = false;
        _currentStep = _isUnder18 ? 22 : 3;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      _showSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      _showSnackBar('Verification failed: ${e.toString()}');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF0D653E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in your name, email and password first.');
      setState(() => _currentStep = 1);
      return;
    }

    setState(() => _isFinishing = true);
    final authService = AuthService();

    final profileFields = {
      'user_role': _userRole,
      'occupation': _occupationController.text.trim().isNotEmpty
          ? _occupationController.text.trim()
          : 'Employed',
      'district': _selectedDistrict ?? 'Colombo',
      'preferred_language': _selectedLanguage,
      'is_under_18': _isUnder18,
      'guardian_name': _guardianNameController.text.trim(),
      'guardian_mobile': _guardianContactController.text.trim(),
      'guardian_relation': _guardianRelation,
      'selected_assets': _selectedAssets.toList(),
    };

    try {
      if (authService.currentUser != null) {
        // The account already exists and is verified (from the email OTP
        // step), with a live session and password already set. Just attach
        // the rest of the onboarding answers, including the contact-only
        // mobile number.
        await authService.updateProfile({
          'full_name': name,
          'email': email,
          if (phone.isNotEmpty) 'mobile_number': phone,
          ...profileFields,
        });
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }

      // Defensive fallback: there's no live session (the OTP step wasn't
      // completed), so the account is created here for the first time.
      final response = await authService.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
        extraMetaData: profileFields,
      );

      if (!mounted) return;

      if (response?.session != null) {
        // Signed up AND already has a live session (email confirmation is
        // off for this project) — go straight to the dashboard.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else if (response?.user != null) {
        // Account was created, but Supabase requires email confirmation
        // before a session can start — there is no session yet, so sending
        // the user to Home would show a logged-out state. Send them to
        // Login instead with a clear explanation.
        _showSnackBar(
          'Account created! Check $email for a confirmation link, then log in.',
          isError: false,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showSnackBar('Sign up did not complete — please try again.');
        setState(() => _isFinishing = false);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
      setState(() => _isFinishing = false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Sign up failed: ${e.toString()}');
      setState(() => _isFinishing = false);
    }
  }

  // Pick Date of Birth
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2004, 5, 15),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D653E),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
      final age = DateTime.now().year - picked.year;
      setState(() {
        _dobController.text = formatted;
        _isUnder18 = age < 18;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Progress Header
            _buildTopProgressHeader(),

            // Step Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildCurrentStepBody(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP PROGRESS HEADER
  // ==========================================
  Widget _buildTopProgressHeader() {
    int displayStep = _currentStep == 22 ? 2 : _currentStep;
    double progressRatio = displayStep / 5.0;

    String categoryText = 'Account';
    switch (_currentStep) {
      case 1:
        categoryText = 'Account';
        break;
      case 2:
        categoryText = 'Verify';
        break;
      case 22:
        categoryText = 'Guardian';
        break;
      case 3:
        categoryText = 'About you';
        break;
      case 4:
        categoryText = 'Money profile';
        break;
      case 5:
        categoryText = 'Goals';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // Circular Back Button
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
                  onPressed: _prevStep,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 16),
              // Progress Line & Texts
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step $displayStep of 5',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A5568),
                          ),
                        ),
                        Text(
                          categoryText,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A5568),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Color(0xFF0D653E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SWITCH CURRENT STEP BODY
  // ==========================================
  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Account();
      case 2:
        return _buildStep2Verify();
      case 22:
        return _buildStep2bGuardian();
      case 3:
        return _buildStep3AboutYou();
      case 4:
        return _buildStep4MoneyProfile();
      default:
        return _buildStep1Account();
    }
  }

  // ==========================================
  // STEP 1: CREATE YOUR ACCOUNT
  // ==========================================
  Widget _buildStep1Account() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Create your account',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1D1E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Practise investing safely and get money advice that explains itself.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF5A6578),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Full name
        _buildInputFieldLabel('Full name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _fullNameController,
          hintText: 'e.g. Nimali Perera',
        ),
        const SizedBox(height: 16),

        // Email
        _buildInputFieldLabel('Email'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _emailController,
          hintText: 'you@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 4),
        Text(
          "We'll send a one-time code to verify it.",
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
        ),
        const SizedBox(height: 16),

        // Mobile number
        _buildInputFieldLabel('Mobile number'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _phoneController,
          hintText: '07X XXX XXXX',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 4),
        Text(
          'For contact purposes only — not used to sign in.',
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
        ),
        const SizedBox(height: 16),

        // Date of birth
        _buildInputFieldLabel('Date of birth'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: _buildTextField(
              controller: _dobController,
              hintText: 'mm/dd/yyyy',
              suffixIcon: const Icon(Icons.calendar_today_outlined,
                  size: 18, color: Color(0xFF1A1D1E)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Under 18? A parent or guardian approves your account.',
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
        ),
        const SizedBox(height: 16),

        // Password
        _buildInputFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _passwordController,
          hintText: 'Create a password',
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: const Color(0xFF718096),
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'At least 8 characters, with letters and numbers.',
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
        ),
        const SizedBox(height: 20),

        // Terms Checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreedToTerms,
                activeColor: const Color(0xFF0D653E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged: (val) =>
                    setState(() => _agreedToTerms = val ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: const Color(0xFF4A5568), height: 1.4),
                  children: const [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(
                        color: Color(0xFF0D653E),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Color(0xFF0D653E),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(
                        text:
                            ', and understand FinOps gives educational guidance, not professional financial advice.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Create account button
        _buildPrimaryButton(
          label: 'Create account',
          onTap: _handleStep1Continue,
          isLoading: _isSendingOtp,
        ),
        const SizedBox(height: 16),

        // Divider OR
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: const Color(0xFF718096)),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 16),

        // Continue with Google
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            icon: Image.network(
              'https://lh3.googleusercontent.com/COxitJu2yaJnseERlu3rE4nMTBUkoAkKfiR2HTXvW5md_3gE1KKOd72ReOmj53zznl8',
              height: 20,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.g_mobiledata, size: 24, color: Colors.black87),
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
            onPressed: () =>
                _showSnackBar('Google sign-in is coming soon.', isError: false),
          ),
        ),
        const SizedBox(height: 20),

        // Footer Log in link
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: GoogleFonts.outfit(
                    fontSize: 14, color: const Color(0xFF4A5568)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: Text(
                  'Log in',
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
    );
  }

  // ==========================================
  // STEP 2: ENTER YOUR CODE
  // ==========================================
  Widget _buildStep2Verify() {
    final contactText = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Email Icon Emblem
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEBF4EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: Color(0xFF0D653E),
            size: 26,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Enter your code',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1D1E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'We sent a 6-digit code to ',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: const Color(0xFF5A6578)),
            ),
            Text(
              contactText,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                _resendTimer?.cancel();
                setState(() {
                  _currentStep = 1;
                  _resendSecondsLeft = 0;
                });
              },
              child: Text(
                'Change',
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
        const SizedBox(height: 28),

        // 6-digit OTP Inputs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final isFilled = _otpControllers[index].text.isNotEmpty;
            return SizedBox(
              width: 52,
              height: 58,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E),
                ),
                cursorColor: const Color(0xFF0D653E),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isFilled
                          ? const Color(0xFF0D653E)
                          : const Color(0xFFE2E8F0),
                      width: isFilled ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF0D653E), width: 2),
                  ),
                ),
                onChanged: (val) {
                  setState(() {});
                  if (val.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              _resendSecondsLeft > 0
                  ? "Didn't get it? Resend in 0:${_resendSecondsLeft.toString().padLeft(2, '0')}"
                  : "Didn't get it?",
              style: GoogleFonts.outfit(
                  fontSize: 13, color: const Color(0xFF718096)),
            ),
            if (_resendSecondsLeft == 0) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _isResending ? null : _handleResendOtp,
                child: Text(
                  _isResending ? 'Sending…' : 'Resend code',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D653E),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 140),

        // Info Callout Card (Under 18)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF0D653E), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "If you're under 18, we'll ask a parent or guardian to approve your account next.",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF4A5568),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Verify button
        _buildPrimaryButton(
          label: 'Verify',
          onTap: _handleVerifyOtp,
          isLoading: _isVerifyingOtp,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ==========================================
  // STEP 2B: ASK A PARENT OR GUARDIAN
  // ==========================================
  Widget _buildStep2bGuardian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Ask a parent or guardian',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1D1E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Because you're under 18, a parent or guardian needs to approve your account.",
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF5A6578),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Their full name
        _buildInputFieldLabel('Their full name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _guardianNameController,
          hintText: 'e.g. Sunil Perera',
        ),
        const SizedBox(height: 16),

        // Relationship to you
        _buildInputFieldLabel('Relationship to you'),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _guardianRelation,
          items: const ['Parent', 'Guardian', 'Relative'],
          onChanged: (val) => setState(() => _guardianRelation = val),
        ),
        const SizedBox(height: 16),

        // Their mobile number or email
        _buildInputFieldLabel('Their mobile number or email'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _guardianContactController,
          hintText: '07X XXX XXXX',
        ),
        const SizedBox(height: 4),
        Text(
          "We'll send them a link to approve. They can see your learning progress, never your password.",
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
        ),
        const SizedBox(height: 24),

        // Mint Benefits Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF4EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'While you wait for approval',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D653E),
                ),
              ),
              const SizedBox(height: 12),
              _buildCheckRow('Lessons and quizzes are open'),
              const SizedBox(height: 8),
              _buildCheckRow('Sandbox practice with virtual money is open'),
              const SizedBox(height: 8),
              _buildCheckRow('Personal recommendations unlock after approval'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Send request button
        _buildPrimaryButton(
          label: 'Send request',
          onTap: _nextStep,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ==========================================
  // STEP 3: TELL US ABOUT YOU
  // ==========================================
  Widget _buildStep3AboutYou() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Tell us about you',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1D1E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This shapes your dashboard, lessons and advice.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF5A6578),
          ),
        ),
        const SizedBox(height: 24),

        // Section 1: Which best describes you? (2x2 Grid)
        _buildInputFieldLabel('Which best describes you?'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildRoleCard(
              title: 'Student',
              subtitle: 'Aged 15–18',
              icon: Icons.school_outlined,
              isSelected: _userRole == 'Student',
              onTap: () => setState(() => _userRole = 'Student'),
            ),
            _buildRoleCard(
              title: 'Employee',
              subtitle: 'Monthly salary',
              icon: Icons.work_outline_rounded,
              isSelected: _userRole == 'Employee',
              onTap: () => setState(() => _userRole = 'Employee'),
            ),
            _buildRoleCard(
              title: 'Business owner',
              subtitle: 'Own or run a business',
              icon: Icons.storefront_outlined,
              isSelected: _userRole == 'Business owner',
              onTap: () => setState(() => _userRole = 'Business owner'),
            ),
            _buildRoleCard(
              title: 'Other adult',
              subtitle: 'Homemaker, retired, other',
              icon: Icons.person_outline_rounded,
              isSelected: _userRole == 'Other adult',
              onTap: () => setState(() => _userRole = 'Other adult'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Occupation or field
        _buildInputFieldLabel('Occupation or field'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _occupationController,
          hintText: 'e.g. Teacher, IT, Retail',
        ),
        const SizedBox(height: 16),

        // District
        _buildInputFieldLabel('District'),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _selectedDistrict,
          items: _districts,
          hintText: 'Select your district',
          onChanged: (val) => setState(() => _selectedDistrict = val),
        ),
        const SizedBox(height: 16),

        // App language
        _buildInputFieldLabel('App language'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildLanguagePill('සිංහල'),
            const SizedBox(width: 8),
            _buildLanguagePill('தமிழ்'),
            const SizedBox(width: 8),
            _buildLanguagePill('English'),
          ],
        ),
        const SizedBox(height: 32),

        // Continue button
        _buildPrimaryButton(
          label: 'Continue',
          onTap: _nextStep,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ==========================================
  // STEP 4: YOUR MONEY TODAY (MONEY PROFILE)
  // ==========================================
  Widget _buildStep4MoneyProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Your money today',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1D1E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ranges are fine. You can change these any time.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF5A6578),
          ),
        ),
        const SizedBox(height: 24),

        // 1. Monthly income (Rs)
        _buildInputFieldLabel('Monthly income (Rs)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip('Under 50,000', _monthlyIncome,
                (val) => setState(() => _monthlyIncome = val)),
            _buildChoiceChip('50,000–100,000', _monthlyIncome,
                (val) => setState(() => _monthlyIncome = val)),
            _buildChoiceChip('100,000–200,000', _monthlyIncome,
                (val) => setState(() => _monthlyIncome = val)),
            _buildChoiceChip('Over 200,000', _monthlyIncome,
                (val) => setState(() => _monthlyIncome = val)),
            _buildChoiceChip('Prefer not to say', _monthlyIncome,
                (val) => setState(() => _monthlyIncome = val)),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Main source of income
        _buildInputFieldLabel('Main source of income'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip(
                'Salary', _incomeSource, (val) => setState(() => _incomeSource = val)),
            _buildChoiceChip('Business', _incomeSource,
                (val) => setState(() => _incomeSource = val)),
            _buildChoiceChip('Allowance', _incomeSource,
                (val) => setState(() => _incomeSource = val)),
            _buildChoiceChip('Freelance / irregular', _incomeSource,
                (val) => setState(() => _incomeSource = val)),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Typical monthly spending
        _buildInputFieldLabel('Typical monthly spending'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _spendingController,
          hintText: 'e.g. 65,000',
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8, top: 14, bottom: 14),
            child: Text(
              'Rs',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D1E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Savings you could use in an emergency
        _buildInputFieldLabel('Savings you could use in an emergency'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip('None yet', _emergencySavings,
                (val) => setState(() => _emergencySavings = val)),
            _buildChoiceChip('Under 1 month of spending', _emergencySavings,
                (val) => setState(() => _emergencySavings = val)),
            _buildChoiceChip('1–3 months', _emergencySavings,
                (val) => setState(() => _emergencySavings = val)),
            _buildChoiceChip('3+ months', _emergencySavings,
                (val) => setState(() => _emergencySavings = val)),
          ],
        ),
        const SizedBox(height: 20),

        // 5. People who depend on your income
        _buildInputFieldLabel('People who depend on your income'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip(
                'None', _dependents, (val) => setState(() => _dependents = val)),
            _buildChoiceChip(
                '1–2', _dependents, (val) => setState(() => _dependents = val)),
            _buildChoiceChip(
                '3 or more', _dependents, (val) => setState(() => _dependents = val)),
          ],
        ),
        const SizedBox(height: 20),

        // 6. What do you already have? Pick all that apply (Multi-select)
        Row(
          children: [
            _buildInputFieldLabel('What do you already have? '),
            Text(
              'Pick all that apply',
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF718096)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Savings account',
            'Fixed deposit',
            'Gold',
            'Shares (CSE)',
            'Treasury bills / bonds',
            'Seettu',
            'Loan or lease',
            'None',
          ].map((asset) => _buildMultiAssetChip(asset)).toList(),
        ),
        const SizedBox(height: 24),

        // Encrypted footer note
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 16, color: Color(0xFF718096)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Encrypted and only used to personalise your advice. We never ask for bank or card details.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF718096),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Continue Button
        _buildPrimaryButton(
          label: 'Create Account',
          onTap: _nextStep,
          isLoading: _isFinishing,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

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
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF1A1D1E)),
      cursorColor: const Color(0xFF0D653E),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: hintText,
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFA0AEC0)),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0D653E), width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    String? hintText,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hintText ?? 'Select',
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFA0AEC0))),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF1A1D1E)),
          style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF1A1D1E)),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D653E),
          disabledBackgroundColor: const Color(0xFF0D653E).withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildCheckRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_rounded, color: Color(0xFF0D653E), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1D1E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF4EE) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D653E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? const Color(0xFF0D653E) : const Color(0xFF4A5568),
                size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D1E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF718096),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePill(String lang) {
    final isSelected = _selectedLanguage == lang;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLanguage = lang),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF4EE) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF0D653E) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Center(
            child: Text(
              lang,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF1A1D1E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
      String label, String currentSelected, ValueChanged<String> onSelected) {
    final isSelected = currentSelected == label;
    return GestureDetector(
      onTap: () => onSelected(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF4EE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D653E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0D653E) : const Color(0xFF1A1D1E),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiAssetChip(String asset) {
    final isSelected = _selectedAssets.contains(asset);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (asset == 'None') {
            _selectedAssets.clear();
            _selectedAssets.add('None');
          } else {
            _selectedAssets.remove('None');
            if (isSelected) {
              _selectedAssets.remove(asset);
            } else {
              _selectedAssets.add(asset);
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF4EE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D653E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Text(
          asset,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0D653E) : const Color(0xFF1A1D1E),
          ),
        ),
      ),
    );
  }
}
