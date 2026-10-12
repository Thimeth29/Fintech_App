import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/core/sandbox/sandbox_config.dart';
import 'package:my_app/models/sandbox_models.dart';
import 'package:my_app/services/sandbox/fast_forward.dart';
import 'package:my_app/services/sandbox/lesson_repository.dart';
import 'package:my_app/services/sandbox/price_engine.dart';
import 'package:my_app/services/sandbox/sim_math.dart';

SandboxPosition _pos({
  String type = 'fd',
  SandboxModule module = SandboxModule.fd,
  double principal = 100000,
  double? cost,
  double rate = 10,
  double? coupon,
  String payout = 'maturity',
  int? months = 12,
  int? days,
  DateTime? start,
  DateTime? maturity,
  double totalPaid = 0,
  bool autoRenew = false,
}) {
  final s = start ?? DateTime(2026, 1, 1);
  return SandboxPosition(
    id: 'p1',
    module: module,
    type: type,
    label: 'Test',
    principal: principal,
    cost: cost ?? principal,
    rate: rate,
    couponRate: coupon,
    payoutType: payout,
    tenureMonths: months,
    tenureDays: days,
    startSimDate: s,
    maturitySimDate: maturity ?? (days != null ? addDays(s, days) : addMonths(s, months ?? 12)),
    payoutsCount: 0,
    totalPaid: totalPaid,
    autoRenew: autoRenew,
    renewCount: 0,
    status: 'open',
    resetBatch: 'b1',
  );
}

SandboxWallet _wallet(SandboxModule m, {DateTime? sim, DateTime? start, Map<String, double> anchors = const {}}) =>
    SandboxWallet(
      id: 'w1',
      module: m,
      balance: kSandboxStartingBalance,
      simDate: sim ?? DateTime(2026, 1, 1),
      startDate: start ?? DateTime(2026, 1, 1),
      anchors: anchors,
      resetCount: 0,
      resetBatch: 'b1',
    );

SandboxHolding _holding({
  String symbol = 'ZEPH',
  SandboxModule module = SandboxModule.trading,
  double qty = 10,
  double avg = 100,
  double fees = 0,
  bool short = false,
  double? sl,
  double? tp,
}) =>
    SandboxHolding(
      id: 'h1',
      module: module,
      symbol: symbol,
      name: symbol,
      type: 'trading',
      isShort: short,
      quantity: qty,
      averagePrice: avg,
      totalFees: fees,
      openedSimDate: DateTime(2026, 1, 1),
      stopLoss: sl,
      takeProfit: tp,
    );

