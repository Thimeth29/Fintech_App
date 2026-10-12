// lib/services/sandbox/trading_engine.dart
//
// How trading works in the Investment Trainer, independent of where prices
// come from. Everything here asks a PriceSource (price_source.dart) for
// prices and rates, so the same rules run on simulated prices (offline,
// demos, tests) and on live market data, with no changes.
//
//   TradableEngine   CSE shares, gold, foreign currency and the trading
//                    module: buy and sell any time at the current price,
//                    with that market's spread and fees.
//   TermEngine       FDs, T-bills and T-bonds: money locked for a term at a
//                    fixed rate. Withdrawing early pays back what has
//                    accrued so far, not the full return.
//   SeettuEngine     the community fund: a rotating savings circle where
//                    everyone pays each round and one member takes the pot.
//
// Pure Dart (no Flutter, no Supabase) so it is unit-tested directly.
// Rounding and formulas here must match the server functions in
// supabase/migrations/20261014090000_sandbox_live_prices.sql.

import 'dart:math' as math;

import '../../core/sandbox/sandbox_config.dart';
import '../../models/sandbox_models.dart';
import 'price_engine.dart' show hashString, mix32, unitFromHash;
import 'price_source.dart';
import 'sim_math.dart';

/// What a trade costs or pays, before it is sent to the server.
class TradeQuote {
  final double price;
  final double gross;
  final double fee;

  /// Cash out (buy/short) or cash in (sell/cover).
  final double total;
  const TradeQuote({required this.price, required this.gross, required this.fee, required this.total});
}

bool isOpeningSide(String side) => side == 'buy' || side == 'short';

// ---------------------------------------------------------------------------
// Tradable instruments
// ---------------------------------------------------------------------------
class TradableEngine {
  TradableEngine(this._prices);

  final PriceSource Function() _prices;
  PriceSource get prices => _prices();

  /// The market (mid) price of [spec], from whichever source is plugged in.
  double midPrice(InstrumentSpec spec) {
    if (spec.module == SandboxModule.gold) return GoldMath.midFor(spec, gold24kMid);
    return prices.quote(spec.priceKey)?.price ?? spec.fallbackPrice;
  }

  /// 24K gold, LKR per gram (both gold products are priced off it).
  double get gold24kMid => prices.quote(kGold24kKey)?.price ?? kGoldBullion.fallbackPrice;

  /// The price you pay per unit when buying.
  double buyPrice(InstrumentSpec spec) => switch (spec.module) {
        SandboxModule.gold => GoldMath.buyPrice(midPrice(spec)),
        SandboxModule.forex => ForexMath.buyPrice(midPrice(spec)),
        _ => midPrice(spec),
      };

  /// The price you get per unit when selling.
  double sellPrice(InstrumentSpec spec) => switch (spec.module) {
        SandboxModule.gold => GoldMath.sellPrice(midPrice(spec)),
        SandboxModule.forex => ForexMath.sellPrice(midPrice(spec)),
        _ => midPrice(spec),
      };

  TradeQuote quote(InstrumentSpec spec, String side, double quantity) {
    final buying = isOpeningSide(side);
    var price = buying ? buyPrice(spec) : sellPrice(spec);
    price = (price * 10000).roundToDouble() / 10000;
    final gross = roundRs(price * quantity);
    final fee = switch (spec.module) {
      SandboxModule.gold => buying ? GoldMath.makingCharge(spec, quantity, gold24kMid) : 0.0,
      SandboxModule.cse => TradeMath.cseFee(gross),
      SandboxModule.trading => TradeMath.tradingFee(gross),
      _ => 0.0, // forex: the spread is the cost
    };
    return TradeQuote(price: price, gross: gross, fee: fee, total: buying ? gross + fee : gross - fee);
  }

  /// Local checks before a trade is sent (the server repeats them under a
  /// wallet lock). Returns an error code from sandboxErrorText, or null.
  String? check({
    required InstrumentSpec spec,
    required String side,
    required double quantity,
    required double cash,
    SandboxHolding? held,
  }) {
    if (!quantity.isFinite || quantity <= 0) return 'invalid_quantity';
    if (spec.module == SandboxModule.cse && quantity != quantity.roundToDouble()) return 'whole_shares_only';
    if (isOpeningSide(side)) {
      if (quote(spec, side, quantity).total > cash + 0.005) return 'insufficient_balance';
    } else if (held == null || held.quantity < quantity - 1e-9) {
      return 'insufficient_holdings';
    }
    return null;
  }

