import 'dart:math';
import '../data/mock_instruments.dart';
import '../models/holding.dart';
import '../models/instrument.dart';
import '../models/portfolio.dart';
import 'price_simulator.dart';
import 'price_source.dart';

class SandboxException implements Exception {
  final String message;
  SandboxException(this.message);
  @override
  String toString() => message;
}

/// Starting mock balance every new sandbox trial begins with.
const double kSandboxStartingBalance = 100000;

/// Owns all sandbox state and enforces the trading rules for each
/// instrument category. This has no dependency on Flutter — it's a
/// plain Dart engine so it's easy to unit test, and can be wrapped by
/// a ChangeNotifier/Provider, Riverpod, or Bloc on the UI side.
class SandboxEngine {
  final List<Instrument> instruments;

  /// Where prices come from. Trading logic below is identical whether
  /// this is [SimulatedPriceSource] (offline/demo) or
  /// [LiveSupabasePriceSource] (real CBSL/CSE/bank data via your
  /// scraper). Account balances are always virtual — this only affects
  /// what price a trade executes at.
  final PriceSource priceSource;
  final Portfolio portfolio;
  final Random _idRng = Random();

  SandboxEngine({
    List<Instrument>? instruments,
    PriceSource? priceSource,
    double startingBalance = kSandboxStartingBalance,
  })  : instruments = instruments ?? mockInstruments,
        priceSource = priceSource ?? SimulatedPriceSource(),
        portfolio = Portfolio(cashBalance: startingBalance);

  /// Must be called once before trading — starts the underlying price
  /// source (simulator tick loop, or Supabase fetch + realtime subscribe).
  Future<void> start() => priceSource.start(instruments);

