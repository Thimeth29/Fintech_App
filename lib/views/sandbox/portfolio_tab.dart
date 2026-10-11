import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/sandbox_models.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'widgets/detail_sheets.dart';
import 'widgets/sandbox_widgets.dart';

class PortfolioTab extends StatelessWidget {
  final SandboxModule module;
  const PortfolioTab({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final holdings = vm.holdingsFor(module);
    final positions = vm.openPositions(module);
    final closed = vm.closedPositions(module);
    final perf = vm.performance(module);
    final invested = vm.moduleValue(module) - vm.balance(module);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TileGrid(children: [
          StatTile(label: 'Cash', value: formatRs(vm.balance(module))),
          StatTile(label: 'Invested (value now)', value: formatRs(invested)),
          StatTile(label: 'Total', value: formatRs(vm.moduleValue(module))),
          StatTile(
            label: 'Return since start',
            value: signedRs(perf.totalReturn),
            valueColor: pnlColor(perf.totalReturn),
            sub: signedPct(vm.moduleReturnPct(module)),
          ),
        ]),
        const SizedBox(height: 16),
        _Performance(module: module, perf: perf),
        if (module == SandboxModule.cse && holdings.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectorDonut(vm: vm),
        ],
        const SizedBox(height: 16),
        SectionTitle(module == SandboxModule.fd || module == SandboxModule.govSecurities ? 'Open positions' : 'Holdings'),
        if (holdings.isEmpty && positions.isEmpty)
          Text('Nothing here yet — head to Practise.', style: sbText(13, color: AppColors.onGlassMuted)),
        for (final h in holdings) ...[
          _HoldingRow(vm: vm, h: h),
          const SizedBox(height: 8),
        ],
        for (final p in positions) ...[
          _PositionRow(vm: vm, p: p),
          const SizedBox(height: 8),
        ],
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionTitle('Matured and closed'),
          for (final p in closed.reversed.take(10)) ...[
            _PositionRow(vm: vm, p: p),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 8),
        const Center(child: SimulatedLabel()),
      ],
    );
  }
}

class _Performance extends StatelessWidget {
  final SandboxModule module;
  final ModulePerformance perf;
  const _Performance({required this.module, required this.perf});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance', style: sbText(16, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          TileGrid(children: [
            StatTile(label: 'Fees paid', value: formatRs(perf.feesPaid)),
            if (module == SandboxModule.cse || module == SandboxModule.fd || module == SandboxModule.govSecurities)
              StatTile(label: 'Interest, coupons & dividends', value: formatRs(perf.income)),
            StatTile(
              label: 'Best closed trade',
              value: perf.best == null ? '—' : signedRs(perf.best!),
              valueColor: perf.best == null ? null : pnlColor(perf.best!),
            ),
            StatTile(
              label: 'Worst closed trade',
              value: perf.worst == null ? '—' : signedRs(perf.worst!),
              valueColor: perf.worst == null ? null : pnlColor(perf.worst!),
            ),
            if (module == SandboxModule.trading)
              StatTile(
                label: 'Win rate',
                value: perf.winRate == null ? '—' : '${(perf.winRate! * 100).round()}%',
                sub: '${perf.closedTrades} closed trades',
              ),
          ]),
          if (module == SandboxModule.trading && perf.feesPaid > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Fees so far: ${formatRs(perf.feesPaid)}. Win rate matters less than how big your wins are compared with your losses.',
                style: sbText(12, color: AppColors.onGlassFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectorDonut extends StatelessWidget {
  final SandboxViewModel vm;
  const _SectorDonut({required this.vm});

  @override
  Widget build(BuildContext context) {
    final bySector = <String, double>{};
    for (final h in vm.holdingsFor(SandboxModule.cse)) {
      final sector = instrumentBySymbol(h.symbol)?.sector ?? 'Other';
      bySector[sector] = (bySector[sector] ?? 0) + vm.holdingValue(h);
    }
    final total = bySector.values.fold(0.0, (s, v) => s + v);
    final entries = bySector.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Color colorAt(int i) => AppColors.chartSeries[i % AppColors.chartSeries.length];
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sector diversification', style: sbText(16, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            entries.length >= 3
                ? 'Spread across ${entries.length} sectors.'
                : 'Only ${entries.length} sector${entries.length == 1 ? '' : 's'} — one bad headline hits everything you own.',
            style: sbText(13, color: entries.length >= 3 ? AppColors.gain : AppColors.warning),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: [
                      for (final (i, e) in entries.indexed)
                        PieChartSectionData(value: e.value, color: colorAt(i), radius: 24, showTitle: false),
                    ],
                  ),
                  swapAnimationDuration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, e) in entries.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colorAt(i), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key, style: sbText(13))),
                            Text('${(e.value / total * 100).round()}%', style: sbText(13, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final SandboxViewModel vm;
  final SandboxHolding h;
  const _HoldingRow({required this.vm, required this.h});

  @override
  Widget build(BuildContext context) {
    final pnl = vm.holdingPnl(h);
    final pct = h.costBasis == 0 ? 0.0 : pnl / h.costBasis * 100;
    final qty = h.quantity == h.quantity.roundToDouble() ? h.quantity.toStringAsFixed(0) : h.quantity.toStringAsFixed(3);
    return GlassCard(
      onTap: () => showHoldingSheet(context, h),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(instrumentTypeIcon(h.type), color: h.module.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: sbText(15, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${h.isShort ? 'Short · ' : ''}$qty × avg ${formatRs(h.averagePrice)} · ${instrumentTypeLabel(h.type)}',
                    style: sbText(12, color: AppColors.onGlassMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatRs(vm.holdingValue(h)), style: sbText(14, weight: FontWeight.w800)),
              Text('${signedRs(pnl)} (${signedPct(pct, decimals: 1)})',
                  style: sbText(12, weight: FontWeight.w700, color: pnlColor(pnl))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final SandboxViewModel vm;
  final SandboxPosition p;
  const _PositionRow({required this.vm, required this.p});

  @override
  Widget build(BuildContext context) {
    final value = p.isOpen ? vm.positionValue(p) : (p.closedAmount ?? 0);
    final status = switch (p.status) {
      'matured' => 'Matured ${p.closedSimDate == null ? '' : shortDate(p.closedSimDate!)}',
      'closed_early' => 'Closed early ${p.closedSimDate == null ? '' : shortDate(p.closedSimDate!)}',
      _ => 'Matures ${shortDate(p.maturitySimDate)}',
    };
    return Opacity(
      opacity: p.isOpen ? 1 : 0.75,
      child: GlassCard(
        onTap: () => showPositionSheet(context, p),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(instrumentTypeIcon(p.type), color: p.module.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.label}${p.isFd ? ' · ${p.tenureMonths}m' : ''}', style: sbText(15, weight: FontWeight.w700)),
                  Text('${instrumentTypeLabel(p.type)} · ${p.rate.toStringAsFixed(2)}% · $status',
                      style: sbText(12, color: AppColors.onGlassMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(formatRs(value), style: sbText(14, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
