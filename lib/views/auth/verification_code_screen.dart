// lib/views/auth/verification_code_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
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
    final primary = Theme.of(context).colorScheme.primary;
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
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'F',
                          style: GoogleFonts.rubik(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'FinSmart',
                          style: GoogleFonts.rubik(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _timerLabel,
                      style: GoogleFonts.rubik(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verification Code',
                    style: GoogleFonts.rubik(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please confirm the security code sent to ${widget.email.isEmpty ? "your registered email" : widget.email}.',
                    style: GoogleFonts.rubik(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: List.generate(_codeLength, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i == _codeLength - 1 ? 0 : 8),
                          child: SizedBox(
                            height: 54,
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: GoogleFonts.rubik(
                                  fontSize: 16, color: Colors.black),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.92),
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: primary, width: 1.5),
                                ),
                              ),
                              onChanged: (value) => _onDigitChanged(i, value),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  PrimaryActionButton(label: 'Confirm', onPressed: _confirm),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Did not receive the code?',
                          style: GoogleFonts.rubik(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _secondsLeft == 0 ? _startTimer : null,
                          child: Text(
                            'Send again',
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _secondsLeft == 0
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
