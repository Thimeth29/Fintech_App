import 'package:flutter/material.dart';

/// Breakpoints and small helpers used to keep layouts sane from a narrow
/// phone up through a resized desktop/web window — the app is tested in
/// Chrome during development, where an un-constrained phone layout would
/// otherwise stretch edge to edge and look unfinished.
class Responsive {
  static const double tablet = 600;
  static const double desktop = 1024;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// How many grid columns to use for a card/tile grid at the current width.
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) return 4;
    if (width >= tablet) return 3;
    return 2;
  }
}

/// Centers page content and caps its width on wide (tablet/desktop/web)
/// viewports, so phone-first layouts don't stretch edge to edge. On a
/// phone-width screen this is a no-op passthrough.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
