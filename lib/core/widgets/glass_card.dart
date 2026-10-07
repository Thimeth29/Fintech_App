import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clean rounded Card container with subtle border & shadow matching the Forest Green light theme system.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double blur;
  final double borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.gradient,
    this.backgroundColor,
    this.blur = 0.0,
    this.borderRadius = 22.0,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (gradient == null ? Colors.white : null),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.borderLight,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    Widget result = cardContent;

    if (blur > 0) {
      result = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: result,
        ),
      );
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    if (onTap != null) {
      result = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: result,
      );
    }

    return result;
  }
}


