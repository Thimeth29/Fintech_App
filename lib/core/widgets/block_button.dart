import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Next-Gen rounded action block button with responsive scale feedback,
/// entrance animations, and clean Forest Green light theme styling.
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

class _BlockButtonState extends State<BlockButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.entranceDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.gradient != null || widget.backgroundColor == AppColors.primary;
    final Color effectiveText = widget.textColor ?? (isDark ? Colors.white : AppColors.textDark);
    final Color effectiveSubtitle = isDark ? Colors.white70 : AppColors.textMuted;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.12),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.96),
          onTapUp: (_) => setState(() => _scale = 1.0),
          onTapCancel: () => setState(() => _scale = 1.0),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInOut,
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: widget.gradient,
                color: widget.gradient == null ? (widget.backgroundColor ?? Colors.white) : null,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.transparent : AppColors.borderLight,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.18) : AppColors.mintBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: isDark ? Colors.white : AppColors.primary,
                        size: 20,
                      ),
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
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: effectiveSubtitle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


