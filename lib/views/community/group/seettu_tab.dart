import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/community/community_math.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/group_models.dart';
import '../../../services/community_service.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../widgets/community_widgets.dart';

const _statusLabels = {
  'pending': 'Not paid',
  'marked_paid': 'Marked paid',
  'confirmed': 'Confirmed',
  'late': 'Late',
};

Color _statusColor(String s) => switch (s) {
      'confirmed' => AppColors.gain,
      'marked_paid' => AppColors.accentCyan,
      'late' => AppColors.loss,
      _ => AppColors.onGlassMuted,
    };

class SeettuTab extends StatelessWidget {
  const SeettuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final g = vm.info!;
    return RefreshIndicator(
      onRefresh: vm.loadMoney,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          _Overview(vm: vm),
          const SizedBox(height: 12),
          if (g.status == 'forming') _Setup(vm: vm) else ...[
            if (vm.mustCompletePayments)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.warning.withValues(alpha: 0.6),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('You\'ve received the pot. Keep paying your remaining instalments until the seettu ends.',
                          style: cText(12.5)),
                    ),
                  ]),
                ),
              ),
            _LeaderActions(vm: vm),
            _BiddingPanel(vm: vm),
            const SectionTitle('Rounds'),
            for (final r in vm.rounds) _RoundCard(vm: vm, round: r),
          ],
          const SizedBox(height: 8),
          _ExpenseLink(vm: vm),
          const RecordKeepingFooter(),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final GroupViewModel vm;
  const _Overview({required this.vm});

  @override
  Widget build(BuildContext context) {
    final g = vm.info!;
    final s = g.seettu ?? const {};
    final n = g.maxMembers;
    final pot = seettuPot(g.seettuContribution, n);
    final next = vm.myNextPayment;
    final myPot = vm.myPotRound;
    final rate = vm.onTimeRate;
    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: cText(11.5, color: AppColors.onGlassMuted)),
            const SizedBox(height: 2),
            Text(value, style: cText(14.5, weight: FontWeight.w800)),
          ]),
        );
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      gradient: AppGradients.heroCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatRs(g.seettuContribution)} ${s['frequency']} · $n members · pot ${formatRs(pot)}',
              style: cText(14, weight: FontWeight.w700)),
          Text(
            'Starts ${s['start_date']} · ${switch (g.seettuPayoutMethod) {
              'agreed' => 'agreed order',
              'random' => 'random draw',
              _ => 'bidding (auction)',
            }}',
            style: cText(12.5, color: AppColors.onGlassMuted),
          ),
          if (g.status != 'forming') ...[
            const SizedBox(height: 12),
            Row(children: [
              stat('My next payment',
                  next == null ? 'All paid' : '${formatRs(next.payment.amountDue)} · ${shortDate(next.round.dueDate)}'),
              stat('Paid / owed', '${formatRs(vm.myTotalPaid, decimals: 0)} / ${formatRs(vm.myTotalDue, decimals: 0)}'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              stat('My pot', myPot == null ? 'Not drawn yet' : 'Round ${myPot.roundNo} · ${formatRs(myPot.pot, decimals: 0)}'),
              stat('Group on-time rate', rate == null ? '—' : '${(rate * 100).round()}%'),
            ]),
          ],
          if (s['late_rule'] != null || s['late_fee'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Late payments: ${s['late_rule'] ?? ''}${s['late_fee'] != null ? ' (fee ${formatRs((s['late_fee'] as num).toDouble())}, recorded only)' : ''}',
              style: cText(12, color: AppColors.onGlassMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Setup extends StatelessWidget {
  final GroupViewModel vm;
  const _Setup({required this.vm});

  @override
  Widget build(BuildContext context) {
    final g = vm.info!;
    final confirmed = vm.members.where((m) => m.seettuConfirmed).length;
    final ordered = [...vm.members]..sort((a, b) => (a.payoutPosition ?? 999).compareTo(b.payoutPosition ?? 999));
    final agreed = g.seettuPayoutMethod == 'agreed';
    final orderSet = vm.members.every((m) => m.payoutPosition != null);

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Getting ready', style: cText(15, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          _check('Seats filled: ${vm.members.length} of ${g.maxMembers}', vm.members.length >= g.maxMembers),
          if (agreed) _check('Payout order set', orderSet),
          _check('Members confirmed the terms: $confirmed of ${vm.members.length}', confirmed == vm.members.length),
          if (agreed && orderSet) ...[
            const SizedBox(height: 10),
            Text('Payout order', style: cText(13, weight: FontWeight.w700)),
            for (final m in ordered)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Round ${m.payoutPosition}: ${m.name}', style: cText(13)),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!(vm.me?.seettuConfirmed ?? false))
              ElevatedButton(
                onPressed: () => act(context, vm.confirmSeettu(), 'You confirmed the terms.'),
                child: const Text('Confirm terms & order'),
              ),
            if (vm.isOfficer && agreed)
              OutlinedButton(onPressed: () => _orderSheet(context), child: Text(orderSet ? 'Change order' : 'Set payout order')),
            if (vm.isOfficer)
              OutlinedButton(onPressed: () => _editTerms(context), child: const Text('Edit terms')),
            if (vm.isOfficer)
              FilledButton(
                onPressed: () async {
                  if (await confirmAction(context, 'Start the seettu?',
                      'Rounds and payment schedules are created now and can\'t be changed afterwards.', confirm: 'Start')) {
                    if (context.mounted) await act(context, vm.startSeettu(), 'The seettu has started.');
                  }
                },
                child: const Text('Start seettu'),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _check(String text, bool done) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18, color: done ? AppColors.gain : AppColors.onGlassMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: cText(13))),
        ]),
      );

  Future<void> _orderSheet(BuildContext context) async {
    final order = [...vm.members]..sort((a, b) => (a.payoutPosition ?? 999).compareTo(b.payoutPosition ?? 999));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Drag to set who receives the pot in each round. Everyone confirms again after a change.',
                  style: cText(13, color: AppColors.onGlassMuted)),
            ),
            Expanded(
              child: ReorderableListView(
                onReorderItem: (from, to) => setSheet(() => order.insert(to, order.removeAt(from))),
                children: [
                  for (var i = 0; i < order.length; i++)
                    ListTile(
                      key: ValueKey(order[i].userId),
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(order[i].name),
                      trailing: const Icon(Icons.drag_handle_rounded),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save order')),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await act(context, vm.setOrder(order.map((m) => m.userId).toList()), 'Order saved. Members need to confirm it.');
    }
  }

  Future<void> _editTerms(BuildContext context) async {
    final s = vm.info!.seettu ?? const {};
    final contribution = TextEditingController(text: (s['contribution'] as num?)?.toStringAsFixed(0) ?? '');
    final lateRule = TextEditingController(text: (s['late_rule'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit seettu terms'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: contribution, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Contribution per round (Rs)')),
          TextField(controller: lateRule, maxLines: 2, decoration: const InputDecoration(labelText: 'Late payment rule')),
          const SizedBox(height: 8),
          const Text('Every member will need to confirm the terms again.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await act(
      context,
      vm.updateSeettu({
        if (parseAmount(contribution.text) != null) 'contribution': parseAmount(contribution.text),
        'late_rule': lateRule.text.trim(),
      }),
      'Terms updated.',
    );
  }
}

class _LeaderActions extends StatelessWidget {
  final GroupViewModel vm;
  const _LeaderActions({required this.vm});

  @override
  Widget build(BuildContext context) {
    final g = vm.info!;
    if (!vm.isOfficer || g.status != 'active') return const SizedBox.shrink();
    final unassigned = vm.rounds.where((r) => r.recipientId == null).toList();
    if (unassigned.isEmpty) return const SizedBox.shrink();
    final method = g.seettuPayoutMethod;
    final bidding = vm.rounds.any((r) => r.status == 'bidding');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        if (method == 'random')
          FilledButton.icon(
            onPressed: () => _draw(context),
            icon: const Icon(Icons.casino_rounded, size: 18),
            label: Text(g.seettuDrawMode == 'all' ? 'Draw all rounds' : 'Draw round ${unassigned.first.roundNo}'),
          ),
        if (method == 'bidding' && !bidding)
          FilledButton.icon(
            onPressed: () => act(context, vm.openBidding(), 'Bidding is open.'),
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: Text('Open bidding for round ${unassigned.first.roundNo}'),
          ),
      ]),
    );
  }

  Future<void> _draw(BuildContext context) async {
    List<Map<String, dynamic>> result;
    try {
      result = await vm.service.draw(vm.groupId);
    } on CommunityException catch (e) {
      if (context.mounted) showResult(context, e.message);
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DrawReveal(names: vm.members.map((m) => m.name).toList(), result: result),
    );
    await vm.loadMoney();
  }
}

/// Spins through member names, then reveals the server's draw.
class _DrawReveal extends StatefulWidget {
  final List<String> names;
  final List<Map<String, dynamic>> result;
  const _DrawReveal({required this.names, required this.result});

  @override
  State<_DrawReveal> createState() => _DrawRevealState();
}

class _DrawRevealState extends State<_DrawReveal> {
  final _random = math.Random();
  Timer? _timer;
  String _spinning = '';
  bool _done = false;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      setState(() {
        _spinning = widget.names.isEmpty ? '' : widget.names[_random.nextInt(widget.names.length)];
        if (++_ticks > 18) {
          t.cancel();
          _done = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seettu draw'),
      content: SizedBox(
        width: 320,
        child: _done
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                for (final r in widget.result)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(child: Text('${r['round_no']}')),
                    title: Text('${r['recipient_name']}'),
                  ),
                const SizedBox(height: 6),
                const Text('Drawn on the server and saved in the activity log.'),
              ])
            : SizedBox(
                height: 80,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 80),
                    child: Text(_spinning, key: ValueKey(_ticks), style: cText(22, weight: FontWeight.w800)),
                  ),
                ),
              ),
      ),
      actions: [if (_done) FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    );
  }
}

