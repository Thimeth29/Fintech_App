import 'package:flutter/material.dart';
import '../theme/app_backgrounds.dart';
import '../responsive.dart';

/// Every screen sits on the same blurred-artwork backdrop. Wrap a screen's
/// Scaffold content in this instead of setting a background color
/// directly — it also centers and caps content width on wide
/// (tablet/desktop/web) viewports so layouts don't stretch edge to edge.
class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final double maxContentWidth;
  final AppBackgroundKind background;
  final bool? resizeToAvoidBottomInset;

  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.maxContentWidth = 640,
    this.background = AppBackgroundKind.main,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      kind: background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          child: ResponsiveCenter(maxWidth: maxContentWidth, child: body),
        ),
      ),
    );
  }
}
