import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/utils/money.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import 'sandbox_widgets.dart';

Future<void> showResetModule(BuildContext context, SandboxModule m) async {
  final vm = context.read<SandboxViewModel>();
  final w = vm.wallets[m];
  if (w == null) return;
  final ok = await confirmDialog(
    context,
    title: 'Reset ${m.shortTitle}?',
    confirmLabel: 'Reset module',
    lines: [
      'Wallet goes back to ${formatRs(kSandboxStartingBalance)} (now ${formatRs(vm.moduleValue(m))}).',
      if (vm.holdingsFor(m).isNotEmpty) '${vm.holdingsFor(m).length} holding(s) will be cleared.',
      if (vm.openPositions(m).isNotEmpty) '${vm.openPositions(m).length} open position(s) will be closed with no payout.',
      if (m.hasSimClock) 'The sim clock goes back to today.',
      'Trade history is archived, not deleted.',
      'Kept: XP, level, badges, lessons and challenges.',
      'Times reset so far: ${w.resetCount} (private, no penalty).',
    ],
  );
  if (!ok || !context.mounted) return;
  final res = await vm.reset(module: m);
  if (context.mounted) {
    sandboxSnack(context, res.ok ? '${m.shortTitle} reset to ${formatRs(kSandboxStartingBalance)}' : res.error!, error: !res.ok);
  }
}

Future<void> showResetEverything(BuildContext context) async {
  final vm = context.read<SandboxViewModel>();
  var learning = false;
  final ok = await confirmDialog(
    context,
    title: 'Reset everything?',
    confirmLabel: 'Reset everything',
    lines: [
      'All ${vm.wallets.length} module wallets go back to ${formatRs(kSandboxStartingBalance)} each.',
      'All holdings and open positions are cleared; sim clocks go back to today.',
      'Trade history is archived, not deleted.',
    ],
    extra: StatefulBuilder(
      builder: (ctx, setState) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: learning,
        onChanged: (v) => setState(() => learning = v ?? false),
        title: Text('Also reset learning progress', style: sbText(14, weight: FontWeight.w600)),
        subtitle: Text('Lessons, quizzes, challenges, badges, XP, level and streak.',
            style: sbText(12, color: Colors.white70)),
      ),
    ),
  );
  if (!ok || !context.mounted) return;
  final res = await vm.reset(resetLearning: learning);
  if (context.mounted) {
    sandboxSnack(context, res.ok ? 'Trainer reset' : res.error!, error: !res.ok);
  }
}