class _BiddingPanel extends StatelessWidget {
  final GroupViewModel vm;
  const _BiddingPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final round = vm.rounds.where((r) => r.status == 'bidding').firstOrNull;
    if (round == null) return const SizedBox.shrink();
    final received = vm.rounds.any((r) => r.recipientId == vm.myId);
    final myBid = vm.currentBids.where((b) => b.userId == vm.myId).firstOrNull;
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.gold.withValues(alpha: 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bidding for round ${round.roundNo}', style: cText(15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Bid the discount you\'ll accept on the ${formatRs(round.pot)} pot. The biggest discount wins; '
          'it\'s shared as a credit on everyone else\'s instalment. Bids are sealed until bidding closes.',
          style: cText(12.5, color: AppColors.onGlassMuted, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (myBid != null) Text('Your bid: ${formatRs(myBid.discount)} discount', style: cText(13, weight: FontWeight.w700)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!received)
            OutlinedButton(
              onPressed: () async {
                final amount = await _askAmount(context, 'Your discount (Rs)', max: round.pot / 2);
                if (amount != null && context.mounted) await act(context, vm.placeBid(round.id, amount), 'Bid placed.');
              },
              child: Text(myBid == null ? 'Place a bid' : 'Change bid'),
            ),
          if (vm.isOfficer)
            FilledButton(
              onPressed: () => act(context, vm.closeBidding(round.id), 'Bidding closed.'),
              child: const Text('Close bidding'),
            ),
        ]),
      ]),
    );
  }
}

