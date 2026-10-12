import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../responsive.dart';

/// Platform checks that are safe on every target, including web.
///
/// Uses only [kIsWeb] and [defaultTargetPlatform] — never `dart:io`'s
/// `Platform.isX`, which throws on web.
class AppPlatform {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Android or iOS, whether running natively or in a mobile browser.
  static bool get isMobileOS => isAndroid || isIOS;

  static bool get isDesktopOS =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Whether a mouse pointer is likely: desktop OSes, or a browser on a
  /// desktop-width window that isn't running on a phone/tablet OS.
  static bool hasHover(BuildContext context) {
    if (isDesktopOS) return true;
    return isWeb && !isMobileOS && MediaQuery.sizeOf(context).width >= Responsive.desktop;
  }
}
