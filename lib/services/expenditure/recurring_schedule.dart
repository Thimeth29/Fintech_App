// Pure date logic for recurring expenses — no I/O, unit-tested.
import '../../models/recurring_expense_model.dart';

/// [anchor] moved forward [months] months, keeping [anchorDay] where the
/// month allows it and clamping to the month's last day otherwise
/// (31 Jan + 1 month -> 28/29 Feb; + 2 months -> 31 Mar).
DateTime addMonthsClamped(DateTime anchor, int months, {int? anchorDay}) {
  final day = anchorDay ?? anchor.day;
  final firstOfTarget = DateTime(anchor.year, anchor.month + months);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  return DateTime(firstOfTarget.year, firstOfTarget.month, day > lastDay ? lastDay : day);
}

/// The occurrence after [date] for [r].
DateTime nextOccurrence(RecurringExpense r, DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  if (r.frequency == RecurringExpense.weekly) {
    return DateTime(d.year, d.month, d.day + 7);
  }
  return addMonthsClamped(d, 1, anchorDay: r.startDate.day);
}

/// Every occurrence of [r] from its [RecurringExpense.nextDueDate] up to and
/// including [today] — i.e. what still has to be turned into expenses.
/// Capped at [max] so a long-dormant item can't flood the table.
List<DateTime> dueOccurrences(RecurringExpense r, DateTime today, {int max = 60}) {
  if (!r.active) return const [];
  final end = DateTime(today.year, today.month, today.day);
  final out = <DateTime>[];
  var d = DateTime(r.nextDueDate.year, r.nextDueDate.month, r.nextDueDate.day);
  while (!d.isAfter(end) && out.length < max) {
    out.add(d);
    d = nextOccurrence(r, d);
  }
  return out;
}

/// Occurrences of [r] that fall within [from]..[to] (inclusive), starting
/// from its next due date. Used for upcoming bills, the remaining-this-month
/// part of safe-to-spend, and next month's forecast.
List<DateTime> occurrencesBetween(RecurringExpense r, DateTime from, DateTime to, {int max = 60}) {
  if (!r.active) return const [];
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final out = <DateTime>[];
  var d = DateTime(r.nextDueDate.year, r.nextDueDate.month, r.nextDueDate.day);
  var guard = 0;
  while (!d.isAfter(end) && guard < 1000 && out.length < max) {
    if (!d.isBefore(start)) out.add(d);
    d = nextOccurrence(r, d);
    guard++;
  }
  return out;
}

/// The next due date after generating [occurrences] (unchanged if none).
DateTime advanceAfter(RecurringExpense r, List<DateTime> occurrences) =>
    occurrences.isEmpty ? r.nextDueDate : nextOccurrence(r, occurrences.last);
