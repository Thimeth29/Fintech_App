import 'expense_priority.dart';

class ExpenseModel {
  final String? id;
  final String userId;
  final double amount;
  final String category;
  final String? note;
  final DateTime createdAt;

  /// The day the money was spent (`expenses.expense_date`). Null only for
  /// rows that never had one; use [effectiveDate] for grouping.
  final DateTime? expenseDate;

  /// `essential` | `important` | `flexible` — see [ExpensePriority].
  final String priority;

  /// Set when this row was generated from a recurring expense.
  final String? recurringId;

  ExpenseModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.note,
    DateTime? createdAt,
    this.expenseDate,
    String? priority,
    this.recurringId,
  })  : createdAt = createdAt ?? DateTime.now(),
        priority = ExpensePriority.normalise(priority, category);

  /// Date used for every month/day grouping: [expenseDate], falling back
  /// to [createdAt] for old rows.
  DateTime get effectiveDate {
    final d = expenseDate ?? createdAt.toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  bool get isRecurring => recurringId != null;

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String;
    final rawDate = json['expense_date'] as String?;
    return ExpenseModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: category,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expenseDate: rawDate == null ? null : DateTime.parse(rawDate),
      priority: json['priority'] as String?,
      recurringId: json['recurring_id'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'amount': amount,
        'category': category,
        'note': note,
        'expense_date': _isoDate(expenseDate ?? DateTime.now()),
        'priority': priority,
        if (recurringId != null) 'recurring_id': recurringId,
      };

  /// Fields a user can edit on an existing row.
  Map<String, dynamic> toUpdateJson() => {
        'amount': amount,
        'category': category,
        'note': note,
        'expense_date': _isoDate(effectiveDate),
        'priority': priority,
      };

  ExpenseModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? note,
    bool clearNote = false,
    DateTime? expenseDate,
    String? priority,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
      expenseDate: expenseDate ?? this.expenseDate,
      priority: priority ?? this.priority,
      recurringId: recurringId,
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
