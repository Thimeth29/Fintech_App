import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/models/debt_model.dart';
import 'package:my_app/models/expense_model.dart';
import 'package:my_app/models/expense_priority.dart';
import 'package:my_app/models/recurring_expense_model.dart';
import 'package:my_app/models/savings_goal_model.dart';
import 'package:my_app/services/expense_forecast_service.dart';
import 'package:my_app/services/expenditure/goal_math.dart';
import 'package:my_app/services/expenditure/recurring_schedule.dart';
import 'package:my_app/services/expenditure/safe_to_spend.dart';

const _uid = 'u1';

ExpenseModel _e(double amount, DateTime date,
        {String category = 'Food', String? priority, String? recurringId}) =>
    ExpenseModel(
      id: '${date.toIso8601String()}-$amount-$category',
      userId: _uid,
      amount: amount,
      category: category,
      expenseDate: date,
      priority: priority,
      recurringId: recurringId,
      createdAt: date,
    );

RecurringExpense _r({
  required double amount,
  required DateTime start,
  DateTime? next,
  String frequency = RecurringExpense.monthly,
  String category = 'Housing',
  String? priority,
  String id = 'r1',
}) =>
    RecurringExpense(
      id: id,
      userId: _uid,
      category: category,
      amount: amount,
      priority: priority,
      frequency: frequency,
      startDate: start,
      nextDueDate: next ?? start,
    );

