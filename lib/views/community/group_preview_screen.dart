import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'group/group_screen.dart';
import 'widgets/community_widgets.dart';

/// A group's summary. Non-members read the rules and ask to join (or
/// answer an invite); members see who's in it and can leave or report.
/// Pops `true` when the user joined or sent a request.
class GroupPreviewScreen extends StatefulWidget {
  final String groupId;
  final GroupInvite? invite;
  const GroupPreviewScreen({super.key, required this.groupId, this.invite});

  @override
  State<GroupPreviewScreen> createState() => _GroupPreviewScreenState();
}

class _GroupPreviewScreenState extends State<GroupPreviewScreen> {
  GroupSummary? _summary;
  List<GroupMember> _members = const [];
  bool _loading = true;
  String? _error;
  bool _acceptedRules = false;
  bool _busy = false;
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final community = context.read<CommunityViewModel>();
    final service = community.service;
    try {
      final s = await service.groupSummary(widget.groupId);
      if ((s?.isMember ?? false) && widget.invite == null && mounted) {
        // Members get the full group screen.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GroupScreen(groupId: widget.groupId, community: community),
        ));
        return;
      }
      final members = (s?.isMember ?? false) ? await service.members(widget.groupId) : const <GroupMember>[];
      if (mounted) {
        setState(() {
          _summary = s;
          _members = members;
        });
      }
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final vm = context.read<CommunityViewModel>();
    if (!vm.hasProfile) {
      showResult(context, 'Set up your community profile (My Profile tab) first.');
      return;
    }
    setState(() => _busy = true);
    final message = _message.text.trim().isEmpty ? null : _message.text.trim();
    final error = widget.invite != null
        ? await vm.respondInvite(widget.invite!, true)
        : await vm.requestJoin(widget.groupId, message: message);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, error, widget.invite != null ? 'Invite accepted.' : 'Request sent to the leader.');
    if (error == null) Navigator.pop(context, true);
  }

  Future<void> _declineInvite() async {
    final vm = context.read<CommunityViewModel>();
    final error = await vm.respondInvite(widget.invite!, false);
    if (!mounted) return;
    showResult(context, error, 'Invite declined.');
    if (error == null) Navigator.pop(context, false);
  }

  Future<void> _leave() async {
    final vm = context.read<CommunityViewModel>();
    final s = _summary!;
    if (!await confirmAction(context, 'Leave ${s.name}?',
        'Your records stay in the group\'s history. You\'d need to ask again to rejoin.', confirm: 'Leave')) {
      return;
    }
    final error = await vm.leaveGroup(s.id);
    if (!mounted) return;
    showResult(context, error, 'You left ${s.name}.');
    if (error == null) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return GradientScaffold(
      maxContentWidth: 720,
      appBar: TopNavBar(
        current: AppSection.community,
        title: s?.name ?? 'Group',
        showBackButton: true,
        isSectionRoot: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppSection.community, isSectionRoot: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2))
          : s == null
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  EmptyState(
                    icon: Icons.group_off_rounded,
                    title: 'Group not available',
                    body: _error ?? 'This group is private, closed or no longer exists.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _overview(s),
                    const SizedBox(height: 12),
                    _terms(s),
                    if (s.warnings.isNotEmpty) ...[const SizedBox(height: 12), _warnings(s)],
                    const SizedBox(height: 12),
                    _rules(s),
                    const SizedBox(height: 12),
                    if (s.isMember) ..._memberSection(s) else _joinSection(s),
                    const RecordKeepingFooter(),
                  ],
                ),
    );
  }

  Widget _overview(GroupSummary s) {
    final color = s.isSeettu ? AppColors.gold : AppColors.accentLavender;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      gradient: AppGradients.heroCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(s.isSeettu ? Icons.autorenew_rounded : Icons.groups_rounded, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(s.name, style: cText(20, weight: FontWeight.w800))),
          ]),
          const SizedBox(height: 6),
          Text(
            '${s.isSeettu ? 'Seettu' : 'Investment group'} · led by ${s.leaderName ?? 'a member'} · ${s.memberCount}/${s.maxMembers} members',
            style: cText(13, color: AppColors.onGlassMuted),
          ),
          if (s.description != null) ...[
            const SizedBox(height: 10),
            Text(s.description!, style: cText(13.5, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _terms(GroupSummary s) {
    final rows = <(String, String)>[];
    final st = s.seettu;
    final inv = s.investment;
    if (st != null) {
      final contribution = (st['contribution'] as num).toDouble();
      rows.addAll([
        ('Contribution', '${formatRs(contribution)} ${st['frequency']}'),
        ('Pot each round', formatRs(contribution * s.maxMembers)),
        ('Rounds', '${s.maxMembers}'),
        ('Starts', '${st['start_date']}'),
        ('Payout order', switch (st['payout_method']) {
          'agreed' => 'Agreed order',
          'random' => 'Random draw',
          _ => 'Bidding (auction)',
        }),
        if (st['late_fee'] != null) ('Late fee (recorded only)', formatRs((st['late_fee'] as num).toDouble())),
      ]);
    }
    if (inv != null) {
      final minC = (inv['min_contribution'] as num?)?.toDouble();
      final maxC = (inv['max_contribution'] as num?)?.toDouble();
      rows.addAll([
        if (inv['purpose'] != null) ('Purpose', '${inv['purpose']}'),
        if (inv['target_amount'] != null) ('Target', formatRs((inv['target_amount'] as num).toDouble())),
        ('Contribution', [if (minC != null) 'from ${formatRs(minC)}', if (maxC != null) 'up to ${formatRs(maxC)}'].join(' ')),
        ('Invests in', ((inv['allowed_types'] as List?) ?? const []).map((t) => kInterestLabels[t] ?? t).join(', ')),
        ('Risk accepted', '${inv['risk_level']}'.toUpperCase()),
        ('Profit split', inv['distribution_rule'] == 'equal' ? 'Equal split' : 'Pro-rata to contribution'),
        ('Lock-in', (inv['lock_in_months'] as num? ?? 0) == 0 ? 'None' : '${inv['lock_in_months']} months'),
      ]);
    }
    rows.addAll([
      ('Joining', s.joinApproval == 'vote' ? 'Members vote' : 'Leader approves'),
      ('Voting', s.votingMethod == 'weighted' ? 'Weighted by contribution' : 'One member, one vote'),
    ]);
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 140, child: Text(r.$1, style: cText(13, color: AppColors.onGlassMuted))),
                Expanded(child: Text(r.$2, style: cText(13, weight: FontWeight.w600))),
              ]),
            ),
          if (inv != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Returns are never guaranteed. Group investments can lose money.',
                  style: cText(12, color: AppColors.warning)),
            ),
        ],
      ),
    );
  }

  Widget _warnings(GroupSummary s) => GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        borderColor: AppColors.warning.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Before you join', style: cText(14, weight: FontWeight.w700, color: AppColors.warning)),
            const SizedBox(height: 6),
            for (final w in s.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(child: Text(kGroupWarningText[w] ?? w, style: cText(12.5))),
                ]),
              ),
          ],
        ),
      );

  Widget _rules(GroupSummary s) => GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group rules', style: cText(15, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.innerFill, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '$kRecordKeepingNotice Mobile SAP never holds, collects or invests group money, and no returns are promised.',
                style: cText(12.5, weight: FontWeight.w600, color: AppColors.accentCyan, height: 1.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(s.rules.trim().isEmpty ? 'The leader hasn\'t added any other rules.' : s.rules,
                style: cText(13.5, height: 1.45)),
          ],
        ),
      );

  Widget _joinSection(GroupSummary s) {
    if (s.myRequestStatus == 'pending') {
      return const EmptyState(
        icon: Icons.schedule_rounded,
        title: 'Request sent',
        body: 'You\'ll get a notification when it\'s decided.',
      );
    }
    final canJoin = s.status == 'forming' || (!s.isSeettu && s.status == 'active');
    if (!canJoin || s.memberCount >= s.maxMembers) {
      return const EmptyState(icon: Icons.lock_outline_rounded, title: 'Not taking new members');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _acceptedRules,
          onChanged: (v) => setState(() => _acceptedRules = v ?? false),
          title: Text('I\'ve read and accept the group rules', style: cText(14, weight: FontWeight.w600)),
        ),
        if (widget.invite == null) ...[
          TextField(
            controller: _message,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Message to the leader (optional)'),
          ),
          const SizedBox(height: 4),
          Text('The leader will see your public community profile.', style: cText(12, color: AppColors.onGlassFaint)),
          const SizedBox(height: 10),
        ],
        ElevatedButton(
          onPressed: _acceptedRules && !_busy ? _join : null,
          child: Text(widget.invite != null ? 'Accept invite' : 'Request to join'),
        ),
        if (widget.invite != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _declineInvite, child: const Text('Decline invite')),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showReportSheet(context, context.read<CommunityViewModel>(), groupId: s.id, scam: true),
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18, color: AppColors.loss),
            label: Text('Report suspected scam', style: cText(13, weight: FontWeight.w600, color: AppColors.loss)),
          ),
        ),
      ],
    );
  }

  List<Widget> _memberSection(GroupSummary s) => [
        SectionTitle('Members (${_members.length})'),
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final m in _members)
                ListTile(
                  leading: CommunityAvatar(name: m.displayName, size: 38),
                  title: Text(m.displayName, style: cText(14, weight: FontWeight.w600)),
                  subtitle: m.joinedAt == null
                      ? null
                      : Text('Joined ${shortDate(m.joinedAt!)}', style: cText(12, color: AppColors.onGlassMuted)),
                  trailing: m.role == 'member'
                      ? null
                      : InfoChip(kRoleLabels[m.role] ?? m.role, color: AppColors.accentCyan),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GroupScreen(groupId: s.id, community: context.read<CommunityViewModel>()),
          )),
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: const Text('Open group'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          TextButton.icon(
            onPressed: () => showReportSheet(context, context.read<CommunityViewModel>(), groupId: s.id, scam: true),
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18, color: AppColors.loss),
            label: Text('Report suspected scam', style: cText(13, weight: FontWeight.w600, color: AppColors.loss)),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _leave,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Leave group'),
          ),
        ]),
      ];
}
