// Shared building blocks for the Investment Trainer screens. Everything
// uses the app's blue glass look (GlassCard, Outfit, AppColors).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/sandbox_models.dart';
import '../../../services/sandbox/price_engine.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../../auth/login_screen.dart';
import '../../bot/chat_screen.dart';

/// Honour the OS "reduce motion" setting everywhere in the trainer.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

TextStyle sbText(double size, {FontWeight weight = FontWeight.w500, Color color = AppColors.onGlass, double? height}) =>
    GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: color, height: height);

Color pnlColor(double v) => v >= 0 ? AppColors.gain : AppColors.loss;

String signedPct(double v, {int decimals = 2}) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(decimals)}%';

String signedRs(double v) => '${v >= 0 ? '+' : ''}${formatRs(v)}';

void sandboxSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
      backgroundColor: error ? AppColors.lossStrong : AppColors.gainStrong,
    ));
}

/// The small "Simulated: virtual money, not financial advice" tag.
class SimulatedLabel extends StatelessWidget {
  final bool compact;
  const SimulatedLabel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kSandboxDisclaimer,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warningTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined, size: 13, color: AppColors.warning),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                compact ? 'Simulated · virtual money' : kSandboxDisclaimer,
                style: sbText(11, weight: FontWeight.w600, color: AppColors.warning),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Counts smoothly from the previous value to the new one.
class AnimatedMoney extends StatefulWidget {
  final double value;
  final TextStyle style;
  final bool signed;
  final int decimals;
  final String suffix;
  final bool percent;

  const AnimatedMoney({
    super.key,
    required this.value,
    required this.style,
    this.signed = false,
    this.decimals = 2,
    this.suffix = '',
    this.percent = false,
  });

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney> {
  late double _from = widget.value;

  @override
  void didUpdateWidget(covariant AnimatedMoney old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  String _fmt(double v) {
    if (widget.percent) return '${widget.signed && v >= 0 ? '+' : ''}${v.toStringAsFixed(widget.decimals)}%';
    final s = formatRs(v, decimals: widget.decimals);
    return '${widget.signed && v >= 0 ? '+' : ''}$s${widget.suffix}';
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(_fmt(widget.value), style: widget.style);
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _from, end: widget.value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(_fmt(v), style: widget.style),
    );
  }
}

/// Circular progress ring with an optional child in the middle.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 48,
    this.stroke = 5,
    this.color = AppColors.accentCyan,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(v, stroke, color),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [ring, if (child != null) child!]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  _RingPainter(this.v, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = AppColors.chartGrid);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: sbText(17, weight: FontWeight.w700).copyWith(shadows: kTitleShadow)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? sub;
  const StatTile({super.key, required this.label, required this.value, this.valueColor, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.innerFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: sbText(11, weight: FontWeight.w600, color: AppColors.onGlassMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: sbText(15, weight: FontWeight.w800, color: valueColor ?? AppColors.onGlass)),
          ),
          if (sub != null)
            Text(sub!, style: sbText(11, color: AppColors.onGlassFaint), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Lays out tiles two (or more) per row without fixed aspect ratios.
class TileGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  const TileGrid({super.key, required this.children, this.minTileWidth = 150});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = math.max(2, (c.maxWidth / minTileWidth).floor()).clamp(2, 4);
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

/// Shown instead of the trainer when nobody is logged in: no demo trades.
class LoginRequiredCard extends StatelessWidget {
  const LoginRequiredCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.accentCyan),
          const SizedBox(height: 12),
          Text('Log in to start training', style: sbText(20, weight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Your lessons, virtual wallets and badges are saved to your account, so you need to be logged in.',
            style: sbText(14, color: AppColors.onGlassMuted, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Log in'),
          ),
          const SizedBox(height: 12),
          const SimulatedLabel(),
        ],
      ),
    );
  }
}

/// Opens FinBot with a question already typed in.
class AskFinBotButton extends StatelessWidget {
  final String prompt;
  final String label;
  final bool dense;
  const AskFinBotButton({super.key, required this.prompt, this.label = 'Ask FinBot', this.dense = false});

  static void open(BuildContext context, String prompt) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          title: 'Ask FinBot AI',
          seedContext: 'the Investment Trainer (simulated, virtual money)',
          initialPrompt: prompt,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: dense ? const EdgeInsets.symmetric(horizontal: 8) : null,
        visualDensity: dense ? VisualDensity.compact : null,
      ),
      onPressed: () => open(context, prompt),
      icon: const Icon(Icons.smart_toy_outlined, size: 18),
      label: Text(label),
    );
  }
}

