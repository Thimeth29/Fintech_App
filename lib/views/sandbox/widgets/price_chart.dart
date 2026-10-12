// Animated line chart for simulated prices: morphs smoothly to new data
// (fast-forward), draws a gradient fill, and pulses a marker on the
// latest price. Pure CustomPainter so it's light on web.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import 'sandbox_widgets.dart';

class SandboxLineChart extends StatefulWidget {
  final List<double> values;
  final Color color;
  final double height;

  /// Horizontal reference line, e.g. the user's average buy price.
  final double? reference;
  final String? referenceLabel;

  const SandboxLineChart({
    super.key,
    required this.values,
    this.color = AppColors.accentCyan,
    this.height = 160,
    this.reference,
    this.referenceLabel,
  });

  @override
  State<SandboxLineChart> createState() => _SandboxLineChartState();
}

class _SandboxLineChartState extends State<SandboxLineChart> with TickerProviderStateMixin {
  late final AnimationController _morph =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..value = 1;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  List<double> _from = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SandboxLineChart old) {
    super.didUpdateWidget(old);
    if (!_listEquals(old.values, widget.values)) {
      _from = old.values;
      if (reduceMotion(context)) {
        _morph.value = 1;
      } else {
        _morph.forward(from: 0);
      }
    }
  }

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _morph.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_morph, _pulse]),
          builder: (_, __) => CustomPaint(
            painter: _LinePainter(
              from: _from,
              to: widget.values,
              t: Curves.easeInOutCubic.transform(_morph.value),
              pulse: _pulse.value,
              color: widget.color,
              reference: widget.reference,
              referenceLabel: widget.referenceLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> from;
  final List<double> to;
  final double t;
  final double pulse;
  final Color color;
  final double? reference;
  final String? referenceLabel;

  _LinePainter({
    required this.from,
    required this.to,
    required this.t,
    required this.pulse,
    required this.color,
    this.reference,
    this.referenceLabel,
  });

  double _valueAt(int i) {
    final target = to[i];
    if (from.isEmpty || t >= 1) return target;
    // Map index proportionally so different lengths still morph.
    final j = (i / math.max(1, to.length - 1) * (from.length - 1)).round().clamp(0, from.length - 1);
    return ui.lerpDouble(from[j], target, t)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (to.length < 2) return;
    final vals = [for (var i = 0; i < to.length; i++) _valueAt(i)];
    var lo = vals.reduce(math.min), hi = vals.reduce(math.max);
    if (reference != null) {
      lo = math.min(lo, reference!);
      hi = math.max(hi, reference!);
    }
    final pad = (hi - lo) * 0.12 + hi.abs() * 0.002 + 1e-9;
    lo -= pad;
    hi += pad;
    const left = 0.0, right = 54.0, top = 8.0, bottom = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double x(int i) => left + w * i / (vals.length - 1);
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));

    final grid = Paint()
      ..color = AppColors.chartGrid
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final gy = top + h * k / 3;
      canvas.drawLine(Offset(left, gy), Offset(left + w, gy), grid);
      final v = hi - (hi - lo) * k / 3;
      _label(canvas, _short(v), Offset(left + w + 6, gy - 7), AppColors.onGlassFaint);
    }

    final path = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      final px = x(i - 1), py = y(vals[i - 1]);
      final cx = x(i), cy = y(vals[i]);
      final mx = (px + cx) / 2;
      path.cubicTo(mx, py, mx, cy, cx, cy);
    }
    final fill = Path.from(path)
      ..lineTo(x(vals.length - 1), top + h)
      ..lineTo(x(0), top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, top),
          Offset(0, top + h),
          [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    if (reference != null) {
      final ry = y(reference!);
      final dash = Paint()
        ..color = AppColors.warning.withValues(alpha: 0.8)
        ..strokeWidth = 1.2;
      for (var dx = left; dx < left + w; dx += 8) {
        canvas.drawLine(Offset(dx, ry), Offset(math.min(dx + 4, left + w), ry), dash);
      }
      if (referenceLabel != null) _label(canvas, referenceLabel!, Offset(left + 4, ry - 16), AppColors.warning);
    }

    final last = Offset(x(vals.length - 1), y(vals.last));
    canvas.drawCircle(last, 4 + 10 * pulse, Paint()..color = color.withValues(alpha: 0.35 * (1 - pulse)));
    canvas.drawCircle(last, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 3, Paint()..color = color);
  }

  static String _short(double v) {
    if (v.abs() >= 100000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v.abs() >= 1000) return formatRs(v, decimals: 0).replaceFirst('Rs ', '');
    return v.toStringAsFixed(v.abs() >= 100 ? 1 : 2);
  }

  void _label(Canvas canvas, String text, Offset at, Color c) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.t != t || old.pulse != pulse || old.to != to || old.reference != reference;
}
