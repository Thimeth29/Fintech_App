import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/sandbox_models.dart';
import '../../../services/sandbox/sim_math.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../widgets/fast_forward_sheet.dart';
import '../widgets/price_chart.dart';
import '../widgets/sandbox_widgets.dart';
import '../widgets/trade_sheet.dart';

class GoldPractice extends StatefulWidget {
  const GoldPractice({super.key});

  @override
  State<GoldPractice> createState() => _GoldPracticeState();
}

class _GoldPracticeState extends State<GoldPractice> {
  bool _showSpread = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    const m = SandboxModule.gold;
    final mid = vm.gold24kMid;
    final start = vm.anchorOf(kGoldBullion);
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
              Text('24K gold, per gram', style: sbText(13, color: AppColors.onGlassMuted)),
              AnimatedMoney(value: mid, style: sbText(26, weight: FontWeight.w800, color: AppColors.gold)),
              PriceSourceBadge(quote: vm.quoteFor(kGoldBullion)),
              Text(
                vm.isLivePrice(kGoldBullion)
                    ? 'CBSL\'s gold rate (per troy ounce) converted to grams. Jewellers\' prices include a premium.'
                    : 'Started at ${formatRs(start)} — the same reference as Home\'s "Market today" card.',
                style: sbText(12, color: AppColors.onGlassFaint),
              ),
              const SizedBox(height: 10),
              SandboxLineChart(values: vm.priceHistory(kGoldBullion, days: 180), color: AppColors.gold),
              const SizedBox(height: 10),
              TileGrid(children: [
                StatTile(label: 'You buy at', value: formatRs(GoldMath.buyPrice(mid)), sub: 'per gram, 24K'),
                StatTile(label: 'You sell at', value: formatRs(GoldMath.sellPrice(mid)), sub: 'per gram, 24K'),
                StatTile(label: '1 sovereign (8 g, 24K)', value: formatRs(mid * kGramsPerSovereign, decimals: 0)),
                StatTile(label: '22K, per gram', value: formatRs(GoldMath.midFor(kGoldJewellery, mid))),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final spec in kGoldInstruments) ...[
          _GoldCard(spec: spec, vm: vm),
          const SizedBox(height: 10),
        ],
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Discover the spread', style: sbText(16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('What if you bought 10 g and sold it straight back?', style: sbText(13, color: AppColors.onGlassMuted)),
              const SizedBox(height: 10),
              if (!_showSpread)
                OutlinedButton(
                  onPressed: () {
                    setState(() => _showSpread = true);
                    vm.markChallengeEvent('gold_spread');
                  },
                  child: const Text('Show me'),
                )
              else ...[
                Text('Bullion: you\'d lose ${formatRs(GoldMath.roundTripLoss(kGoldBullion, 10, mid))} (the 3% spread).',
                    style: sbText(14, weight: FontWeight.w600, color: AppColors.loss)),
                const SizedBox(height: 4),
                Text(
                  'Jewellery: you\'d lose ${formatRs(GoldMath.roundTripLoss(kGoldJewellery, 10, mid))} '
                  '(spread + ${(kJewelleryMakingCharge * 100).round()}% making charge you never get back).',
                  style: sbText(14, weight: FontWeight.w600, color: AppColors.loss),
                ),
                const SizedBox(height: 6),
                Text('Gold has to rise by more than this before you make any profit.',
                    style: sbText(12, color: AppColors.onGlassFaint)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FastForwardBar(module: m, onForward: (d) => runFastForward(context, m, d)),
        const SizedBox(height: 18),
        const SectionTitle('What moved gold'),
        if (news.isEmpty)
          Text(
              vm.usesLivePrices(m)
                  ? 'Live gold prices move with the world gold price and the rupee.'
                  : 'No gold news yet. Fast-forward a few months.',
              style: sbText(13, color: AppColors.onGlassMuted))
        else
          for (final n in news) ...[
            NewsEventCard(event: n, dateLabel: shortDate(addDays(vm.wallets[m]!.startDate, n.day))),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _GoldCard extends StatelessWidget {
  final InstrumentSpec spec;
  final SandboxViewModel vm;
  const _GoldCard({required this.spec, required this.vm});

  @override
  Widget build(BuildContext context) {
    final held = vm.holdingOf(spec);
    final jewel = spec.symbol == kGoldJewellery.symbol;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(jewel ? Icons.diamond_outlined : Icons.view_module_rounded, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(child: Text(spec.name, style: sbText(16, weight: FontWeight.w700))),
              if (held != null)
                Text('${held.quantity.toStringAsFixed(2)} g', style: sbText(14, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            jewel
                ? '22K (91.6% pure). Adds a ${(kJewelleryMakingCharge * 100).round()}% making charge that isn\'t paid back when you sell.'
                : '24K bars and coins. Only the dealer spread to pay.',
            style: sbText(13, color: AppColors.onGlassMuted),
          ),
          if (held != null) ...[
            const SizedBox(height: 6),
            Text(
              'Worth ${formatRs(vm.holdingValue(held))} if sold now · ${signedRs(vm.holdingPnl(held))} incl. charges',
              style: sbText(13, weight: FontWeight.w600, color: pnlColor(vm.holdingPnl(held))),
            ),
          ],
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
    );
  }
}
