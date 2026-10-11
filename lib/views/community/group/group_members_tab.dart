import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/community_models.dart';
import '../../../models/group_models.dart';
import '../../../viewmodels/community_viewmodel.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../widgets/community_widgets.dart';

class GroupMembersTab extends StatelessWidget {
  final CommunityViewModel? community;
  const GroupMembersTab({super.key, this.community});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final g = vm.info!;
    final canInvite = !g.isClosed && (g.status == 'forming' || !g.isSeettu) && vm.members.length < g.maxMembers;

    return RefreshIndicator(
      onRefresh: vm.loadMembers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Row(children: [
            Expanded(child: Text('${vm.members.length} of ${g.maxMembers} members', style: cText(14, weight: FontWeight.w700))),
            if (canInvite && community != null)
              TextButton.icon(
                onPressed: () => _invite(context, vm),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Invite'),
              ),
          ]),
          const SizedBox(height: 6),
          for (final m in vm.members) _MemberTile(m: m, vm: vm),
          const SizedBox(height: 14),
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How this group decides', style: cText(14, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '• New members: ${g.joinApproval == 'vote' ? 'members vote' : 'the leader approves'}\n'
                '• Voting: ${g.votingMethod == 'weighted' ? 'weighted by confirmed contribution' : 'one member, one vote'}\n'
                '• Quorum ${g.quorumPct}%, ordinary votes need ${g.passThreshold == 'two_thirds' ? 'two thirds' : 'a simple majority'}\n'
                '• Changing the leader needs 2/3 of all members; rule changes need 2/3 of votes cast\n'
                '• Votes stay open ${g.voteHours} hours',
                style: cText(12.5, color: AppColors.onGlassMuted, height: 1.5),
              ),
              if (vm.isOfficer && !g.isClosed)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => _editDetails(context, vm), child: const Text('Edit group details')),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context, GroupViewModel vm) async {
    final c = community!;
    final memberIds = vm.members.map((m) => m.userId).toSet();
    final friends = c.friends.where((f) => !memberIds.contains(f.userId)).toList();
    if (friends.isEmpty) {
      showResult(context, 'None of your connections are left to invite. Find people in Discover first.');
      return;
    }
    final picked = await showModalBottomSheet<ConnectionEntry>(
      context: context,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Invite a connection', style: cText(17, weight: FontWeight.w700)),
          ),
          for (final f in friends)
            ListTile(
              leading: CommunityAvatar(name: f.displayName, size: 36),
              title: Text(f.displayName),
              subtitle: Text(kExperienceLabels[f.experience] ?? ''),
              onTap: () => Navigator.pop(ctx, f),
            ),
        ]),
      ),
    );
    if (picked != null && context.mounted) {
      await act(context, c.inviteToGroup(vm.groupId, picked.userId), 'Invited ${picked.displayName}.');
    }
  }

  Future<void> _editDetails(BuildContext context, GroupViewModel vm) async {
    final g = vm.info!;
    final description = TextEditingController(text: g.description ?? '');
    var discoverable = g.discoverable;
    String? district = g.district;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Group details'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: description, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Description')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show in Discover'),
                subtitle: const Text('Off: invite only'),
                value: discoverable,
                onChanged: (v) => setD(() => discoverable = v),
              ),
              DropdownButtonFormField<String?>(
                initialValue: district,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'District'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Not shown')),
                  for (final d in kSriLankaDistricts) DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => setD(() => district = v),
              ),
              const SizedBox(height: 8),
              Text('Rules and voting settings change by a group vote (Decide tab).', style: cText(12, color: AppColors.onGlassMuted)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await act(
      context,
      vm.updateDetails(description: description.text.trim(), discoverable: discoverable, district: district ?? ''),
      'Details saved.',
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Member m;
  final GroupViewModel vm;
  const _MemberTile({required this.m, required this.vm});

  @override
  Widget build(BuildContext context) {
    final isMe = m.userId == vm.myId;
    final canManage = vm.isOfficer && !isMe && m.role != 'leader' && !(vm.info?.isClosed ?? true);
    final contribution = vm.dashboard?.members.where((x) => x.userId == m.userId).firstOrNull;
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      borderRadius: 16,
      child: Row(children: [
        CommunityAvatar(name: m.name, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMe ? '${m.name} (you)' : m.name, style: cText(14, weight: FontWeight.w700)),
            Text(
              [
                if (m.joinedAt != null) 'Joined ${shortDate(m.joinedAt!)}',
                if (vm.info!.isSeettu && m.payoutPosition != null) 'Round ${m.payoutPosition}',
                if (contribution != null) '${formatRs(contribution.confirmed, decimals: 0)} (${contribution.sharePct.toStringAsFixed(1)}%)',
              ].join(' · '),
              style: cText(12, color: AppColors.onGlassMuted),
            ),
          ]),
        ),
        if (m.role != 'member') InfoChip(kRoleLabels[m.role] ?? m.role, color: AppColors.accentCyan),
        if (canManage)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.onGlass),
            onSelected: (v) async {
              switch (v) {
                case 'co_leader':
                case 'treasurer':
                case 'member':
                  await act(context, vm.setRole(m.userId, v), 'Role updated.');
                case 'leader':
                  if (await confirmAction(context, 'Make ${m.name} the leader?', 'You become a co-leader.', confirm: 'Transfer')) {
                    if (context.mounted) await act(context, vm.transferLeadership(m.userId), '${m.name} is now the leader.');
                  }
                case 'remove':
                  final reason = await _reason(context, m.name);
                  if (reason != null && context.mounted) {
                    await act(context, vm.removeMember(m.userId, reason), '${m.name} was removed.');
                  }
              }
            },
            itemBuilder: (_) => [
              if (m.role != 'co_leader') const PopupMenuItem(value: 'co_leader', child: Text('Make co-leader')),
              if (!vm.info!.isSeettu && m.role != 'treasurer') const PopupMenuItem(value: 'treasurer', child: Text('Make treasurer')),
              if (m.role != 'member') const PopupMenuItem(value: 'member', child: Text('Make regular member')),
              if (vm.isLeader) const PopupMenuItem(value: 'leader', child: Text('Make leader')),
              const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
            ],
          ),
      ]),
    );
  }

  Future<String?> _reason(BuildContext context, String name) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $name?'),
        content: TextField(
          controller: c,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Reason (recorded and shared with members)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim().length >= 3 ? c.text.trim() : null),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
