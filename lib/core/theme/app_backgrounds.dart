import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

enum AppBackgroundKind { main, welcome }

class AppBackgrounds {
  /// Teal / blue / violet abstract with overlapping glossy circles.
  static const String main = 'assets/branding/bg_main.jpg';

  /// Blue glass vessel — Welcome, login, sign-up and the rest of auth.
  static const String welcome = 'assets/branding/bg_welcome.jpg';

  /// Source images are 736×1472 (1:2 portrait).
  static const double _sourceAspect = 736 / 1472;

  static String pathFor(AppBackgroundKind kind) =>
      kind == AppBackgroundKind.welcome ? welcome : main;

  /// Where to anchor the crop when [BoxFit.cover] trims a portrait image on
  /// a wide screen — keeps the most interesting band in view.
  static Alignment alignmentFor(AppBackgroundKind kind) =>
      kind == AppBackgroundKind.welcome ? Alignment.center : const Alignment(0, -0.15);

  /// Downscaled provider sized to what [BoxFit.cover] will actually draw on
  /// this screen, so phones and browsers don't hold a full-size bitmap.
  /// Widths are bucketed so resizing a window doesn't re-decode every frame.
  /// [ResizeImage] never upscales, so wide screens simply get the source.
  static ImageProvider providerFor(AppBackgroundKind kind, BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final drawnWidth = math.max(size.width, size.height * _sourceAspect) * dpr;
    final bucketed = ((drawnWidth / 256).ceil() * 256).clamp(256, 4096);
    return ResizeImage(AssetImage(pathFor(kind)), width: bucketed);
  }

  /// Warms the image cache for both backgrounds. Never throws — a missing
  /// asset just means [AppBackground] shows its gradient fallback.
  static Future<void> precache(BuildContext context) async {
    for (final kind in AppBackgroundKind.values) {
      try {
        await precacheImage(
          providerFor(kind, context),
          context,
          onError: (_, __) {},
        );
      } catch (_) {
        // Fallback gradient covers it.
      }
    }
  }
}

/// Full-bleed background: image, then a dark-blue overlay so white text
/// stays readable over the pale parts of the artwork. Falls back to
/// [AppGradients.background] if the image is missing or still decoding.
class AppBackground extends StatelessWidget {
  final AppBackgroundKind kind;
  final Widget? child;

  const AppBackground({super.key, this.kind = AppBackgroundKind.main, this.child});

  /// Navy #0B1F4D @ 60% at the top easing to #1E3A8A @ 45% at the bottom.
  /// Tuned against the brightest 2% of pixels in both images so white text
  /// on glass panes stays ≥ 4.5:1 (WCAG AA).
  static const LinearGradient overlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x990B1F4D), Color(0x731E3A8A)],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.background)),
        RepaintBoundary(
          child: Image(
            image: AppBackgrounds.providerFor(kind, context),
            fit: BoxFit.cover,
            alignment: AppBackgrounds.alignmentFor(kind),
            gaplessPlayback: true,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              );
            },
          ),
        ),
        const DecoratedBox(decoration: BoxDecoration(gradient: overlay)),
        if (child != null) child!,
      ],
    );
  }
}