class _RoundCard extends StatelessWidget {
  final GroupViewModel vm;
  final SeettuRound round;
  const _RoundCard({required this.vm, required this.round});

  @override
  Widget build(BuildContext context) {
    final r = round;
    final pays = vm.paymentsFor(r.id)..sort((a, b) => vm.nameOf(a.payerId).compareTo(vm.nameOf(b.payerId)));
    final confirmed = pays.where((p) => p.status == 'confirmed').length;
    final current = vm.currentRound?.id == r.id;
    final isRecipient = r.recipientId == vm.myId;
    final statusText = switch (r.status) {
      'upcoming' => 'Upcoming',
      'bidding' => 'Bidding',
      'collecting' => 'Collecting $confirmed/${pays.length}',
      'handed_over' => 'Pot handed over',
      _ => 'Completed',
    };

    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      borderRadius: 16,
      borderColor: current ? AppColors.accentCyan.withValues(alpha: 0.6) : null,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: current,
          leading: CircleAvatar(
            backgroundColor: r.isDone ? AppColors.gain.withValues(alpha: 0.25) : AppColors.innerFillSelected,
            child: Text('${r.roundNo}', style: cText(13, weight: FontWeight.w700)),
          ),
          title: Text(r.recipientId == null ? 'Recipient not decided' : vm.nameOf(r.recipientId), style: cText(14, weight: FontWeight.w700)),
          subtitle: Text('${shortDate(r.dueDate)} · ${formatRs(r.pot, decimals: 0)}${r.discount > 0 ? ' (discount ${formatRs(r.discount, decimals: 0)})' : ''} · $statusText',
              style: cText(12, color: AppColors.onGlassMuted)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final p in pays) _paymentRow(context, r, p),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.status == 'collecting' && vm.canConfirmMoney && confirmed == pays.length)
                FilledButton(
                  onPressed: () => act(context, vm.handOver(r.id), 'Pot marked as handed over.'),
                  child: const Text('Mark pot handed over'),
                ),
              if (r.status == 'handed_over' && isRecipient)
                FilledButton(
                  onPressed: () => act(context, vm.confirmReceived(r.id), 'Thanks, receipt confirmed.'),
                  child: const Text('I received the pot'),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(BuildContext context, SeettuRound r, SeettuPayment p) {
    final mine = p.payerId == vm.myId;
    final canConfirm = !mine && (vm.canConfirmMoney || r.recipientId == vm.myId) && p.status != 'confirmed' && r.recipientId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vm.nameOf(p.payerId), style: cText(13, weight: FontWeight.w600)),
            Text('${formatRs(p.amountDue)}${p.credit > 0 ? ' (credit ${formatRs(p.credit)})' : ''}',
                style: cText(11.5, color: AppColors.onGlassMuted)),
          ]),
        ),
        InfoChip(_statusLabels[p.status] ?? p.status, color: _statusColor(p.status)),
        if (mine && (p.status == 'pending' || p.status == 'late') && r.recipientId != null)
          TextButton(onPressed: () => act(context, vm.markPaid(p.id), 'Marked as paid. Waiting for confirmation.'), child: const Text('Mark paid')),
        if (canConfirm)
          TextButton(onPressed: () => act(context, vm.confirmPayment(p.id), 'Payment confirmed.'), child: const Text('Confirm')),
      ]),
    );
  }
}

