import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'widgets/community_widgets.dart';

/// Someone's public profile with connect / invite / block / report.
Future<void> showPersonSheet(BuildContext context, CommunityViewModel vm, String userId, {VoidCallback? onChanged}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.deepNavy,
    builder: (ctx) => _PersonSheet(vm: vm, userId: userId, onChanged: onChanged),
  );
}

class _PersonSheet extends StatefulWidget {
  final CommunityViewModel vm;
  final String userId;
  final VoidCallback? onChanged;
  const _PersonSheet({required this.vm, required this.userId, this.onChanged});

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.vm.service.profileOf(widget.userId);
      if (mounted) setState(() => _profile = p);
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<String?> Function() action, String success, {bool close = false}) async {
    final error = await action();
    if (!mounted) return;
    showResult(context, error, success);
    if (error == null) {
      widget.onChanged?.call();
      if (close) {
        Navigator.pop(context);
      } else {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)))
            : p == null
                ? EmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'Profile not available',
                    body: _error ?? 'This person is hidden or no longer available.')
                : _content(p),
      ),
    );
  }

  Widget _content(Map<String, dynamic> p) {
    final name = (p['display_name'] as String?) ?? 'Member';
    final trust = TrustIndicators.fromJson(p['trust'] is Map ? Map<String, dynamic>.from(p['trust'] as Map) : null);
    final connection = p['connection'] is Map ? Map<String, dynamic>.from(p['connection'] as Map) : null;
    final status = connection?['status'] as String?;
    final incoming = connection?['direction'] == 'incoming';
    final interests = (p['interests'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAvatar(name: name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: cText(19, weight: FontWeight.w800)),
                    Text(
                      [kExperienceLabels[p['experience']] ?? 'New to investing', if (p['district'] != null) p['district']]
                          .join(' · '),
                      style: cText(12.5, color: AppColors.onGlassMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            VerifiedChip(trust.phoneVerified),
            if (p['contribution_label'] != null)
              InfoChip('Up to ${p['contribution_label']}', icon: Icons.payments_outlined, color: AppColors.gold),
            for (final i in interests) InfoChip(kInterestLabels[i] ?? i),
            if (p['phone'] != null) InfoChip(p['phone'] as String, icon: Icons.phone_rounded, color: AppColors.accentCyan),
          ]),
          if ((p['bio'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(p['bio'] as String, style: cText(13, color: AppColors.onGlassMuted, height: 1.4)),
          ],
          const SizedBox(height: 14),
          Text('Trust', style: cText(13, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          _trustRow(Icons.event_rounded, 'Member since',
              trust.memberSince == null ? '—' : shortDate(trust.memberSince!)),
          _trustRow(Icons.flag_rounded, 'Groups completed', '${trust.groupsCompleted}'),
          _trustRow(Icons.schedule_rounded, 'Seettu payments on time',
              trust.seettuOnTimePct == null ? 'No record yet' : '${trust.seettuOnTimePct}%'),
          const SizedBox(height: 16),
          if (status == null || status == 'declined' || status == 'cancelled')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _act(() => widget.vm.requestConnection(widget.userId), 'Request sent to $name.'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Send connection request'),
              ),
            )
          else if (status == 'pending' && incoming)
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _act(
                      () => widget.vm.respond(_entry(connection!, name), true), 'You\'re now connected with $name.'),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _act(() => widget.vm.respond(_entry(connection!, name), false), 'Request declined.'),
                  child: const Text('Decline'),
                ),
              ),
            ])
          else if (status == 'pending')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _act(() => widget.vm.cancelRequest(_entry(connection!, name)), 'Request cancelled.'),
                child: const Text('Cancel request'),
              ),
            )
          else ...[
            const InfoChip('Connected', icon: Icons.check_circle_rounded, color: AppColors.gain),
            const SizedBox(height: 10),
            if (widget.vm.myGroups.any((g) => g.status != 'closed'))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => pickGroupAndInvite(context, widget.vm, widget.userId, name),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Invite to a group'),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (status == 'accepted')
                TextButton(
                  onPressed: () async {
                    if (await confirmAction(context, 'Remove connection?', '$name won\'t be notified.', confirm: 'Remove')) {
                      _act(() => widget.vm.removeConnection(widget.userId), 'Connection removed.');
                    }
                  },
                  child: const Text('Remove'),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showReportSheet(context, widget.vm, userId: widget.userId),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report'),
              ),
              TextButton.icon(
                onPressed: () async {
                  if (await confirmAction(context, 'Block $name?',
                      'You\'ll stop seeing each other in search and any requests between you are removed.',
                      confirm: 'Block')) {
                    _act(() => widget.vm.block(widget.userId), '$name is blocked.', close: true);
                  }
                },
                icon: const Icon(Icons.block_rounded, size: 18, color: AppColors.loss),
                label: Text('Block', style: cText(14, weight: FontWeight.w600, color: AppColors.loss)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ConnectionEntry _entry(Map<String, dynamic> c, String name) => ConnectionEntry(
        connectionId: c['id'] as String,
        userId: widget.userId,
        displayName: name,
        status: c['status'] as String,
        direction: c['direction'] as String,
      );

  Widget _trustRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.onGlassMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: cText(13, color: AppColors.onGlassMuted))),
          Text(value, style: cText(13, weight: FontWeight.w700)),
        ]),
      );
}

/// One-tap invite: pick one of my open groups.
Future<void> pickGroupAndInvite(BuildContext context, CommunityViewModel vm, String userId, String name) async {
  final groups = vm.myGroups.where((g) => g.status != 'closed').toList();
  final picked = await showModalBottomSheet<MyGroup>(
    context: context,
    backgroundColor: AppColors.deepNavy,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Invite $name to…', style: cText(17, weight: FontWeight.w700)),
          ),
          for (final g in groups)
            ListTile(
              leading: Icon(g.isSeettu ? Icons.autorenew_rounded : Icons.groups_rounded,
                  color: g.isSeettu ? AppColors.gold : AppColors.accentLavender),
              title: Text(g.name),
              subtitle: Text(g.isSeettu ? 'Seettu' : 'Investment group'),
              onTap: () => Navigator.pop(ctx, g),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final error = await vm.inviteToGroup(picked.id, userId);
  if (context.mounted) showResult(context, error, 'Invited $name to ${picked.name}.');
}
