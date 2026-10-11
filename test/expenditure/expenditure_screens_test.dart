// Renders the expenditure screens in their logged-in state with realistic
// seeded data (no Supabase calls) and fails on any layout overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/core/config/supabase_config.dart';
import 'package:my_app/core/responsive.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/models/debt_model.dart';
import 'package:my_app/models/expense_model.dart';
import 'package:my_app/models/finance_settings_model.dart';
import 'package:my_app/models/recurring_expense_model.dart';
import 'package:my_app/models/savings_goal_model.dart';
import 'package:my_app/viewmodels/debts_viewmodel.dart';
import 'package:my_app/viewmodels/expense_viewmodel.dart';
import 'package:my_app/viewmodels/finance_settings_viewmodel.dart';
import 'package:my_app/viewmodels/savings_goals_viewmodel.dart';
import 'package:my_app/views/expenditure/budgets_screen.dart';
import 'package:my_app/views/expenditure/debts_screen.dart';
import 'package:my_app/views/expenditure/expenditure_screen.dart';
import 'package:my_app/views/expenditure/plan_expenses_screen.dart';
import 'package:my_app/views/expenditure/recurring_expenses_screen.dart';
import 'package:my_app/views/expenditure/savings_goals_screen.dart';

const _uid = 'test-user';

