// One training module: Learn → Quiz → Practise → Challenges, plus the
// module's portfolio and history.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/sandbox_models.dart';
import '../../services/sandbox/gamification.dart';
import '../../services/sandbox/lesson_repository.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'badge_gallery_screen.dart';
import 'history_tab.dart';
import 'learning_path_screen.dart';
import 'lesson_screen.dart';
import 'portfolio_tab.dart';
import 'practice/cse_practice.dart';
import 'practice/fd_practice.dart';
import 'practice/gold_practice.dart';
import 'practice/gov_practice.dart';
import 'practice/trading_practice.dart';
import 'quiz_screen.dart';
import 'widgets/reset_dialogs.dart';
import 'widgets/sandbox_widgets.dart';

/// Tab indexes.
class ModuleTab {
  static const learn = 0, practise = 1, portfolio = 2, challenges = 3, history = 4;
}

class ModuleScreen extends StatefulWidget {
  final SandboxModule module;
  final int initialTab;
  const ModuleScreen({super.key, required this.module, this.initialTab = -1});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final vm = context.read<SandboxViewModel>();
    final start = widget.initialTab >= 0
        ? widget.initialTab
        : (vm.isUnlocked(widget.module) && vm.firstLessonPassed(widget.module) ? ModuleTab.practise : ModuleTab.learn);
    _tabs = TabController(length: 5, vsync: this, initialIndex: start);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Opens a lesson; a passed quiz returns 'practise' to jump to the simulator.
  Future<void> openLesson(Lesson lesson, {bool quiz = false}) async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => quiz ? QuizScreen(lesson: lesson) : LessonScreen(lesson: lesson),
    ));
    if (result == 'practise' && mounted) _tabs.animateTo(ModuleTab.practise);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final m = widget.module;
    return CelebrationHost(
      child: GradientScaffold(
        maxContentWidth: 980,
        appBar: TopNavBar(current: AppSection.sandbox, title: m.title, showBackButton: true, isSectionRoot: false),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Hero(tag: 'sandbox-module-${m.id}', child: Icon(m.icon, color: m.color, size: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vm.isUnlocked(m))
                          Row(
                            children: [
                              Flexible(
                                child: AnimatedMoney(
                                    value: vm.moduleValue(m), style: sbText(18, weight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 8),
                              Text(signedPct(vm.moduleReturnPct(m)),
                                  style: sbText(13, weight: FontWeight.w700, color: pnlColor(vm.moduleReturnPct(m)))),
                            ],
                          )
                        else
                          Text('Simulator locked', style: sbText(16, weight: FontWeight.w700)),
                        const SimulatedLabel(compact: true),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) {
                      switch (v) {
                        case 'reset':
                          showResetModule(context, m);
                        case 'path':
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LearningPathScreen(focus: m)));
                        case 'badges':
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgeGalleryScreen()));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'path', child: Text('Learning path')),
                      const PopupMenuItem(value: 'badges', child: Text('Badge gallery')),
                      if (vm.isUnlocked(m)) const PopupMenuItem(value: 'reset', child: Text('Reset this module…')),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: sbText(14, weight: FontWeight.w700),
              unselectedLabelColor: AppColors.onGlassMuted,
              labelColor: Colors.white,
              indicatorColor: m.color,
              dividerColor: AppColors.chartGrid,
              tabs: const [
                Tab(text: 'Learn'),
                Tab(text: 'Practise'),
                Tab(text: 'Portfolio'),
                Tab(text: 'Challenges'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: !vm.isLoggedIn
                  ? ListView(padding: const EdgeInsets.all(20), children: const [LoginRequiredCard()])
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        LearnTab(module: m, onOpen: openLesson),
                        vm.isUnlocked(m) ? _practiceFor(m) : _LockedPractice(module: m, onOpen: openLesson),
                        vm.isUnlocked(m) ? PortfolioTab(module: m) : _LockedPractice(module: m, onOpen: openLesson),
                        ChallengesTab(module: m),
                        HistoryTab(module: m),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _practiceFor(SandboxModule m) => switch (m) {
        SandboxModule.cse => const CsePractice(),
        SandboxModule.fd => const FdPractice(),
        SandboxModule.gold => const GoldPractice(),
        SandboxModule.trading => const TradingPractice(),
        SandboxModule.govSecurities => const GovPractice(),
      };
}

class _LockedPractice extends StatelessWidget {
  final SandboxModule module;
  final Future<void> Function(Lesson, {bool quiz}) onOpen;
  const _LockedPractice({required this.module, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final lessons = vm.lessonsFor(module);
    final first = lessons.isEmpty ? null : lessons.first;
    final passedButLocked = vm.firstLessonPassed(module);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(Icons.lock_outline_rounded, size: 40, color: module.color),
              const SizedBox(height: 10),
              Text('Simulator locked', style: sbText(19, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                passedButLocked
                    ? 'You passed the first quiz. Tap below to open your ${formatRs(kSandboxStartingBalance, decimals: 0)} practice wallet.'
                    : 'Read the first lesson and pass its quiz to unlock a ${formatRs(kSandboxStartingBalance, decimals: 0)} practice wallet.',
                textAlign: TextAlign.center,
                style: sbText(14, color: AppColors.onGlassMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (passedButLocked)
                ElevatedButton(
                  onPressed: () async {
                    final res = await vm.unlock(module);
                    if (!res.ok && context.mounted) sandboxSnack(context, res.error!, error: true);
                  },
                  child: const Text('Unlock simulator'),
                )
              else if (first != null)
                ElevatedButton(
                  onPressed: () => onOpen(first, quiz: vm.isLessonRead(module, first.id)),
                  child: Text(vm.isLessonRead(module, first.id) ? 'Take the quiz' : 'Start lesson 1'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The module's lessons as a path: lesson → quiz, then simulator, then
/// challenges.
class LearnTab extends StatelessWidget {
  final SandboxModule module;
  final Future<void> Function(Lesson, {bool quiz}) onOpen;
  const LearnTab({super.key, required this.module, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final lessons = vm.lessonsFor(module);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            ProgressRing(
              value: vm.moduleProgress(module),
              color: module.color,
              child: Text('${(vm.moduleProgress(module) * 100).round()}%', style: sbText(11, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${vm.lessonsPassed(module)} of ${lessons.length} lessons passed',
                  style: sbText(15, weight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final (i, l) in lessons.indexed) ...[
          _LessonNode(
            index: i,
            lesson: l,
            unlocked: vm.isLessonUnlocked(module, i),
            read: vm.isLessonRead(module, l.id),
            passed: vm.isLessonPassed(module, l.id),
            score: vm.lessonState(module, l.id)?.quizScore,
            color: module.color,
            onRead: () => onOpen(l),
            onQuiz: () => onOpen(l, quiz: true),
          ),
          const SizedBox(height: 10),
        ],
        if (lessons.isEmpty)
          Text('Lessons could not be loaded.', style: sbText(14, color: AppColors.onGlassMuted)),
      ],
    );
  }
}

class _LessonNode extends StatelessWidget {
  final int index;
  final Lesson lesson;
  final bool unlocked, read, passed;
  final double? score;
  final Color color;
  final VoidCallback onRead, onQuiz;

  const _LessonNode({
    required this.index,
    required this.lesson,
    required this.unlocked,
    required this.read,
    required this.passed,
    required this.score,
    required this.color,
    required this.onRead,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final icon = passed
        ? const Icon(Icons.check_rounded, color: AppColors.onLight, size: 20)
        : unlocked
            ? Text('${index + 1}', style: sbText(15, weight: FontWeight.w800, color: AppColors.onLight))
            : const Icon(Icons.lock_outline_rounded, color: AppColors.onGlassFaint, size: 18);
    return Opacity(
      opacity: unlocked ? 1 : 0.6,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed ? AppColors.gain : (unlocked ? color : AppColors.glassFillStrong),
              ),
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title, style: sbText(15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(lesson.summary, style: sbText(13, color: AppColors.onGlassMuted)),
                  if (score != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Best quiz score ${score!.round()}%',
                          style: sbText(12, weight: FontWeight.w600, color: passed ? AppColors.gain : AppColors.warning)),
                    ),
                  if (unlocked) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                          onPressed: onRead,
                          icon: Icon(read ? Icons.replay_rounded : Icons.menu_book_rounded, size: 18),
                          label: Text(read ? 'Read again' : 'Read · ${lesson.cards.length} cards'),
                        ),
                        if (read)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                            onPressed: onQuiz,
                            icon: const Icon(Icons.quiz_outlined, size: 18),
                            label: Text(passed ? 'Retake quiz' : 'Take quiz'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChallengesTab extends StatelessWidget {
  final SandboxModule module;
  const ChallengesTab({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final list = challengesFor(module);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Challenges reward good habits, not how much you trade. Each is worth 50 XP.',
          style: sbText(13, color: AppColors.onGlassMuted),
        ),
        const SizedBox(height: 12),
        for (final c in list) ...[
          _ChallengeCard(spec: c, state: vm.challenges[c.id], locked: !vm.isUnlocked(module)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeSpec spec;
  final ChallengeState? state;
  final bool locked;
  const _ChallengeCard({required this.spec, required this.state, required this.locked});

  @override
  Widget build(BuildContext context) {
    final done = state?.isDone == true;
    final progress = (state?.progress ?? 0) / spec.target;
    final badge = spec.badgeId == null ? null : badgeById(spec.badgeId!);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: done ? AppColors.gain.withValues(alpha: 0.6) : null,
      child: Row(
        children: [
          ProgressRing(
            value: done ? 1 : progress,
            size: 44,
            color: done ? AppColors.gain : spec.module.color,
            child: Icon(done ? Icons.check_rounded : Icons.flag_outlined, size: 18,
                color: done ? AppColors.gain : AppColors.onGlassMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.title, style: sbText(15, weight: FontWeight.w700)),
                Text(spec.description, style: sbText(13, color: AppColors.onGlassMuted)),
                const SizedBox(height: 4),
                Text(
                  done
                      ? 'Completed${badge != null ? ' · badge: ${badge.title}' : ''}'
                      : locked
                          ? 'Unlock the simulator to start'
                          : spec.target > 1
                              ? '${state?.progress ?? 0} / ${spec.target}'
                              : 'Not done yet',
                  style: sbText(12, weight: FontWeight.w600, color: done ? AppColors.gain : AppColors.onGlassFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
