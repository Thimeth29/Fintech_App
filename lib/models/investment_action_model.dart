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

  factory InvestmentActionModel.fromJson(Map<String, dynamic> json) {
    return InvestmentActionModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      assetType: json['asset_type'] as String,
      symbol: json['symbol'] as String,
      action: json['action'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'asset_type': assetType,
    'symbol': symbol,
    'action': action,
    'amount': amount,
  };
}
