enum TxnType { buy, sell, openTerm, maturePayout, communityContribution, communityPayout }

class Transaction {
  final String id;
  final String instrumentId;
  final TxnType type;
  final double quantity;
  final double price;
  final DateTime timestamp;

  Transaction({
    required this.id,
    required this.instrumentId,
    required this.type,
    required this.quantity,
    required this.price,
    required this.timestamp,
  });

  double get amount => quantity * price;
}

/// A holding in a freely tradable instrument (gold, forex, stocks).
class Holding {
  final String instrumentId;
  double quantity;
  double avgCost; // average cost per unit, for P&L calculation

  Holding({required this.instrumentId, this.quantity = 0, this.avgCost = 0});

  double marketValue(double currentPrice) => quantity * currentPrice;

  double unrealizedPnl(double currentPrice) => (currentPrice - avgCost) * quantity;

  double unrealizedPnlPct(double currentPrice) =>
      avgCost == 0 ? 0 : ((currentPrice - avgCost) / avgCost) * 100;
}

/// A locked position in a term instrument (fixed deposit / treasury bond).
class TermPosition {
  final String id;
  final String instrumentId;
  final double principal;
  final double annualRatePct;
  final DateTime openedAt;
  final DateTime maturesAt;
  bool withdrawn;

  TermPosition({
    required this.id,
    required this.instrumentId,
    required this.principal,
    required this.annualRatePct,
    required this.openedAt,
    required this.maturesAt,
    this.withdrawn = false,
  });

  bool get isMatured => DateTime.now().isAfter(maturesAt);

  int get termDays => maturesAt.difference(openedAt).inDays;

  /// Projected value if held to maturity (simple interest, pro-rated by term).
  double get maturityValue =>
      principal + (principal * (annualRatePct / 100) * (termDays / 365));

  /// Value accrued so far if withdrawn today (linear accrual, for display only).
  double currentAccruedValue() {
    final elapsedDays = DateTime.now().difference(openedAt).inDays.clamp(0, termDays);
    final accrued = principal * (annualRatePct / 100) * (elapsedDays / 365);
    return principal + accrued;
  }
}

/// A position in a rotating community fund (seettu / cheetu style).
class CommunityPosition {
  final String id;
  final String instrumentId;
  final double roundContribution;
  final int totalRounds;
  int roundsContributed;
  bool hasReceivedPayout;
  final DateTime joinedAt;

  CommunityPosition({
    required this.id,
    required this.instrumentId,
    required this.roundContribution,
    required this.totalRounds,
    required this.joinedAt,
    this.roundsContributed = 0,
    this.hasReceivedPayout = false,
  });

  int get roundsRemaining => totalRounds - roundsContributed;
  double get totalContributedSoFar => roundsContributed * roundContribution;
}
