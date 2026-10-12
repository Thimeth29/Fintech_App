import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../services/sandbox/lesson_repository.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'widgets/sandbox_widgets.dart';

/// Multiple choice with instant feedback. 70% passes; retries allowed.
/// Pops 'practise' when the user chooses to go to the simulator.
class QuizScreen extends StatefulWidget {
  final Lesson lesson;
  const QuizScreen({super.key, required this.lesson});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _picked;
  int _correct = 0;
  bool _done = false;
  bool _submitting = false;
  bool? _passed;
  String? _error;

  List<QuizQuestion> get _qs => widget.lesson.quiz;

  void _pick(int i) {
    if (_picked != null) return;
    final right = i == _qs[_index].answer;
    HapticFeedback.selectionClick();
    setState(() {
      _picked = i;
      if (right) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index < _qs.length - 1) {
      setState(() {
        _index++;
        _picked = null;
      });
      return;
    }
    setState(() {
      _done = true;
      _submitting = true;
    });
    final res = await context.read<SandboxViewModel>().submitQuiz(widget.lesson.module, widget.lesson.id, _correct, _qs.length);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _passed = res.ok ? res.data == true : null;
      _error = res.error;
    });
  }

  void _retry() => setState(() {
        _index = 0;
        _picked = null;
        _correct = 0;
        _done = false;
        _passed = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    return CelebrationHost(
      child: GradientScaffold(
        maxContentWidth: 640,
        appBar: TopNavBar(
            current: AppSection.sandbox, title: 'Quiz: ${widget.lesson.title}', showBackButton: true, isSectionRoot: false),
        bottomNavigationBar: const AppBottomNav(current: AppSection.sandbox, isSectionRoot: false),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [if (_done) _result(context) else _question(context)],
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final q = _qs[_index];
    final answered = _picked != null;
    final right = answered && _picked == q.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: (_index + (answered ? 1 : 0)) / _qs.length, minHeight: 6),
        ),
        const SizedBox(height: 14),
        Text('Question ${_index + 1} of ${_qs.length}', style: sbText(13, color: AppColors.onGlassMuted)),
        const SizedBox(height: 6),
        Text(q.question, style: sbText(20, weight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 16),
        for (final (i, o) in q.options.indexed) ...[
          _Option(
            text: o,
            state: !answered
                ? _OptState.idle
                : i == q.answer
                    ? _OptState.right
                    : i == _picked
                        ? _OptState.wrong
                        : _OptState.dim,
            onTap: () => _pick(i),
          ),
          const SizedBox(height: 10),
        ],
        if (answered) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            borderColor: right ? AppColors.gain : AppColors.loss,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(right ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: right ? AppColors.gain : AppColors.loss),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${right ? 'Correct! ' : 'Not quite. '}${q.explanation}',
                      style: sbText(14, color: AppColors.onGlassMuted, height: 1.4)),
                ),
              ],
            ),
          ).animate().fadeIn(duration: reduceMotion(context) ? 1.ms : 250.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _next,
              child: Text(_index < _qs.length - 1 ? 'Next question' : 'See result'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _result(BuildContext context) {
    final pct = _qs.isEmpty ? 0 : (_correct / _qs.length * 100).round();
    final passedLocal = pct >= kQuizPassPercent;
    final vm = context.watch<SandboxViewModel>();
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ProgressRing(
            value: pct / 100,
            size: 110,
            stroke: 9,
            color: passedLocal ? AppColors.gain : AppColors.warning,
            child: Text('$pct%', style: sbText(26, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          Text(passedLocal ? 'Passed!' : 'Not passed yet', style: sbText(22, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '$_correct of ${_qs.length} correct. You need $kQuizPassPercent% to pass.',
            textAlign: TextAlign.center,
            style: sbText(14, color: AppColors.onGlassMuted),
          ),
          const SizedBox(height: 10),
          if (_submitting) const CircularProgressIndicator(),
          if (_error != null)
            Text(_error!, textAlign: TextAlign.center, style: sbText(13, color: AppColors.loss)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(onPressed: _retry, child: const Text('Retry quiz')),
              if (_passed == true && vm.isUnlocked(widget.lesson.module))
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop('practise'),
                  child: const Text('Go to the simulator'),
                )
              else
                ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ],
          ),
        ],
      ),
    ).animate().scaleXY(begin: reduceMotion(context) ? 1 : 0.94, end: 1, duration: 300.ms).fadeIn();
  }
}

enum _OptState { idle, right, wrong, dim }

class _Option extends StatelessWidget {
  final String text;
  final _OptState state;
  final VoidCallback onTap;
  const _Option({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = switch (state) {
      _OptState.right => AppColors.gain,
      _OptState.wrong => AppColors.loss,
      _ => AppColors.glassBorder,
    };
    final card = GlassCard(
      onTap: state == _OptState.idle ? onTap : null,
      borderColor: border,
      backgroundColor: switch (state) {
        _OptState.right => AppColors.gainStrong.withValues(alpha: 0.55),
        _OptState.wrong => AppColors.lossStrong.withValues(alpha: 0.55),
        _ => null,
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: sbText(15,
                    weight: FontWeight.w600, color: state == _OptState.dim ? AppColors.onGlassFaint : AppColors.onGlass)),
          ),
          if (state == _OptState.right) const Icon(Icons.check_rounded, color: AppColors.gain),
          if (state == _OptState.wrong) const Icon(Icons.close_rounded, color: AppColors.loss),
        ],
      ),
    );
    if (state == _OptState.wrong && !reduceMotion(context)) {
      return card.animate().shakeX(hz: 5, amount: 4, duration: 350.ms);
    }
    return card;
  }
}
