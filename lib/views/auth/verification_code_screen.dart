// lib/views/auth/verification_code_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/primary_action_button.dart';

const _codeLength = 6;
const _resendSeconds = 59;

class VerificationCodeScreen extends StatefulWidget {
  final String email;

  const VerificationCodeScreen({super.key, required this.email});

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _confirm() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
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
                        child: const Icon(Icons.mark_email_read_rounded, size: 36, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Verification Code',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please enter the 6-digit security code sent to ${widget.email.isEmpty ? "your registered email" : widget.email}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.mintBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'Expires in: $_timerLabel',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      padding: const EdgeInsets.all(22),
                      backgroundColor: Colors.white,
                      child: Column(
                        children: [
                          Row(
                            children: List.generate(_codeLength, (i) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right: i == _codeLength - 1 ? 0 : 6),
                                  child: SizedBox(
                                    height: 54,
                                    child: TextField(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                      cursorColor: AppColors.primary,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: AppColors.borderLight,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: AppColors.borderLight,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 1.8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) => _onDigitChanged(i, value),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),
                          PrimaryActionButton(label: 'Verify & Proceed', onPressed: _confirm),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive the code? ",
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              GestureDetector(
                                onTap: _secondsLeft == 0 ? _startTimer : null,
                                child: Text(
                                  'Resend Code',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _secondsLeft == 0
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
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

