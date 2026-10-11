import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/group_models.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../../bot/chat_screen.dart';
import '../widgets/community_widgets.dart';

const _contributionLabels = {
  'pledged': 'Pledged',
  'marked_paid': 'Marked paid',
  'confirmed': 'Confirmed',
};

class InvestmentTab extends StatelessWidget {
  const InvestmentTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final g = vm.info!;
    final d = vm.dashboard;
    final mine = vm.contributions.where((c) => c.userId == vm.myId).toList();
    final toConfirm = vm.contributions.where((c) => c.userId != vm.myId && c.status != 'confirmed').toList();
    final myExit = vm.exits.where((e) => e.userId == vm.myId).firstOrNull;
    final otherExits = vm.exits.where((e) => e.userId != vm.myId).toList();
    final myShares = vm.distributions.where((x) => x.shares.containsKey(vm.myId) && !x.confirmed.contains(vm.myId)).toList();

    return RefreshIndicator(
      onRefresh: vm.loadMoney,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          if (d != null) _Dashboard(d: d, vm: vm),
          const SizedBox(height: 12),
          SectionTitle('My contributions',
              trailing: g.isClosed
                  ? null
                  : TextButton.icon(
                      onPressed: () => _pledge(context, vm),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Pledge'),
                    )),
          Text(
            'Pay the treasurer by bank transfer or cash, then mark it paid here. ${g.minContribution > 0 ? 'Minimum ${formatRs(g.minContribution, decimals: 0)}' : ''}'
            '${g.maxContribution != null ? ', maximum ${formatRs(g.maxContribution!, decimals: 0)}' : ''}.',
            style: cText(12, color: AppColors.onGlassMuted),
          ),
          const SizedBox(height: 6),
          if (mine.isEmpty) Text('You haven\'t pledged yet.', style: cText(13, color: AppColors.onGlassMuted)),
          for (final c in mine)
            _row(
              title: formatRs(c.amount),
              subtitle: c.pledgedAt == null ? null : shortDate(c.pledgedAt!),
              status: c.status,
              actions: [
                if (c.status == 'pledged')
                  TextButton(onPressed: () => act(context, vm.markContributionPaid(c.id), 'Marked as paid.'), child: const Text('Mark paid')),
                if (c.status != 'confirmed')
                  TextButton(onPressed: () => act(context, vm.cancelPledge(c.id), 'Pledge cancelled.'), child: const Text('Cancel')),
              ],
            ),
          if (vm.canConfirmMoney && toConfirm.isNotEmpty) ...[
            const SizedBox(height: 10),
            SectionTitle('To confirm (${toConfirm.length})'),
            for (final c in toConfirm)
              _row(
                title: '${vm.nameOf(c.userId)} · ${formatRs(c.amount)}',
                status: c.status,
                actions: [
                  TextButton(
                    onPressed: () => act(context, vm.confirmContribution(c.id), 'Contribution confirmed.'),
                    child: const Text('Confirm received'),
                  ),
                ],
              ),
          ],
          if (myShares.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionTitle('Distributions to confirm'),
            for (final x in myShares)
              _row(
                title: 'Your share ${formatRs(x.shares[vm.myId]!)}',
                subtitle: 'of ${formatRs(x.total)} (${x.rule == 'equal' ? 'equal split' : 'pro-rata'})',
                actions: [
                  TextButton(onPressed: () => act(context, vm.confirmDistribution(x.id), 'Receipt confirmed.'), child: const Text('I received it')),
                ],
              ),
          ],
          const SizedBox(height: 12),
          SectionTitle('Proposals',
              trailing: g.isClosed
                  ? null
                  : TextButton.icon(
                      onPressed: () => _propose(context, vm),
                      icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                      label: const Text('Propose'),
                    )),
          if (vm.proposals.isEmpty) Text('No proposals yet.', style: cText(13, color: AppColors.onGlassMuted)),
          for (final p in vm.proposals) _ProposalCard(p: p, vm: vm),
          const SizedBox(height: 12),
          SectionTitle('Investments',
              trailing: vm.canConfirmMoney && !g.isClosed
                  ? TextButton.icon(
                      onPressed: () => _recordInvestment(context, vm, null),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Record'),
                    )
                  : null),
          if (vm.canConfirmMoney)
            Text('Without a vote you can record up to ${formatRs(g.decisionThreshold, decimals: 0)}. Bigger amounts need a passed proposal.',
                style: cText(12, color: AppColors.onGlassMuted)),
          if (vm.investments.isEmpty) Text('Nothing invested yet.', style: cText(13, color: AppColors.onGlassMuted)),
          for (final i in vm.investments) _InvestmentCard(i: i, vm: vm),
          if (vm.distributions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SectionTitle('Distributions'),
            for (final x in vm.distributions)
              _row(
                title: '${formatRs(x.total)} · ${x.rule == 'equal' ? 'equal split' : 'pro-rata'}',
                subtitle: '${x.confirmed.length} of ${x.shares.length} members confirmed receipt',
                status: x.status == 'completed' ? 'confirmed' : null,
              ),
          ],
          if (vm.canConfirmMoney && !g.isClosed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _distribute(context, vm),
                icon: const Icon(Icons.call_split_rounded, size: 18),
                label: const Text('Create a distribution'),
              ),
            ),
          const SizedBox(height: 12),
          const SectionTitle('Leaving the group'),
          if (myExit != null)
            _row(
              title: 'Your exit: ${formatRs(myExit.payout)}',
              subtitle: myExit.status == 'approved' ? 'Approved. Confirm once you\'ve been paid.' : 'Waiting for ${myExit.voteId != null ? 'the group vote' : 'the leader'}',
              actions: [
                if (myExit.status == 'approved')
                  TextButton(
                    onPressed: () async {
                      if (await confirmAction(context, 'Confirm exit payout?',
                          'You confirm you received ${formatRs(myExit.payout)}. You\'ll then leave the group.', confirm: 'Confirm')) {
                        if (!context.mounted) return;
                        final error = await vm.confirmExitPayout(myExit.id);
                        if (!context.mounted) return;
                        showResult(context, error, 'You\'ve left the group.');
                        if (error == null) Navigator.of(context).pop();
                      }
                    },
                    child: const Text('I was paid'),
                  ),
              ],
            )
          else if (!g.isClosed)
            OutlinedButton(onPressed: () => _requestExit(context, vm), child: const Text('Request exit')),
          for (final e in otherExits)
            _row(
              title: '${vm.nameOf(e.userId)} wants to exit · ${formatRs(e.payout)}',
              subtitle: e.reason,
              status: e.status == 'approved' ? 'confirmed' : null,
              actions: [
                if (vm.isOfficer && e.status == 'pending' && e.voteId == null) ...[
                  TextButton(onPressed: () => act(context, vm.decideExit(e.id, true), 'Exit approved.'), child: const Text('Approve')),
                  TextButton(onPressed: () => act(context, vm.decideExit(e.id, false), 'Exit declined.'), child: const Text('Decline')),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Text('Returns are never guaranteed. Group investments can lose money.', style: cText(12, color: AppColors.warning)),
          const RecordKeepingFooter(),
        ],
      ),
    );
  }

  Widget _row({required String title, String? subtitle, String? status, List<Widget> actions = const []}) => GlassCard(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        borderRadius: 14,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: cText(13.5, weight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle, style: cText(12, color: AppColors.onGlassMuted)),
            ]),
          ),
          if (status != null)
            InfoChip(_contributionLabels[status] ?? status,
                color: status == 'confirmed' ? AppColors.gain : AppColors.accentCyan),
          ...actions,
        ]),
      );

  Future<void> _pledge(BuildContext context, GroupViewModel vm) async {
    final amount = await _amountDialog(context, 'Pledge a contribution (Rs)');
    if (amount != null && context.mounted) await act(context, vm.pledge(amount), 'Pledge recorded. Pay the treasurer, then mark it paid.');
  }

  Future<void> _distribute(BuildContext context, GroupViewModel vm) async {
    final amount = await _amountDialog(context, 'Amount to distribute (Rs)',
        helper: 'Available cash on record: ${formatRs(vm.dashboard?.cash ?? 0)}');
    if (amount != null && context.mounted) {
      await act(context, vm.createDistribution(amount), 'Distribution created. Members confirm when they receive their share.');
    }
  }

  Future<void> _requestExit(BuildContext context, GroupViewModel vm) async {
    final g = vm.info!;
    final reason = TextEditingController();
    final inv = g.investment ?? const {};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request to exit'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Payout rule: ${inv['exit_payout_method'] == 'contribution_back' ? 'you get back what you paid in' : 'your share of the group\'s current value'}'
            '${(inv['lock_in_months'] as num? ?? 0) > 0 ? ', less ${inv['early_exit_penalty_pct']}% during the ${inv['lock_in_months']}-month lock-in' : ''}.'
            '${inv['exit_rule'] != null ? '\n\n${inv['exit_rule']}' : ''}',
          ),
          TextField(controller: reason, maxLength: 500, decoration: const InputDecoration(labelText: 'Reason (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request exit')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await act(context, vm.requestExit(reason: reason.text.trim().isEmpty ? null : reason.text.trim()), 'Exit requested.');
    }
  }

  Future<void> _propose(BuildContext context, GroupViewModel vm) async {
    final g = vm.info!;
    final title = TextEditingController();
    final amount = TextEditingController();
    final holding = TextEditingController();
    final reasoning = TextEditingController();
    final links = TextEditingController();
    final estimate = TextEditingController();
    var type = g.allowedTypes.isNotEmpty ? g.allowedTypes.first : 'fd';
    String? risk;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('New investment proposal', style: cText(18, weight: FontWeight.w700)),
              Text('The group votes on every proposal.', style: cText(12.5, color: AppColors.onGlassMuted)),
              TextField(controller: title, maxLength: 150, decoration: const InputDecoration(labelText: 'Title')),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Investment type'),
                items: [for (final t in g.allowedTypes) DropdownMenuItem(value: t, child: Text(kInvestmentTypeLabels[t] ?? t))],
                onChanged: (v) => setSheet(() => type = v!),
              ),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Rs)')),
              TextField(controller: holding, maxLength: 100, decoration: const InputDecoration(labelText: 'Expected holding period (e.g. 12 months)')),
              const SizedBox(height: 8),
              Text('Risk level (required)', style: cText(13, weight: FontWeight.w700)),
              Wrap(spacing: 6, children: [
                for (final r in kRiskLabels.entries)
                  ChoiceChip(label: Text(r.value), selected: risk == r.key, onSelected: (_) => setSheet(() => risk = r.key)),
              ]),
              TextField(controller: reasoning, maxLines: 4, maxLength: 3000, decoration: const InputDecoration(labelText: 'Why this investment?')),
              TextField(controller: links, decoration: const InputDecoration(labelText: 'Links (optional, comma separated)')),
              TextField(
                controller: estimate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Expected return % (optional)', helperText: 'Estimate — not guaranteed'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit for a vote')),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final value = parseAmount(amount.text);
    if (value == null || risk == null) {
      showResult(context, 'Enter an amount and choose a risk level.');
      return;
    }
    await act(
      context,
      vm.createProposal(
        title: title.text.trim(),
        type: type,
        amount: value,
        risk: risk!,
        reasoning: reasoning.text.trim(),
        holdingPeriod: holding.text.trim().isEmpty ? null : holding.text.trim(),
        links: links.text.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty).take(5).toList(),
        expectedReturnPct: double.tryParse(estimate.text.trim()),
      ),
      'Proposal submitted. The vote is open.',
    );
  }
}

