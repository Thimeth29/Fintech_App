import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/group_models.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../widgets/community_widgets.dart';

String _left(DateTime deadline) {
  final d = deadline.difference(DateTime.now());
  if (d.isNegative) return 'closed';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m left';
  return '${d.inMinutes}m left';
}

/// Join requests, formal votes and polls.
class GroupDecideTab extends StatelessWidget {
  const GroupDecideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final g = vm.info!;
    final openVotes = vm.votes.where((v) => v.status == 'open').toList();
    final pastVotes = vm.votes.where((v) => v.status != 'open').toList();
    final leaderRequests = vm.joinRequests.where((r) => r.voteId == null).toList();

    return RefreshIndicator(
      onRefresh: vm.loadDecisions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          if (!g.isClosed)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startVoteSheet(context, vm),
                  icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                  label: const Text('Start a vote'),
                ),
              ),
              if (vm.isOfficer) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createPollSheet(context, vm),
                    icon: const Icon(Icons.poll_outlined, size: 18),
                    label: const Text('New poll'),
                  ),
                ),
              ],
            ]),
          if (vm.isOfficer && leaderRequests.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionTitle('Join requests (${leaderRequests.length})'),
            for (final r in leaderRequests)
              GlassCard(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: Row(children: [
                  CommunityAvatar(name: vm.nameOf(r.userId), size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(vm.nameOf(r.userId), style: cText(14, weight: FontWeight.w700)),
                      if (r.message != null) Text('"${r.message}"', style: cText(12, color: AppColors.onGlassMuted)),
                      Text('Accepted the group rules', style: cText(11.5, color: AppColors.onGlassFaint)),
                    ]),
                  ),
                  IconButton.filled(
                    tooltip: 'Approve',
                    onPressed: () => act(context, vm.decideJoin(r.id, true), '${vm.nameOf(r.userId)} joined.'),
                    icon: const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    tooltip: 'Decline',
                    onPressed: () => act(context, vm.decideJoin(r.id, false), 'Request declined.'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 12),
          const SectionTitle('Formal votes'),
          if (openVotes.isEmpty)
            Text('No open votes.', style: cText(13, color: AppColors.onGlassMuted))
          else
            for (final v in openVotes) _VoteCard(vote: v),
          const SizedBox(height: 12),
          const SectionTitle('Polls'),
          if (vm.polls.isEmpty)
            Text('No polls yet.', style: cText(13, color: AppColors.onGlassMuted))
          else
            for (final p in vm.polls) _PollCard(poll: p),
          if (pastVotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SectionTitle('Past votes'),
            for (final v in pastVotes.take(15)) _VoteCard(vote: v),
          ],
        ],
      ),
    );
  }

  Future<void> _startVoteSheet(BuildContext context, GroupViewModel vm) async {
    final g = vm.info!;
    var kind = 'leader_change';
    String? target;
    var method = g.votingMethod == 'weighted' ? 'one_member_one_vote' : 'weighted';
    final title = TextEditingController();
    final reason = TextEditingController();
    final rules = TextEditingController(text: g.rules);
    var joinApproval = g.joinApproval;
    var passThreshold = g.passThreshold;
    final quorum = TextEditingController(text: '${g.quorumPct}');
    final candidates = vm.members.where((m) => m.role != 'leader').toList();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start a vote', style: cText(18, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Votes stay open for ${g.voteHours} hours. Members can change their vote until then.',
                    style: cText(12.5, color: AppColors.onGlassMuted)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'What is it about?'),
                  items: [
                    const DropdownMenuItem(value: 'leader_change', child: Text('Change leader (2/3 of all members)')),
                    const DropdownMenuItem(value: 'member_removal', child: Text('Remove a member')),
                    const DropdownMenuItem(value: 'rule_change', child: Text('Change rules or settings (2/3)')),
                    const DropdownMenuItem(value: 'voting_method', child: Text('Change voting method (2/3)')),
                    if (vm.isOfficer) const DropdownMenuItem(value: 'custom', child: Text('Other group decision')),
                    if (vm.isOfficer) const DropdownMenuItem(value: 'close_group', child: Text('Close the group')),
                  ],
                  onChanged: (v) => setSheet(() {
                    kind = v!;
                    target = null;
                  }),
                ),
                const SizedBox(height: 10),
                if (kind == 'leader_change' || kind == 'member_removal')
                  DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration: InputDecoration(labelText: kind == 'leader_change' ? 'New leader' : 'Member to remove'),
                    items: [
                      for (final m in candidates.where((m) => kind != 'member_removal' || m.userId != vm.myId))
                        DropdownMenuItem(value: m.userId, child: Text(m.name)),
                    ],
                    onChanged: (v) => setSheet(() => target = v),
                  ),
                if (kind == 'member_removal')
                  TextField(controller: reason, maxLength: 300, decoration: const InputDecoration(labelText: 'Reason')),
                if (kind == 'rule_change') ...[
                  TextField(controller: rules, maxLines: 5, maxLength: 4000, decoration: const InputDecoration(labelText: 'Group rules')),
                  DropdownButtonFormField<String>(
                    initialValue: joinApproval,
                    decoration: const InputDecoration(labelText: 'New members'),
                    items: const [
                      DropdownMenuItem(value: 'leader', child: Text('Leader approves')),
                      DropdownMenuItem(value: 'vote', child: Text('Members vote')),
                    ],
                    onChanged: (v) => setSheet(() => joinApproval = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: passThreshold,
                    decoration: const InputDecoration(labelText: 'Ordinary votes pass with'),
                    items: const [
                      DropdownMenuItem(value: 'majority', child: Text('Simple majority')),
                      DropdownMenuItem(value: 'two_thirds', child: Text('Two thirds')),
                    ],
                    onChanged: (v) => setSheet(() => passThreshold = v!),
                  ),
                  TextField(
                    controller: quorum,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quorum (% of members who must vote)'),
                  ),
                ],
                if (kind == 'voting_method')
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'New voting method'),
                    items: const [
                      DropdownMenuItem(value: 'one_member_one_vote', child: Text('One member, one vote')),
                      DropdownMenuItem(value: 'weighted', child: Text('Weighted by contribution')),
                    ],
                    onChanged: (v) => setSheet(() => method = v!),
                  ),
                if (kind == 'custom')
                  TextField(controller: title, maxLength: 200, decoration: const InputDecoration(labelText: 'Question')),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open vote')),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true || !context.mounted) return;

    String voteTitle;
    Map<String, dynamic> subject = {};
    switch (kind) {
      case 'leader_change':
        if (target == null) return showResult(context, 'Choose the new leader.');
        voteTitle = 'Make ${vm.nameOf(target)} the leader';
        subject = {'new_leader': target};
      case 'member_removal':
        if (target == null) return showResult(context, 'Choose a member.');
        voteTitle = 'Remove ${vm.nameOf(target)} from the group';
        subject = {'user_id': target, 'reason': reason.text.trim()};
      case 'rule_change':
        voteTitle = 'Change the group rules and settings';
        subject = {
          if (rules.text.trim() != g.rules.trim()) 'rules': rules.text.trim(),
          if (joinApproval != g.joinApproval) 'join_approval': joinApproval,
          if (passThreshold != g.passThreshold) 'pass_threshold': passThreshold,
          if ((int.tryParse(quorum.text) ?? g.quorumPct) != g.quorumPct) 'quorum_pct': int.tryParse(quorum.text),
        };
      case 'voting_method':
        voteTitle = method == 'weighted' ? 'Weight votes by contribution' : 'Switch to one member, one vote';
        subject = {'method': method};
      case 'close_group':
        voteTitle = 'Close the group';
      default:
        voteTitle = title.text.trim();
    }
    final error = await vm.startVote(kind, voteTitle, subject: subject);
    if (context.mounted) showResult(context, error, 'Vote opened.');
  }

  Future<void> _createPollSheet(BuildContext context, GroupViewModel vm) async {
    final question = TextEditingController();
    final options = [TextEditingController(), TextEditingController()];
    var multiple = false;
    var anonymous = false;
    var hours = 48;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New poll', style: cText(18, weight: FontWeight.w700)),
                Text('Polls are informal. Use a vote for binding decisions.', style: cText(12.5, color: AppColors.onGlassMuted)),
                const SizedBox(height: 10),
                TextField(controller: question, maxLength: 300, decoration: const InputDecoration(labelText: 'Question')),
                for (var i = 0; i < options.length; i++)
                  TextField(controller: options[i], maxLength: 100, decoration: InputDecoration(labelText: 'Option ${i + 1}')),
                if (options.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setSheet(() => options.add(TextEditingController())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add option'),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow more than one choice'),
                  value: multiple,
                  onChanged: (v) => setSheet(() => multiple = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anonymous'),
                  subtitle: const Text('Members see counts but not who voted.'),
                  value: anonymous,
                  onChanged: (v) => setSheet(() => anonymous = v),
                ),
                DropdownButtonFormField<int>(
                  initialValue: hours,
                  decoration: const InputDecoration(labelText: 'Open for'),
                  items: const [
                    DropdownMenuItem(value: 12, child: Text('12 hours')),
                    DropdownMenuItem(value: 24, child: Text('1 day')),
                    DropdownMenuItem(value: 48, child: Text('2 days')),
                    DropdownMenuItem(value: 168, child: Text('1 week')),
                  ],
                  onChanged: (v) => setSheet(() => hours = v!),
                ),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create poll')),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await vm.createPoll(
      question.text.trim(),
      options.map((o) => o.text.trim()).where((o) => o.isNotEmpty).toList(),
      multiple: multiple,
      anonymous: anonymous,
      deadline: DateTime.now().add(Duration(hours: hours)),
    );
    if (context.mounted) showResult(context, error, 'Poll created.');
  }
}

