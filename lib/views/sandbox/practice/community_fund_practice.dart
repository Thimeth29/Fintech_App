// Community fund: a simulated seettu. The user joins a circle of simulated
// members, pays every round, and takes the pot on their turn. Members who
// already took their pot may stop paying — more often among strangers.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/sandbox_models.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../widgets/fast_forward_sheet.dart';
import '../widgets/sandbox_widgets.dart';

class CommunityFundPractice extends StatefulWidget {
  const CommunityFundPractice({super.key});

  @override
  State<CommunityFundPractice> createState() => _CommunityFundPracticeState();
}

class _CommunityFundPracticeState extends State<CommunityFundPractice> {
  final _name = TextEditingController(text: 'Office seettu');
  final _amount = TextEditingController(text: '5,000');
  int _members = kSeettuMemberOptions[1];
  int _turn = 3;
  String _trust = 'known';
  bool _compare = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _join(SandboxViewModel vm) async {
    final c = parseAmount(_amount.text);
    if (c == null || c < kSeettuMinContribution || c > kSeettuMaxContribution) {
      setState(() => _error = 'Choose a contribution between ${formatRs(kSeettuMinContribution, decimals: 0)} '
          'and ${formatRs(kSeettuMaxContribution, decimals: 0)}.');
      return;
    }
    setState(() => _error = null);
    final res = await vm.joinCircle(
      name: _name.text.trim().isEmpty ? 'Seettu' : _name.text.trim(),
      members: _members,
      contribution: c,
      myTurn: _turn,
      trust: _trust,
    );
    if (!mounted) return;
    if (res.ok) {
      sandboxSnack(context, _turn == 1 ? 'Joined, and the first pot is yours' : 'Joined: round 1 paid');
    } else {
      setState(() => _error = res.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    const m = SandboxModule.communityFund;
    final contribution = parseAmount(_amount.text) ?? 0;
    if (_turn > _members) _turn = _members;
    final pot = contribution * _members;
    final today = vm.simDate(m);
    final potDate = SeettuEngine.roundDate(today, _turn);
    final committed = SeettuEngine.committed(vm.openCircles);
    final affordable = contribution > 0 && vm.canJoinCircle(members: _members, contribution: contribution);
    final open = vm.openCircles;
    final done = vm.circles.where((c) => c.status == 'completed').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Cash: ${formatRs(vm.balance(m))}', style: sbText(15, weight: FontWeight.w700))),
            const SimulatedLabel(compact: true),
          ],
        ),
        if (committed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${formatRs(committed)} still owed to your circles',
                style: sbText(12, color: AppColors.onGlassMuted)),
          ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join a seettu', style: sbText(16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Everyone pays each month; one member takes the pot. Simulated members, virtual money.',
                  style: sbText(12, color: AppColors.onGlassMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Name', counterText: ''),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Each member pays per month (Rs)'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              Text('Members', style: sbText(13, weight: FontWeight.w600, color: AppColors.onGlassMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in kSeettuMemberOptions)
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _members == n,
                      onSelected: (_) => setState(() => _members = n),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Your turn for the pot: round $_turn of $_members',
                  style: sbText(13, weight: FontWeight.w600, color: AppColors.onGlassMuted)),
              Slider(
                value: _turn.toDouble(),
                min: 1,
                max: _members.toDouble(),
                divisions: _members - 1,
                label: 'Round $_turn',
                onChanged: (v) => setState(() => _turn = v.round()),
              ),
              Text('Who are you saving with?', style: sbText(13, weight: FontWeight.w600, color: AppColors.onGlassMuted)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'known', label: Text('People I know')),
                  ButtonSegment(value: 'strangers', label: Text('Strangers online')),
                ],
                selected: {_trust},
                onSelectionChanged: (v) => setState(() => _trust = v.first),
              ),
              const SizedBox(height: 6),
              Text(
                _trust == 'known'
                    ? 'Friends, family or colleagues you can find. A member rarely stops paying.'
                    : 'Riskier: about a ${(kSeettuDefaultChance['strangers']! * 100).round()}% chance someone takes '
                        'their pot and stops paying.',
                style: sbText(12, color: _trust == 'known' ? AppColors.onGlassFaint : AppColors.warning),
              ),
              const SizedBox(height: 12),
              TileGrid(children: [
                StatTile(label: 'Pot each round', value: formatRs(pot, decimals: 0)),
                StatTile(label: 'You pay in total', value: formatRs(pot, decimals: 0), sub: '$_members × ${formatRs(contribution, decimals: 0)}'),
                StatTile(label: 'Your pot', value: shortDate(potDate), sub: _turn == 1 ? 'today' : 'round $_turn'),
                StatTile(label: 'Interest', value: 'None', sub: 'you get back what you put in'),
              ]),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  setState(() => _compare = !_compare);
                  if (_compare) vm.markChallengeEvent('cf_compare');
                },
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text('Early turn vs late turn'),
              ),
              if (_compare) _TurnCompare(members: _members, contribution: contribution, fdRate: vm.fdRate('Commercial Bank', 12)),
              if (!affordable && contribution > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'You\'d owe ${formatRs(committed + pot)} across all circles but have ${formatRs(vm.balance(m))}. '
                    'Only join if you can pay every round, even if your pot comes last.',
                    style: sbText(13, weight: FontWeight.w600, color: AppColors.warning),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: sbText(13, weight: FontWeight.w600, color: AppColors.loss)),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.busy || !affordable ? null : () => _join(vm),
                  child: Text('Join and pay round 1 (${formatRs(contribution, decimals: 0)})'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FastForwardBar(module: m, onForward: (d) => runFastForward(context, m, d)),
        const SizedBox(height: 18),
        SectionTitle('Your circles (${open.length})'),
        if (open.isEmpty)
          Text('No circles yet. Join one above, then fast-forward month by month.',
              style: sbText(13, color: AppColors.onGlassMuted)),
        for (final c in open) ...[
          CircleCard(circle: c),
          const SizedBox(height: 8),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionTitle('Finished'),
          for (final c in done.reversed.take(5)) ...[
            CircleCard(circle: c),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _TurnCompare extends StatelessWidget {
  final int members;
  final double contribution;
  final double fdRate;
  const _TurnCompare({required this.members, required this.contribution, required this.fdRate});

  @override
  Widget build(BuildContext context) {
    final pot = contribution * members;
    // Money-months lent (+) or borrowed (−), valued at an FD rate after tax.
    double value(int turn) => (SeettuEngine.averageMonthsLent(members: members, turn: turn) * pot * fdRate / 100 / 12 *
            (1 - kInterestWhtRate))
        .abs();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.innerFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Round 1: the pot now, repaid over $members months',
              style: sbText(13, weight: FontWeight.w700)),
          Text('Like an interest-free loan. A loan would cost interest; an FD at ${fdRate.toStringAsFixed(2)}% '
              'on the same money would earn about ${formatRs(value(1), decimals: 0)}.',
              style: sbText(12, color: AppColors.onGlassMuted, height: 1.35)),
          const SizedBox(height: 8),
          Text('Round $members: you wait for the pot', style: sbText(13, weight: FontWeight.w700)),
          Text('Like saving with no interest. The same savings in an FD could earn about '
              '${formatRs(value(members), decimals: 0)} after tax, and inflation shrinks the pot while you wait.',
              style: sbText(12, color: AppColors.onGlassMuted, height: 1.35)),
        ],
      ),
    );
  }
}

