import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/community_models.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'group_preview_screen.dart';
import 'widgets/community_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<CommunityViewModel>().refreshNotifications();
    if (mounted) setState(() => _loading = false);
  }

  IconData _icon(String kind) => switch (kind) {
        'connection_request' || 'connection_accepted' => Icons.person_add_alt_1_rounded,
        'join_request' || 'join_decision' || 'group_invite' => Icons.group_add_rounded,
        'chat_message' => Icons.forum_rounded,
        'poll_opened' || 'vote_opened' || 'vote_closing_soon' || 'vote_result' => Icons.how_to_vote_rounded,
        'seettu_payment_due' || 'seettu_payment_overdue' => Icons.event_rounded,
        'seettu_payment_marked' || 'seettu_payment_confirmed' || 'contribution_marked' || 'contribution_confirmed' =>
          Icons.receipt_long_rounded,
        'seettu_pot_handed' || 'seettu_pot_received' || 'distribution_created' || 'exit_update' => Icons.payments_rounded,
        'role_changed' => Icons.badge_rounded,
        'removed_from_group' => Icons.person_remove_rounded,
        _ => Icons.notifications_rounded,
      };

  Future<void> _open(AppNotification n) async {
    final vm = context.read<CommunityViewModel>();
    if (!n.isRead) vm.markNotificationRead(n.id);
    final groupId = n.groupId ?? n.data['group_id'] as String?;
    if (groupId == null) return;
    final invite = n.kind == 'group_invite'
        ? vm.invites.where((i) => i.id == n.data['invite_id']).firstOrNull
        : null;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: GroupPreviewScreen(groupId: groupId, invite: invite)),
    ));
    vm.refreshGroups();
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return shortDate(t);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityViewModel>();
    final items = vm.notifications;
    return GradientScaffold(
      maxContentWidth: 720,
      appBar: const TopNavBar(
        current: AppSection.community,
        title: 'Notifications',
        showBackButton: true,
        isSectionRoot: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: vm.refreshNotifications,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  if (items.any((n) => !n.isRead))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final error = await vm.markAllNotificationsRead();
                          if (context.mounted) showResult(context, error);
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Mark all as read'),
                      ),
                    ),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications yet',
                      body: 'Connection requests, group invites, votes and payment reminders will show up here.',
                    )
                  else
                    for (final n in items)
                      GlassCard(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        borderRadius: 18,
                        borderColor: n.isRead ? null : AppColors.accentCyan.withValues(alpha: 0.6),
                        onTap: () => _open(n),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_icon(n.kind), color: n.isRead ? AppColors.onGlassMuted : AppColors.accentCyan, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: cText(14, weight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                                  if (n.body != null)
                                    Text(n.body!, style: cText(12.5, color: AppColors.onGlassMuted),
                                        maxLines: 3, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(_ago(n.createdAt), style: cText(11.5, color: AppColors.onGlassFaint)),
                                ],
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: const BoxDecoration(color: AppColors.accentCyan, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
