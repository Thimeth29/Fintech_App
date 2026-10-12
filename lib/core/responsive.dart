import 'package:flutter/material.dart';

/// Breakpoints and small helpers used to keep layouts sane from a narrow
/// phone up through a resized desktop/web window — the app is tested in
/// Chrome during development, where an un-constrained phone layout would
/// otherwise stretch edge to edge and look unfinished.
class Responsive {
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Max content width per device class.
  static const double mobileMaxWidth = 640;
  static const double tabletMaxWidth = 900;
  static const double desktopMaxWidth = 1200;

  /// Bounds for the OS text-scale setting, so very large accessibility
  /// sizes don't overflow fixed-height cards and tiles.
  static const double minTextScale = 0.9;
  static const double maxTextScale = 1.3;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static DeviceType deviceTypeFor(double width) {
    if (width >= desktop) return DeviceType.desktop;
    if (width >= tablet) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  static double maxContentWidthFor(DeviceType type) {
    switch (type) {
      case DeviceType.desktop:
        return desktopMaxWidth;
      case DeviceType.tablet:
        return tabletMaxWidth;
      case DeviceType.mobile:
        return mobileMaxWidth;
    }
  }

  /// How many grid columns to use for a card/tile grid at the current width.
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) return 4;
    if (width >= tablet) return 3;
    return 2;
  }
}

enum DeviceType { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  DeviceType get deviceType => Responsive.deviceTypeFor(MediaQuery.sizeOf(this).width);
  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
}

/// Centers page content and caps its width on wide (tablet/desktop/web)
/// viewports, so phone-first layouts don't stretch edge to edge. On a
/// phone-width screen this is a no-op passthrough.
///
/// With the default [maxWidth] (640), tablets and desktops get the wider
/// [Responsive.tabletMaxWidth] / [Responsive.desktopMaxWidth]. Any other
/// value is an explicit cap (e.g. a 440px auth form) and is kept as-is.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    final type = context.deviceType;
    final cap = (type != DeviceType.mobile && maxWidth == Responsive.mobileMaxWidth)
        ? Responsive.maxContentWidthFor(type)
        : maxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}

/// Picks a layout by the width actually available, so it re-flows live as
/// a browser or desktop window is resized. [tablet] and [desktop] fall back
/// to the next-smaller layout when not given.
class AdaptiveLayout extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const AdaptiveLayout({super.key, required this.mobile, this.tablet, this.desktop});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        switch (Responsive.deviceTypeFor(width)) {
          case DeviceType.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case DeviceType.tablet:
            return (tablet ?? mobile)(context);
          case DeviceType.mobile:
            return mobile(context);
        }
      },
    );
  }
}

/// Clamps the inherited text scaler to the app's supported range.
class ClampedTextScale extends StatelessWidget {
  final Widget child;
  const ClampedTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: Responsive.minTextScale,
          maxScaleFactor: Responsive.maxTextScale,
        ),
      ),
      child: child,
    );
  }
}