/// A scripted headline and why it moved the price — the teaching moment.
class NewsEventCard extends StatelessWidget {
  final NewsEvent event;
  final String? dateLabel;
  const NewsEventCard({super.key, required this.event, this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final up = event.isPositive;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      borderColor: (up ? AppColors.gain : AppColors.loss).withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.newspaper_rounded, size: 18, color: up ? AppColors.gain : AppColors.loss),
              const SizedBox(width: 8),
              Expanded(child: Text(event.headline, style: sbText(14, weight: FontWeight.w700))),
              if (dateLabel != null) ...[
                const SizedBox(width: 6),
                Text(dateLabel!, style: sbText(11, color: AppColors.onGlassFaint)),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text('Why it matters: ${event.why}', style: sbText(13, color: AppColors.onGlassMuted, height: 1.35)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AskFinBotButton(
              dense: true,
              prompt: 'In my investment trainer, the news was "${event.headline}". Why would that move prices, '
                  'and how should a long-term investor react?',
            ),
          ),
        ],
      ),
    );
  }
}

/// +1 day / +1 month / +6 months / +1 year.
class FastForwardBar extends StatelessWidget {
  final SandboxModule module;
  final ValueChanged<int> onForward; // days
  const FastForwardBar({super.key, required this.module, required this.onForward});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final now = vm.simDate(module);
    final options = <(String, int)>[
      ('+1 day', 1),
      ('+1 month', daysBetween(now, addMonths(now, 1))),
      ('+6 months', daysBetween(now, addMonths(now, 6))),
      ('+1 year', daysBetween(now, addMonths(now, 12))),
    ];
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fast_forward_rounded, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Sim date: ${shortDate(now)}', style: sbText(14, weight: FontWeight.w700)),
              ),
              Text('Day ${vm.simDay(module)}', style: sbText(12, color: AppColors.onGlassFaint)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, days) in options)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: vm.busy ? null : () => onForward(days),
                  child: Text(label, style: sbText(13, weight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wraps a screen: shows confetti and a banner for every celebration the
/// shared view model emits (level-ups, badges, challenges, maturities).
class CelebrationHost extends StatefulWidget {
  final Widget child;
  const CelebrationHost({super.key, required this.child});

  @override
  State<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends State<CelebrationHost> with SingleTickerProviderStateMixin {
  StreamSubscription<SandboxCelebration>? _sub;
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  SandboxCelebration? _current;
  final List<SandboxCelebration> _queue = [];
  Timer? _hide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.read<SandboxViewModel>().celebrations.listen(_onCelebration);
  }

  void _onCelebration(SandboxCelebration c) {
    if (!mounted) return;
    // Only the top-most route celebrates.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (_current != null) {
      _queue.add(c);
      return;
    }
    _show(c);
  }

  void _show(SandboxCelebration c) {
    setState(() => _current = c);
    HapticFeedback.mediumImpact();
    if (!reduceMotion(context)) _confetti.forward(from: 0);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() => _current = null);
      if (_queue.isNotEmpty) _show(_queue.removeAt(0));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _current;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, __) => _confetti.isAnimating
                  ? CustomPaint(painter: ConfettiPainter(_confetti.value))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        if (c != null)
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassCard(
                    gradient: AppGradients.heroCard,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(c.icon, color: AppColors.gold, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c.title, style: sbText(15, weight: FontWeight.w800)),
                              if (c.subtitle != null)
                                Text(c.subtitle!, style: sbText(13, color: AppColors.onGlassMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: -0.6, duration: 350.ms, curve: Curves.easeOutBack).fadeIn(),
          ),
      ],
    );
  }
}

/// Deterministic confetti burst; [t] runs 0..1.
class ConfettiPainter extends CustomPainter {
  final double t;
  ConfettiPainter(this.t);

  static const _colors = [AppColors.gold, AppColors.accentCyan, AppColors.gain, AppColors.accentLavender, Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final vx = (rnd.nextDouble() - 0.5) * 160;
      final vy = 120 + rnd.nextDouble() * 260;
      final spin = rnd.nextDouble() * 10;
      final x = x0 + vx * t;
      final y = -20 + vy * t * 1.6 + 260 * t * t;
      if (y > size.height) continue;
      paint.color = _colors[i % _colors.length].withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * t * math.pi);
      canvas.drawRect(const Rect.fromLTWH(-4, -2, 8, 4), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) => old.t != t;
}

/// Confirm-and-explain dialog used by resets and early closes.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required List<String> lines,
  required String confirmLabel,
  bool destructive = true,
  Widget? extra,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(l, style: sbText(14, color: AppColors.onGlassMuted, height: 1.35))),
                  ],
                ),
              ),
            if (extra != null) extra,
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.lossStrong, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Little coins that pop up when payouts arrive during fast-forward.
class CoinBurst extends StatelessWidget {
  final int count;
  const CoinBurst({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const Icon(Icons.monetization_on, color: AppColors.gold, size: 28);
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            const Icon(Icons.monetization_on, color: AppColors.gold, size: 26)
                .animate(delay: (i * 90).ms)
                .moveY(begin: 24, end: 0, duration: 450.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 250.ms),
        ],
      ),
    );
  }
}
