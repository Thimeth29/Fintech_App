import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Frosted-glass card: backdrop blur, navy-tinted translucent fill, thin
/// white border, top-left sheen and a soft navy shadow.
///
/// [blur] defaults to the glass sigma; pass 0 for a flat translucent pane.
/// Blur is skipped automatically when [AppGlass.useBlur] is false, and the
/// fill gets more opaque to compensate.
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
  final double? width;

  /// Light streak drawn over the pane; defaults to [AppGradients.glassHighlight].
  final Gradient? sheen;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.gradient,
    this.backgroundColor,
    this.blur = AppGlass.blurSigma,
    this.borderRadius = AppGlass.radius,
    this.borderColor,
    this.onTap,
    this.width,
    this.sheen,
  });

  @override
  Widget build(BuildContext context) {
    final useBlur = blur > 0 && AppGlass.useBlur(context);
    final radius = BorderRadius.circular(borderRadius);
    final fill = backgroundColor ??
        (gradient == null
            ? (useBlur ? AppColors.glassFill : AppColors.glassFillNoBlur)
            : null);

    Widget pane = Container(
      decoration: BoxDecoration(
        color: fill,
        gradient: gradient,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.glassBorder, width: 1.0),
      ),
      child: Stack(
        // Passthrough keeps the child's constraints identical to the old
        // plain-Container card, so existing layouts don't shift.
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: sheen ?? AppGradients.glassHighlight),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (onTap != null) {
      pane = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: pane,
        ),
      );
    }

    pane = ClipRRect(
      borderRadius: radius,
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: pane,
            )
          : pane,
    );

    Widget result = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppGlass.shadow),
        child: pane,
      ),
    );

    if (width != null) {
      result = SizedBox(width: width, child: result);
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    return result;
  }
}