class CircleCard extends StatelessWidget {
  final SandboxCircle circle;
  const CircleCard({super.key, required this.circle});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final c = circle;
    final def = vm.visibleDefault(c);
    final net = SeettuEngine.value(c);
    final round = c.roundsPaid.clamp(0, c.members);
    final potDate = SeettuEngine.roundDate(c.startSimDate, c.myTurn);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_outlined, color: SandboxModule.communityFund.color),
              const SizedBox(width: 10),
              Expanded(child: Text(c.name, style: sbText(15, weight: FontWeight.w700))),
              Text(c.isOpen ? 'Round $round of ${c.members}' : 'Finished', style: sbText(12, color: AppColors.onGlassMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${c.members} members × ${formatRs(c.contribution, decimals: 0)} a month · '
            '${c.trust == 'known' ? 'people you know' : 'strangers'}',
            style: sbText(12, color: AppColors.onGlassMuted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: c.members == 0 ? 0 : round / c.members,
              minHeight: 6,
              color: SandboxModule.communityFund.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.potTaken
                ? 'Your pot: ${formatRs(c.potReceived!, decimals: 0)} on ${shortDate(c.potSimDate ?? potDate)}'
                : 'Your pot: round ${c.myTurn}, ${shortDate(potDate)}',
            style: sbText(13, weight: FontWeight.w600),
          ),
          if (c.isOpen)
            Text(
              net >= 0 ? 'The group owes you ${formatRs(net, decimals: 0)}' : 'You owe the group ${formatRs(-net, decimals: 0)}',
              style: sbText(12, color: AppColors.onGlassMuted),
            ),
          if (def != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'The member who took the round ${def.memberTurn} pot stopped paying. '
                'Every pot from round ${def.fromRound} is ${formatRs(c.contribution, decimals: 0)} smaller.',
                style: sbText(12, weight: FontWeight.w600, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
