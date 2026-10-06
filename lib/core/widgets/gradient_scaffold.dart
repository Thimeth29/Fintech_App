import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../responsive.dart';

/// Every screen sits on the same brand gradient backdrop. Wrap a screen's
/// Scaffold content in this instead of setting a background color
/// directly — it also centers and caps content width on wide
/// (tablet/desktop/web) viewports so layouts don't stretch edge to edge.
class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.maxContentWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          child: ResponsiveCenter(maxWidth: maxContentWidth, child: body),
        ),
      ),
    );
  }
}
