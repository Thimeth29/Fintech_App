// lib/services/sandbox/sim_math.dart
//
// The money maths behind every trainer module. Pure functions, unit-tested
// in test/sandbox/sim_math_test.dart. All rates are % per year.

import 'dart:math' as math;

import '../../core/sandbox/sandbox_config.dart';
import '../../models/sandbox_models.dart';

double roundRs(double v) => (v * 100).roundToDouble() / 100;

/// Full calendar months from [a] to [b] (a day-of-month not yet reached
/// doesn't count).
int fullMonthsBetween(DateTime a, DateTime b) {
  var m = (b.year - a.year) * 12 + (b.month - a.month);
  if (m > 0 && addMonths(a, m).isAfter(b)) m--;
  return math.max(0, m);
}

// ---------------------------------------------------------------------------
// Fixed deposits
// ---------------------------------------------------------------------------
class FdMath {
  /// Simple interest for [months] (how Sri Lankan FDs pay at maturity).
  static double simpleInterest(double principal, double rate, int months) =>
      principal * rate / 100 * months / 12;

  /// Compound growth: interest is added to the principal [periodsPerYear]
  /// times a year. Used to show what auto-renewing does.
  static double compoundValue(double principal, double rate, int months, {int periodsPerYear = 12}) =>
      principal * math.pow(1 + rate / 100 / periodsPerYear, periodsPerYear * months / 12).toDouble();

  static double afterTax(double interest, {double tax = kInterestWhtRate}) => interest * (1 - tax);

  /// Monthly-payout FDs pay a slightly lower rate.
  static double monthlyPayoutRate(double maturityRate) => math.max(0, maturityRate - kFdMonthlyRateDiscount);

  /// One month's interest (after tax) on a monthly-payout FD.
  static double monthlyPayment(double principal, double monthlyRate) =>
      roundRs(afterTax(principal * monthlyRate / 100 / 12));

  /// What an interest-at-maturity FD pays back in total (after tax).
  static double maturityAmount(double principal, double rate, int months) =>
      roundRs(principal + afterTax(simpleInterest(principal, rate, months)));

  /// Total after-tax interest over the term for either payout type.
  static double totalInterest(double principal, double rate, int months, {required bool monthly}) => monthly
      ? monthlyPayment(principal, monthlyPayoutRate(rate)) * months
      : roundRs(afterTax(simpleInterest(principal, rate, months)));

  /// Breaking early: interest is recalculated at [kFdEarlyWithdrawalRate]
  /// for full months held, and interest already paid out is deducted.
  static EarlyBreakQuote earlyBreak(SandboxPosition p, DateTime simDate) {
    final months = fullMonthsBetween(p.startSimDate, simDate);
    final penaltyInterest = roundRs(afterTax(simpleInterest(p.principal, kFdEarlyWithdrawalRate, months)));
    final alreadyPaid = p.payoutType == 'monthly' ? p.totalPaid : 0.0;
    final receive = math.max(0.0, roundRs(p.principal + penaltyInterest - alreadyPaid));
    final ifHeld = p.payoutType == 'monthly'
        ? p.principal
        : maturityAmount(p.principal, p.rate, p.tenureMonths ?? 12);
    final heldInterest = p.payoutType == 'monthly'
        ? monthlyPayment(p.principal, p.rate) * (p.tenureMonths ?? 12) - alreadyPaid
        : ifHeld - p.principal;
    return EarlyBreakQuote(
      monthsHeld: months,
      receive: receive,
      interestAtPenaltyRate: penaltyInterest,
      clawback: alreadyPaid > penaltyInterest ? roundRs(alreadyPaid - penaltyInterest) : 0,
      interestGivenUp: math.max(0, roundRs(heldInterest - (receive - p.principal))),
    );
  }

  /// Real return after inflation, as % (Fisher equation).
  static double realReturn(double nominalPct, double inflationPct) =>
      ((1 + nominalPct / 100) / (1 + inflationPct / 100) - 1) * 100;
}