  /// What one unit of a holding would sell for now (shorts: what covering
  /// would cost).
  double holdingPrice(SandboxHolding h) {
    final spec = instrumentBySymbol(h.symbol);
    if (spec == null) return h.averagePrice;
    return h.isShort ? buyPrice(spec) : sellPrice(spec);
  }

  double holdingValue(SandboxHolding h) => TradeMath.holdingValue(h, holdingPrice(h));

  double holdingPnl(SandboxHolding h) => TradeMath.unrealisedPnl(h, holdingPrice(h));
}

class ForexMath {
  static double buyPrice(double mid) => mid * (1 + kForexSpread / 2);
  static double sellPrice(double mid) => mid * (1 - kForexSpread / 2);

  /// Rupees lost buying [units] and selling them straight back.
  static double roundTripLoss(double units, double mid) =>
      roundRs(units * buyPrice(mid)) - roundRs(units * sellPrice(mid));
}

// ---------------------------------------------------------------------------
// Term instruments
// ---------------------------------------------------------------------------
/// What withdrawing a term instrument early would mean.
class EarlyWithdrawal {
  /// Paid back now: principal (a T-bill's price) plus accrued interest.
  final double receive;

  /// Interest earned so far, after tax, that is included in [receive].
  final double accrued;

  /// Interest still to come (after tax) if held to maturity, that
  /// withdrawing now gives up.
  final double givenUp;

  /// Days held since the interest last started accruing.
  final int daysAccrued;

  const EarlyWithdrawal({
    required this.receive,
    required this.accrued,
    required this.givenUp,
    required this.daysAccrued,
  });
}

class TermEngine {
  TermEngine(this._prices);

  final PriceSource Function() _prices;
  PriceSource get prices => _prices();

  double _rate(String key, double fallback) => prices.quote(key)?.price ?? fallback;

  /// Today's FD rate (% p.a., interest at maturity) at [bank] for [months].
  double fdRate(String bank, int months) => _rate(fdAnchorKey(bank, months), kFdFallbackRates[bank]?[months] ?? 8.0);

  double tbillYield(int days) => _rate(tbillAnchorKey(days), kTbillFallbackYields[days] ?? 8.5);

  double tbondYield(int years) => _rate(tbondAnchorKey(years), kTbondFallbackYields[years] ?? 10.0);

  /// New T-bonds are issued at face value with a coupon equal to the
  /// market yield, rounded to 0.25%.
  static double couponFor(double yieldPct) => (yieldPct * 4).roundToDouble() / 4;

  /// What [p] pays if withdrawn on [now]: the principal (for a T-bill, the
  /// price paid) plus interest accrued so far at the locked rate, after
  /// tax. Interest already paid out isn't paid twice. Mirrors
  /// _sandbox_withdrawal_amount() on the server.
  static double withdrawalAmount(SandboxPosition p, DateTime now) {
    if (p.isTbill) {
      final total = daysBetween(p.startSimDate, p.maturitySimDate);
      final held = daysBetween(p.startSimDate, now).clamp(0, total);
      return roundRs(p.cost + (p.principal - p.cost) * (1 - kGovSecWhtRate) * held / math.max(total, 1));
    }
    return roundRs(p.principal + accruedInterest(p, now));
  }

  /// After-tax interest accrued (not yet paid) on an FD or T-bond.
  static double accruedInterest(SandboxPosition p, DateTime now) {
    if (p.isTbill) return withdrawalAmount(p, now) - p.cost;
    final from = _accrualStart(p);
    final days = daysBetween(from, now).clamp(0, math.max(0, daysBetween(from, p.maturitySimDate)));
    final rate = p.isTbond ? (p.couponRate ?? p.rate) : p.rate;
    final tax = p.isFd ? kInterestWhtRate : kGovSecWhtRate;
    return p.principal * rate / 100 * days / 365 * (1 - tax);
  }

  static DateTime _accrualStart(SandboxPosition p) =>
      p.isFd && p.payoutType == 'maturity' ? p.startSimDate : (p.lastPayoutSimDate ?? p.startSimDate);

  /// What [p] is worth today: what withdrawing it would pay.
  static double value(SandboxPosition p, DateTime now) => p.isOpen ? withdrawalAmount(p, now) : 0;

