import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Every screen sits on the same purple -> blue -> teal gradient backdrop
/// from the mockups. Wrap a screen's Scaffold content in this instead of
/// setting a background color directly.
class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(child: body),
      ),
    );
  }
}
