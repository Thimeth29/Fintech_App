class ExpenseModel {
  final String? id;
  final String userId;
  final double amount;
  final String category;
  final String? note;
  final DateTime createdAt;

  ExpenseModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'amount': amount,
    'category': category,
    'note': note,
  };
}
