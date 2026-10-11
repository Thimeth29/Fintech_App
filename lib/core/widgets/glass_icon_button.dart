import 'dart:ui';
import 'package:flutter/material.dart';
import '../platform/app_platform.dart';
import '../theme/app_theme.dart';

/// Small square glass button with a white icon — back buttons, toolbar
/// actions, social buttons.
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 18,
    this.tooltip,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.size >= 44 ? 18 : 14);
    final hasHover = AppPlatform.hasHover(context);
    final useBlur = AppGlass.useBlur(context);

    Widget button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: radius,
        mouseCursor: hasHover ? SystemMouseCursors.click : MouseCursor.defer,
        onHover: hasHover ? (h) => setState(() => _hover = h) : null,
        splashColor: Colors.white.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.glassFillStrong
                : (useBlur ? AppColors.glassFill : AppColors.glassFillNoBlur),
            borderRadius: radius,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(widget.icon, color: AppColors.onGlass, size: widget.iconSize),
        ),
      ),
    );

    button = ClipRRect(
      borderRadius: radius,
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: button,
            )
          : button,
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
