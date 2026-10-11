import 'expense_priority.dart';

/// A repeating bill or subscription (`public.recurring_expenses`). Due
/// occurrences are turned into ordinary expense rows on load.
class RecurringExpense {
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';

  final String? id;
  final String userId;
  final String category;
  final double amount;
  final String? note;
  final String priority;
  final String frequency;

  /// First occurrence. Monthly items repeat on this day of the month.
  final DateTime startDate;

  /// Next occurrence not yet turned into an expense.
  final DateTime nextDueDate;
  final bool active;

  RecurringExpense({
    this.id,
    required this.userId,
    required this.category,
    required this.amount,
    this.note,
    String? priority,
    required this.frequency,
    required this.startDate,
    DateTime? nextDueDate,
    this.active = true,
  })  : priority = ExpensePriority.normalise(priority, category),
        nextDueDate = nextDueDate ?? startDate;

  factory RecurringExpense.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String;
    return RecurringExpense(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      category: category,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String?,
      priority: json['priority'] as String?,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'category': category,
        'amount': amount,
        'note': note,
        'priority': priority,
        'frequency': frequency,
        'start_date': _iso(startDate),
        'next_due_date': _iso(nextDueDate),
        'active': active,
      };

  RecurringExpense copyWith({
    String? category,
    double? amount,
    String? note,
    String? priority,
    String? frequency,
    DateTime? startDate,
    DateTime? nextDueDate,
    bool? active,
  }) {
    return RecurringExpense(
      id: id,
      userId: userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      priority: priority ?? this.priority,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      active: active ?? this.active,
    );
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
