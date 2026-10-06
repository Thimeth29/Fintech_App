import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The big rounded "block" buttons from the mockups (Sign Up Now, Login,
/// My Investments, CSE, etc). Has a light press animation and an optional
/// entrance animation for a bit of motion when a page first appears.
class BlockButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Duration entranceDelay;

  const BlockButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient,
    this.entranceDelay = Duration.zero,
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
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.15),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.96),
          onTapUp: (_) => setState(() => _scale = 1.0),
          onTapCancel: () => setState(() => _scale = 1.0),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: widget.gradient ?? AppGradients.block,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
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
