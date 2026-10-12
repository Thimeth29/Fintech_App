import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../services/sandbox/gamification.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'widgets/sandbox_widgets.dart';

class BadgeGalleryScreen extends StatelessWidget {
  const BadgeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(current: AppSection.sandbox, title: 'Badges', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.sandbox, isSectionRoot: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('${vm.badges.length} of ${kBadges.length} earned', style: sbText(15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 3 : 2;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, b) in kBadges.indexed)
                  SizedBox(
                    width: w,
                    child: _BadgeTile(badge: b, earned: vm.badges.contains(b.id))
                        .animate(delay: (30 * i).ms)
                        .fadeIn(duration: reduceMotion(context) ? 1.ms : 250.ms),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeSpec badge;
  final bool earned;
  const _BadgeTile({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    final color = badge.module?.color ?? AppColors.gold;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: earned ? color.withValues(alpha: 0.7) : null,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned ? color.withValues(alpha: 0.25) : AppColors.innerFill,
              border: Border.all(color: earned ? color : AppColors.glassBorder, width: 2),
            ),
            child: Icon(earned ? badge.icon : Icons.lock_outline_rounded,
                color: earned ? color : AppColors.onGlassFaint, size: 28),
          ),
          const SizedBox(height: 8),
          Text(badge.title, textAlign: TextAlign.center, style: sbText(14, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(badge.description,
              textAlign: TextAlign.center, style: sbText(12, color: AppColors.onGlassMuted), maxLines: 3),
          if (badge.module != null) ...[
            const SizedBox(height: 4),
            Text(badge.module!.shortTitle, style: sbText(11, color: AppColors.onGlassFaint)),
          ],
        ],
      ),
    );
  }
}
