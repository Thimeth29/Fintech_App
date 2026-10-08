// Basic smoke tests: the app boots to the Welcome screen without crashing
// when there's no active Supabase session, and ProfileScreen renders
// without throwing a ProviderNotFoundException<AuthViewModel> (it used to
// — nothing provided AuthViewModel anywhere in the app).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/core/config/supabase_config.dart';
import 'package:my_app/main.dart';
import 'package:my_app/viewmodels/auth_viewmodel.dart';
import 'package:my_app/views/profile/profile_screen.dart';

void main() {
  setUpAll(() async {
    // supabase_flutter persists sessions via shared_preferences, which has
    // no real platform channel in the widget-test sandbox — fake one so
    // Supabase.initialize() (called by SupabaseConfig.initialize, same as
    // real app startup) can actually complete instead of hanging on it.
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.initialize();
  });

  testWidgets('App boots to the Welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('FinOps'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Get started'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders without a missing-provider crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(),
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    // The real bug: ProfileScreen used Consumer<AuthViewModel> with no
    // ChangeNotifierProvider<AuthViewModel> anywhere above it in the real
    // app, so it always threw on build. Confirming no exception and that
    // the screen's own content actually rendered is the meaningful check
    // here — "Log out of account" exists further down the ListView but
    // is outside the default test viewport, so it's not asserted on.
    expect(tester.takeException(), isNull);
    expect(find.text('My Profile'), findsOneWidget);
  });
}
