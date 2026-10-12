// Foreign currency: buy and sell dollars, euros and other currencies for
// rupees at CBSL's indicative rates plus a bank-style spread.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/sandbox_models.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../widgets/fast_forward_sheet.dart';
import '../widgets/price_chart.dart';
import '../widgets/sandbox_widgets.dart';
import '../widgets/trade_sheet.dart';

/// "Rs 298.82" for most currencies, more decimals for small ones (yen, rupee).
String fxRate(double v) => formatRs(v, decimals: v < 10 ? 4 : 2);

class ForexPractice extends StatefulWidget {
  const ForexPractice({super.key});

  @override
  State<ForexPractice> createState() => _ForexPracticeState();
}

class _ForexPracticeState extends State<ForexPractice> {
  InstrumentSpec _selected = kForexInstruments.first;
  bool _showSpread = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    const m = SandboxModule.forex;
    final spec = _selected;
    final mid = vm.priceOf(spec);
    final held = vm.holdingOf(spec);
    final change = vm.dayChangePct(spec);
    final news = vm.recentNews(m, days: 180).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Cash: ${formatRs(vm.balance(m))}', style: sbText(15, weight: FontWeight.w700))),
            const SimulatedLabel(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${spec.name} (${spec.unit})', style: sbText(17, weight: FontWeight.w800)),
                        Text('Rupees for 1 ${spec.unit}', style: sbText(12, color: AppColors.onGlassMuted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fxRate(mid), style: sbText(18, weight: FontWeight.w800)),
                      Text(signedPct(change), style: sbText(12, weight: FontWeight.w700, color: pnlColor(change))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              PriceSourceBadge(quote: vm.quoteFor(spec)),
              const SizedBox(height: 10),
              SandboxLineChart(
                values: vm.priceHistory(spec, days: 90),
                color: m.color,
                reference: held?.averagePrice,
                referenceLabel: held == null ? null : 'You paid ${fxRate(held.averagePrice)}',
              ),
              const SizedBox(height: 10),
              TileGrid(children: [
                StatTile(label: 'You buy at', value: fxRate(ForexMath.buyPrice(mid)), sub: 'bank selling rate'),
                StatTile(label: 'You sell at', value: fxRate(ForexMath.sellPrice(mid)), sub: 'bank buying rate'),
                StatTile(label: '100 ${spec.unit} costs', value: formatRs(ForexMath.buyPrice(mid) * 100, decimals: 0)),
                if (held != null)
                  StatTile(
                    label: 'You hold',
                    value: '${held.quantity.toStringAsFixed(2)} ${spec.unit}',
                    sub: '${signedRs(vm.holdingPnl(held))} if sold now',
                  ),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => showTradeSheet(context, spec), child: const Text('Buy'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: held == null ? null : () => showTradeSheet(context, spec, side: 'sell'),
                      child: const Text('Sell'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle('Currencies'),
        for (final c in kForexInstruments) ...[
          _CurrencyRow(
            spec: c,
            rate: vm.priceOf(c),
            change: vm.dayChangePct(c),
            held: vm.holdingOf(c)?.quantity,
            live: vm.isLivePrice(c),
            selected: c.symbol == spec.symbol,
            onTap: () => setState(() => _selected = c),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spot the bank spread', style: sbText(16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('What if you bought 100 ${spec.unit} and sold them straight back?',
                  style: sbText(13, color: AppColors.onGlassMuted)),
              const SizedBox(height: 10),
              if (!_showSpread)
                OutlinedButton(
                  onPressed: () {
                    setState(() => _showSpread = true);
                    vm.markChallengeEvent('fx_spread');
                  },
                  child: const Text('Show me'),
                )
              else ...[
                Text(
                  'You\'d lose ${formatRs(ForexMath.roundTripLoss(100, mid))} '
                  '(${(kForexSpread * 100).toStringAsFixed(1)}% round trip).',
                  style: sbText(14, weight: FontWeight.w600, color: AppColors.loss),
                ),
                const SizedBox(height: 6),
                Text('The rate has to move more than this in your favour before you make anything.',
                    style: sbText(12, color: AppColors.onGlassFaint)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FastForwardBar(module: m, onForward: (d) => runFastForward(context, m, d)),
        if (!vm.usesLivePrices(m)) ...[
          const SizedBox(height: 18),
          const SectionTitle('What moved the rupee'),
          if (news.isEmpty)
            Text('No currency news yet. Fast-forward a few months.', style: sbText(13, color: AppColors.onGlassMuted))
          else
            for (final n in news) ...[
              NewsEventCard(event: n, dateLabel: shortDate(addDays(vm.wallets[m]!.startDate, n.day))),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  final InstrumentSpec spec;
  final double rate;
  final double change;
  final double? held;
  final bool live;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyRow({
    required this.spec,
    required this.rate,
    required this.change,
    required this.held,
    required this.live,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: selected ? AppColors.accentCyan : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.glassFillStrong, shape: BoxShape.circle),
            child: Text(spec.unit, style: sbText(11, weight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.name, style: sbText(15, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${live ? 'Live CBSL rate' : 'Simulated'}${held != null ? ' · you own ${held!.toStringAsFixed(2)}' : ''}',
                  style: sbText(12, color: AppColors.onGlassMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fxRate(rate), style: sbText(14, weight: FontWeight.w800)),
              Text(signedPct(change), style: sbText(12, weight: FontWeight.w700, color: pnlColor(change))),
            ],
          ),
        ],
      ),
    );
  }
}