  Instrument instrumentById(String id) =>
      instruments.firstWhere((i) => i.id == id, orElse: () => throw SandboxException('Unknown instrument: $id'));

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idRng.nextInt(9999)}';

  // ---------------------------------------------------------------------
  // Tradable instruments (gold, forex, stocks): buy / sell at live price
  // ---------------------------------------------------------------------

  void buyTradable(String instrumentId, double lkrAmount) {
    final instrument = instrumentById(instrumentId);
    _assertCategory(instrument, InstrumentCategory.tradable);
    if (lkrAmount <= 0) throw SandboxException('Amount must be greater than zero.');
    if (lkrAmount > portfolio.cashBalance) {
      throw SandboxException('Not enough sandbox balance for this trade.');
    }

    final price = priceSource.priceOf(instrumentId);
    final qty = lkrAmount / price;

    final holding = portfolio.holdings.putIfAbsent(
      instrumentId,
      () => Holding(instrumentId: instrumentId),
    );

    final newTotalCost = (holding.avgCost * holding.quantity) + lkrAmount;
    final newQty = holding.quantity + qty;
    holding
      ..quantity = newQty
      ..avgCost = newQty == 0 ? 0 : newTotalCost / newQty;

    portfolio.cashBalance -= lkrAmount;
    portfolio.history.add(Transaction(
      id: _newId(),
      instrumentId: instrumentId,
      type: TxnType.buy,
      quantity: qty,
      price: price,
      timestamp: DateTime.now(),
    ));
  }

  void sellTradable(String instrumentId, double quantity) {
    final instrument = instrumentById(instrumentId);
    _assertCategory(instrument, InstrumentCategory.tradable);
    final holding = portfolio.holdings[instrumentId];
    if (holding == null || quantity > holding.quantity) {
      throw SandboxException('You don\'t hold enough ${instrument.name} to sell that much.');
    }

    final price = priceSource.priceOf(instrumentId);
    final proceeds = quantity * price;

    holding.quantity -= quantity;
    if (holding.quantity <= 0.0000001) {
      portfolio.holdings.remove(instrumentId);
    }

    portfolio.cashBalance += proceeds;
    portfolio.history.add(Transaction(
      id: _newId(),
      instrumentId: instrumentId,
      type: TxnType.sell,
      quantity: quantity,
      price: price,
      timestamp: DateTime.now(),
    ));
  }

  // ---------------------------------------------------------------------
  // Term instruments (fixed deposits, treasury bonds): lock for a term
  // ---------------------------------------------------------------------

  TermPosition openTermPosition(String instrumentId, double principal) {
    final instrument = instrumentById(instrumentId);
    _assertCategory(instrument, InstrumentCategory.term);
    if (principal <= 0) throw SandboxException('Amount must be greater than zero.');
    if (principal > portfolio.cashBalance) {
      throw SandboxException('Not enough sandbox balance to open this position.');
    }

    final now = DateTime.now();
    final position = TermPosition(
      id: _newId(),
      instrumentId: instrumentId,
      principal: principal,
      annualRatePct: instrument.annualRatePct!,
      openedAt: now,
      maturesAt: now.add(Duration(days: instrument.termDays!)),
    );

    portfolio.cashBalance -= principal;
    portfolio.termPositions.add(position);
    portfolio.history.add(Transaction(
      id: _newId(),
      instrumentId: instrumentId,
      type: TxnType.openTerm,
      quantity: 1,
      price: principal,
      timestamp: now,
    ));
    return position;
  }

  /// Withdraws a term position. If matured, pays the full maturity value.
  /// If withdrawn early, pays only the accrued value so far (a simple
  /// stand-in for an early-withdrawal penalty).
  void withdrawTermPosition(String positionId) {
    final position = portfolio.termPositions.firstWhere(
      (p) => p.id == positionId,
      orElse: () => throw SandboxException('Position not found.'),
    );
    if (position.withdrawn) throw SandboxException('This position was already withdrawn.');

    final payout = position.isMatured ? position.maturityValue : position.currentAccruedValue();
    position.withdrawn = true;
    portfolio.cashBalance += payout;
    portfolio.history.add(Transaction(
      id: _newId(),
      instrumentId: position.instrumentId,
      type: TxnType.maturePayout,
      quantity: 1,
      price: payout,
      timestamp: DateTime.now(),
    ));
  }

  // ---------------------------------------------------------------------
  // Community fund (seettu/cheetu-style rotating pool)
  // ---------------------------------------------------------------------

  CommunityPosition joinCommunityFund(String instrumentId) {
    final instrument = instrumentById(instrumentId);
    _assertCategory(instrument, InstrumentCategory.community);

    final position = CommunityPosition(
      id: _newId(),
      instrumentId: instrumentId,
      roundContribution: instrument.roundContribution!,
      totalRounds: instrument.totalRounds!,
      joinedAt: DateTime.now(),
    );
    portfolio.communityPositions.add(position);
    return position;
  }

  void contributeToCommunityRound(String positionId) {
    final position = portfolio.communityPositions.firstWhere(
      (p) => p.id == positionId,
      orElse: () => throw SandboxException('Community position not found.'),
    );
    if (position.roundsContributed >= position.totalRounds) {
      throw SandboxException('All rounds already contributed.');
    }
    if (position.roundContribution > portfolio.cashBalance) {
      throw SandboxException('Not enough sandbox balance for this round\'s contribution.');
    }

    portfolio.cashBalance -= position.roundContribution;
    position.roundsContributed += 1;
    portfolio.history.add(Transaction(
      id: _newId(),
      instrumentId: position.instrumentId,
      type: TxnType.communityContribution,
      quantity: 1,
      price: position.roundContribution,
      timestamp: DateTime.now(),
    ));
  }

  /// Simulates this member's turn to receive the pooled payout.
  void receiveCommunityPayout(String positionId) {
    final position = portfolio.communityPositions.firstWhere(
      (p) => p.id == positionId,
      orElse: () => throw SandboxException('Community position not found.'),
    );
    if (position.hasReceivedPayout) throw SandboxException('Payout already received for this round.');

    final payout = position.roundContribution * position.totalRounds;
    position.hasReceivedPayout = true;
    portfolio.cashBalance += payout;
    portfolio.history.add(Transaction(
      id: _newId(),
      instrumentId: position.instrumentId,
      type: TxnType.communityPayout,
      quantity: 1,
      price: payout,
      timestamp: DateTime.now(),
    ));
  }

  // ---------------------------------------------------------------------

  void resetSandbox({double startingBalance = kSandboxStartingBalance}) {
    portfolio.cashBalance = startingBalance;
    portfolio.holdings.clear();
    portfolio.termPositions.clear();
    portfolio.communityPositions.clear();
    portfolio.history.clear();
  }

  double totalPortfolioValue() => portfolio.totalValue(priceSource.snapshot());

  Future<void> dispose() => priceSource.dispose();

  void _assertCategory(Instrument instrument, InstrumentCategory expected) {
    if (instrument.category != expected) {
      throw SandboxException('${instrument.name} does not support this action.');
    }
  }
}
