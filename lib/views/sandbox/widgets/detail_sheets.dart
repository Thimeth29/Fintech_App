// Bottom sheets for one holding (shares, gold, trading) or one position
// (FD, T-bill, T-bond), with "Ask FinBot" and close / early-break actions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../models/sandbox_models.dart';
import '../../../services/sandbox/sim_math.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import 'price_chart.dart';
import 'sandbox_widgets.dart';
import 'trade_sheet.dart';

Future<void> showHoldingSheet(BuildContext context, SandboxHolding h) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HoldingSheet(holdingId: h.id, symbol: h.symbol, module: h.module),
  );
}

class _HoldingSheet extends StatelessWidget {
  final String holdingId;
  final String symbol;
  final SandboxModule module;
  const _HoldingSheet({required this.holdingId, required this.symbol, required this.module});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final h = vm.holdings.where((x) => x.id == holdingId).firstOrNull;
    final spec = instrumentBySymbol(symbol);
    if (h == null || spec == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('This holding has been closed.'));
    }
    final price = vm.holdingPrice(h);
    final pnl = vm.holdingPnl(h);
    final pnlPct = h.costBasis == 0 ? 0.0 : pnl / h.costBasis * 100;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.name, style: sbText(20, weight: FontWeight.w800)),
            Text('${instrumentTypeLabel(h.type)}${h.isShort ? ' · short' : ''}',
                style: sbText(13, color: AppColors.onGlassMuted)),
            if (!spec.fictional) PriceSourceBadge(quote: vm.quoteFor(spec)),
            const SizedBox(height: 12),
            if (module != SandboxModule.trading)
              SandboxLineChart(
                values: vm.priceHistory(spec, days: 90),
                color: module.color,
                reference: module == SandboxModule.gold ? null : h.averagePrice,
                referenceLabel: 'Your average',
              ),
            const SizedBox(height: 12),
            TileGrid(children: [
              StatTile(label: 'Quantity', value: '${_qty(h.quantity)} ${spec.unit == 'share' ? 'shares' : spec.unit}'),
              StatTile(label: 'Average price', value: formatRs(h.averagePrice)),
              StatTile(
                  label: module == SandboxModule.gold || module == SandboxModule.forex ? 'Sell price now' : 'Current price',
                  value: formatRs(price, decimals: price < 10 ? 4 : 2)),
              StatTile(label: 'Value', value: formatRs(vm.holdingValue(h))),
              StatTile(label: 'Profit / loss', value: signedRs(pnl), valueColor: pnlColor(pnl), sub: signedPct(pnlPct)),
              StatTile(label: 'Fees paid', value: formatRs(h.totalFees)),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showTradeSheet(context, spec, side: h.isShort ? 'cover' : 'sell'),
                    child: Text(h.isShort ? 'Cover' : 'Sell'),
                  ),
                ),
                const SizedBox(width: 10),
                if (!h.isShort)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => showTradeSheet(context, spec, side: 'buy'),
                      child: const Text('Buy more'),
                    ),
                  ),
              ],
            ),
            AskFinBotButton(
              prompt: 'In my investment trainer I hold ${_qty(h.quantity)} ${spec.name} at an average of '
                  '${formatRs(h.averagePrice)}. It\'s now ${formatRs(price)} (${signedPct(pnlPct)}). '
                  'Why might it have moved, and what should I consider before buying more or selling?',
            ),
            const SimulatedLabel(),
          ],
        ),
      ),
    );
  }
}

String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(q < 10 ? 3 : 2);

Future<void> showPositionSheet(BuildContext context, SandboxPosition p) {
  if (p.isFd) context.read<SandboxViewModel>().markChallengeEvent('fd_early_cost');
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PositionSheet(positionId: p.id),
  );
}

