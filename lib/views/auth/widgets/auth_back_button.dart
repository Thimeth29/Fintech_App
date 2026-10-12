import 'package:flutter/material.dart';
import '../../../core/widgets/glass_icon_button.dart';
import '../welcome_screen.dart';

/// Pops the current auth screen, or returns to Welcome when it was opened
/// with the stack cleared (after logout or a password reset).
void authGoBack(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }
}

/// The back arrow used on auth screens.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12),
      child: GlassIconButton(
        icon: Icons.arrow_back,
        size: 44,
        iconSize: 20,
        tooltip: 'Back',
        onPressed: () => authGoBack(context),
      ),
    );
  }
}