Future<double?> _amountDialog(BuildContext context, String title, {String? helper}) {
  final c = TextEditingController();
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(helperText: helper),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, parseAmount(c.text)), child: const Text('OK')),
      ],
    ),
  );
}

Future<void> _recordInvestment(BuildContext context, GroupViewModel vm, Proposal? proposal) async {
  final g = vm.info!;
  final title = TextEditingController(text: proposal?.title ?? '');
  final amount = TextEditingController(text: proposal?.amount.toStringAsFixed(0) ?? '');
  final details = TextEditingController();
  var type = proposal?.investmentType ?? (g.allowedTypes.isNotEmpty ? g.allowedTypes.first : 'fd');
  var madeOn = DateTime.now();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.deepNavy,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Record an investment made', style: cText(18, weight: FontWeight.w700)),
            Text('Record what the group actually invested, outside the app.', style: cText(12.5, color: AppColors.onGlassMuted)),
            TextField(controller: title, maxLength: 150, decoration: const InputDecoration(labelText: 'Title')),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in g.allowedTypes) DropdownMenuItem(value: t, child: Text(kInvestmentTypeLabels[t] ?? t))],
              onChanged: proposal != null ? null : (v) => setSheet(() => type = v!),
            ),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount invested (Rs)')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date made'),
              subtitle: Text(shortDate(madeOn)),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: madeOn, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setSheet(() => madeOn = d);
              },
            ),
            TextField(controller: details, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Details (bank, reference, maturity…)')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
          ]),
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final value = parseAmount(amount.text);
  if (value == null) return showResult(context, 'Enter the amount invested.');
  await act(
    context,
    vm.recordInvestment(
      title: title.text.trim(),
      type: type,
      amount: value,
      madeOn: madeOn,
      details: details.text.trim().isEmpty ? null : details.text.trim(),
      proposalId: proposal?.id,
    ),
    'Investment recorded.',
  );
}