class _PositionSheet extends StatelessWidget {
  final String positionId;
  const _PositionSheet({required this.positionId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final p = vm.positions.where((x) => x.id == positionId).firstOrNull;
    if (p == null) return const SizedBox.shrink();
    final now = vm.simDate(p.module);
    final daysLeft = daysBetween(now, p.maturitySimDate);
    final tiles = <Widget>[
      StatTile(label: p.isFd ? 'Deposit' : 'Face value', value: formatRs(p.principal)),
      if (!p.isFd) StatTile(label: 'You paid', value: formatRs(p.cost)),
      StatTile(
        label: p.isTbond ? 'Coupon / yield at purchase' : (p.isTbill ? 'Yield' : 'Rate'),
        value: p.isTbond
            ? '${(p.couponRate ?? p.rate).toStringAsFixed(2)}% / ${p.rate.toStringAsFixed(2)}%'
            : '${p.rate.toStringAsFixed(2)}% p.a.',
      ),
      StatTile(label: 'Matures', value: shortDate(p.maturitySimDate), sub: p.isOpen ? '$daysLeft sim-days left' : p.status),
      if (p.totalPaid > 0) StatTile(label: 'Paid out so far', value: formatRs(p.totalPaid)),
      if (p.isOpen) StatTile(label: 'Value today', value: formatRs(vm.positionValue(p))),
      if (p.closedAmount != null) StatTile(label: 'Paid at close', value: formatRs(p.closedAmount!)),
    ];

    Widget? closeBox;
    if (p.isOpen && now.isBefore(p.maturitySimDate)) {
      final q = vm.earlyWithdrawal(p);
      final what = p.isFd ? 'FD' : (p.isTbill ? 'T-bill' : 'bond');
      final atMaturity = p.isTbill
          ? GovMath.tbillMaturityAmount(p.principal, p.cost)
          : (p.isFd && p.payoutType == 'maturity' ? FdMath.maturityAmount(p.principal, p.rate, p.tenureMonths ?? 12) : null);
      closeBox = _InfoBox(
        title: 'If you withdraw it today',
        lines: [
          'You\'d get ${formatRs(q.receive)}: your ${p.isTbill ? 'purchase price' : 'money'} back plus '
              '${formatRs(q.accrued)} of interest earned so far (after tax).',
          'You\'d give up about ${formatRs(q.givenUp)} still to come if you held to maturity'
              '${atMaturity == null ? '' : ' (${formatRs(atMaturity)} on ${shortDate(p.maturitySimDate)})'}.',
          if (p.isTbond || (p.isFd && p.payoutType == 'monthly'))
            'Payments already made (${formatRs(p.totalPaid)}) are yours to keep.',
          'Your ${p.rate.toStringAsFixed(2)}% rate was locked in when you opened this $what.',
        ],
        actionLabel: 'Withdraw early for ${formatRs(q.receive)}',
        onAction: () => _close(context, p, 'Withdraw this $what early?', [
          'You receive ${formatRs(q.receive)} now.',
          'You give up about ${formatRs(q.givenUp)} of interest.',
        ]),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.label, style: sbText(20, weight: FontWeight.w800)),
            Text(
              '${instrumentTypeLabel(p.type)} · ${p.payoutType == 'monthly' ? 'monthly interest' : p.payoutType == 'maturity' ? 'interest at maturity' : p.payoutType == 'semi_annual' ? 'coupons every 6 months' : 'sold at a discount'}'
              '${p.autoRenew ? ' · auto-renew' : ''}${p.renewCount > 0 ? ' · renewed ${p.renewCount}×' : ''}',
              style: sbText(13, color: AppColors.onGlassMuted),
            ),
            const SizedBox(height: 14),
            TileGrid(children: tiles),
            if (closeBox != null) ...[const SizedBox(height: 14), closeBox],
            AskFinBotButton(
              prompt: p.isFd
                  ? 'In my investment trainer I have a ${formatRs(p.principal)} FD at ${p.rate.toStringAsFixed(2)}% with '
                      '${p.label}, maturing ${shortDate(p.maturitySimDate)}. Should I keep it to maturity or break it early, and why?'
                  : 'In my investment trainer I hold a ${p.label} (face ${formatRs(p.principal)}, ${p.rate.toStringAsFixed(2)}% yield). '
                      'How do changes in interest rates affect it, and when does withdrawing early make sense?',
            ),
            const SimulatedLabel(),
          ],
        ),
      ),
    );
  }

  Future<void> _close(BuildContext context, SandboxPosition p, String title, List<String> lines) async {
    final ok = await confirmDialog(context, title: title, lines: lines, confirmLabel: 'Confirm');
    if (!ok || !context.mounted) return;
    final res = await context.read<SandboxViewModel>().closePosition(p);
    if (!context.mounted) return;
    if (res.ok) {
      Navigator.of(context).pop();
      final pnl = res.realisedPnl ?? 0;
      sandboxSnack(context, 'Withdrew ${p.label}: ${signedRs(pnl)} overall', error: pnl < 0);
    } else {
      sandboxSnack(context, res.error!, error: true);
    }
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final List<String> lines;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _InfoBox({required this.title, required this.lines, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: sbText(15, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $l', style: sbText(13, color: AppColors.onGlassMuted, height: 1.35)),
            ),
          if (actionLabel != null) ...[
            const SizedBox(height: 6),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
