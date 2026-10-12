// Investment Trainer hub: total virtual net worth, level and streak, the
// five training modules and "continue where you left off".
//
// Kept as SandboxScreen so Home's "Practise trade" action and "Sandbox
// portfolio" card keep opening it.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../services/sandbox/sim_math.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'badge_gallery_screen.dart';
import 'learning_path_screen.dart';
import 'module_screen.dart';
import 'widgets/reset_dialogs.dart';
import 'widgets/sandbox_widgets.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});

  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SandboxViewModel>().load();
    });
  }

  void _openModule(SandboxModule m) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModuleScreen(module: m)));

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    return CelebrationHost(
      child: GradientScaffold(
        maxContentWidth: 980,
        appBar: const TopNavBar(
          current: AppSection.sandbox,
          title: 'Investment Trainer',
          showBackButton: true,
        ),
        bottomNavigationBar: const AppBottomNav(current: AppSection.sandbox),
        body: RefreshIndicator(
          onRefresh: () => vm.load(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            children: [
              if (!vm.isLoggedIn) ...[
                const LoginRequiredCard(),
              ] else ...[
                if (vm.error != null) _ErrorBanner(message: vm.error!, onRetry: () => vm.load(force: true)),
                _HeroCard(vm: vm),
                const SizedBox(height: 16),
                if (vm.continueModule case final m?) ...[
                  _ContinueCard(vm: vm, module: m, onTap: () => _openModule(m)),
                  const SizedBox(height: 16),
                ],
                SectionTitle('Training modules',
                    trailing: vm.loading
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : null),
                _ModuleGrid(vm: vm, onOpen: _openModule),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const LearningPathScreen())),
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('Learning path'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const BadgeGalleryScreen())),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: Text('Badges (${vm.badges.length})'),
                    ),
                    if (vm.wallets.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: vm.busy ? null : () => showResetEverything(context),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset everything'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Center(child: SimulatedLabel()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: AppColors.loss,
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.loss),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: sbText(13))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final SandboxViewModel vm;
  const _HeroCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final ret = vm.totalReturnPercent;
    final xp = vm.progress.xp;
    final toNext = LevelMath.xpToNext(xp);
    return GlassCard(
      gradient: AppGradients.heroCard,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('VIRTUAL NET WORTH',
                    style: sbText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted).copyWith(letterSpacing: 1)),
              ),
              const SimulatedLabel(compact: true),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedMoney(value: vm.totalValue, style: sbText(34, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(
            vm.wallets.isEmpty
                ? 'Pass a module\'s first quiz to get ${formatRs(kSandboxStartingBalance, decimals: 0)} of virtual money'
                : '${signedPct(ret)} since start · across ${vm.wallets.length} '
                    '${vm.wallets.length == 1 ? 'module' : 'modules'}',
            style: sbText(13, weight: FontWeight.w700, color: vm.wallets.isEmpty ? AppColors.onGlassMuted : pnlColor(ret)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Chip(icon: Icons.military_tech_outlined, text: 'Level ${vm.progress.level} · ${vm.levelTitle}'),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.local_fire_department_outlined,
                text: '${vm.progress.streak}-day streak',
                color: vm.progress.streak > 0 ? AppColors.gold : AppColors.onGlassMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: LevelMath.progressInLevel(xp)),
              duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: AppColors.gold,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            toNext == null ? '$xp XP · top level reached' : '$xp XP · $toNext XP to level ${vm.progress.level + 1}',
            style: sbText(12, color: AppColors.onGlassMuted),
          ),
        ],
      ),
    );
  }
}


class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Chip({required this.icon, required this.text, this.color = AppColors.onGlass});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(text, style: sbText(12, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final SandboxViewModel vm;
  final SandboxModule module;
  final VoidCallback onTap;
  const _ContinueCard({required this.vm, required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(module.icon, color: module.color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Continue where you left off', style: sbText(12, color: AppColors.onGlassMuted)),
                Text(module.title, style: sbText(16, weight: FontWeight.w700)),
                Text(vm.nextStepFor(module), style: sbText(13, color: AppColors.accentCyan),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  final SandboxViewModel vm;
  final ValueChanged<SandboxModule> onOpen;
  const _ModuleGrid({required this.vm, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 860 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (i, m) in SandboxModule.values.indexed)
            SizedBox(
              width: w,
              child: _ModuleCard(vm: vm, module: m, onTap: () => onOpen(m))
                  .animate(delay: (60 * i).ms)
                  .fadeIn(duration: reduceMotion(context) ? 1.ms : 300.ms)
                  .slideY(begin: reduceMotion(context) ? 0 : 0.08, end: 0),
            ),
        ],
      );
    });
  }
}

class _ModuleCard extends StatelessWidget {
  final SandboxViewModel vm;
  final SandboxModule module;
  final VoidCallback onTap;
  const _ModuleCard({required this.vm, required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = vm.isUnlocked(module);
    final ret = vm.moduleReturnPct(module);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ProgressRing(
            value: vm.moduleProgress(module),
            size: 56,
            color: module.color,
            child: Hero(
              tag: 'sandbox-module-${module.id}',
              child: Icon(module.icon, color: module.color, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: sbText(16, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(module.tagline, style: sbText(12, color: AppColors.onGlassMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (unlocked)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AnimatedMoney(value: vm.moduleValue(module), decimals: 0, style: sbText(14, weight: FontWeight.w800)),
                      Text(signedPct(ret), style: sbText(12, weight: FontWeight.w700, color: pnlColor(ret))),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.onGlassFaint),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('Pass lesson 1 to unlock the simulator',
                            style: sbText(12, color: AppColors.onGlassFaint), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.onGlassMuted),
        ],
      ),
    );
  }
}
