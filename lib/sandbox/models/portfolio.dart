import 'holding.dart';

class Portfolio {
  double cashBalance;
  final Map<String, Holding> holdings; // instrumentId -> Holding
  final List<TermPosition> termPositions;
  final List<CommunityPosition> communityPositions;
  final List<Transaction> history;

  Portfolio({
    required this.cashBalance,
    Map<String, Holding>? holdings,
    List<TermPosition>? termPositions,
    List<CommunityPosition>? communityPositions,
    List<Transaction>? history,
  })  : holdings = holdings ?? {},
        termPositions = termPositions ?? [],
        communityPositions = communityPositions ?? [],
        history = history ?? [];

  /// Total portfolio value = cash + market value of tradable holdings
  /// + current accrued value of term positions + community contributions so far.
  double totalValue(Map<String, double> currentPrices) {
    double tradableValue = 0;
    holdings.forEach((id, h) {
      final price = currentPrices[id] ?? h.avgCost;
      tradableValue += h.marketValue(price);
    });

    double termValue = 0;
    for (final t in termPositions.where((t) => !t.withdrawn)) {
      termValue += t.currentAccruedValue();
    }

    double communityValue = 0;
    for (final c in communityPositions) {
      communityValue += c.totalContributedSoFar;
    }

    return cashBalance + tradableValue + termValue + communityValue;
  }
}
