import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/community_models.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'person_sheet.dart';
import 'widgets/community_widgets.dart';

class ConnectionsTab extends StatefulWidget {
  const ConnectionsTab({super.key});

  @override
  State<ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<ConnectionsTab> {
  String _filter = '';
  bool _showBlocked = false;

  Future<void> _act(Future<String?> future, String success) async {
    final error = await future;
    if (mounted) showResult(context, error, success);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityViewModel>();
    final friends = vm.friends.where((c) => c.displayName.toLowerCase().contains(_filter.toLowerCase())).toList();

    return RefreshIndicator(
      onRefresh: vm.refreshConnections,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          if (vm.received.isNotEmpty) ...[
            SectionTitle('Requests for you (${vm.received.length})'),
            for (final c in vm.received)
              _ConnectionTile(
                entry: c,
                onTap: () => showPersonSheet(context, vm, c.userId),
                actions: [
                  IconButton.filled(
                    tooltip: 'Accept',
                    onPressed: () => _act(vm.respond(c, true), 'You\'re now connected with ${c.displayName}.'),
                    icon: const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    tooltip: 'Decline',
                    onPressed: () => _act(vm.respond(c, false), 'Request declined.'),
                    icon: const Icon(Icons.close_rounded, color: AppColors.onGlassMuted),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
          if (vm.sent.isNotEmpty) ...[
            SectionTitle('Sent (${vm.sent.length})'),
            for (final c in vm.sent)
              _ConnectionTile(
                entry: c,
                onTap: () => showPersonSheet(context, vm, c.userId),
                actions: [
                  TextButton(
                    onPressed: () => _act(vm.cancelRequest(c), 'Request cancelled.'),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
          SectionTitle('Connections (${vm.friends.length})'),
          if (vm.friends.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                decoration: const InputDecoration(hintText: 'Search connections', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
          if (vm.friends.isEmpty)
            const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No connections yet',
              body: 'Find people in Discover and send a connection request. Connections can see each other\'s phone number and invite each other to groups.',
            )
          else
            for (final c in friends)
              _ConnectionTile(
                entry: c,
                onTap: () => showPersonSheet(context, vm, c.userId),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.onGlass),
                    onSelected: (v) async {
                      switch (v) {
                        case 'invite':
                          await pickGroupAndInvite(context, vm, c.userId, c.displayName);
                        case 'remove':
                          if (await confirmAction(context, 'Remove ${c.displayName}?', 'They won\'t be notified.',
                              confirm: 'Remove')) {
                            await _act(vm.removeConnection(c.userId), 'Connection removed.');
                          }
                        case 'block':
                          if (await confirmAction(context, 'Block ${c.displayName}?',
                              'You\'ll stop seeing each other in search and this connection is removed.',
                              confirm: 'Block')) {
                            await _act(vm.block(c.userId), '${c.displayName} is blocked.');
                          }
                        case 'report':
                          if (context.mounted) await showReportSheet(context, vm, userId: c.userId);
                      }
                    },
                    itemBuilder: (_) => [
                      if (vm.myGroups.any((g) => g.status != 'closed'))
                        const PopupMenuItem(value: 'invite', child: Text('Invite to a group')),
                      const PopupMenuItem(value: 'remove', child: Text('Remove connection')),
                      const PopupMenuItem(value: 'block', child: Text('Block')),
                      const PopupMenuItem(value: 'report', child: Text('Report')),
                    ],
                  ),
                ],
              ),
          if (vm.blocked.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _showBlocked = !_showBlocked),
              child: SectionTitle(
                'Blocked (${vm.blocked.length})',
                trailing: Icon(_showBlocked ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.onGlassMuted),
              ),
            ),
            if (_showBlocked)
              for (final b in vm.blocked)
                GlassCard(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  borderRadius: 16,
                  child: Row(children: [
                    const Icon(Icons.block_rounded, color: AppColors.onGlassFaint, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b.displayName, style: cText(14, weight: FontWeight.w600))),
                    TextButton(
                      onPressed: () => _act(vm.unblock(b.userId), '${b.displayName} is unblocked.'),
                      child: const Text('Unblock'),
                    ),
                  ]),
                ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final ConnectionEntry entry;
  final List<Widget> actions;
  final VoidCallback onTap;
  const _ConnectionTile({required this.entry, required this.actions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = entry;
    final details = [
      if (c.experience != null) kExperienceLabels[c.experience] ?? c.experience!,
      if (c.district != null) c.district!,
    ].join(' · ');
    return GlassCard(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      onTap: onTap,
      child: Row(
        children: [
          CommunityAvatar(name: c.displayName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(c.displayName, style: cText(14.5, weight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                  if (c.phoneVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, size: 15, color: AppColors.gain),
                  ],
                ]),
                if (details.isNotEmpty) Text(details, style: cText(12, color: AppColors.onGlassMuted)),
                if (c.isAccepted && c.phone != null)
                  Text(c.phone!, style: cText(12.5, weight: FontWeight.w600, color: AppColors.accentCyan)),
                if (!c.isAccepted && c.message != null)
                  Text('"${c.message}"', style: cText(12, color: AppColors.onGlassMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