class EarlyBreakQuote {
  final int monthsHeld;
  final double receive;
  final double interestAtPenaltyRate;
  final double clawback;
  final double interestGivenUp;
  const EarlyBreakQuote({
    required this.monthsHeld,
    required this.receive,
    required this.interestAtPenaltyRate,
    required this.clawback,
    required this.interestGivenUp,
  });
}

// ---------------------------------------------------------------------------
// Government securities
// ---------------------------------------------------------------------------
class GovMath {
  /// T-bills are sold at a discount: pay this now, get [face] at maturity.
  static double tbillPrice(double face, double yieldPct, int days) =>
      roundRs(face / (1 + yieldPct / 100 * days / 365));

  /// What a T-bill pays at maturity after tax on the discount.
  static double tbillMaturityAmount(double face, double cost, {double tax = kGovSecWhtRate}) =>
      roundRs(face - (face - cost) * tax);

  /// Coupon dates: every 6 months from [start] up to and including [maturity].
  static List<DateTime> couponDates(DateTime start, DateTime maturity) {
    final dates = <DateTime>[];
    for (var k = 1;; k++) {
      final d = addMonths(start, 6 * k);
      if (d.isAfter(maturity)) break;
      dates.add(d);
    }
    if (dates.isEmpty || dates.last != maturity) dates.add(maturity);
    return dates;
  }

  /// One semi-annual coupon after tax.
  static double couponPayment(double face, double couponRate, {double tax = kGovSecWhtRate}) =>
      roundRs(face * couponRate / 100 / 2 * (1 - tax));

  /// Market value today of a bond's remaining (gross) cash flows,
  /// discounted at [yieldPct] with semi-annual compounding. When market
  /// yields rise above the coupon rate, this falls below face value.
  static double bondPrice({
    required double face,
    required double couponRate,
    required double yieldPct,
    required DateTime start,
    required DateTime maturity,
    required DateTime now,
  }) {
    if (!now.isBefore(maturity)) return face;
    final y = yieldPct / 100 / 2;
    var pv = 0.0;
    for (final d in couponDates(start, maturity)) {
      if (!d.isAfter(now)) continue;
      final periods = daysBetween(now, d) / 182.5;
      final disc = math.pow(1 + y, periods).toDouble();
      pv += face * couponRate / 100 / 2 / disc;
      if (d == maturity) pv += face / disc;
    }
    return roundRs(pv);
  }

  /// Linear accretion of a T-bill's value from cost to face (for showing
  /// what it's "worth" mid-way; it can't be sold early in the trainer).
  static double tbillCarryingValue(SandboxPosition p, DateTime now) {
    final total = daysBetween(p.startSimDate, p.maturitySimDate);
    final done = daysBetween(p.startSimDate, now).clamp(0, total);
    return roundRs(p.cost + (p.principal - p.cost) * (total == 0 ? 1 : done / total));
  }
}

// ---------------------------------------------------------------------------
// Gold
// ---------------------------------------------------------------------------
class GoldMath {
  static double buyPrice(double mid) => mid * (1 + kGoldSpread / 2);
  static double sellPrice(double mid) => mid * (1 - kGoldSpread / 2);

  /// Mid price per gram for a gold instrument (jewellery is 22K).
  static double midFor(InstrumentSpec spec, double mid24k) =>
      spec.symbol == kGoldJewellery.symbol ? mid24k * kGold22kPurity : mid24k;

  /// Making charge on a jewellery purchase (0 for bullion).
  static double makingCharge(InstrumentSpec spec, double grams, double mid24k) =>
      spec.symbol == kGoldJewellery.symbol ? roundRs(grams * midFor(spec, mid24k) * kJewelleryMakingCharge) : 0;

  /// Round-trip result of buying and immediately selling [grams].
  static double roundTripLoss(InstrumentSpec spec, double grams, double mid24k) {
    final mid = midFor(spec, mid24k);
    final paid = grams * buyPrice(mid) + makingCharge(spec, grams, mid24k);
    final got = grams * sellPrice(mid);
    return roundRs(paid - got);
  }
}

