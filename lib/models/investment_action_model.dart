class InvestmentActionModel {
  final String? id;
  final String userId;
  final String assetType; // 'CSE', 'SEC', 'FD', 'GOLD'
  final String symbol;
  final String action; // 'buy' | 'sell' | 'considered'
  final double amount;
  final DateTime createdAt;

  InvestmentActionModel({
    this.id,
    required this.userId,
    required this.assetType,
    required this.symbol,
    required this.action,
    required this.amount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Column names here match the `investment_logs` table in
  // supabase_schema.sql exactly: action_type, asset_class (not the more
  // obvious `action`/`asset_type` — double-checked against the live schema
  // since a prior version of this model silently broke fetchActions()).
  factory InvestmentActionModel.fromJson(Map<String, dynamic> json) {
    return InvestmentActionModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      assetType: json['asset_class'] as String,
      symbol: json['symbol'] as String,
      action: json['action_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'asset_class': assetType,
    'symbol': symbol,
    'action_type': action,
    'amount': amount,
  };
}
