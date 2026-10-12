// The PriceSource abstraction and the trading engine: the engine's rules
// run unchanged on any source, live quotes win over simulated ones only
// while fresh, and term / seettu maths match the server functions (the same
// numbers as supabase/tests/sandbox_live_prices_test.sql).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/core/sandbox/sandbox_config.dart';
import 'package:my_app/models/sandbox_models.dart';
import 'package:my_app/services/sandbox/fast_forward.dart';
import 'package:my_app/services/sandbox/live_price_source.dart';
import 'package:my_app/services/sandbox/price_engine.dart';
import 'package:my_app/services/sandbox/price_source.dart';
import 'package:my_app/services/sandbox/sim_math.dart';
import 'package:my_app/services/sandbox/simulated_price_source.dart';
import 'package:my_app/services/sandbox/trading_engine.dart';

/// A PriceSource with fixed prices, for driving the engine in tests.
class FixedPriceSource extends PriceSource {
  FixedPriceSource(this.prices, {this.origin = PriceOrigin.simulated});
  final Map<String, double> prices;
  final PriceOrigin origin;
  final _changes = StreamController<Set<String>>.broadcast();

  @override
  String get label => 'fixed';

  @override
  PriceQuote? quote(String key) =>
      prices[key] == null ? null : PriceQuote(key: key, price: prices[key]!, origin: origin);

  @override
  List<PricePoint> history(String key, {int days = 60}) => const [];

  @override
  bool followsSimClock(String key) => origin == PriceOrigin.simulated;

  @override
  Stream<Set<String>> get changes => _changes.stream;
}

/// In-memory market_prices / market_price_history.
class FakeMarketRepository implements MarketPriceRepository {
  final List<MarketPriceRow> rows;
  final Map<String, List<PricePoint>> historyRows;
  void Function(MarketPriceRow)? _listener;
  FakeMarketRepository(this.rows, {this.historyRows = const {}});

  @override
  Future<List<MarketPriceRow>> fetchLatest() async => rows;

  @override
  Future<Map<String, List<PricePoint>>> fetchHistory(Iterable<String> symbols, DateTime since) async => {
        for (final s in symbols)
          if (historyRows[s] case final h?) s: h.where((p) => !p.date.isBefore(since)).toList(),
      };

  @override
  Future<void> Function() watch(void Function(MarketPriceRow row) onRow) {
    _listener = onRow;
    return () async => _listener = null;
  }

  /// What Supabase Realtime would deliver after a new scrape.
  void push(MarketPriceRow row) => _listener?.call(row);
}

MarketPriceRow row(String symbol, double price, {String kind = 'stock', DateTime? asOf, double? change}) =>
    MarketPriceRow(
      symbol: symbol,
      kind: kind,
      name: symbol,
      price: price,
      unit: 'LKR',
      source: 'TEST',
      asOf: asOf ?? DateTime(2026, 10, 12, 9, 30),
      changePct: change,
    );

class FakeClock implements SimClock {
  int day = 0;
  final Map<String, double> anchors;
  FakeClock([this.anchors = const {}]);
  @override
  int dayFor(SandboxModule m) => day;
  @override
  DateTime startDateFor(SandboxModule m) => DateTime(2026, 1, 1);
  @override
  double? anchorFor(SandboxModule m, String key) => anchors[key];
  @override
  double? intradayPrice(String symbol) => null;
}

SandboxPosition position({
  required String type,
  required double principal,
  double? cost,
  required double rate,
  double? coupon,
  String payout = 'maturity',
  int? months,
  int? days,
}) {
  final start = DateTime(2026, 1, 1);
  return SandboxPosition(
    id: 'p',
    module: type == 'fd' ? SandboxModule.fd : SandboxModule.govSecurities,
    type: type,
    label: 'Test',
    principal: principal,
    cost: cost ?? principal,
    rate: rate,
    couponRate: coupon,
    payoutType: payout,
    tenureMonths: months,
    tenureDays: days,
    startSimDate: start,
    maturitySimDate: days != null ? addDays(start, days) : addMonths(start, months ?? 12),
    payoutsCount: 0,
    totalPaid: 0,
    autoRenew: false,
    renewCount: 0,
    status: 'open',
    resetBatch: 'b',
  );
}