class _ExpenseLink extends StatelessWidget {
  final GroupViewModel vm;
  const _ExpenseLink({required this.vm});

  @override
  Widget build(BuildContext context) {
    final me = vm.me;
    if (me == null) return const SizedBox.shrink();
    final g = vm.info!;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('My expenses', style: cText(14, weight: FontWeight.w700)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Log confirmed payments as expenses', style: cText(13.5)),
          subtitle: Text('Each confirmed instalment is added to Expenditure under "Seettu".', style: cText(11.5, color: AppColors.onGlassMuted)),
          value: me.logPaymentsAsExpenses,
          onChanged: (v) => act(context, vm.setExpenseLink(logPayments: v)),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final s = g.seettu ?? const {};
            final first = seettuDueDate(
              DateTime.tryParse('${s['start_date']}') ?? DateTime.now(),
              '${s['frequency']}',
              (s['due_day'] as num?)?.toInt() ?? 1,
              1,
            );
            final id = await vm.service.addRecurringInstalment(
              groupName: g.name,
              amount: g.seettuContribution,
              frequency: '${s['frequency']}',
              firstDue: first,
            );
            if (!context.mounted) return;
            if (id == null) {
              showResult(context, 'Recurring expenses aren\'t available yet. Turn on the switch above to log payments instead.');
              return;
            }
            await act(context, vm.setExpenseLink(recurringExpenseId: id, logPayments: me.logPaymentsAsExpenses),
                'Added as a recurring essential expense.');
          },
          icon: const Icon(Icons.event_repeat_rounded, size: 18),
          label: const Text('Add instalment to recurring expenses'),
        ),
        const SizedBox(height: 4),
        Text('When you receive the pot, it\'s income, not an expense.', style: cText(11.5, color: AppColors.onGlassFaint)),
      ]),
    );
  }
}

Future<double?> _askAmount(BuildContext context, String label, {double? max}) async {
  final c = TextEditingController();
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(helperText: max == null ? null : 'Up to ${formatRs(max)}'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, parseAmount(c.text)), child: const Text('OK')),
      ],
    ),
  );
  return v;
}
