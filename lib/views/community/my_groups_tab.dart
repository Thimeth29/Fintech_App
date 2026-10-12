import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/community_models.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'create_group_screen.dart';
import 'group/group_screen.dart';
import 'group_preview_screen.dart';
import 'widgets/community_widgets.dart';

class MyGroupsTab extends StatelessWidget {
  const MyGroupsTab({super.key});

  Future<void> _open(BuildContext context, String groupId, {GroupInvite? invite}) async {
    final vm = context.read<CommunityViewModel>();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => invite == null
          ? GroupScreen(groupId: groupId, community: vm)
          : ChangeNotifierProvider.value(value: vm, child: GroupPreviewScreen(groupId: groupId, invite: invite)),
    ));
    vm.refreshGroups();
  }

  Future<void> _create(BuildContext context) async {
    final vm = context.read<CommunityViewModel>();
    if (!vm.hasProfile) {
      showResult(context, 'Set up your community profile (My Profile tab) first.');
      return;
    }
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
    if (id == null || !context.mounted) return;
    await vm.refreshGroups();
    if (context.mounted) await _open(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityViewModel>();
    final investment = vm.myGroups.where((g) => !g.isSeettu).toList();
    final seettu = vm.myGroups.where((g) => g.isSeettu).toList();

    return RefreshIndicator(
      onRefresh: vm.refreshGroups,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          if (vm.invites.isNotEmpty) ...[
            SectionTitle('Invites (${vm.invites.length})'),
            for (final i in vm.invites)
              GlassCard(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                borderRadius: 18,
                borderColor: AppColors.accentCyan.withValues(alpha: 0.5),
                onTap: () => _open(context, i.groupId, invite: i),
                child: Row(children: [
                  const Icon(Icons.mail_outline_rounded, color: AppColors.accentCyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.summary?.name ?? 'Group invite', style: cText(14.5, weight: FontWeight.w700)),
                      Text(
                        i.summary == null
                            ? 'Tap to see the group'
                            : '${i.summary!.isSeettu ? 'Seettu' : 'Investment group'} · ${i.summary!.memberCount}/${i.summary!.maxMembers} members',
                        style: cText(12, color: AppColors.onGlassMuted),
                      ),
                    ]),
                  ),
                  Text('Review', style: cText(13, weight: FontWeight.w700, color: AppColors.accentCyan)),
                ]),
              ),
            const SizedBox(height: 8),
          ],
          if (vm.myGroups.isEmpty)
            const EmptyState(
              icon: Icons.groups_2_outlined,
              title: 'You\'re not in any groups yet',
              body: 'Find an investment group or seettu in Discover, or accept an invite from a connection.',
            )
          else ...[
            if (investment.isNotEmpty) ...[
              const SectionTitle('Investment groups'),
              for (final g in investment) _GroupTile(group: g, onTap: () => _open(context, g.id)),
              const SizedBox(height: 8),
            ],
            if (seettu.isNotEmpty) ...[
              const SectionTitle('Seettu groups'),
              for (final g in seettu) _GroupTile(group: g, onTap: () => _open(context, g.id)),
            ],
          ],
          const SizedBox(height: 12),
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            onTap: () => _create(context),
            borderColor: AppColors.accentCyan.withValues(alpha: 0.5),
            child: Row(children: [
              const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Start a group', style: cText(14.5, weight: FontWeight.w700)),
                  Text('Run a seettu or an investment group. You\'ll be the leader.',
                      style: cText(12, color: AppColors.onGlassMuted)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.accentCyan),
            ]),
          ),
          const RecordKeepingFooter(),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final MyGroup group;
  final VoidCallback onTap;
  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final color = g.isSeettu ? AppColors.gold : AppColors.accentLavender;
    final status = switch (g.status) {
      'forming' => 'Forming',
      'active' => 'Active',
      _ => 'Closed',
    };
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(13)),
          child: Icon(g.isSeettu ? Icons.autorenew_rounded : Icons.groups_rounded, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: cText(14.5, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text('${kRoleLabels[g.role] ?? g.role} · $status', style: cText(12, color: AppColors.onGlassMuted)),
          ]),
        ),
        if (g.unread > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accentCyan, borderRadius: BorderRadius.circular(10)),
            child: Text('${g.unread}', style: cText(11.5, weight: FontWeight.w700, color: AppColors.onLight)),
          ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.onGlassMuted),
      ]),
    );
  }
}
