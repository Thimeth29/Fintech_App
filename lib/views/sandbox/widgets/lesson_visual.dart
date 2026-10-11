// Small animated illustrations for lesson cards, keyed by the `visual`
// field in the lesson JSON. Unknown keys fall back to a pulsing icon.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import 'sandbox_widgets.dart';

class LessonVisual extends StatefulWidget {
  final String kind;
  final Color color;
  const LessonVisual({super.key, required this.kind, this.color = AppColors.accentCyan});

  @override
  State<LessonVisual> createState() => _LessonVisualState();
}

class _LessonVisualState extends State<LessonVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _icons = <String, IconData>{
    'bank': Icons.account_balance_rounded,
    'clock': Icons.schedule_rounded,
    'calendar': Icons.calendar_month_rounded,
    'shield': Icons.shield_rounded,
    'warning': Icons.warning_amber_rounded,
    'receipt': Icons.receipt_long_rounded,
    'percent': Icons.percent_rounded,
    'target': Icons.track_changes_rounded,
    'idea': Icons.lightbulb_outline_rounded,
    'gold': Icons.diamond_outlined,
    'chart_index': Icons.insights_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final painter = switch (widget.kind) {
      'pie' => _PiePainter(_c, widget.color),
      'line_up' => _LinePainter(_c, widget.color, up: true),
      'line_down' => _LinePainter(_c, AppColors.loss, up: false),
      'candles' => _CandlePainter(_c),
      'coins' => _CoinsPainter(_c),
      'ladder' => _LadderPainter(_c, widget.color),
      'seesaw' => _SeesawPainter(_c, widget.color),
      'scale' => _SeesawPainter(_c, widget.color, balanced: true),
      _ => null,
    };
    if (painter == null) {
      final icon = Icon(_icons[widget.kind] ?? Icons.auto_awesome_rounded, size: 72, color: widget.color);
      return SizedBox(
        height: 140,
        child: Center(
          child: reduceMotion(context)
              ? icon
              : icon
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.92, end: 1.05, duration: 1200.ms, curve: Curves.easeInOut),
        ),
      );
    }
    return SizedBox(height: 140, width: double.infinity, child: CustomPaint(painter: painter));
  }
}

abstract class _AnimPainter extends CustomPainter {
  final Animation<double> a;
  _AnimPainter(this.a) : super(repaint: a);
  double get t => Curves.easeOutCubic.transform(a.value);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PiePainter extends _AnimPainter {
  final Color color;
  _PiePainter(super.a, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.height * 0.42;
    const shares = [0.4, 0.25, 0.2, 0.15];
    var start = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * 2 * math.pi * t;
      final paint = Paint()..color = AppColors.chartSeries[i % AppColors.chartSeries.length];
      final offset = i == 1 ? Offset.fromDirection(start + sweep / 2, 8 * t) : Offset.zero;
      canvas.drawArc(Rect.fromCircle(center: c + offset, radius: r), start, sweep, true, paint);
      start += shares[i] * 2 * math.pi * t;
    }
  }
}

class _LinePainter extends _AnimPainter {
  final Color color;
  final bool up;
  _LinePainter(super.a, this.color, {required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    const pts = [0.2, 0.35, 0.3, 0.5, 0.45, 0.62, 0.58, 0.8];
    final w = size.width * 0.7, left = size.width * 0.15;
    final path = Path();
    final n = (pts.length * t).clamp(1, pts.length).toDouble();
    for (var i = 0; i < n.ceil(); i++) {
      final v = up ? pts[i] : 1 - pts[i];
      final p = Offset(left + w * i / (pts.length - 1), size.height * (0.9 - 0.8 * v));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

class _CandlePainter extends _AnimPainter {
  _CandlePainter(super.a);

  @override
  void paint(Canvas canvas, Size size) {
    const data = [(0.3, 0.5, 0.2, 0.6), (0.5, 0.45, 0.4, 0.6), (0.45, 0.65, 0.4, 0.7), (0.65, 0.55, 0.5, 0.72), (0.55, 0.78, 0.5, 0.85)];
    final cw = size.width * 0.07;
    for (var i = 0; i < data.length; i++) {
      final appear = ((t * data.length) - i).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      final (o, c, l, h) = data[i];
      final x = size.width * (0.25 + i * 0.12);
      double y(double v) => size.height * (0.95 - 0.85 * v);
      final up = c >= o;
      final paint = Paint()..color = (up ? AppColors.gain : AppColors.loss).withValues(alpha: appear);
      canvas.drawLine(Offset(x, y(h)), Offset(x, y(l)), paint..strokeWidth = 2);
      canvas.drawRect(Rect.fromLTRB(x - cw / 2, y(math.max(o, c)), x + cw / 2, y(math.min(o, c))), paint);
    }
  }
}

class _CoinsPainter extends _AnimPainter {
  _CoinsPainter(super.a);

  @override
  void paint(Canvas canvas, Size size) {
    const stacks = [2, 3, 5, 8];
    for (var s = 0; s < stacks.length; s++) {
      final x = size.width * (0.3 + s * 0.13);
      final shown = (stacks[s] * t).round();
      for (var k = 0; k < shown; k++) {
        final rect = Rect.fromCenter(center: Offset(x, size.height * 0.9 - k * 12), width: 40, height: 12);
        canvas.drawOval(rect, Paint()..color = AppColors.gold);
        canvas.drawOval(rect, Paint()
          ..color = const Color(0xFFD97706)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }
}

class _LadderPainter extends _AnimPainter {
  final Color color;
  _LadderPainter(super.a, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const labels = ['3m', '6m', '12m'];
    for (var i = 0; i < 3; i++) {
      final appear = ((t * 3) - i).clamp(0.0, 1.0);
      final w = size.width * (0.25 + 0.2 * i) * appear;
      final y = size.height * (0.2 + i * 0.28);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.15, y, w, 22), const Radius.circular(8));
      canvas.drawRRect(r, Paint()..color = AppColors.chartSeries[i + 1].withValues(alpha: 0.85));
      if (appear > 0.6) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: const TextStyle(color: AppColors.onLight, fontSize: 12, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width * 0.15 + 8, y + 4));
      }
    }
  }
}

class _SeesawPainter extends _AnimPainter {
  final Color color;
  final bool balanced;
  _SeesawPainter(super.a, this.color, {this.balanced = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.65);
    final angle = balanced ? math.sin(a.value * math.pi * 2) * 0.08 : -0.28 * t;
    final half = size.width * 0.3;
    final dir = Offset(math.cos(angle), math.sin(angle)) * half;
    final beam = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - dir, c + dir, beam);
    final tri = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx - 16, c.dy + 30)
      ..lineTo(c.dx + 16, c.dy + 30)
      ..close();
    canvas.drawPath(tri, Paint()..color = AppColors.onGlassFaint);
    void label(String s, Offset at, Color col) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, 26));
    }

    label(balanced ? 'Risk' : 'Yield ↑', c - dir, balanced ? AppColors.loss : AppColors.warning);
    label(balanced ? 'Return' : 'Price ↓', c + dir, balanced ? AppColors.gain : AppColors.loss);
  }
}
