import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../services/sandbox/lesson_repository.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'quiz_screen.dart';
import 'widgets/lesson_visual.dart';
import 'widgets/sandbox_widgets.dart';

/// 3–5 swipeable cards, then the quiz.
class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final vm = context.read<SandboxViewModel>();
    final res = await vm.markLessonRead(widget.lesson.module, widget.lesson.id);
    if (!mounted) return;
    // Recording the read is only for XP; it never blocks the quiz (the quiz
    // submission records the read on the server too).
    if (!res.ok) sandboxSnack(context, res.error!, error: true);
    // The quiz's result flows back to the module screen.
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => QuizScreen(lesson: widget.lesson)),
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  void _go(int delta) {
    final next = (_page + delta).clamp(0, widget.lesson.cards.length - 1);
    _pages.animateToPage(next,
        duration: reduceMotion(context) ? const Duration(milliseconds: 1) : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final cards = lesson.cards;
    final last = _page == cards.length - 1;
    return GradientScaffold(
      maxContentWidth: 640,
      appBar: TopNavBar(current: AppSection.sandbox, title: lesson.title, showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.sandbox, isSectionRoot: false),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1} / ${cards.length}', style: sbText(12, color: AppColors.onGlassFaint)),
                      const SizedBox(height: 8),
                      LessonVisual(kind: cards[i].visual, color: lesson.module.color),
                      const SizedBox(height: 16),
                      Text(cards[i].title, style: sbText(22, weight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(cards[i].body, style: sbText(16, color: AppColors.onGlassMuted, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? lesson.module.color : AppColors.glassBorderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              children: [
                if (_page > 0)
                  OutlinedButton(onPressed: () => _go(-1), child: const Text('Back'))
                else
                  const SimulatedLabel(compact: true),
                const Spacer(),
                ElevatedButton(
                  onPressed: last ? _finish : () => _go(1),
                  child: Text(last ? 'Take the quiz' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
