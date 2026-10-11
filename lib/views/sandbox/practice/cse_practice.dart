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

/// True when the real CSE is trading (9:30 am – 2:30 pm, Mon–Fri, local).
bool cseOpenNow(DateTime now) {
  if (now.weekday > DateTime.friday) return false;
  final mins = now.hour * 60 + now.minute;
  return mins >= 9 * 60 + 30 && mins < 14 * 60 + 30;
}

class CsePractice extends StatefulWidget {
  const CsePractice({super.key});

  @override
  State<CsePractice> createState() => _CsePracticeState();
}

class _CsePracticeState extends State<CsePractice> {
  InstrumentSpec _selected = kCseInstruments.first;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    const m = SandboxModule.cse;
    final simDate = vm.simDate(m);
    final weekend = simDate.weekday > DateTime.friday;
    final realOpen = cseOpenNow(DateTime.now());
    final held = vm.holdingOf(_selected);
    final news = vm.recentNews(m, days: 120).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Cash: ${formatRs(vm.balance(m))}', style: sbText(15, weight: FontWeight.w700)),
            ),
            const SimulatedLabel(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        if (weekend)
          _Banner(
            icon: Icons.storefront_outlined,
            color: AppColors.warning,
            text: 'Market closed: ${shortDate(simDate)} is a weekend in the simulation. The CSE trades 9:30 am – 2:30 pm, '
                'Monday to Friday. Fast-forward a day to trade again.',
          )
        else if (!realOpen)
          const _Banner(
            icon: Icons.schedule_rounded,
            color: AppColors.accentCyan,
            text: 'The real CSE is closed right now (9:30 am – 2:30 pm, weekdays). The simulator runs on sim time, '
                'so you can keep practising.',
          ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selected.name, style: sbText(17, weight: FontWeight.w800)),
                        Text('${_selected.symbol} · ${_selected.sector}', style: sbText(12, color: AppColors.onGlassMuted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedMoney(value: vm.priceOf(_selected), style: sbText(18, weight: FontWeight.w800)),
                      Text(signedPct(vm.dayChangePct(_selected)),
                          style: sbText(12, weight: FontWeight.w700, color: pnlColor(vm.dayChangePct(_selected)))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SandboxLineChart(
                values: vm.priceHistory(_selected, days: 90),
                color: AppColors.primary,
                reference: held?.averagePrice,
                referenceLabel: held == null ? null : 'Your average ${formatRs(held.averagePrice)}',
              ),
              const SizedBox(height: 6),
              Text('Last 90 sim-days · dividend yield ~${(_selected.dividendYield * 100).toStringAsFixed(1)}%',
                  style: sbText(12, color: AppColors.onGlassFaint)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: weekend ? null : () => showTradeSheet(context, _selected),
                      child: const Text('Buy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: weekend || held == null ? null : () => showTradeSheet(context, _selected, side: 'sell'),
                      child: Text(held == null ? 'Sell' : 'Sell (${held.quantity.toStringAsFixed(0)})'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FastForwardBar(module: m, onForward: (d) => runFastForward(context, m, d)),
        const SizedBox(height: 18),
        const SectionTitle('Companies'),
        for (final spec in kCseInstruments) ...[
          _InstrumentRow(
            spec: spec,
            price: vm.priceOf(spec),
            change: vm.dayChangePct(spec),
            held: vm.holdingOf(spec)?.quantity,
            selected: spec.symbol == _selected.symbol,
            onTap: () => setState(() => _selected = spec),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        const SectionTitle('Recent news'),
        if (news.isEmpty)
          Text('No company news yet. Fast-forward to see how headlines move prices.',
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

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Banner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: sbText(13, height: 1.35))),
        ],
      ),
    );
  }
}

class _InstrumentRow extends StatelessWidget {
  final InstrumentSpec spec;
  final double price;
  final double change;
  final double? held;
  final bool selected;
  final VoidCallback onTap;

  const _InstrumentRow({
    required this.spec,
    required this.price,
    required this.change,
    required this.held,
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
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.glassFillStrong, shape: BoxShape.circle),
            child: Icon(instrumentTypeIcon(spec.type), color: AppColors.accentCyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.name, style: sbText(15, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${spec.symbol} · ${spec.sector}${held != null ? ' · you own ${held!.toStringAsFixed(0)}' : ''}',
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
              Text(formatRs(price), style: sbText(14, weight: FontWeight.w800)),
              Text(signedPct(change), style: sbText(12, weight: FontWeight.w700, color: pnlColor(change))),
            ],
          ),
        ],
      ),
    );
  }
}
