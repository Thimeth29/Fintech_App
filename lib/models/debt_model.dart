/// Money lent or borrowed (`public.debts`) with its repayments. Neither
/// lending nor repaying is an expense — the original spending was.
class Debt {
  /// They owe me.
  static const String lent = 'lent';

  /// I owe them.
  static const String borrowed = 'borrowed';

  static const String open = 'open';
  static const String settled = 'settled';

  final String? id;
  final String userId;
  final String direction;
  final String personName;
  final double principalAmount;
  final String? note;
  final DateTime startDate;
  final DateTime? dueDate;
  final String status;
  final List<DebtPayment> payments;

  Debt({
    this.id,
    required this.userId,
    required this.direction,
    required this.personName,
    required this.principalAmount,
    this.note,
    DateTime? startDate,
    this.dueDate,
    this.status = open,
    this.payments = const [],
  }) : startDate = startDate ?? DateTime.now();

  double get paidAmount => payments.fold(0.0, (s, p) => s + p.amount);

  /// Principal minus repayments, never below zero.
  double get outstanding {
    final o = principalAmount - paidAmount;
    return o < 0.005 ? 0 : o;
  }

  bool get isOpen => status == open;
  bool get isLent => direction == lent;

  /// Open, has a due date, and that date is before [today].
  bool isOverdue(DateTime today) =>
      isOpen && dueDate != null && dueDate!.isBefore(DateTime(today.year, today.month, today.day));

  /// Open and due within [days] days of [today] (including overdue).
  bool isDueWithin(DateTime today, int days) {
    if (!isOpen || dueDate == null) return false;
    final t = DateTime(today.year, today.month, today.day);
    return !dueDate!.isAfter(t.add(Duration(days: days)));
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    final raw = json['debt_payments'] as List?;
    final payments = raw == null
        ? <DebtPayment>[]
        : raw.map((r) => DebtPayment.fromJson(r as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    final due = json['due_date'] as String?;
    return Debt(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      direction: json['direction'] as String,
      personName: json['person_name'] as String,
      principalAmount: (json['principal_amount'] as num).toDouble(),
      note: json['note'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      dueDate: due == null ? null : DateTime.parse(due),
      status: json['status'] as String? ?? open,
      payments: payments,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'direction': direction,
        'person_name': personName,
        'principal_amount': principalAmount,
        'note': note,
        'start_date': _iso(startDate),
        'due_date': dueDate == null ? null : _iso(dueDate!),
        'status': status,
      };

  Debt copyWith({String? status, List<DebtPayment>? payments}) => Debt(
        id: id,
        userId: userId,
        direction: direction,
        personName: personName,
        principalAmount: principalAmount,
        note: note,
        startDate: startDate,
        dueDate: dueDate,
        status: status ?? this.status,
        payments: payments ?? this.payments,
      );

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class DebtPayment {
  final String? id;
  final String debtId;
  final String userId;
  final double amount;
  final DateTime paidOn;
  final String? note;

  DebtPayment({
    this.id,
    required this.debtId,
    required this.userId,
    required this.amount,
    required this.paidOn,
    this.note,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) => DebtPayment(
        id: json['id'] as String?,
        debtId: json['debt_id'] as String,
        userId: json['user_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        paidOn: DateTime.parse(json['paid_on'] as String),
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'debt_id': debtId,
        'user_id': userId,
        'amount': amount,
        'paid_on':
            '${paidOn.year}-${paidOn.month.toString().padLeft(2, '0')}-${paidOn.day.toString().padLeft(2, '0')}',
        'note': note,
      };
}