/// Realistic metrics instead of the 1em-square test font (see
/// layout_overflow_test.dart).
Future<void> _loadFonts() async {
  final dir = Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}${Platform.pathSeparator}material_fonts');
  if (!dir.existsSync()) return;
  const faces = {
    'regular': 'regular', '500': 'medium', '600': 'bold', '700': 'bold', '800': 'black',
  };
  for (final e in faces.entries) {
    final f = File('${dir.path}${Platform.pathSeparator}roboto-${e.value}.ttf');
    if (!f.existsSync()) continue;
    await (FontLoader('Outfit_${e.key}')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

({
  ExpenseViewModel expenses,
  SavingsGoalsViewModel goals,
  DebtsViewModel debts,
  FinanceSettingsViewModel settings,
}) seededViewModels() {
  final now = DateTime.now();
  DateTime d(int monthsAgo, int day) => DateTime(now.year, now.month - monthsAgo, day.clamp(1, 28));
  var i = 0;
  ExpenseModel e(double amount, DateTime date, String category, {String? note, String? recurringId}) =>
      ExpenseModel(
        id: 'e${i++}',
        userId: _uid,
        amount: amount,
        category: category,
        note: note,
        expenseDate: date,
        createdAt: date,
        recurringId: recurringId,
      );

  final expenses = ExpenseViewModel()
    ..seedForTest(
      userId: _uid,
      expenses: [
        e(45000, d(0, 1), 'Housing', note: 'Rent — Nugegoda annex', recurringId: 'r1'),
        e(3250.50, d(0, 2), 'Food', note: 'Keells weekly groceries'),
        e(1800, d(0, 2), 'Transport', note: 'PickMe rides to office and back'),
        e(12500, d(0, 3), 'Entertainment', note: 'Concert tickets'),
        e(6400, d(0, 4), 'Utilities', note: 'CEB electricity bill'),
        e(2200, d(0, 5), 'Other'),
        for (var m = 1; m <= 3; m++) ...[
          e(45000, d(m, 1), 'Housing', recurringId: 'r1'),
          e(18000.0 + m * 900, d(m, 8), 'Food'),
          e(7000.0 - m * 300, d(m, 12), 'Transport'),
          e(9000, d(m, 20), 'Entertainment'),
        ],
      ],
      budgets: [
        {'category': 'Food', 'limit_amount': 20000, 'month_year': ''},
        {'category': 'Entertainment', 'limit_amount': 10000, 'month_year': ''},
        {'category': 'Transport', 'limit_amount': 2000, 'month_year': ''},
      ],
      recurring: [
        RecurringExpense(id: 'r1', userId: _uid, category: 'Housing', amount: 45000, note: 'Rent — Nugegoda annex',
            frequency: RecurringExpense.monthly, startDate: d(5, 1), nextDueDate: d(-1, 1)),
        RecurringExpense(id: 'r2', userId: _uid, category: 'Utilities', amount: 1499, note: 'Dialog fibre',
            frequency: RecurringExpense.monthly, startDate: d(3, 28), nextDueDate: now.add(const Duration(days: 5))),
        RecurringExpense(id: 'r3', userId: _uid, category: 'Transport', amount: 750, note: 'Weekly bus pass',
            frequency: RecurringExpense.weekly, startDate: now, nextDueDate: now.add(const Duration(days: 2))),
      ],
    );

  final goals = SavingsGoalsViewModel()
    ..seedForTest(userId: _uid, goals: [
      SavingsGoal(
        id: 'g1', userId: _uid, name: 'Year-end trip to Ella', targetAmount: 150000, icon: '✈️',
        deadline: DateTime(now.year, 12, 31), createdAt: d(4, 1), plannedMonthlyContribution: 15000,
        contributions: [
          GoalContribution(goalId: 'g1', userId: _uid, amount: 20000, contributedOn: d(3, 2)),
          GoalContribution(goalId: 'g1', userId: _uid, amount: 10000, contributedOn: d(1, 2)),
        ],
      ),
      SavingsGoal(
        id: 'g2', userId: _uid, name: 'Emergency fund', targetAmount: 300000, icon: '🛟',
        createdAt: d(2, 1),
        contributions: [GoalContribution(goalId: 'g2', userId: _uid, amount: 300000, contributedOn: d(0, 1))],
        status: SavingsGoal.completed,
      ),
    ]);

  final debts = DebtsViewModel()
    ..seedForTest(userId: _uid, debts: [
      Debt(id: 'd1', userId: _uid, direction: Debt.lent, personName: 'Kasun Perera (cousin)',
          principalAmount: 25000, startDate: d(2, 1), dueDate: now.subtract(const Duration(days: 3)),
          payments: [DebtPayment(debtId: 'd1', userId: _uid, amount: 10000, paidOn: d(1, 1))]),
      Debt(id: 'd2', userId: _uid, direction: Debt.borrowed, personName: 'Office welfare fund',
          principalAmount: 50000, startDate: d(1, 1), dueDate: now.add(const Duration(days: 4))),
      Debt(id: 'd3', userId: _uid, direction: Debt.lent, personName: 'Nimali', principalAmount: 5000,
          status: Debt.settled, startDate: d(3, 1),
          payments: [DebtPayment(debtId: 'd3', userId: _uid, amount: 5000, paidOn: d(2, 1))]),
    ]);

  final settings = FinanceSettingsViewModel()
    ..seedForTest(userId: _uid, settings: const FinanceSettings(monthlyIncome: 185000, incomeDay: 25));

  return (expenses: expenses, goals: goals, debts: debts, settings: settings);
}

final _screens = <String, Widget Function(dynamic vms)>{
  'Hub': (v) => ExpenditureScreen(testViewModels: v),
  'Plan': (v) => PlanExpensesScreen(viewModel: v.expenses),
  'Budgets': (v) => BudgetsScreen(viewModel: v.expenses),
  'Recurring': (v) => RecurringExpensesScreen(viewModel: v.expenses),
  'Goals': (v) => SavingsGoalsScreen(viewModel: v.goals),
  'Debts': (v) => DebtsScreen(viewModel: v.debts),
};

const _cases = <(double, double)>[(360, 1.0), (414, 1.0), (1280, 1.0), (360, 1.3)];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.initialize();
    await _loadFonts();
  });

  for (final s in _screens.entries) {
    for (final (width, scale) in _cases) {
      testWidgets('${s.key} @ ${width.toInt()}px${scale == 1 ? '' : ' ×$scale'} renders without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, width < Responsive.tablet ? 1600 : 1000);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final problems = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString(minLevel: DiagnosticLevel.info));
          problems.add('${text.split('\n').first} @ ${where?.group(0) ?? '?'}');
        };
        addTearDown(() => FlutterError.onError = previous);

        final vms = seededViewModels();
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => ClampedTextScale(child: child ?? const SizedBox.shrink()),
          home: s.value(vms),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        FlutterError.onError = previous;
        // Image/network noise isn't a layout problem; everything else is.
        expect(problems.where((p) => !p.contains('HTTP') && !p.contains('NetworkImage')), isEmpty,
            reason: problems.join('\n'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(minutes: 2));
      });
    }
  }
}