void main() {
  group('Price engine', () {
    final jkh = kCseInstruments.first;

    test('same seed gives the same path (reproducible after reload)', () {
      final a = SandboxPriceEngine('user-1').path(jkh, 145.5, -30, 400);
      final b = SandboxPriceEngine('user-1').path(jkh, 145.5, -30, 400);
      expect(a, b);
    });

    test('different users and instruments get different paths', () {
      final a = SandboxPriceEngine('user-1').path(jkh, 145.5, 1, 50);
      final b = SandboxPriceEngine('user-2').path(jkh, 145.5, 1, 50);
      final c = SandboxPriceEngine('user-1').path(kCseInstruments[1], 145.5, 1, 50);
      expect(a, isNot(b));
      expect(a, isNot(c));
    });

    test('day 0 is the anchor and the path is continuous through it', () {
      final e = SandboxPriceEngine('seed');
      expect(e.priceOn(jkh, 145.5, 0), closeTo(145.5, 1e-9));
      // Querying in a different order must not change any value.
      final later = e.priceOn(jkh, 145.5, 200);
      final fresh = SandboxPriceEngine('seed');
      fresh.priceOn(jkh, 145.5, -100);
      expect(fresh.priceOn(jkh, 145.5, 200), later);
    });

    test('prices stay positive and inside the clamp, even over decades', () {
      final e = SandboxPriceEngine('bounds');
      for (final spec in [...kCseInstruments, ...kGoldInstruments, ...kTradingInstruments]) {
        for (final p in e.path(spec, 100, -365, 365 * 20)) {
          expect(p, greaterThan(0));
          expect(p, lessThanOrEqualTo(100 * 20.09));
          expect(p, greaterThanOrEqualTo(100 * 0.0497));
        }
      }
    });

    test('daily moves are in a sensible range for the instrument volatility', () {
      final e = SandboxPriceEngine('vol');
      final gold = e.path(kGoldBullion, 24800, 0, 1000);
      final moves = [for (var i = 1; i < gold.length; i++) (gold[i] / gold[i - 1] - 1).abs()];
      final avg = moves.reduce((a, b) => a + b) / moves.length;
      // 15% annual vol ≈ 0.8% daily sd -> mean |move| ≈ 0.6%.
      expect(avg, inInclusiveRange(0.003, 0.012));
    });

    test('news events are deterministic and carry an explanation', () {
      final a = SandboxPriceEngine('news').newsBetween(SandboxModule.cse, 0, 365);
      final b = SandboxPriceEngine('news').newsBetween(SandboxModule.cse, 0, 365);
      expect(a.map((e) => e.headline), b.map((e) => e.headline));
      expect(a, isNotEmpty);
      expect(a.every((e) => e.why.isNotEmpty && e.shocks.isNotEmpty), isTrue);
    });

    test('rates move but never drop below 0.5%', () {
      final e = SandboxPriceEngine('rates');
      expect(e.rateOn(SandboxModule.govSecurities, 8.65, 0), 8.65);
      for (var d = 0; d < 3650; d += 7) {
        expect(e.rateOn(SandboxModule.govSecurities, 1.0, d), greaterThanOrEqualTo(0.5));
      }
    });

    test('intraday ticks are reproducible and candles are well formed', () {
      final spec = kTradingInstruments.first;
      final date = DateTime(2026, 10, 11);
      final s1 = SandboxPriceEngine('t').intraday(spec, 250, date);
      final s2 = SandboxPriceEngine('t').intraday(spec, 250, date);
      expect(s1.at(5000), s2.at(5000));
      expect(s1.at(-3000), s2.at(-3000));
      expect(s1.at(0), closeTo(250, 1e-9));
      final candles = s1.candles(endTick: 4000, ticksPerCandle: 60, count: 30);
      expect(candles.length, 30);
      for (final c in candles) {
        expect(c.high, greaterThanOrEqualTo(c.open));
        expect(c.high, greaterThanOrEqualTo(c.close));
        expect(c.low, lessThanOrEqualTo(c.open));
        expect(c.low, lessThanOrEqualTo(c.close));
      }
      expect(candles.last.startTick, 3960);
    });

    test('32-bit hashing is stable', () {
      expect(hashString(''), 0x811c9dc5);
      expect(hashString('a'), 0xe40c292c); // FNV-1a reference value
      expect(mix32(0), 0);
    });
  });

  group('Fixed deposits', () {
    test('simple interest and maturity amount after 10% tax', () {
      expect(FdMath.simpleInterest(100000, 10, 12), 10000);
      expect(FdMath.simpleInterest(100000, 10, 6), 5000);
      expect(FdMath.maturityAmount(100000, 10, 12), 109000);
    });

    test('compound beats simple over time', () {
      final compound = FdMath.compoundValue(100000, 10, 120, periodsPerYear: 1);
      expect(compound, closeTo(259374.25, 0.01));
      expect(compound, greaterThan(100000 + FdMath.simpleInterest(100000, 10, 120)));
    });

    test('monthly payout uses a lower rate and pays monthly after tax', () {
      expect(FdMath.monthlyPayoutRate(10), 10 - kFdMonthlyRateDiscount);
      expect(FdMath.monthlyPayment(120000, 9.5), 855); // 120000 * 9.5% / 12 = 950, -10% tax
      expect(FdMath.totalInterest(120000, 10, 12, monthly: true), 855 * 12);
      expect(FdMath.totalInterest(120000, 10, 12, monthly: false), 10800);
    });

    test('early withdrawal recalculates at the penalty rate', () {
      final p = _pos(rate: 10, months: 12);
      final q = FdMath.earlyBreak(p, DateTime(2026, 7, 15)); // 6 full months
      expect(q.monthsHeld, 6);
      // 100000 * 3% * 6/12 = 1500, after tax 1350.
      expect(q.interestAtPenaltyRate, 1350);
      expect(q.receive, 101350);
      expect(q.interestGivenUp, 9000 - 1350);
    });

    test('early withdrawal claws back monthly interest already paid', () {
      final p = _pos(rate: 9.5, payout: 'monthly', months: 12, totalPaid: 855 * 6);
      final q = FdMath.earlyBreak(p, DateTime(2026, 7, 1));
      expect(q.receive, 100000 + 1350 - 5130);
      expect(q.clawback, 5130 - 1350);
    });

    test('real return after inflation', () {
      expect(FdMath.realReturn(8.1, 5), closeTo(2.952, 0.001));
      expect(FdMath.realReturn(6, 8), lessThan(0));
    });

    test('fast-forward plans monthly interest and maturity', () {
      final planner = FastForwardPlanner(SandboxPriceEngine('ff'));
      final p = _pos(rate: 9.5, payout: 'monthly', months: 3);
      final plan = planner.plan(
        wallet: _wallet(SandboxModule.fd),
        days: 120,
        positions: [p],
        holdings: const [],
      );
      expect(plan.events.where((e) => e.kind == 'fd_interest').length, 3);
      final mature = plan.events.singleWhere((e) => e.kind == 'fd_mature');
      expect(mature.amount, 100000);
      expect(mature.simDate, DateTime(2026, 4, 1));
      // Maturity comes after the same-day interest.
      expect(plan.events.last.kind, 'fd_mature');
    });

    test('auto-renew compounds and can roll several times in one jump', () {
      final planner = FastForwardPlanner(SandboxPriceEngine('ff'));
      final p = _pos(rate: 12, months: 1, autoRenew: true);
      final plan = planner.plan(wallet: _wallet(SandboxModule.fd), days: 365, positions: [p], holdings: const []);
      final renews = plan.events.where((e) => e.kind == 'fd_renew').toList();
      expect(renews.length, 12);
      expect(renews.first.amount, 900); // 100000 * 12% / 12, -10%
      expect(renews[1].amount, greaterThan(renews.first.amount)); // interest on interest
    });

    test('month arithmetic clamps like Postgres', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(fullMonthsBetween(DateTime(2026, 1, 31), DateTime(2026, 2, 28)), 1);
      expect(fullMonthsBetween(DateTime(2026, 1, 15), DateTime(2026, 2, 14)), 0);
    });
  });

  group('Government securities', () {
    test('T-bill discount pricing', () {
      expect(GovMath.tbillPrice(100000, 8.65, 364), closeTo(92058.74, 0.01));
      expect(GovMath.tbillPrice(100000, 7.9, 91), closeTo(98068.4, 0.1));
      final cost = GovMath.tbillPrice(100000, 8.65, 364);
      expect(GovMath.tbillMaturityAmount(100000, cost), closeTo(100000 - (100000 - cost) * 0.1, 0.01));
    });

    test('coupon schedule is every 6 months ending at maturity', () {
      final dates = GovMath.couponDates(DateTime(2026, 1, 1), DateTime(2028, 1, 1));
      expect(dates, [DateTime(2026, 7, 1), DateTime(2027, 1, 1), DateTime(2027, 7, 1), DateTime(2028, 1, 1)]);
      expect(GovMath.couponPayment(100000, 10), 4500);
    });

    test('bond price is par at the coupon rate and falls when yields rise', () {
      final start = DateTime(2026, 1, 1);
      final maturity = DateTime(2031, 1, 1);
      double price(double y, DateTime now) => GovMath.bondPrice(
          face: 100000, couponRate: 10, yieldPct: y, start: start, maturity: maturity, now: now);
      // Just after a coupon (six months exactly ahead) a 10% bond at a 10% yield ≈ par.
      expect(price(10, DateTime(2026, 1, 1)), closeTo(100000, 400));
      expect(price(11, start), lessThan(price(10, start)));
      expect(price(9, start), greaterThan(price(10, start)));
      // Longer bonds are more sensitive.
      final short = GovMath.bondPrice(
          face: 100000, couponRate: 10, yieldPct: 11, start: start, maturity: DateTime(2028, 1, 1), now: start);
      expect(100000 - short, lessThan(100000 - price(11, start)));
      expect(price(20, maturity), 100000);
    });

    test('fast-forward pays coupons then the face value', () {
      final planner = FastForwardPlanner(SandboxPriceEngine('ff'));
      final p = _pos(
          type: 'tbond', module: SandboxModule.govSecurities, rate: 10, coupon: 10, payout: 'semi_annual', months: 24);
      final plan =
          planner.plan(wallet: _wallet(SandboxModule.govSecurities), days: 366 * 2, positions: [p], holdings: const []);
      expect(plan.events.where((e) => e.kind == 'tbond_coupon').length, 4);
      expect(plan.events.last.kind, 'tbond_mature');
      expect(plan.totalPaid, 4500 * 4 + 100000);
    });

    test('T-bill matures inside the window only', () {
      final planner = FastForwardPlanner(SandboxPriceEngine('ff'));
      final p = _pos(type: 'tbill', module: SandboxModule.govSecurities, cost: 98000, payout: 'discount', months: null, days: 91);
      final wallet = _wallet(SandboxModule.govSecurities);
      expect(planner.plan(wallet: wallet, days: 30, positions: [p], holdings: const []).events, isEmpty);
      final e = planner.plan(wallet: wallet, days: 91, positions: [p], holdings: const []).events.single;
      expect(e.kind, 'tbill_mature');
      expect(e.amount, 100000 - 200);
    });
  });

  group('Gold', () {
    test('spread around the mid price', () {
      expect(GoldMath.buyPrice(25000), closeTo(25375, 1e-6));
      expect(GoldMath.sellPrice(25000), closeTo(24625, 1e-6));
    });

    test('jewellery is 22K and loses its making charge', () {
      expect(GoldMath.midFor(kGoldJewellery, 25000), 22900);
      expect(GoldMath.makingCharge(kGoldJewellery, 10, 25000), 27480);
      expect(GoldMath.makingCharge(kGoldBullion, 10, 25000), 0);
      expect(GoldMath.roundTripLoss(kGoldBullion, 10, 25000), 7500);
      expect(GoldMath.roundTripLoss(kGoldJewellery, 10, 25000), closeTo(6870 + 27480, 0.01));
    });
  });

  group('Trading', () {
    test('fees have a minimum', () {
      expect(TradeMath.tradingFee(1000), kTradingMinFee);
      expect(TradeMath.tradingFee(100000), 200);
      expect(TradeMath.cseFee(50000), 560);
    });

    test('P&L for long and short positions, net of fees', () {
      expect(TradeMath.unrealisedPnl(_holding(avg: 100, qty: 10, fees: 25), 110), 75);
      expect(TradeMath.unrealisedPnl(_holding(avg: 100, qty: 10, fees: 25, short: true), 90), 75);
      expect(TradeMath.holdingValue(_holding(avg: 100, qty: 10, short: true), 90), 1100);
      expect(TradeMath.holdingValue(_holding(avg: 100, qty: 10, short: true), 250), 0);
    });

    test('stop-loss and take-profit triggering', () {
      final long = _holding(avg: 100, sl: 95, tp: 110);
      expect(TradeMath.triggered(long, 100), isNull);
      expect(TradeMath.triggered(long, 94.9), 'stop_loss');
      expect(TradeMath.triggered(long, 110), 'take_profit');
      final short = _holding(avg: 100, short: true, sl: 105, tp: 90);
      expect(TradeMath.triggered(short, 106), 'stop_loss');
      expect(TradeMath.triggered(short, 89), 'take_profit');
      expect(TradeMath.triggered(_holding(), 1), isNull);
    });

    test('risk per trade and reward-to-risk', () {
      expect(TradeMath.riskShare(entry: 50, stopLoss: 48, quantity: 500, equity: 100000), closeTo(0.01, 1e-12));
      expect(TradeMath.riskShare(entry: 50, stopLoss: 52, quantity: 500, equity: 100000, isShort: true), 0.01);
      expect(TradeMath.rewardToRisk(entry: 100, stopLoss: 95, takeProfit: 110), 2);
      expect(TradeMath.rewardToRisk(entry: 100, stopLoss: 105, takeProfit: 110), isNull);
    });
  });

  group('Up-or-Down', () {
    test('a 1.8x payout on a coin flip loses 10% per round', () {
      expect(UpDownMath.expectedValue(1000), closeTo(-100, 1e-9));
      expect(UpDownMath.houseEdge(), closeTo(0.10, 1e-12));
      expect(UpDownMath.breakEvenWinRate(), closeTo(0.5556, 0.0001));
      expect(kUpDownPayout, lessThan(2));
    });
  });

  group('XP and levels', () {
    test('thresholds map to levels 1..10', () {
      expect(LevelMath.levelForXp(0), 1);
      expect(LevelMath.levelForXp(99), 1);
      expect(LevelMath.levelForXp(100), 2);
      expect(LevelMath.levelForXp(999), 5);
      expect(LevelMath.levelForXp(1000), 6);
      expect(LevelMath.levelForXp(3200), 10);
      expect(LevelMath.levelForXp(99999), 10);
      expect(LevelMath.titleFor(1), 'Beginner Saver');
      expect(LevelMath.titleFor(10), 'Smart Investor');
    });

    test('progress within a level', () {
      expect(LevelMath.progressInLevel(175), closeTo(0.5, 1e-9));
      expect(LevelMath.xpToNext(175), 75);
      expect(LevelMath.xpToNext(5000), isNull);
      expect(LevelMath.progressInLevel(5000), 1);
    });
  });

  group('Lesson content', () {
    test('parses and every quiz answer is in range', () {
      const source = '{"lessons":[{"id":"x","title":"T","summary":"S","cards":[{"title":"a","body":"b","visual":"pie"}],'
          '"quiz":[{"question":"q","options":["a","b"],"answer":1,"explanation":"e"}]}]}';
      final lessons = LessonRepository.parse(SandboxModule.cse, source);
      expect(lessons.single.quiz.single.options[lessons.single.quiz.single.answer], 'b');
    });

    for (final m in SandboxModule.values) {
      test('${m.id}.json: 3-5 cards and 3-5 valid questions per lesson', () {
        final lessons = LessonRepository.parse(m, File(LessonRepository.assetPath(m)).readAsStringSync());
        expect(lessons.length, greaterThanOrEqualTo(3));
        expect(lessons.map((l) => l.id).toSet().length, lessons.length);
        for (final l in lessons) {
          expect(l.cards.length, inInclusiveRange(3, 5), reason: l.id);
          expect(l.quiz.length, inInclusiveRange(3, 5), reason: l.id);
          for (final q in l.quiz) {
            expect(q.answer, inInclusiveRange(0, q.options.length - 1), reason: '${l.id}: ${q.question}');
            expect(q.explanation, isNotEmpty);
          }
        }
      });
    }
  });
}
