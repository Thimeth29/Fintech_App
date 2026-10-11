// Renders every screen at phone, tablet and desktop widths and fails on any
// RenderFlex overflow ("A RenderFlex overflowed by N pixels"). Other
// exceptions — e.g. a service call failing because tests have no network —
// are reported but don't fail the layout check.
//
// Widget tests normally draw text in the "FlutterTest" font, where every
// glyph is a full 1em square — roughly twice the width of real text — and
// Outfit can't be downloaded here. That makes text-heavy rows "overflow" in
// tests when they fit fine on a device. So the SDK's bundled Roboto is
// registered under GoogleFonts' per-weight family names ("Outfit_regular",
// "Outfit_700", …) to get realistic metrics. If the SDK fonts can't be
// found, the test still runs, just with the pessimistic test font.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/core/config/supabase_config.dart';
import 'package:my_app/core/responsive.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/viewmodels/auth_viewmodel.dart';
import 'package:my_app/viewmodels/sandbox_viewmodel.dart';
import 'package:my_app/views/auth/forgot_password_screen.dart';
import 'package:my_app/views/auth/login_screen.dart';
import 'package:my_app/views/auth/reset_password_screen.dart';
import 'package:my_app/views/auth/signup_screen.dart';
import 'package:my_app/views/auth/verification_code_screen.dart';
import 'package:my_app/views/auth/welcome_screen.dart';
import 'package:my_app/views/bot/chat_screen.dart';
import 'package:my_app/views/expenditure/expenditure_screen.dart';
import 'package:my_app/views/expenditure/explore_plans_screen.dart';
import 'package:my_app/views/expenditure/plan_expenses_screen.dart';
import 'package:my_app/views/home/home_screen.dart';
import 'package:my_app/views/community/community_screen.dart';
import 'package:my_app/views/investments/investing/cse_investments_screen.dart';
import 'package:my_app/views/investments/investing/fd_investments_screen.dart';
import 'package:my_app/views/investments/investing/gold_investments_screen.dart';
import 'package:my_app/views/investments/investing/gov_securities_screen.dart';
import 'package:my_app/views/investments/investing_options_screen.dart';
import 'package:my_app/views/profile/profile_screen.dart';
import 'package:my_app/views/sandbox/sandbox_screen.dart';

/// (width, OS text scale). The 1.3 cases check the top of the range the app
/// clamps text scaling to (see ClampedTextScale).
const _cases = <(double, double)>[
  (360, 1.0), (414, 1.0), (768, 1.0), (1024, 1.0), (1280, 1.0), (1920, 1.0),
  (360, 1.3), (1280, 1.3),
];

final _screens = <String, Widget Function()>{
  'Welcome': () => const WelcomeScreen(),
  'Login': () => const LoginScreen(),
  'Signup': () => const SignupScreen(),
  'Verification': () => const VerificationCodeScreen(email: 'test@example.com'),
  'ForgotPassword': () => const ForgotPasswordScreen(),
  'ResetPassword': () => const ResetPasswordScreen(),
  'Home': () => const HomeScreen(),
  'Expenditure': () => const ExpenditureScreen(),
  'PlanExpenses': () => const PlanExpensesScreen(),
  'ExplorePlans': () => const ExploreExpenditurePlansScreen(),
  'Sandbox': () => const SandboxScreen(),
  'InvestingOptions': () => const InvestingOptionsScreen(),
  'Community': () => const CommunityScreen(),
  'FD': () => const FdInvestmentsScreen(),
  'Gold': () => const GoldInvestmentsScreen(),
  'CSE': () => const CseInvestmentsScreen(),
  'GovSecurities': () => const GovSecuritiesScreen(),
  'Chat': () => const ChatScreen(),
  'Profile': () => const ProfileScreen(),
};

Future<void> _loadRealisticFont() async {
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final engineDir = File(Platform.resolvedExecutable).parent;
  final fontsDir = Directory(
      '${engineDir.parent.parent.path}${Platform.pathSeparator}material_fonts');
  if (!fontsDir.existsSync()) return;
  // GoogleFonts variant name -> closest bundled Roboto face.
  const faces = {
    '100': 'thin', '200': 'light', '300': 'light', 'regular': 'regular',
    '500': 'medium', '600': 'bold', '700': 'bold', '800': 'black', '900': 'black',
  };
  for (final e in faces.entries) {
    final file = File('${fontsDir.path}${Platform.pathSeparator}roboto-${e.value}.ttf');
    if (!file.existsSync()) continue;
    final loader = FontLoader('Outfit_${e.key}')
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.initialize();
    await _loadRealisticFont();
  });

  for (final entry in _screens.entries) {
    for (final (width, scale) in _cases) {
      // Portrait-ish phones, landscape-ish everything else.
      final height = width < Responsive.tablet ? 800.0 : 900.0;
      final label = scale == 1.0 ? '' : ' (text ×$scale)';
      testWidgets('${entry.key} @ ${width.toInt()}px$label has no overflow', (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final overflows = <String>[];
        final others = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            // Point at the offending widget in lib/ so failures are actionable.
            final where = RegExp(r'lib/[\w/]+\.dart:\d+')
                .firstMatch(details.toString(minLevel: DiagnosticLevel.info));
            overflows.add('${text.split('\n').first} @ ${where?.group(0) ?? '?'}');
          } else {
            others.add(text.split('\n').first);
          }
        };
        addTearDown(() => FlutterError.onError = previous);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthViewModel()),
              ChangeNotifierProvider(create: (_) => SandboxViewModel(listenToAuth: false)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) =>
                  ClampedTextScale(child: child ?? const SizedBox.shrink()),
              home: entry.value(),
            ),
          ),
        );
        // A few frames for entrance animations and async loads to settle,
        // without pumpAndSettle (some screens run periodic timers).
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        // Drain anything the test binding captured itself.
        Object? e;
        while ((e = tester.takeException()) != null) {
          final text = e.toString();
          (text.contains('overflowed') ? overflows : others).add(text.split('\n').first);
        }

        FlutterError.onError = previous;
        if (others.isNotEmpty) {
          // ignore: avoid_print
          print('[${entry.key} @ ${width.toInt()}] non-layout: ${others.toSet().join(' | ')}');
        }
        expect(overflows, isEmpty, reason: overflows.toSet().join('\n'));

        // Unmount, then run out any one-shot timers the screens scheduled
        // (refresh delays, carousels) so the binding doesn't flag them.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(minutes: 2));
      });
    }
  }
}
