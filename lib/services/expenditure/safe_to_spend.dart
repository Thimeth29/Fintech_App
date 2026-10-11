// Pure safe-to-spend calculation — no I/O, unit-tested.
import '../../models/debt_model.dart';
import '../../models/expense_model.dart';
import '../../models/expense_priority.dart';
import '../../models/recurring_expense_model.dart';
import '../../models/savings_goal_model.dart';
import 'recurring_schedule.dart';

class SafeToSpend {
  final double income;

  /// Essential expenses already logged this month.
  final double essentialSpent;

  /// Essential recurring bills still to come this month (not yet logged).
  final double upcomingEssentials;

  /// Money set aside for savings goals this month.
  final double goalReserve;

  /// Borrowed-money repayments this month (already paid + still due).
  final double debtRepayments;

  /// Important + flexible spending already logged this month.
  final double nonEssentialSpent;

  /// Unpaid seettu instalments due this month (groups not already linked
  /// to a recurring expense, so nothing is counted twice).
  final double upcomingSeettu;

  const SafeToSpend({
    required this.income,
    required this.essentialSpent,
    required this.upcomingEssentials,
    required this.goalReserve,
    required this.debtRepayments,
    required this.nonEssentialSpent,
    this.upcomingSeettu = 0,
  });

  /// Income minus everything already committed: what the month allows for
  /// important + flexible spending in total.
  double get safeToSpend =>
      income - essentialSpent - upcomingEssentials - goalReserve - debtRepayments - upcomingSeettu;

  /// [safeToSpend] minus the non-essential spending already done.
  double get leftToSpend => safeToSpend - nonEssentialSpent;

  /// Low when less than 10% of income is left (or it's already negative).
  bool get isLow => leftToSpend < income * 0.10;
}

/// Returns null when there's no income to measure against.
SafeToSpend? computeSafeToSpend({
  required double? monthlyIncome,
  required List<ExpenseModel> expenses,
  required List<RecurringExpense> recurring,
  required List<SavingsGoal> goals,
  required List<Debt> debts,
  required DateTime now,
  double upcomingSeettu = 0,
}) {
  if (monthlyIncome == null || monthlyIncome <= 0) return null;
  final today = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(today.year, today.month);
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  bool inMonth(DateTime d) => !d.isBefore(monthStart) && !d.isAfter(monthEnd);

  var essential = 0.0;
  var nonEssential = 0.0;
  for (final e in expenses) {
    if (!inMonth(e.effectiveDate)) continue;
    if (e.priority == ExpensePriority.essential) {
      essential += e.amount;
    } else {
      nonEssential += e.amount;
    }
  }

  // Recurring occurrences from their next due date are, by definition, not
  // logged yet — so they never double-count with [essential].
  var upcoming = 0.0;
  for (final r in recurring) {
    if (r.priority != ExpensePriority.essential) continue;
    upcoming += occurrencesBetween(r, monthStart, monthEnd).length * r.amount;
  }

  // Each active goal reserves the larger of its plan and what was actually
  // put in this month (money already moved out of the spending pool).
  var goalReserve = 0.0;
  for (final g in goals) {
    if (g.status != SavingsGoal.active) continue;
    final contributedThisMonth = g.contributions
        .where((c) => inMonth(c.contributedOn))
        .fold(0.0, (s, c) => s + c.amount);
    final planned = g.plannedMonthlyContribution ?? 0;
    final reserve = contributedThisMonth > planned ? contributedThisMonth : planned;
    if (reserve > 0) goalReserve += reserve;
  }

  // Borrowed money: repayments already made this month, plus whatever is
  // still outstanding on debts due by the end of the month.
  var debtRepayments = 0.0;
  for (final d in debts) {
    if (d.direction != Debt.borrowed) continue;
    debtRepayments += d.payments.where((p) => inMonth(p.paidOn)).fold(0.0, (s, p) => s + p.amount);
    if (d.isOpen && d.dueDate != null && !d.dueDate!.isAfter(monthEnd)) {
      debtRepayments += d.outstanding;
    }
  }

  return SafeToSpend(
    income: monthlyIncome,
    essentialSpent: essential,
    upcomingEssentials: upcoming,
    goalReserve: goalReserve,
    debtRepayments: debtRepayments,
    nonEssentialSpent: nonEssential,
    upcomingSeettu: upcomingSeettu,
  );
}