void main() {
  final forecast = ExpenseForecastService();

  group('ExpenseForecastService', () {
    test('1 month of history: that month, low confidence, ±15%', () {
      final now = DateTime(2026, 10, 15);
      final f = forecast.forecastNextMonth(
        expenses: [_e(10000, DateTime(2026, 9, 3)), _e(5000, DateTime(2026, 9, 20), category: 'Transport')],
        recurring: const [],
        now: now,
      )!;
      expect(f.month, DateTime(2026, 11));
      expect(f.total, closeTo(15000, 0.01));
      expect(f.byCategory['Food'], closeTo(10000, 0.01));
      expect(f.confidence, ForecastConfidence.low);
      expect(f.low, closeTo(15000 * 0.85, 0.01));
      expect(f.high, closeTo(15000 * 1.15, 0.01));
    });

    test('2 months: weights 0.5/0.3 renormalised, medium confidence', () {
      final f = forecast.forecastNextMonth(
        expenses: [_e(10000, DateTime(2026, 9, 1)), _e(20000, DateTime(2026, 8, 1))],
        recurring: const [],
        now: DateTime(2026, 10, 5),
      )!;
      // (0.5*10000 + 0.3*20000) / 0.8
      expect(f.total, closeTo(13750, 0.01));
      expect(f.confidence, ForecastConfidence.medium);
    });

    test('3+ months: 0.5/0.3/0.2, high confidence, std-dev range', () {
      final f = forecast.forecastNextMonth(
        expenses: [
          _e(10000, DateTime(2026, 9, 1)),
          _e(20000, DateTime(2026, 8, 1)),
          _e(30000, DateTime(2026, 7, 1)),
          _e(99999, DateTime(2026, 6, 1)), // older than 3 months: not in the average
        ],
        recurring: const [],
        now: DateTime(2026, 10, 5),
      )!;
      expect(f.total, closeTo(0.5 * 10000 + 0.3 * 20000 + 0.2 * 30000, 0.01));
      expect(f.confidence, ForecastConfidence.high);
      expect(f.high - f.total, greaterThan(0));
      expect(f.high - f.total, isNot(closeTo(f.total * 0.15, 0.01)));
    });

    test('a month with no spend after the first month counts as zero', () {
      final f = forecast.forecastNextMonth(
        expenses: [_e(10000, DateTime(2026, 8, 1))], // September empty
        recurring: const [],
        now: DateTime(2026, 10, 5),
      )!;
      // history = [Sep (0), Aug (10000)] -> (0.5*0 + 0.3*10000) / 0.8
      expect(f.total, closeTo(3750, 0.01));
    });

    test('recurring: generated rows excluded from average, next month\'s occurrences added', () {
      final rent = _r(amount: 40000, start: DateTime(2026, 1, 5), next: DateTime(2026, 11, 5));
      final f = forecast.forecastNextMonth(
        expenses: [
          _e(10000, DateTime(2026, 9, 10)),
          _e(40000, DateTime(2026, 9, 5), category: 'Housing', recurringId: 'r1'),
        ],
        recurring: [rent],
        now: DateTime(2026, 10, 20),
      )!;
      expect(f.recurringTotal, closeTo(40000, 0.01));
      expect(f.total, closeTo(50000, 0.01));
      expect(f.byCategory['Housing'], closeTo(40000, 0.01));
    });

    test('December bump: +15% on non-recurring spend only', () {
      final weekly = _r(
          amount: 1000,
          start: DateTime(2026, 12, 1),
          frequency: RecurringExpense.weekly,
          category: 'Transport'); // Dec 1, 8, 15, 22, 29 = 5
      final f = forecast.forecastNextMonth(
        expenses: [_e(20000, DateTime(2026, 10, 3))],
        recurring: [weekly],
        now: DateTime(2026, 11, 10),
      )!;
      expect(f.seasonalBumpApplied, isTrue);
      expect(f.total, closeTo(20000 * 1.15 + 5000, 0.01));
    });

    test('only the current month: scaled up to a full month', () {
      final f = forecast.forecastNextMonth(
        expenses: [_e(10000, DateTime(2026, 10, 1))],
        recurring: const [],
        now: DateTime(2026, 10, 10),
      )!;
      expect(f.usedPartialMonth, isTrue);
      expect(f.total, closeTo(10000 * 31 / 10, 0.01));
      expect(f.confidence, ForecastConfidence.low);
    });

    test('nothing to forecast returns null', () {
      expect(forecast.forecastNextMonth(expenses: const [], recurring: const [], now: DateTime(2026, 10, 1)),
          isNull);
    });
  });

  group('Recurring schedule', () {
    test('monthly keeps the anchor day and clamps short months', () {
      final r = _r(amount: 1, start: DateTime(2026, 1, 31));
      expect(nextOccurrence(r, DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
      expect(nextOccurrence(r, DateTime(2026, 2, 28)), DateTime(2026, 3, 31));
    });

    test('generation is idempotent: running twice yields nothing new', () {
      var r = _r(amount: 5000, start: DateTime(2026, 8, 15));
      final today = DateTime(2026, 10, 20);
      final first = dueOccurrences(r, today);
      expect(first, [DateTime(2026, 8, 15), DateTime(2026, 9, 15), DateTime(2026, 10, 15)]);
      // After generating, the next due date advances past today.
      r = r.copyWith(nextDueDate: advanceAfter(r, first));
      expect(r.nextDueDate, DateTime(2026, 11, 15));
      expect(dueOccurrences(r, today), isEmpty);
    });

    test('inactive items never generate', () {
      final r = _r(amount: 1, start: DateTime(2026, 1, 1)).copyWith(active: false);
      expect(dueOccurrences(r, DateTime(2026, 10, 1)), isEmpty);
    });

    test('weekly occurrences within a window', () {
      final r = _r(amount: 1, start: DateTime(2026, 10, 2), frequency: RecurringExpense.weekly);
      expect(occurrencesBetween(r, DateTime(2026, 10, 5), DateTime(2026, 10, 20)),
          [DateTime(2026, 10, 9), DateTime(2026, 10, 16)]);
    });
  });

  group('Safe-to-spend', () {
    final now = DateTime(2026, 10, 10);

    test('null without income', () {
      expect(
          computeSafeToSpend(
              monthlyIncome: null, expenses: const [], recurring: const [], goals: const [], debts: const [], now: now),
          isNull);
    });

    test('income − essentials − upcoming essentials − goals − debt repayments', () {
      final s = computeSafeToSpend(
        monthlyIncome: 200000,
        expenses: [
          _e(30000, DateTime(2026, 10, 2), category: 'Housing'), // essential
          _e(8000, DateTime(2026, 10, 3), category: 'Food'), // important
          _e(5000, DateTime(2026, 10, 4), category: 'Entertainment'), // flexible
          _e(99999, DateTime(2026, 9, 30), category: 'Housing'), // last month: ignored
        ],
        recurring: [
          _r(amount: 6000, start: DateTime(2026, 1, 25), next: DateTime(2026, 10, 25), category: 'Utilities'),
          _r(amount: 2000, start: DateTime(2026, 1, 25), next: DateTime(2026, 10, 25),
              category: 'Entertainment', priority: ExpensePriority.flexible, id: 'r2'), // not essential
        ],
        goals: [
          SavingsGoal(id: 'g', userId: _uid, name: 'Trip', targetAmount: 100000, plannedMonthlyContribution: 10000),
        ],
        debts: [
          Debt(id: 'd', userId: _uid, direction: Debt.borrowed, personName: 'A', principalAmount: 15000,
              dueDate: DateTime(2026, 10, 28)),
          Debt(id: 'd2', userId: _uid, direction: Debt.lent, personName: 'B', principalAmount: 50000,
              dueDate: DateTime(2026, 10, 28)), // lent: doesn't reduce safe-to-spend
        ],
        now: now,
      )!;
      expect(s.essentialSpent, 30000);
      expect(s.upcomingEssentials, 6000);
      expect(s.goalReserve, 10000);
      expect(s.debtRepayments, 15000);
      expect(s.safeToSpend, closeTo(200000 - 30000 - 6000 - 10000 - 15000, 0.01));
      expect(s.nonEssentialSpent, 13000);
      expect(s.leftToSpend, closeTo(139000 - 13000, 0.01));
    });

    test('goal reserve uses actual contributions when above the plan', () {
      final goal = SavingsGoal(
        id: 'g', userId: _uid, name: 'Trip', targetAmount: 100000, plannedMonthlyContribution: 5000,
        contributions: [GoalContribution(goalId: 'g', userId: _uid, amount: 12000, contributedOn: DateTime(2026, 10, 5))],
      );
      final s = computeSafeToSpend(
          monthlyIncome: 50000, expenses: const [], recurring: const [], goals: [goal], debts: const [], now: now)!;
      expect(s.goalReserve, 12000);
    });
  });

  group('Goal progress', () {
    test('required per month/week and on-track check', () {
      final goal = SavingsGoal(
        id: 'g', userId: _uid, name: 'Year-end trip', targetAmount: 120000,
        deadline: DateTime(2026, 12, 31),
        createdAt: DateTime(2026, 7, 1),
        contributions: [GoalContribution(goalId: 'g', userId: _uid, amount: 30000, contributedOn: DateTime(2026, 8, 1))],
      );
      final p = computeGoalProgress(goal, DateTime(2026, 10, 1));
      expect(p.remaining, 90000);
      expect(p.daysLeft, 91);
      expect(p.requiredPerMonth, closeTo(90000 / (91 / 30.4375), 0.01));
      expect(p.requiredPerWeek, closeTo(90000 / 13, 0.01));
      // ~3 months elapsed -> ~10k/month average, far below ~30k required.
      expect(p.isOnTrack, isFalse);
      expect(p.projectedShareAtDeadline!, lessThan(1));
    });

    test('complete goals are on track and need nothing more', () {
      final goal = SavingsGoal(
        id: 'g', userId: _uid, name: 'G', targetAmount: 1000, deadline: DateTime(2026, 12, 31),
        contributions: [GoalContribution(goalId: 'g', userId: _uid, amount: 1000, contributedOn: DateTime(2026, 10, 1))],
      );
      final p = computeGoalProgress(goal, DateTime(2026, 10, 2));
      expect(p.isComplete, isTrue);
      expect(p.isOnTrack, isTrue);
      expect(p.requiredPerMonth, 0);
    });

    test('milestones', () {
      expect(crossedMilestone(0, 260, 1000), 25);
      expect(crossedMilestone(200, 800, 1000), 75);
      expect(crossedMilestone(900, 1000, 1000), 100);
      expect(crossedMilestone(300, 400, 1000), isNull);
      expect(yearEndDeadline(DateTime(2026, 3, 4)), DateTime(2026, 12, 31));
    });
  });

  group('Debts', () {
    test('outstanding = principal − payments; overdue / due-soon', () {
      final d = Debt(
        id: 'd', userId: _uid, direction: Debt.lent, personName: 'Kamal', principalAmount: 10000,
        dueDate: DateTime(2026, 10, 8),
        payments: [
          DebtPayment(debtId: 'd', userId: _uid, amount: 4000, paidOn: DateTime(2026, 10, 1)),
          DebtPayment(debtId: 'd', userId: _uid, amount: 2500, paidOn: DateTime(2026, 10, 5)),
        ],
      );
      expect(d.outstanding, 3500);
      expect(d.isOverdue(DateTime(2026, 10, 10)), isTrue);
      expect(d.isDueWithin(DateTime(2026, 10, 2), 7), isTrue);
      expect(d.isDueWithin(DateTime(2026, 9, 1), 7), isFalse);
    });

    test('fully repaid debt has zero outstanding and is not overdue once settled', () {
      final d = Debt(
        id: 'd', userId: _uid, direction: Debt.borrowed, personName: 'Nimal', principalAmount: 5000,
        dueDate: DateTime(2026, 10, 1), status: Debt.settled,
        payments: [DebtPayment(debtId: 'd', userId: _uid, amount: 5000, paidOn: DateTime(2026, 9, 30))],
      );
      expect(d.outstanding, 0);
      expect(d.isOverdue(DateTime(2026, 10, 10)), isFalse);
    });
  });
}
