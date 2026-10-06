import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The back arrow used on every Forgot Password step in the Figma file.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: SvgPicture.asset(
        'assets/icons/arrow_left.svg',
        width: 24,
        height: 24,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}