SandboxCircle circle({String id = 'c1', int members = 5, double contribution = 10000, int turn = 3, String trust = 'known'}) =>
    SandboxCircle(
      id: id,
      name: 'Test circle',
      members: members,
      contribution: contribution,
      myTurn: turn,
      trust: trust,
      startSimDate: DateTime(2026, 1, 31),
      roundsPaid: 1,
      totalPaid: contribution,
      status: 'open',
      resetBatch: 'b',
    );

void main() {
  final now = DateTime(2026, 10, 12, 12);

  group('FallbackPriceSource', () {
    test('uses a fresh live quote, otherwise the simulated one', () async {
      final live = LivePriceSource(repository: FakeMarketRepository([row('JKH.N', 21.5)]), now: () => now);
      await live.start();
      final sim = SimulatedPriceSource(engine: () => SandboxPriceEngine('seed'), clock: FakeClock());
      final source = FallbackPriceSource(primary: live, fallback: sim);

      final jkh = source.quote('JKH.N')!;
      expect(jkh.isLive, isTrue);
      expect(jkh.price, 21.5);
      expect(jkh.source, 'TEST');
      // Not scraped, so simulated from its fallback price.
      final comb = source.quote('COMB.N')!;
      expect(comb.isLive, isFalse);
      expect(comb.price, closeTo(kCseInstruments[1].fallbackPrice, 1e-9));
      // Fictional instruments are always simulated.
      expect(source.quote('ZEPH')!.isLive, isFalse);
      expect(source.followsSimClock('JKH.N'), isFalse);
      expect(source.followsSimClock('COMB.N'), isTrue);
    });

    test('a stale live quote is ignored', () async {
      final old = now.subtract(kLiveQuoteMaxAgeMarket + const Duration(hours: 1));
      final live = LivePriceSource(repository: FakeMarketRepository([row('USDLKR', 310, kind: 'forex', asOf: old)]), now: () => now);
      await live.start();
      expect(live.quote('USDLKR'), isNull);
      // Rates may be older (banks publish less often).
      final rates = LivePriceSource(
          repository: FakeMarketRepository([row('TBILL_364', 8.1, kind: 'tbill_yield', asOf: old)]), now: () => now);
      await rates.start();
      expect(rates.quote('TBILL_364')?.price, 8.1);
    });
  });

  group('LivePriceSource', () {
    test('a realtime update changes the quote and notifies listeners', () async {
      final repo = FakeMarketRepository([row('USDLKR', 300, kind: 'forex')]);
      final live = LivePriceSource(repository: repo, now: () => now);
      await live.start();
      final seen = <Set<String>>[];
      final sub = live.changes.listen(seen.add);
      repo.push(row('USDLKR', 305.25, kind: 'forex', asOf: DateTime(2026, 10, 12, 10)));
      await Future<void>.delayed(Duration.zero);
      expect(live.quote('USDLKR')!.price, 305.25);
      expect(seen.last, {'USDLKR'});
      await sub.cancel();
    });

    test('history is fetched once and returned oldest first', () async {
      final repo = FakeMarketRepository([row('GOLD24K', 31000, kind: 'gold')], historyRows: {
        'GOLD24K': [PricePoint(DateTime(2026, 10, 11), 30900), PricePoint(DateTime(2026, 10, 9), 30500)],
      });
      final live = LivePriceSource(repository: repo, now: () => now);
      await live.start();
      expect(live.history('GOLD24K'), isEmpty);
      await live.prefetchHistory(['GOLD24K']);
      expect([for (final p in live.history('GOLD24K')) p.price], [30500, 30900]);
    });
  });

  group('TradableEngine (same rules, any source)', () {
    test('swapping the PriceSource changes prices, not the trading rules', () {
      PriceSource current = FixedPriceSource({'JKH.N': 20.0});
      final engine = TradableEngine(() => current);
      final spec = kCseInstruments.first;
      final q1 = engine.quote(spec, 'buy', 100);
      expect(q1.price, 20);
      expect(q1.fee, TradeMath.cseFee(2000));

      current = FixedPriceSource({'JKH.N': 25.0}, origin: PriceOrigin.live);
      final q2 = engine.quote(spec, 'buy', 100);
      expect(q2.price, 25);
      expect(q2.fee, TradeMath.cseFee(2500)); // identical fee rule
    });

    test('forex: buy above and sell below the CBSL rate, no separate fee', () {
      final engine = TradableEngine(() => FixedPriceSource({'USDLKR': 300.0}));
      final usd = kForexInstruments.first;
      final buy = engine.quote(usd, 'buy', 100);
      final sell = engine.quote(usd, 'sell', 100);
      expect(buy.price, closeTo(300 * (1 + kForexSpread / 2), 1e-4));
      expect(sell.price, closeTo(300 * (1 - kForexSpread / 2), 1e-4));
      expect(buy.fee, 0);
      expect(buy.total - sell.total, closeTo(300 * 100 * kForexSpread, 0.02));
    });

    test('gold is priced off GOLD24K whatever the source', () {
      final engine = TradableEngine(() => FixedPriceSource({kGold24kKey: 30000.0}));
      expect(engine.midPrice(kGoldBullion), 30000);
      expect(engine.midPrice(kGoldJewellery), closeTo(30000 * kGold22kPurity, 1e-9));
      expect(engine.quote(kGoldJewellery, 'buy', 1).fee, greaterThan(0)); // making charge
    });

    test('missing prices fall back to the configured reference', () {
      final engine = TradableEngine(() => FixedPriceSource({}));
      expect(engine.midPrice(kForexInstruments.first), kForexInstruments.first.fallbackPrice);
    });

    test('checks quantity, cash and holdings', () {
      final engine = TradableEngine(() => FixedPriceSource({'USDLKR': 300.0}));
      final usd = kForexInstruments.first;
      expect(engine.check(spec: usd, side: 'buy', quantity: 0, cash: 1e6), 'invalid_quantity');
      expect(engine.check(spec: usd, side: 'buy', quantity: 1000, cash: 1000), 'insufficient_balance');
      expect(engine.check(spec: usd, side: 'sell', quantity: 1, cash: 0), 'insufficient_holdings');
      expect(engine.check(spec: usd, side: 'buy', quantity: 10.5, cash: 1e6), isNull);
      expect(engine.check(spec: kCseInstruments.first, side: 'buy', quantity: 1.5, cash: 1e6), 'whole_shares_only');
    });
  });

  group('TermEngine', () {
    test('rates come from the PriceSource', () {
      final term = TermEngine(() => FixedPriceSource({fdAnchorKey('Commercial Bank', 12): 9.75, tbillAnchorKey(91): 7.5}));
      expect(term.fdRate('Commercial Bank', 12), 9.75);
      expect(term.tbillYield(91), 7.5);
      expect(term.tbondYield(5), kTbondFallbackYields[5]); // not supplied: fallback
    });

    test('early withdrawal pays principal plus interest accrued so far (matches the server)', () {
      final fd = position(type: 'fd', principal: 50000, rate: 10, months: 12);
      expect(TermEngine.withdrawalAmount(fd, addDays(fd.startSimDate, 73)), 50900);
      final w = TermEngine.earlyWithdrawal(fd, addDays(fd.startSimDate, 73));
      expect(w.accrued, 900);
      expect(w.givenUp, FdMath.maturityAmount(50000, 10, 12) - 50900);

      final bill = position(type: 'tbill', principal: 50000, cost: 46000, rate: 8.65, days: 364);
      expect(TermEngine.withdrawalAmount(bill, addDays(bill.startSimDate, 100)), 46989.01);
      expect(TermEngine.withdrawalAmount(bill, bill.maturitySimDate), GovMath.tbillMaturityAmount(50000, 46000));

      final bond = position(type: 'tbond', principal: 50000, rate: 10, coupon: 10, payout: 'semi_annual', months: 60);
      expect(TermEngine.withdrawalAmount(bond, addDays(bond.startSimDate, 100)), 51232.88);
    });

    test('withdrawing on day 0 returns exactly what was paid', () {
      final fd = position(type: 'fd', principal: 25000, rate: 9, months: 6);
      expect(TermEngine.withdrawalAmount(fd, fd.startSimDate), 25000);
      final bill = position(type: 'tbill', principal: 10000, cost: 9500, rate: 8, days: 182);
      expect(TermEngine.withdrawalAmount(bill, bill.startSimDate), 9500);
    });
  });

  group('SeettuEngine', () {
    test('defaults are deterministic and only by members who already took a pot', () {
      for (var i = 0; i < 200; i++) {
        final c = circle(id: 'circle-$i', trust: 'strangers', members: 8, turn: 5);
        final a = SeettuEngine.defaultFor(c, 'user');
        final b = SeettuEngine.defaultFor(c, 'user');
        expect(a?.memberTurn, b?.memberTurn);
        if (a != null) {
          expect(a.memberTurn, isNot(5));
          expect(a.memberTurn, lessThan(8));
          expect(a.fromRound, a.memberTurn + 1);
        }
      }
    });

    test('strangers default far more often than people you know', () {
      int count(String trust) =>
          [for (var i = 0; i < 400; i++) SeettuEngine.defaultFor(circle(id: 'x$i', trust: trust), 'u')].nonNulls.length;
      expect(count('strangers'), greaterThan(count('known') * 3));
    });

    test('pots shrink after a default; the first pot never does', () {
      final c = circle(id: 'pick', members: 5, contribution: 1000, turn: 5, trust: 'strangers');
      expect(SeettuEngine.potForRound(c, 1, 'u'), 5000);
      final d = SeettuEngine.defaultFor(c, 'u');
      if (d != null) expect(SeettuEngine.potForRound(c, d.fromRound, 'u'), 4000);
    });

    test('can only join if every owed round is covered (matches the server)', () {
      final open = [circle(members: 5, contribution: 10000)]; // 4 rounds still owed
      expect(SeettuEngine.committed(open), 40000);
      expect(SeettuEngine.canJoin(balance: 90000, open: open, members: 10, contribution: 6000), isFalse);
      expect(SeettuEngine.canJoin(balance: 90000, open: open, members: 5, contribution: 5000), isTrue);
    });

    test('fast-forward plans each round, contribution before pot', () {
      final c = circle(members: 5, contribution: 10000, turn: 3);
      final wallet = SandboxWallet(
        id: 'w',
        module: SandboxModule.communityFund,
        balance: 90000,
        simDate: c.startSimDate,
        startDate: c.startSimDate,
        anchors: const {},
        resetCount: 0,
        resetBatch: 'b',
      );
      final plan = FastForwardPlanner(SandboxPriceEngine('u'))
          .plan(wallet: wallet, days: 70, positions: const [], holdings: const [], circles: [c]);
      expect([for (final e in plan.events) e.kind], ['seettu_pay', 'seettu_pay', 'seettu_pot']);
      // 31 Jan + 1 month clamps to 28 Feb, like Postgres.
      expect(plan.events.first.simDate, DateTime(2026, 2, 28));
      expect(plan.events[1].simDate, DateTime(2026, 3, 31));
      expect(plan.totalOut, 20000);
      expect(plan.totalPaid, SeettuEngine.potForRound(c, 3, 'u'));
      expect(plan.events.last.toJson()['circle_id'], 'c1');
    });

    test('net position: owed to you before your pot, owed by you after', () {
      final before = circle(members: 5, contribution: 1000).copyWith(roundsPaid: 2, totalPaid: 2000);
      expect(SeettuEngine.value(before), 2000);
      final after = before.copyWith(roundsPaid: 3, totalPaid: 3000, potReceived: 5000);
      expect(SeettuEngine.value(after), -2000);
    });
  });
}
