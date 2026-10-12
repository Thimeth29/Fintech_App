// lib/core/community/community_math.dart
//
// Dart copies of the pure SQL helpers in
// supabase/migrations/20261013090000_community_groups.sql (cg_split_amount,
// cg_seettu_due_date, cg_vote_passes, cg_exit_payout,
// cg_has_payment_details). The server is the source of truth; these give
// instant previews in the app and are unit-tested to match.

/// Splits [total] proportionally to [weights], rounded to cents so the parts
/// add up exactly to [total] (largest remainder; ties go to the earlier
/// position). All-zero weights split equally.
List<double> splitAmount(double total, List<double> weights) {
  final n = weights.length;
  if (n == 0) return const [];
  if (total < 0) throw ArgumentError('invalid_amount');
  if (weights.any((w) => w < 0)) throw ArgumentError('invalid_weight');
  var w = weights;
  var sum = w.fold<double>(0, (a, b) => a + b);
  if (sum == 0) {
    w = List.filled(n, 1);
    sum = n.toDouble();
  }
  final totalCents = (total * 100).round();
  final cents = List<int>.filled(n, 0);
  final remainders = List<double>.filled(n, 0);
  var assigned = 0;
  for (var i = 0; i < n; i++) {
    final raw = totalCents * w[i] / sum;
    cents[i] = raw.floor();
    remainders[i] = raw - raw.floor();
    assigned += cents[i];
  }
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final c = remainders[b].compareTo(remainders[a]);
      return c != 0 ? c : a.compareTo(b);
    });
  for (var i = 0; i < totalCents - assigned; i++) {
    cents[order[i]]++;
  }
  return [for (final c in cents) c / 100];
}

/// Due date of a seettu round. Weekly: the first [dueDay] (ISO weekday,
/// 1 = Monday) on or after [start], then every 7 days. Monthly: the first
/// [dueDay] (1–28) on or after [start], then every month.
DateTime seettuDueDate(DateTime start, String frequency, int dueDay, int round) {
  if (round < 1) throw ArgumentError('invalid_round');
  final s = DateTime(start.year, start.month, start.day);
  if (frequency == 'weekly') {
    if (dueDay < 1 || dueDay > 7) throw ArgumentError('invalid_due_day');
    final first = s.add(Duration(days: (dueDay - s.weekday + 7) % 7));
    return DateTime(first.year, first.month, first.day + 7 * (round - 1));
  }
  if (frequency == 'monthly') {
    if (dueDay < 1 || dueDay > 28) throw ArgumentError('invalid_due_day');
    var first = DateTime(s.year, s.month, dueDay);
    if (first.isBefore(s)) first = DateTime(s.year, s.month + 1, dueDay);
    return DateTime(first.year, first.month + round - 1, dueDay);
  }
  throw ArgumentError('invalid_frequency');
}

/// Formal vote result. Quorum is by headcount (ballots incl. abstain); the
/// threshold is on weights. Ties always fail. [base] 'eligible' measures
/// yes against all eligible weight (leader change); 'cast' against yes+no.
bool votePasses({
  required double yes,
  required double no,
  required int ballots,
  required int eligibleCount,
  required double eligibleWeight,
  required int quorumPct,
  required String threshold,
  required String base,
}) {
  if (eligibleCount <= 0) return false;
  if (ballots * 100 < quorumPct * eligibleCount) return false;
  if (!(yes > no)) return false;
  if (base == 'eligible') {
    return threshold == 'two_thirds' ? 3 * yes >= 2 * eligibleWeight : 2 * yes > eligibleWeight;
  }
  return threshold == 'two_thirds' ? 3 * yes >= 2 * (yes + no) : true;
}

/// Early-exit payout: what the member paid in, or their share of the
/// group's current value; less the penalty during lock-in. Rounded to cents.
double exitPayout({
  required String method,
  required double contribution,
  required double share,
  required double poolValue,
  required double penaltyPct,
  required bool inLockIn,
}) {
  final base = method == 'contribution_back' ? contribution : share * poolValue;
  final value = base * (inLockIn ? (100 - penaltyPct) / 100 : 1);
  final rounded = (value * 100).round() / 100;
  return rounded < 0 ? 0 : rounded;
}

/// Seettu pot for a round: contribution × members, less any auction discount.
double seettuPot(double contribution, int members, {double discount = 0}) =>
    ((contribution * members - discount) * 100).round() / 100;

/// Auction seettu: the discount is shared equally among everyone except
/// the winner as a credit on this round's instalment.
List<double> seettuBidCredits(double discount, int otherMembers) =>
    splitAmount(discount, List.filled(otherMembers, 1));

final RegExp _digitRun = RegExp(r'\d(?:[ -]?\d){7,}');
final RegExp _paymentWords = RegExp(r'(a/c|acc|account|bank|branch|card|iban|swift|cvv)');
final RegExp _mobile = RegExp(r'^(0?7\d{8}|947\d{8})$');

/// True when [text] looks like it contains a bank account or card number.
/// Mirrors cg_has_payment_details() so the app can warn before sending.
bool hasPaymentDetails(String text) {
  final keyword = _paymentWords.hasMatch(text.toLowerCase());
  for (final m in _digitRun.allMatches(text)) {
    final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (_mobile.hasMatch(digits)) continue;
    if (digits.length >= 12) return true;
    if (keyword) return true;
  }
  return false;
}
