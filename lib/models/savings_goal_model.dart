/// A savings target (`public.savings_goals`) with its contributions.
/// Contributions move money into the goal; they are never expenses.
class SavingsGoal {
  static const String active = 'active';
  static const String completed = 'completed';
  static const String archived = 'archived';

  final String? id;
  final String userId;
  final String name;
  final double targetAmount;
  final DateTime? deadline;
  final String? icon;
  final double? plannedMonthlyContribution;
  final String status;
  final DateTime createdAt;
  final List<GoalContribution> contributions;

  SavingsGoal({
    this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    this.deadline,
    this.icon,
    this.plannedMonthlyContribution,
    this.status = active,
    DateTime? createdAt,
    this.contributions = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  /// Net saved so far (withdrawals are negative contributions).
  double get savedAmount => contributions.fold(0.0, (s, c) => s + c.amount);

  double get progress => targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  bool get isActive => status == active;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    final raw = json['goal_contributions'] as List?;
    final contributions = raw == null
        ? <GoalContribution>[]
        : raw.map((r) => GoalContribution.fromJson(r as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.contributedOn.compareTo(a.contributedOn));
    final deadline = json['deadline'] as String?;
    return SavingsGoal(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      deadline: deadline == null ? null : DateTime.parse(deadline),
      icon: json['icon'] as String?,
      plannedMonthlyContribution: (json['planned_monthly_contribution'] as num?)?.toDouble(),
      status: json['status'] as String? ?? active,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      contributions: contributions,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'target_amount': targetAmount,
        'deadline': deadline == null ? null : _iso(deadline!),
        'icon': icon,
        'planned_monthly_contribution': plannedMonthlyContribution,
        'status': status,
      };

  SavingsGoal copyWith({
    String? name,
    double? targetAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    String? icon,
    double? plannedMonthlyContribution,
    bool clearPlanned = false,
    String? status,
    List<GoalContribution>? contributions,
  }) {
    return SavingsGoal(
      id: id,
      userId: userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      icon: icon ?? this.icon,
      plannedMonthlyContribution:
          clearPlanned ? null : (plannedMonthlyContribution ?? this.plannedMonthlyContribution),
      status: status ?? this.status,
      createdAt: createdAt,
      contributions: contributions ?? this.contributions,
    );
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class GoalContribution {
  final String? id;
  final String goalId;
  final String userId;

  /// Positive = added, negative = withdrawn.
  final double amount;
  final String? note;
  final DateTime contributedOn;

  GoalContribution({
    this.id,
    required this.goalId,
    required this.userId,
    required this.amount,
    this.note,
    required this.contributedOn,
  });

  factory GoalContribution.fromJson(Map<String, dynamic> json) => GoalContribution(
        id: json['id'] as String?,
        goalId: json['goal_id'] as String,
        userId: json['user_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String?,
        contributedOn: DateTime.parse(json['contributed_on'] as String),
      );

  Map<String, dynamic> toJson() => {
        'goal_id': goalId,
        'user_id': userId,
        'amount': amount,
        'note': note,
        'contributed_on':
            '${contributedOn.year}-${contributedOn.month.toString().padLeft(2, '0')}-${contributedOn.day.toString().padLeft(2, '0')}',
      };
}
