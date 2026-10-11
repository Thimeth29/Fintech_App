import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/top_nav_bar.dart';
import '../../../viewmodels/community_viewmodel.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../widgets/community_widgets.dart';
import 'group_chat_tab.dart';
import 'group_decide_tab.dart';
import 'group_log_tab.dart';
import 'group_members_tab.dart';
import 'investment_tab.dart';
import 'seettu_tab.dart';

/// A group I belong to: chat, decisions, money records, members and log.
class GroupScreen extends StatelessWidget {
  final String groupId;
  final CommunityViewModel? community;
  const GroupScreen({super.key, required this.groupId, this.community});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupViewModel(groupId)..load(),
      child: _GroupShell(community: community),
    );
  }
}

class _GroupShell extends StatelessWidget {
  final CommunityViewModel? community;
  const _GroupShell({this.community});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final g = vm.info;

    if (vm.isLoading && g == null) {
      return const GradientScaffold(
        appBar: TopNavBar(current: AppSection.community, title: 'Group', showBackButton: true, isSectionRoot: false),
        body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)),
      );
    }
    if (g == null) {
      return GradientScaffold(
        appBar: const TopNavBar(current: AppSection.community, title: 'Group', showBackButton: true, isSectionRoot: false),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          EmptyState(
            icon: Icons.group_off_rounded,
            title: 'Group not available',
            body: 'You may no longer be a member of this group.',
            action: OutlinedButton(onPressed: vm.load, child: const Text('Try again')),
          ),
        ]),
      );
    }

    final tabs = [
      ('Chat', Icons.forum_rounded),
      ('Decide', Icons.how_to_vote_rounded),
      (g.isSeettu ? 'Seettu' : 'Money', g.isSeettu ? Icons.autorenew_rounded : Icons.account_balance_wallet_rounded),
      ('Members', Icons.people_alt_rounded),
      ('Log', Icons.history_rounded),
    ];
    final openVotes = vm.votes.where((v) => v.isOpen && v.myChoice == null).length +
        vm.polls.where((p) => p.isOpen && p.myChoices.isEmpty).length;

    return DefaultTabController(
      length: tabs.length,
      child: GradientScaffold(
        maxContentWidth: 820,
        appBar: TopNavBar(current: AppSection.community, title: g.name, showBackButton: true, isSectionRoot: false),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.onGlass,
                      unselectedLabelColor: AppColors.onGlassMuted,
                      indicatorColor: AppColors.accentCyan,
                      dividerColor: Colors.transparent,
                      tabs: [
                        for (var i = 0; i < tabs.length; i++)
                          Tab(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(tabs[i].$2, size: 16),
                              const SizedBox(width: 6),
                              Text(tabs[i].$1),
                              if (i == 1 && openVotes > 0) ...[
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: AppColors.accentCyan,
                                  child: Text('$openVotes', style: cText(10, weight: FontWeight.w700, color: AppColors.onLight)),
                                ),
                              ],
                            ]),
                          ),
                      ],
                    ),
                  ),
                  _GroupMenu(community: community),
                ],
              ),
            ),
            if (g.isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: AppColors.innerFill,
                child: Text('This group is closed. Its records are read-only.', style: cText(12.5, color: AppColors.onGlassMuted)),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  const GroupChatTab(),
                  const GroupDecideTab(),
                  g.isSeettu ? const SeettuTab() : const InvestmentTab(),
                  GroupMembersTab(community: community),
                  const GroupLogTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMenu extends StatelessWidget {
  final CommunityViewModel? community;
  const _GroupMenu({this.community});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final muted = vm.me?.chatMuted ?? false;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.onGlass),
      onSelected: (v) async {
        switch (v) {
          case 'mute':
            await act(context, vm.setMuted(!muted), muted ? 'Chat notifications on.' : 'Chat notifications muted.');
          case 'export':
            await _export(context, vm);
          case 'rules':
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Group rules'),
                content: SingleChildScrollView(
                  child: Text('Mobile SAP keeps records only. Money is exchanged directly between members. '
                      'No returns are promised.\n\n${vm.info!.rules.trim().isEmpty ? 'No other rules.' : vm.info!.rules}'),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            );
          case 'scam':
            final c = community;
            if (c != null && context.mounted) await showReportSheet(context, c, groupId: vm.groupId, scam: true);
          case 'leave':
            if (!await confirmAction(context, 'Leave ${vm.info!.name}?',
                'Your records stay in the group\'s history.', confirm: 'Leave')) {
              return;
            }
            final error = await vm.leave();
            if (!context.mounted) return;
            showResult(context, error, 'You left the group.');
            if (error == null) {
              community?.refreshGroups();
              Navigator.of(context).pop();
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'mute', child: Text(muted ? 'Unmute chat notifications' : 'Mute chat notifications')),
        const PopupMenuItem(value: 'rules', child: Text('Group rules')),
        const PopupMenuItem(value: 'export', child: Text('Export records (CSV)')),
        if (community != null) const PopupMenuItem(value: 'scam', child: Text('Report suspected scam')),
        if (!(vm.info?.isClosed ?? true)) const PopupMenuItem(value: 'leave', child: Text('Leave group')),
      ],
    );
  }

  Future<void> _export(BuildContext context, GroupViewModel vm) async {
    await vm.loadActivity();
    final csv = vm.exportCsv();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export records'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copy this CSV and paste it into a spreadsheet (Excel, Google Sheets) to keep or print.'),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) showResult(context, null, 'Records copied. Paste them into a spreadsheet.');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy CSV'),
          ),
        ],
      ),
    );
  }
}
