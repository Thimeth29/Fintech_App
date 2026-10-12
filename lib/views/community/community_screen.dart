import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/community_models.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'connections_tab.dart';
import 'discover_tab.dart';
import 'my_groups_tab.dart';
import 'notifications_screen.dart';
import 'public_profile_tab.dart';
import 'widgets/community_widgets.dart';

/// Community hub: Discover, Connections, My Groups, My Public Profile and
/// the notification bell.
class CommunityScreen extends StatelessWidget {
  final int initialTab;
  const CommunityScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CommunityViewModel()..load(),
      child: _CommunityHub(initialTab: initialTab),
    );
  }
}

class _CommunityHub extends StatefulWidget {
  final int initialTab;
  const _CommunityHub({required this.initialTab});

  @override
  State<_CommunityHub> createState() => _CommunityHubState();
}

class _CommunityHubState extends State<_CommunityHub> {
  static const _tabs = [
    ('Discover', Icons.travel_explore_rounded),
    ('Connections', Icons.people_alt_rounded),
    ('My Groups', Icons.groups_rounded),
    ('My Profile', Icons.badge_rounded),
  ];
  late int _tab = widget.initialTab;
  bool _explainerQueued = false;

  void _maybeShowExplainer(CommunityViewModel vm) {
    if (_explainerQueued || vm.isLoading || !vm.shouldShowExplainer) return;
    _explainerQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ExplainerDialog(),
      );
      await vm.dismissExplainer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityViewModel>();
    _maybeShowExplainer(vm);

    return GradientScaffold(
      maxContentWidth: 760,
      appBar: const TopNavBar(current: AppSection.community, title: 'Community', showBackButton: true),
      bottomNavigationBar: const AppBottomNav(current: AppSection.community),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2))
          : vm.errorCode != null
              ? _ErrorView(vm: vm)
              : Column(
                  children: [
                    _header(vm),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          DiscoverTab(onOpenProfileTab: () => setState(() => _tab = 3)),
                          const ConnectionsTab(),
                          const MyGroupsTab(),
                          const PublicProfileTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _header(CommunityViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _TabPill(
                          label: _tabs[i].$1,
                          icon: _tabs[i].$2,
                          active: _tab == i,
                          badge: i == 1 ? vm.incomingRequests : (i == 2 ? vm.invites.length : 0),
                          onTap: () => setState(() => _tab = i),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Bell(
                count: vm.unreadNotifications,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(value: vm, child: const NotificationsScreen()),
                )),
              ),
            ],
          ),
          if (!vm.isAvailable && _tab != 3) ...[
            const SizedBox(height: 10),
            _OptInBanner(hasProfile: vm.hasProfile, onTap: () => setState(() => _tab = 3)),
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.icon, required this.active, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onLight : AppColors.onGlass;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : AppColors.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.white : AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? fg : AppColors.onGlassMuted),
            const SizedBox(width: 6),
            Text(label, style: cText(13, weight: active ? FontWeight.w700 : FontWeight.w500, color: fg)),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              _Badge(badge),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: AppColors.lossStrong, borderRadius: BorderRadius.circular(10)),
        child: Text(count > 99 ? '99+' : '$count', style: cText(10.5, weight: FontWeight.w700, color: Colors.white)),
      );
}

class _Bell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _Bell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: AppColors.onGlass, size: 21),
            ),
            if (count > 0) Positioned(right: -4, top: -4, child: _Badge(count)),
          ],
        ),
      ),
    );
  }
}

class _OptInBanner extends StatelessWidget {
  final bool hasProfile;
  final VoidCallback onTap;
  const _OptInBanner({required this.hasProfile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      borderColor: AppColors.accentCyan.withValues(alpha: 0.5),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: AppColors.accentCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasProfile ? 'You\'re hidden from search' : 'Set up your community profile',
                    style: cText(14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  hasProfile
                      ? 'Turn on "Available for group investments" so others can find you.'
                      : 'Create a profile and opt in to find people and groups to invest with.',
                  style: cText(12, color: AppColors.onGlassMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.accentCyan),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final CommunityViewModel vm;
  const _ErrorView({required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        EmptyState(
          icon: vm.unavailable ? Icons.construction_rounded : Icons.cloud_off_rounded,
          title: vm.unavailable ? 'Community is almost here' : 'Couldn\'t load Community',
          body: communityErrorTextFor(vm.errorCode!),
          action: OutlinedButton(onPressed: vm.load, child: const Text('Try again')),
        ),
      ],
    );
  }
}

String communityErrorTextFor(String code) => switch (code) {
      'community_unavailable' =>
        'Community features are being set up on the server. Once they\'re live you can find people, join groups and run seettu here.',
      _ => 'Check your connection and try again.',
    };

class _ExplainerDialog extends StatelessWidget {
  const _ExplainerDialog();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.accentCyan, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: cText(14, weight: FontWeight.w700)),
                    Text(body, style: cText(12.5, color: AppColors.onGlassMuted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );

    return AlertDialog(
      backgroundColor: AppColors.deepNavy,
      title: Text('Welcome to Community', style: cText(20, weight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            point(Icons.groups_rounded, 'Invest and save together',
                'Find people, form investment groups or join a seettu, and decide together with polls and votes.'),
            point(Icons.receipt_long_rounded, 'Records only, never your money',
                '$kRecordKeepingNotice You pay by bank transfer or cash, mark it as paid here, and the treasurer or receiver confirms it.'),
            point(Icons.trending_down_rounded, 'No guaranteed returns',
                'Every investment can lose money. Be wary of anyone promising fixed profits or rewards for recruiting people.'),
            point(Icons.shield_outlined, 'You stay in control',
                'You only appear in search if you opt in, and you can block or report anyone at any time.'),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
      ],
    );
  }
}