  /// Everything still to come (after tax) if [p] is held to maturity,
  /// counted from its last payout.
  static double remainingIfHeld(SandboxPosition p) {
    if (p.isTbill) return GovMath.tbillMaturityAmount(p.principal, p.cost);
    if (p.isFd) {
      final months = p.tenureMonths ?? 12;
      if (p.payoutType == 'monthly') {
        final paidThisTerm = p.lastPayoutSimDate == null ? 0 : fullMonthsBetween(p.startSimDate, p.lastPayoutSimDate!);
        return roundRs(p.principal + FdMath.monthlyPayment(p.principal, p.rate) * math.max(0, months - paidThisTerm));
      }
      return FdMath.maturityAmount(p.principal, p.rate, months);
    }
    final after = p.lastPayoutSimDate ?? p.startSimDate;
    final coupons = GovMath.couponDates(p.startSimDate, p.maturitySimDate).where((d) => d.isAfter(after)).length;
    return roundRs(p.principal + GovMath.couponPayment(p.principal, p.couponRate ?? p.rate) * coupons);
  }

  static EarlyWithdrawal earlyWithdrawal(SandboxPosition p, DateTime now) {
    final receive = withdrawalAmount(p, now);
    final base = p.isTbill ? p.cost : p.principal;
    return EarlyWithdrawal(
      receive: receive,
      accrued: roundRs(receive - base),
      givenUp: math.max(0, roundRs(remainingIfHeld(p) - receive)),
      daysAccrued: math.max(0, daysBetween(p.isTbill ? p.startSimDate : _accrualStart(p), now)),
    );
  }
}

// ---------------------------------------------------------------------------
// Community fund (seettu)
// ---------------------------------------------------------------------------
/// A simulated member who took their pot in round [memberTurn] and then
/// stopped paying, from round [fromRound] on.
class SeettuDefault {
  final int memberTurn;
  final int fromRound;
  const SeettuDefault({required this.memberTurn, required this.fromRound});
}

class SeettuEngine {
  /// Round [round] (1-based): one month apart, round 1 on joining.
  static DateTime roundDate(DateTime start, int round) => addMonths(start, round - 1);

  /// Whether (and when) a simulated member defaults in [c]. Deterministic
  /// for a user ([seed]) and circle, so it never changes after a reload.
  static SeettuDefault? defaultFor(SandboxCircle c, String seed) {
    final h = hashString('$seed|seettu|${c.id}');
    if (unitFromHash(h) >= (kSeettuDefaultChance[c.trust] ?? 0)) return null;
    // Someone who already took their pot, and still owes later rounds.
    final candidates = [for (var t = 1; t < c.members; t++) if (t != c.myTurn) t];
    if (candidates.isEmpty) return null;
    final turn = candidates[mix32(h ^ 0x1f2e3d) % candidates.length];
    return SeettuDefault(memberTurn: turn, fromRound: turn + 1);
  }

  /// The pot paid out in [round]: everyone still paying that round.
  static double potForRound(SandboxCircle c, int round, String seed) {
    final d = defaultFor(c, seed);
    final missing = d != null && round >= d.fromRound ? 1 : 0;
    return roundRs(c.contribution * (c.members - missing));
  }

  /// The default, if it has happened by [now] (so the UI can show it).
  static SeettuDefault? visibleDefault(SandboxCircle c, String seed, DateTime now) {
    final d = defaultFor(c, seed);
    if (d == null || roundDate(c.startSimDate, d.fromRound).isAfter(now)) return null;
    return d;
  }

  /// Contributions still owed across [circles].
  static double committed(Iterable<SandboxCircle> circles) =>
      circles.where((c) => c.isOpen).fold(0.0, (s, c) => s + c.contribution * (c.members - c.roundsPaid));

  /// The wallet must cover every contribution still owed, plus the new
  /// circle's — you keep paying after your pot, and the pot may come late.
  /// Mirrors sandbox_join_circle().
  static bool canJoin({
    required double balance,
    required Iterable<SandboxCircle> open,
    required int members,
    required double contribution,
  }) =>
      balance + 0.005 >= committed(open) + contribution * members;

  /// The circle's net position: paid in minus taken out. Positive before
  /// your pot (the group owes you), negative after it (you owe the group).
  static double value(SandboxCircle c) => roundRs(c.totalPaid - (c.potReceived ?? 0));

  /// Paying [contribution] for [members] rounds and taking the pot in round
  /// [turn]: an early turn is like an interest-free loan, a late one like
  /// saving with no interest. Returns the months you're "lending" (+) or
  /// "borrowing" (−) on average, weighted by money.
  static double averageMonthsLent({required int members, required int turn}) {
    // You pay one contribution in each round 1..members and receive members
    // contributions in round [turn]. Money-weighted average timing gap:
    final avgPayRound = (members + 1) / 2;
    return turn - avgPayRound;
  }
}
