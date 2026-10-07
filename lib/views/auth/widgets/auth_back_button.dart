import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// The back arrow used on auth screens.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
      ),
    );
  }
}


