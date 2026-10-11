// lib/services/sandbox/fast_forward.dart
//
// Works out everything that happens when a module's sim clock jumps
// forward: FD interest and maturities (with auto-renew), T-bill
// maturities, T-bond coupons, CSE dividends and news. The resulting
// events are sent to sandbox_fast_forward(), which applies them in one
// transaction.

import '../../core/sandbox/sandbox_config.dart';
import '../../models/sandbox_models.dart';
import 'price_engine.dart';
import 'sim_math.dart';

class SimEvent {
  final String kind; // fd_interest | fd_mature | fd_renew | tbill_mature | tbond_coupon | tbond_mature | dividend
  final String? positionId;
  final String? symbol;
  final double amount;
  final DateTime simDate;
  final String label;

  const SimEvent({
    required this.kind,
    required this.amount,
    required this.simDate,
    required this.label,
    this.positionId,
    this.symbol,
  });

  bool get isMaturity => kind.endsWith('_mature');

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (positionId != null) 'position_id': positionId,
        if (symbol != null) 'symbol': symbol,
        'amount': amount,
        'sim_date': _iso(simDate),
      };

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class FastForwardPlan {
  final DateTime from;
  final DateTime to;
  final List<SimEvent> events;
  final List<NewsEvent> news;

  const FastForwardPlan({required this.from, required this.to, required this.events, required this.news});

  double get totalPaid => events.where((e) => e.kind != 'fd_renew').fold(0.0, (s, e) => s + e.amount);
}

class FastForwardPlanner {
  final SandboxPriceEngine engine;
  FastForwardPlanner(this.engine);

  FastForwardPlan plan({
    required SandboxWallet wallet,
    required int days,
    required List<SandboxPosition> positions,
    required List<SandboxHolding> holdings,
  }) {
    final from = wallet.simDate;
    final to = addDays(from, days);
    bool inWindow(DateTime d) => d.isAfter(from) && !d.isAfter(to);
    final events = <SimEvent>[];

    for (final p in positions.where((p) => p.isOpen && p.module == wallet.module)) {
      if (p.isFd) {
        _planFd(p, inWindow, to, events);
      } else if (p.isTbill) {
        if (inWindow(p.maturitySimDate)) {
          events.add(SimEvent(
            kind: 'tbill_mature',
            positionId: p.id,
            amount: GovMath.tbillMaturityAmount(p.principal, p.cost),
            simDate: p.maturitySimDate,
            label: '${p.label} matured',
          ));
        }
      } else if (p.isTbond) {
        final coupon = GovMath.couponPayment(p.principal, p.couponRate ?? p.rate);
        for (final d in GovMath.couponDates(p.startSimDate, p.maturitySimDate)) {
          if (!inWindow(d)) continue;
          events.add(SimEvent(
            kind: 'tbond_coupon',
            positionId: p.id,
            amount: coupon,
            simDate: d,
            label: 'Coupon from ${p.label}',
          ));
        }
        if (inWindow(p.maturitySimDate)) {
          events.add(SimEvent(
            kind: 'tbond_mature',
            positionId: p.id,
            amount: p.principal,
            simDate: p.maturitySimDate,
            label: '${p.label} matured',
          ));
        }
      }
    }

    if (wallet.module == SandboxModule.cse) {
      _planDividends(wallet, holdings, inWindow, from, to, events);
    }

    // Server applies in order; same-day coupons come before maturities.
    int rank(SimEvent e) => e.isMaturity || e.kind == 'fd_renew' ? 1 : 0;
    events.sort((a, b) {
      final c = a.simDate.compareTo(b.simDate);
      return c != 0 ? c : rank(a).compareTo(rank(b));
    });

    final startDay = wallet.simDay;
    return FastForwardPlan(
      from: from,
      to: to,
      events: events,
      news: engine.newsBetween(wallet.module, startDay, startDay + days),
    );
  }

  void _planFd(SandboxPosition p, bool Function(DateTime) inWindow, DateTime to, List<SimEvent> out) {
    var principal = p.principal;
    var start = p.startSimDate;
    var maturity = p.maturitySimDate;
    final months = p.tenureMonths ?? 12;
    final monthly = p.payoutType == 'monthly';
    // Auto-renew can roll several times inside one long jump.
    for (var guard = 0; guard < 400; guard++) {
      if (monthly) {
        final pay = FdMath.monthlyPayment(principal, p.rate);
        for (var k = 1; k <= months; k++) {
          final d = addMonths(start, k);
          if (d.isAfter(maturity)) break;
          if (inWindow(d)) {
            out.add(SimEvent(kind: 'fd_interest', positionId: p.id, amount: pay, simDate: d, label: 'Interest from ${p.label}'));
          }
        }
      }
      if (!inWindow(maturity)) return;
      final interest = monthly ? 0.0 : FdMath.maturityAmount(principal, p.rate, months) - principal;
      if (p.autoRenew) {
        out.add(SimEvent(
          kind: 'fd_renew',
          positionId: p.id,
          amount: roundRs(interest),
          simDate: maturity,
          label: '${p.label} renewed${interest > 0 ? ' with interest added' : ''}',
        ));
        principal = roundRs(principal + interest);
        start = maturity;
        maturity = addMonths(start, months);
        if (maturity.isAfter(to) && !monthly) return;
      } else {
        out.add(SimEvent(
          kind: 'fd_mature',
          positionId: p.id,
          amount: roundRs(principal + interest),
          simDate: maturity,
          label: '${p.label} matured',
        ));
        return;
      }
    }
  }

  void _planDividends(SandboxWallet wallet, List<SandboxHolding> holdings, bool Function(DateTime) inWindow,
      DateTime from, DateTime to, List<SimEvent> out) {
    for (final h in holdings.where((h) => h.module == SandboxModule.cse && !h.isShort)) {
      final spec = instrumentBySymbol(h.symbol);
      if (spec == null || spec.dividendMonths.isEmpty) continue;
      final anchor = wallet.anchors[spec.symbol] ?? spec.fallbackPrice;
      for (var y = from.year; y <= to.year; y++) {
        for (final m in spec.dividendMonths) {
          final d = DateTime(y, m, 15);
          if (!inWindow(d)) continue;
          final price = engine.priceOn(spec, anchor, daysBetween(wallet.startDate, d));
          final perShare = price * spec.dividendYield / spec.dividendMonths.length;
          var amount = roundRs(h.quantity * perShare * (1 - kDividendWhtRate));
          // Matches the server's sanity cap (20% of cost per payment).
          final cap = roundRs(h.costBasis * 0.19);
          if (amount > cap) amount = cap;
          if (amount <= 0) continue;
          out.add(SimEvent(
            kind: 'dividend',
            symbol: h.symbol,
            amount: amount,
            simDate: d,
            label: 'Dividend from ${spec.name}',
          ));
        }
      }
    }
  }
}
