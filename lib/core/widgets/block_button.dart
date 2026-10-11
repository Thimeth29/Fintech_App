import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../platform/app_platform.dart';
import '../theme/app_theme.dart';

/// Rounded glass action tile with press-scale feedback, an entrance
/// animation and (on pointer devices) a hover lift.
///
/// Passing [gradient], or [backgroundColor] == [AppColors.primary], gives
/// the emphasised blue variant; anything else is a plain glass tile.
class BlockButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration entranceDelay;
  final double height;
  final String? subtitle;

  const BlockButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient,
    this.backgroundColor,
    this.textColor,
    this.entranceDelay = Duration.zero,
    this.height = 84,
    this.subtitle,
  });

  @override
  State<BlockButton> createState() => _BlockButtonState();
}

class _BlockButtonState extends State<BlockButton> {
  double _scale = 1.0;
  bool _visible = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.entranceDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final hasHover = AppPlatform.hasHover(context);
    final useBlur = AppGlass.useBlur(context);

    final bool emphasised =
        widget.gradient != null || widget.backgroundColor == AppColors.primary;
    final Gradient? gradient =
        widget.gradient ?? (emphasised ? AppGradients.block : null);
    final Color effectiveText = widget.textColor ?? AppColors.onGlass;
    final radius = BorderRadius.circular(22);

    final Color? fill = gradient != null
        ? null
        : _hover
            ? AppColors.glassFillStrong
            : ((widget.backgroundColor == null ||
                    widget.backgroundColor == AppColors.glassFill)
                ? (useBlur ? AppColors.glassFill : AppColors.glassFillNoBlur)
                : widget.backgroundColor);

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: emphasised || _hover ? AppColors.glassBorderStrong : AppColors.glassBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: effectiveText,
                    height: 1.2,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.onGlassMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    tile = ClipRRect(
      borderRadius: radius,
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppGlass.blurSigma, sigmaY: AppGlass.blurSigma),
              child: tile,
            )
          : tile,
    );

    tile = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppGlass.shadow),
        child: tile,
      ),
    );

    final entrance = reduceMotion ? Duration.zero : const Duration(milliseconds: 350);

    return AnimatedOpacity(
      duration: entrance,
      opacity: _visible || reduceMotion ? 1 : 0,
      child: AnimatedSlide(
        duration: entrance,
        curve: Curves.easeOutCubic,
        offset: _visible || reduceMotion ? Offset.zero : const Offset(0, 0.12),
        child: MouseRegion(
          cursor: hasHover ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: hasHover ? (_) => setState(() => _hover = true) : null,
          onExit: hasHover ? (_) => setState(() => _hover = false) : null,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _scale = 0.96),
            onTapUp: (_) => setState(() => _scale = 1.0),
            onTapCancel: () => setState(() => _scale = 1.0),
            onTap: widget.onTap,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 160),
              offset: _hover ? const Offset(0, -0.03) : Offset.zero,
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeInOut,
                child: tile,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