class _VoteCard extends StatelessWidget {
  final GroupVote vote;
  const _VoteCard({required this.vote});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<GroupViewModel>();
    final v = vote;
    final aboutMe = v.subject['user_id'] == vm.myId && (v.kind == 'member_removal' || v.kind == 'exit');
    final statusColor = switch (v.status) {
      'passed' => AppColors.gain,
      'failed' => AppColors.loss,
      'cancelled' => AppColors.onGlassFaint,
      _ => AppColors.accentCyan,
    };
    final counts = {'yes': 0, 'no': 0, 'abstain': 0};
    for (final c in v.ballots.values) {
      counts[c] = (counts[c] ?? 0) + 1;
    }

    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      borderColor: v.isOpen ? AppColors.accentCyan.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InfoChip(kVoteKindLabels[v.kind] ?? v.kind),
            const Spacer(),
            Text(v.status == 'open' ? _left(v.deadline) : v.status.toUpperCase(),
                style: cText(12, weight: FontWeight.w700, color: statusColor)),
          ]),
          const SizedBox(height: 8),
          Text(v.title, style: cText(15, weight: FontWeight.w700)),
          if (v.description != null) ...[
            const SizedBox(height: 4),
            Text(v.description!, style: cText(12.5, color: AppColors.onGlassMuted)),
          ],
          const SizedBox(height: 6),
          Text(v.ruleText, style: cText(11.5, color: AppColors.onGlassFaint)),
          const SizedBox(height: 8),
          if (v.status == 'open')
            Text('So far: ${counts['yes']} yes · ${counts['no']} no · ${counts['abstain']} abstain (${v.ballots.length} of ${vm.members.length} voted)',
                style: cText(12.5))
          else
            Text(
              'Result: yes ${formatWeight(v.yes, v.method)} · no ${formatWeight(v.no, v.method)} · abstain ${v.abstain ?? 0}'
              '${v.resultNote != null ? '\n${v.resultNote}' : ''}',
              style: cText(12.5),
            ),
          if (v.isOpen && !aboutMe) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final c in const ['yes', 'no', 'abstain'])
                ChoiceChip(
                  label: Text(c[0].toUpperCase() + c.substring(1)),
                  selected: v.myChoice == c,
                  onSelected: (_) => act(context, vm.castVote(v.id, c), 'Your vote is recorded. You can change it until the deadline.'),
                ),
            ]),
          ],
          if (aboutMe && v.isOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('You can\'t vote on a decision about yourself.', style: cText(12, color: AppColors.onGlassMuted)),
            ),
          if (v.awaitingClose)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => act(context, vm.closeVote(v.id), 'Vote closed.'),
                child: const Text('Count the votes'),
              ),
            ),
        ],
      ),
    );
  }

  static String formatWeight(double? w, String method) {
    if (w == null) return '0';
    return method == 'weighted' && w > 1 ? formatRs(w, decimals: 0) : w.toStringAsFixed(0);
  }
}

