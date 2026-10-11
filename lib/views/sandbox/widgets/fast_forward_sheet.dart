import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../models/sandbox_models.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import 'sandbox_widgets.dart';

/// Advances the module's sim clock, then shows what happened: payouts
/// counting up, value change, maturities and the news that moved prices.
Future<void> runFastForward(BuildContext context, SandboxModule m, int days) async {
  final vm = context.read<SandboxViewModel>();
  final out = await vm.fastForward(m, days);
  if (!context.mounted) return;
  if (!out.ok) {
    sandboxSnack(context, out.error ?? 'Could not fast-forward.', error: true);
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FastForwardResult(module: m, outcome: out),
  );
}

class _FastForwardResult extends StatelessWidget {
  final SandboxModule module;
  final FastForwardOutcome outcome;
  const _FastForwardResult({required this.module, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final plan = outcome.plan!;
    final paid = plan.totalPaid;
    final valueNow = vm.moduleValue(module);
    final change = valueNow - outcome.valueBefore;
    final days = daysBetween(plan.from, plan.to);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('+$days ${days == 1 ? 'day' : 'days'} → ${shortDate(plan.to)}', style: sbText(20, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paid into your wallet', style: sbText(12, color: AppColors.onGlassMuted)),
                      _CountUp(value: paid, style: sbText(24, weight: FontWeight.w800, color: AppColors.gold)),
                    ],
                  ),
                ),
                if (paid > 0) CoinBurst(count: (plan.events.length).clamp(1, 6)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Module value ${formatRs(outcome.valueBefore)} → ${formatRs(valueNow)} (${signedRs(change)})',
                style: sbText(13, weight: FontWeight.w600, color: pnlColor(change))),
            if (plan.events.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('What happened', style: sbText(15, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final e in plan.events.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(e.isMaturity ? Icons.celebration_outlined : Icons.payments_outlined,
                          size: 18, color: e.isMaturity ? AppColors.gold : AppColors.accentCyan),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${shortDate(e.simDate)} · ${e.label}', style: sbText(13))),
                      Text(e.kind == 'fd_renew' ? '+${formatRs(e.amount)} reinvested' : '+${formatRs(e.amount)}',
                          style: sbText(13, weight: FontWeight.w700, color: AppColors.gain)),
                    ],
                  ),
                ),
              if (plan.events.length > 12)
                Text('…and ${plan.events.length - 12} more in History', style: sbText(12, color: AppColors.onGlassFaint)),
            ],
            const SizedBox(height: 14),
            Text(plan.news.isEmpty ? 'No major news in this period.' : 'News that moved the market',
                style: sbText(15, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final n in plan.news.reversed.take(4)) ...[
              NewsEventCard(event: n, dateLabel: shortDate(addDays(vm.wallets[module]!.startDate, n.day))),
              const SizedBox(height: 8),
            ],
            if (module == SandboxModule.fd || module == SandboxModule.govSecurities)
              Text(
                'Over ${days >= 365 ? '${(days / 365).toStringAsFixed(1)} years' : '$days days'}, '
                '${kAssumedInflation.toStringAsFixed(0)}% inflation would cut buying power by about '
                '${((1 - 1 / (1 + kAssumedInflation / 100 * days / 365)) * 100).toStringAsFixed(1)}%.',
                style: sbText(12, color: AppColors.onGlassFaint),
              ),
            const SizedBox(height: 10),
            AskFinBotButton(
              prompt: 'I fast-forwarded my ${module.shortTitle} practice by $days days. '
                  '${paid > 0 ? 'I received ${formatRs(paid)} in payouts. ' : ''}My module value changed by ${signedRs(change)}. '
                  'Can you explain what drove that?',
            ),
            const SimulatedLabel(),
          ],
        ),
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  final double value;
  final TextStyle style;
  const _CountUp({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(formatRs(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(formatRs(v), style: style),
    );
  }
}
