// Live candlestick chart for the trading module. Candles come from the
// deterministic tick path; the latest close glides to each new tick, the
// current-price marker pulses, the price tag flashes green/red, and the
// stop-loss / take-profit lines can be dragged.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/sandbox/price_engine.dart';
import 'sandbox_widgets.dart';

class CandleChart extends StatefulWidget {
  final IntradaySeries series;
  final int tick;
  final int ticksPerCandle;
  final double? entry;
  final double? stopLoss;
  final double? takeProfit;
  final double height;

  /// Called while dragging (preview) and on release (commit).
  final void Function(double? stopLoss, double? takeProfit)? onRiskChanged;
  final void Function(double? stopLoss, double? takeProfit)? onRiskCommitted;

  const CandleChart({
    super.key,
    required this.series,
    required this.tick,
    required this.ticksPerCandle,
    this.entry,
    this.stopLoss,
    this.takeProfit,
    this.height = 280,
    this.onRiskChanged,
    this.onRiskCommitted,
  });

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> with TickerProviderStateMixin {
  late final AnimationController _glide =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..value = 1;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  double _from = 0;
  double _to = 0;
  int _flash = 0; // 1 up, -1 down

  // Drag state.
  String? _dragging; // 'sl' | 'tp'
  double? _dragSl;
  double? _dragTp;
  _Scale? _scale;

  @override
  void initState() {
    super.initState();
    _to = _from = widget.series.at(widget.tick);
  }

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
  void didUpdateWidget(covariant CandleChart old) {
    super.didUpdateWidget(old);
    final p = widget.series.at(widget.tick);
    if (old.tick != widget.tick || old.series != widget.series) {
      _from = old.series == widget.series ? _current : p;
      _to = p;
      _flash = p > _from ? 1 : (p < _from ? -1 : 0);
      if (reduceMotion(context)) {
        _glide.value = 1;
      } else {
        _glide.forward(from: 0);
      }
    }
  }

  double get _current => ui.lerpDouble(_from, _to, Curves.easeOut.transform(_glide.value))!;

  @override
  void dispose() {
    _glide.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    final s = _scale;
    if (s == null || widget.onRiskCommitted == null) return;
    final y = d.localPosition.dy;
    double? dist(double? price) => price == null ? null : (s.y(price) - y).abs();
    final dSl = dist(widget.stopLoss), dTp = dist(widget.takeProfit);
    const grab = 22.0;
    if (dSl != null && dSl < grab && (dTp == null || dSl <= dTp)) {
      _dragging = 'sl';
    } else if (dTp != null && dTp < grab) {
      _dragging = 'tp';
    }
    _dragSl = widget.stopLoss;
    _dragTp = widget.takeProfit;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final s = _scale;
    if (_dragging == null || s == null) return;
    final price = math.max(0.01, s.price(d.localPosition.dy));
    setState(() {
      if (_dragging == 'sl') {
        _dragSl = double.parse(price.toStringAsFixed(2));
      } else {
        _dragTp = double.parse(price.toStringAsFixed(2));
      }
    });
    widget.onRiskChanged?.call(_dragSl, _dragTp);
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dragging == null) return;
    _dragging = null;
    widget.onRiskCommitted?.call(_dragSl, _dragTp);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: GestureDetector(
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: RepaintBoundary(
          child: LayoutBuilder(builder: (context, c) {
            final count = (c.maxWidth / 11).floor().clamp(12, 60);
            final candles = widget.series.candles(endTick: widget.tick, ticksPerCandle: widget.ticksPerCandle, count: count);
            return AnimatedBuilder(
              animation: Listenable.merge([_glide, _pulse]),
              builder: (_, __) => CustomPaint(
                size: Size(c.maxWidth, widget.height),
                painter: _CandlePainter(
                  candles: candles,
                  current: _current,
                  pulse: _pulse.value,
                  flash: _flash,
                  flashT: _glide.value,
                  entry: widget.entry,
                  stopLoss: _dragging == null ? widget.stopLoss : _dragSl,
                  takeProfit: _dragging == null ? widget.takeProfit : _dragTp,
                  onScale: (s) => _scale = s,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Scale {
  final double lo, hi, top, h;
  const _Scale(this.lo, this.hi, this.top, this.h);
  double y(double v) => top + h * (1 - (v - lo) / (hi - lo));
  double price(double y) => lo + (1 - (y - top) / h) * (hi - lo);
}

class _CandlePainter extends CustomPainter {
  final List<Candle> candles;
  final double current;
  final double pulse;
  final int flash;
  final double flashT;
  final double? entry, stopLoss, takeProfit;
  final void Function(_Scale) onScale;

  _CandlePainter({
    required this.candles,
    required this.current,
    required this.pulse,
    required this.flash,
    required this.flashT,
    required this.onScale,
    this.entry,
    this.stopLoss,
    this.takeProfit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    const right = 64.0, top = 10.0, bottom = 10.0;
    final w = size.width - right;
    final h = size.height - top - bottom;
    var lo = candles.map((c) => c.low).reduce(math.min);
    var hi = candles.map((c) => c.high).reduce(math.max);
    for (final v in [current, entry, stopLoss, takeProfit]) {
      if (v == null) continue;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final pad = (hi - lo) * 0.08 + hi * 0.0005;
    lo -= pad;
    hi += pad;
    final s = _Scale(lo, hi, top, h);
    onScale(s);

    final grid = Paint()
      ..color = AppColors.chartGrid
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final gy = top + h * k / 4;
      canvas.drawLine(Offset(0, gy), Offset(w, gy), grid);
      _text(canvas, (hi - (hi - lo) * k / 4).toStringAsFixed(2), Offset(w + 6, gy - 7), AppColors.onGlassFaint, 10);
    }

    final slot = w / candles.length;
    final body = math.max(2.0, slot * 0.62);
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isLast = i == candles.length - 1;
      final close = isLast ? current : c.close;
      final high = isLast ? math.max(c.high, close) : c.high;
      final low = isLast ? math.min(c.low, close) : c.low;
      final up = close >= c.open;
      final color = up ? AppColors.gain : AppColors.loss;
      final x = slot * i + slot / 2;
      canvas.drawLine(Offset(x, s.y(high)), Offset(x, s.y(low)), Paint()
        ..color = color
        ..strokeWidth = 1.2);
      final top0 = s.y(math.max(c.open, close)), bot0 = s.y(math.min(c.open, close));
      canvas.drawRect(Rect.fromLTRB(x - body / 2, top0, x + body / 2, math.max(bot0, top0 + 1)), Paint()..color = color);
    }

    void hLine(double? v, Color c, String label, {bool dashed = true}) {
      if (v == null) return;
      final y = s.y(v);
      final p = Paint()
        ..color = c
        ..strokeWidth = 1.4;
      if (dashed) {
        for (var x = 0.0; x < w; x += 9) {
          canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, w), y), p);
        }
      } else {
        canvas.drawLine(Offset(0, y), Offset(w, y), p);
      }
      final tag = RRect.fromRectAndRadius(Rect.fromLTWH(4, y - 9, 92, 18), const Radius.circular(6));
      canvas.drawRRect(tag, Paint()..color = c.withValues(alpha: 0.25));
      _text(canvas, '$label ${v.toStringAsFixed(2)}', Offset(8, y - 7), c, 10);
    }

    hLine(entry, AppColors.warning, 'Entry');
    hLine(stopLoss, AppColors.loss, 'Stop', dashed: false);
    hLine(takeProfit, AppColors.gain, 'Target', dashed: false);

    // Current price line, tag (flashing on change) and pulsing marker.
    final cy = s.y(current);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var x = 0.0; x < w; x += 6) {
      canvas.drawLine(Offset(x, cy), Offset(math.min(x + 3, w), cy), linePaint);
    }
    final flashColor = flash > 0 ? AppColors.gainStrong : (flash < 0 ? AppColors.lossStrong : AppColors.primary);
    final tagRect = RRect.fromRectAndRadius(Rect.fromLTWH(w + 2, cy - 10, right - 4, 20), const Radius.circular(6));
    canvas.drawRRect(tagRect, Paint()..color = Color.lerp(flashColor, AppColors.primary, flashT)!);
    _text(canvas, current.toStringAsFixed(2), Offset(w + 6, cy - 7), Colors.white, 11, bold: true);
    final mx = slot * (candles.length - 1) + slot / 2;
    canvas.drawCircle(Offset(mx, cy), 4 + 9 * pulse, Paint()..color = Colors.white.withValues(alpha: 0.3 * (1 - pulse)));
    canvas.drawCircle(Offset(mx, cy), 3.5, Paint()..color = Colors.white);
  }

  void _text(Canvas canvas, String t, Offset at, Color c, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: c, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) => true;
}