class _Dashboard extends StatelessWidget {
  final InvestDashboard d;
  final GroupViewModel vm;
  const _Dashboard({required this.d, required this.vm});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, double value, {bool signed = false}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: cText(11.5, color: AppColors.onGlassMuted)),
            Text(
              '${signed && value > 0 ? '+' : ''}${formatRs(value, decimals: 0)}',
              style: cText(14.5,
                  weight: FontWeight.w800,
                  color: !signed ? AppColors.onGlass : (value >= 0 ? AppColors.gain : AppColors.loss)),
            ),
          ]),
        );
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      gradient: AppGradients.heroCard,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [stat('Confirmed pool', d.confirmedPool), stat('Pending pledges', d.pendingPledges)]),
        const SizedBox(height: 10),
        Row(children: [stat('Invested now', d.investedOpen), stat('Current value', d.currentValue)]),
        const SizedBox(height: 10),
        Row(children: [stat('Unrealised P/L', d.unrealisedPl, signed: true), stat('Realised P/L', d.realisedPl, signed: true)]),
        const SizedBox(height: 10),
        Row(children: [stat('Cash on record', d.cash), stat('Distributed', d.distributed)]),
        if (d.members.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Shares', style: cText(13, weight: FontWeight.w700)),
          for (final m in d.members)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(child: Text(m.userId == vm.myId ? 'You' : m.name, style: cText(12.5))),
                Text('${formatRs(m.confirmed, decimals: 0)} · ${m.sharePct.toStringAsFixed(1)}%', style: cText(12.5, weight: FontWeight.w700)),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final Proposal p;
  final GroupViewModel vm;
  const _ProposalCard({required this.p, required this.vm});

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (p.riskLevel) {
      'low' => AppColors.gain,
      'medium' => AppColors.warning,
      _ => AppColors.loss,
    };
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.title, style: cText(14.5, weight: FontWeight.w700))),
          InfoChip(p.status[0].toUpperCase() + p.status.substring(1)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          InfoChip(kInvestmentTypeLabels[p.investmentType] ?? p.investmentType),
          InfoChip(formatRs(p.amount, decimals: 0), color: AppColors.gold),
          InfoChip(kRiskLabels[p.riskLevel] ?? p.riskLevel, icon: Icons.warning_amber_rounded, color: riskColor),
          if (p.holdingPeriod != null) InfoChip(p.holdingPeriod!),
        ]),
        const SizedBox(height: 8),
        Text(p.reasoning, style: cText(13, height: 1.4)),
        if (p.expectedReturnPct != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Expected return ${p.expectedReturnPct!.toStringAsFixed(1)}% — estimate, not guaranteed',
                style: cText(12, color: AppColors.warning)),
          ),
        for (final l in p.links) Text(l, style: cText(12, color: AppColors.accentCyan)),
        Text('Proposed by ${vm.nameOf(p.createdBy)}', style: cText(11.5, color: AppColors.onGlassFaint)),
        Wrap(spacing: 4, children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                title: 'FinBot review',
                seedContext: 'a group investment proposal',
                initialPrompt: 'Please give me a neutral review of this group investment proposal: the pros, the cons and '
                    'the main risks, and what questions our group should ask before voting. Don\'t tell us what to do.\n\n'
                    '${p.toFinBotBrief()}',
              ),
            )),
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: const Text('Ask FinBot to review'),
          ),
          if (p.status == 'approved' && vm.canConfirmMoney)
            TextButton(onPressed: () => _recordInvestment(context, vm, p), child: const Text('Record as invested')),
          if ((p.status == 'voting' || p.status == 'approved') && (p.createdBy == vm.myId || vm.isOfficer))
            TextButton(onPressed: () => act(context, vm.withdrawProposal(p.id), 'Proposal withdrawn.'), child: const Text('Withdraw')),
        ]),
      ]),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  final GroupInvestment i;
  final GroupViewModel vm;
  const _InvestmentCard({required this.i, required this.vm});

  @override
  Widget build(BuildContext context) {
    final profit = i.profit;
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(i.title, style: cText(14.5, weight: FontWeight.w700))),
          InfoChip(i.isOpen ? 'Open' : 'Closed', color: i.isOpen ? AppColors.accentCyan : AppColors.onGlassFaint),
        ]),
        Text('${kInvestmentTypeLabels[i.investmentType] ?? i.investmentType} · ${shortDate(i.madeOn)} · '
            '${i.approvedVia == 'vote' ? 'approved by vote' : 'leader decision under the limit'}',
            style: cText(12, color: AppColors.onGlassMuted)),
        const SizedBox(height: 6),
        Text(
          'Invested ${formatRs(i.amountInvested, decimals: 0)} · ${i.isOpen ? 'now' : 'closed at'} ${formatRs(i.isOpen ? i.currentValue : (i.closingValue ?? 0), decimals: 0)}'
          '${i.incomeTotal > 0 ? ' · income ${formatRs(i.incomeTotal, decimals: 0)}' : ''}',
          style: cText(13),
        ),
        Text('${profit >= 0 ? '+' : ''}${formatRs(profit, decimals: 0)}',
            style: cText(13, weight: FontWeight.w700, color: profit >= 0 ? AppColors.gain : AppColors.loss)),
        if (i.details != null) Text(i.details!, style: cText(12, color: AppColors.onGlassMuted)),
        if (i.isOpen && vm.canConfirmMoney)
          Wrap(spacing: 4, children: [
            for (final k in const [('value', 'Update value'), ('income', 'Record income'), ('close', 'Close / sold')])
              TextButton(
                onPressed: () async {
                  final amount = await _amountDialog(context, '${k.$2} (Rs)');
                  if (amount != null && context.mounted) await act(context, vm.recordUpdate(i.id, k.$1, amount), 'Recorded.');
                },
                child: Text(k.$2),
              ),
          ]),
      ]),
    );
  }
}