// ---------------------------------------------------------------------------
// Stocks and trading
// ---------------------------------------------------------------------------
class TradeMath {
  static double cseFee(double gross) => roundRs(gross * kCseFeeRate);

  static double tradingFee(double gross) => roundRs(math.max(kTradingMinFee, gross * kTradingFeeRate));

  /// Unrealised P&L of a holding at [price], net of the fees already paid.
  static double unrealisedPnl(SandboxHolding h, double price) {
    final move = h.isShort ? (h.averagePrice - price) : (price - h.averagePrice);
    return roundRs(move * h.quantity - h.totalFees);
  }

  /// Value of a holding at [price]. A short is worth its collateral plus
  /// the move, floored at zero (matches sandbox_trade's cover).
  static double holdingValue(SandboxHolding h, double price) => h.isShort
      ? math.max(0, (2 * h.averagePrice - price) * h.quantity)
      : price * h.quantity;

  /// Share of [equity] lost if the stop-loss is hit.
  static double riskShare({
    required double entry,
    required double stopLoss,
    required double quantity,
    required double equity,
    bool isShort = false,
  }) {
    if (equity <= 0) return 1;
    final perUnit = isShort ? stopLoss - entry : entry - stopLoss;
    return math.max(0, perUnit) * quantity / equity;
  }

  /// 'stop_loss', 'take_profit' or null.
  static String? triggered(SandboxHolding h, double price) {
    if (h.isShort) {
      if (h.stopLoss != null && price >= h.stopLoss!) return 'stop_loss';
      if (h.takeProfit != null && price <= h.takeProfit!) return 'take_profit';
    } else {
      if (h.stopLoss != null && price <= h.stopLoss!) return 'stop_loss';
      if (h.takeProfit != null && price >= h.takeProfit!) return 'take_profit';
    }
    return null;
  }

  /// Reward-to-risk of a planned trade (e.g. 2.0 = "2:1").
  static double? rewardToRisk({required double entry, double? stopLoss, double? takeProfit, bool isShort = false}) {
    if (stopLoss == null || takeProfit == null) return null;
    final risk = (isShort ? stopLoss - entry : entry - stopLoss);
    final reward = (isShort ? entry - takeProfit : takeProfit - entry);
    if (risk <= 0 || reward <= 0) return null;
    return reward / risk;
  }
}

// ---------------------------------------------------------------------------
// Up-or-Down
// ---------------------------------------------------------------------------
class UpDownMath {
  /// Expected profit of one round: win [payout]x the stake with chance
  /// [pWin], otherwise lose the stake.
  static double expectedValue(double stake, {double pWin = 0.5, double payout = kUpDownPayout}) =>
      pWin * stake * payout - stake;

  /// Expected loss as a share of each stake, e.g. 0.10 for 1.8x at 50%.
  static double houseEdge({double pWin = 0.5, double payout = kUpDownPayout}) => 1 - pWin * payout;

  /// Win rate needed just to break even.
  static double breakEvenWinRate({double payout = kUpDownPayout}) => 1 / payout;
}

// ---------------------------------------------------------------------------
// XP and levels
// ---------------------------------------------------------------------------
class LevelMath {
  static int levelForXp(int xp) {
    var level = 1;
    for (var i = 0; i < kSandboxLevelThresholds.length; i++) {
      if (xp >= kSandboxLevelThresholds[i]) level = i + 1;
    }
    return level;
  }

  static String titleFor(int level) => kSandboxLevelTitles[(level - 1).clamp(0, kSandboxLevelTitles.length - 1)];

  /// 0..1 progress through the current level (1.0 at max level).
  static double progressInLevel(int xp) {
    final level = levelForXp(xp);
    if (level >= kSandboxLevelThresholds.length) return 1;
    final lo = kSandboxLevelThresholds[level - 1];
    final hi = kSandboxLevelThresholds[level];
    return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  static int? xpToNext(int xp) {
    final level = levelForXp(xp);
    if (level >= kSandboxLevelThresholds.length) return null;
    return kSandboxLevelThresholds[level] - xp;
  }
}
