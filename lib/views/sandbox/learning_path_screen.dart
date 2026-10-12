import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../services/sandbox/gamification.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'module_screen.dart';
import 'widgets/sandbox_widgets.dart';

enum _NodeState { locked, open, done }

/// Every module as a path of nodes: lesson → quiz (per lesson) →
/// simulator → challenges.
class LearningPathScreen extends StatelessWidget {
  final SandboxModule? focus;
  const LearningPathScreen({super.key, this.focus});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final modules = focus == null ? SandboxModule.values : [focus!, ...SandboxModule.values.where((m) => m != focus)];
    return GradientScaffold(
      maxContentWidth: 760,
      appBar: const TopNavBar(current: AppSection.sandbox, title: 'Learning path', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.sandbox, isSectionRoot: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          for (final m in modules) ...[
            _ModulePath(vm: vm, module: m),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ModulePath extends StatelessWidget {
  final SandboxViewModel vm;
  final SandboxModule module;
  const _ModulePath({required this.vm, required this.module});

  void _open(BuildContext context, int tab) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => ModuleScreen(module: module, initialTab: tab)));

  @override
  Widget build(BuildContext context) {
    final lessons = vm.lessonsFor(module);
    final nodes = <(String, IconData, _NodeState, int)>[];
    for (final (i, l) in lessons.indexed) {
      final unlocked = vm.isLessonUnlocked(module, i);
      final read = vm.isLessonRead(module, l.id);
      final passed = vm.isLessonPassed(module, l.id);
      nodes.add((l.title, Icons.menu_book_rounded,
          read ? _NodeState.done : (unlocked ? _NodeState.open : _NodeState.locked), ModuleTab.learn));
      nodes.add(('Quiz', Icons.quiz_outlined,
          passed ? _NodeState.done : (read ? _NodeState.open : _NodeState.locked), ModuleTab.learn));
      if (i == 0) {
        nodes.add(('Simulator', Icons.play_circle_outline_rounded,
            vm.isUnlocked(module) ? _NodeState.done : _NodeState.locked, ModuleTab.practise));
      }
    }
    final ch = challengesFor(module);
    final doneCh = ch.where((c) => vm.challenges[c.id]?.isDone ?? false).length;
    nodes.add(('Challenges $doneCh/${ch.length}', Icons.flag_outlined,
        doneCh == ch.length ? _NodeState.done : (vm.isUnlocked(module) ? _NodeState.open : _NodeState.locked),
        ModuleTab.challenges));

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(value: vm.moduleProgress(module), color: module.color, child: Icon(module.icon, size: 20, color: module.color)),
              const SizedBox(width: 12),
              Expanded(child: Text(module.title, style: sbText(17, weight: FontWeight.w800))),
              Text('${(vm.moduleProgress(module) * 100).round()}%', style: sbText(14, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          for (final (i, n) in nodes.indexed)
            _PathNode(
              label: n.$1,
              icon: n.$2,
              state: n.$3,
              color: module.color,
              indent: i.isOdd,
              last: i == nodes.length - 1,
              onTap: n.$3 == _NodeState.locked ? null : () => _open(context, n.$4),
            ),
        ],
      ),
    );
  }
}

class _PathNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final _NodeState state;
  final Color color;
  final bool indent;
  final bool last;
  final VoidCallback? onTap;

  const _PathNode({
    required this.label,
    required this.icon,
    required this.state,
    required this.color,
    required this.indent,
    required this.last,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = switch (state) {
      _NodeState.done => AppColors.gain,
      _NodeState.open => color,
      _NodeState.locked => AppColors.glassFillStrong,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.only(left: indent ? 28 : 0),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
                  child: Icon(
                    state == _NodeState.done ? Icons.check_rounded : (state == _NodeState.locked ? Icons.lock_outline : icon),
                    size: 18,
                    color: state == _NodeState.locked ? AppColors.onGlassFaint : AppColors.onLight,
                  ),
                ),
                if (!last) Container(width: 2, height: 16, color: AppColors.glassBorder),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 16),
                child: Text(label,
                    style: sbText(14,
                        weight: FontWeight.w600,
                        color: state == _NodeState.locked ? AppColors.onGlassFaint : AppColors.onGlass)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