class _PollCard extends StatefulWidget {
  final Poll poll;
  const _PollCard({required this.poll});

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  late Set<String> _selected = {...widget.poll.myChoices};

  @override
  void didUpdateWidget(covariant _PollCard old) {
    super.didUpdateWidget(old);
    if (old.poll.myChoices.length != widget.poll.myChoices.length ||
        !old.poll.myChoices.containsAll(widget.poll.myChoices)) {
      _selected = {...widget.poll.myChoices};
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<GroupViewModel>();
    final p = widget.poll;
    final total = p.totalVotes;
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InfoChip(p.anonymous ? 'Anonymous poll' : 'Poll', icon: Icons.poll_outlined),
            if (p.multipleChoice) ...[const SizedBox(width: 6), const InfoChip('Multiple choice')],
            const Spacer(),
            Text(p.isOpen ? _left(p.deadline) : 'CLOSED',
                style: cText(12, weight: FontWeight.w700, color: p.isOpen ? AppColors.accentCyan : AppColors.onGlassFaint)),
          ]),
          const SizedBox(height: 8),
          Text(p.question, style: cText(15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final o in p.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: !p.isOpen
                    ? null
                    : () => setState(() {
                          if (p.multipleChoice) {
                            _selected.contains(o.id) ? _selected.remove(o.id) : _selected.add(o.id);
                          } else {
                            _selected = {o.id};
                          }
                        }),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _selected.contains(o.id) ? AppColors.accentCyan : AppColors.glassBorder),
                    color: AppColors.innerFill,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(
                        _selected.contains(o.id)
                            ? (p.multipleChoice ? Icons.check_box_rounded : Icons.radio_button_checked_rounded)
                            : (p.multipleChoice ? Icons.check_box_outline_blank_rounded : Icons.radio_button_off_rounded),
                        size: 18,
                        color: AppColors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o.label, style: cText(13.5))),
                      Text('${o.votes}', style: cText(13, weight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : o.votes / total,
                        minHeight: 5,
                        backgroundColor: AppColors.glassBorder,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accentCyan),
                      ),
                    ),
                    if (!p.anonymous && o.voterIds.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(o.voterIds.map(vm.nameOf).join(', '), style: cText(11, color: AppColors.onGlassFaint)),
                    ],
                  ]),
                ),
              ),
            ),
          if (p.isOpen)
            Row(children: [
              ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => act(context, vm.votePoll(p.id, _selected.toList()), 'Vote saved.'),
                child: Text(p.myChoices.isEmpty ? 'Vote' : 'Change vote'),
              ),
              const Spacer(),
              if (p.createdBy == vm.myId || vm.isOfficer)
                TextButton(
                  onPressed: () => act(context, vm.closePoll(p.id), 'Poll closed.'),
                  child: const Text('Close poll'),
                ),
            ]),
        ],
      ),
    );
  }
}
