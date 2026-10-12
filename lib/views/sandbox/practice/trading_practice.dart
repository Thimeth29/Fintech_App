// Short-term trading: real-time ticks (1 per second, or 2x / 5x), live
// candlesticks, stop-loss / take-profit, and the safety rules: a daily
// loss limit, a take-a-break nudge, and rewards for good habits only.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/sandbox_models.dart';
import '../../../services/sandbox/price_engine.dart';
import '../../../services/sandbox/sim_math.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../widgets/candle_chart.dart';
import '../widgets/sandbox_widgets.dart';
import '../widgets/trade_sheet.dart';
import 'up_down_game.dart';

int secondsSinceMidnight(DateTime t) => t.hour * 3600 + t.minute * 60 + t.second;

/// Drives the tick clock for every trading instrument while the screen is
/// open. Lives only as long as the screen; the tick offset (from speed-ups)
/// is kept on the shared view model.
class TradingSession extends ChangeNotifier {
  final SandboxViewModel vm;
  final DateTime day = dateOnly(DateTime.now());
  late final Map<String, IntradaySeries> series = {
    for (final s in kTradingInstruments) s.symbol: vm.engine.intraday(s, vm.tradingDayOpen(s), day),
  };
  late int tick = secondsSinceMidnight(DateTime.now()) + vm.tradingTickOffset;
  int speed = 1;
  Timer? _timer;
  final Set<String> _closing = {};
  final List<NewsEvent> news = [];
  bool lossLimitJustHit = false;
  bool breakNudgeDue = false;
  bool _nudged = false;
  String? autoCloseMessage;

  TradingSession(this.vm) {
    vm.beginTradingSession();
    _publishPrices();
    _start();
  }

  double priceOf(String symbol) => series[symbol]!.at(tick);

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ speed), (_) => _onTick());
  }

  void setSpeed(int s) {
    speed = s;
    _start();
    notifyListeners();
  }

  void _publishPrices() {
    for (final s in kTradingInstruments) {
      vm.liveTradingPrices[s.symbol] = priceOf(s.symbol);
    }
  }

  void _onTick() {
    tick++;
    vm.tradingTickOffset = tick - secondsSinceMidnight(DateTime.now());
    _publishPrices();
    for (final s in kTradingInstruments) {
      final n = series[s.symbol]!.newsAt(tick);
      if (n != null) news.insert(0, n);
    }
    if (news.length > 5) news.removeRange(5, news.length);
    _checkTriggers();
    if (vm.checkLossLimit()) lossLimitJustHit = true;
    final started = vm.sessionStartedAt;
    if (!_nudged && started != null && DateTime.now().difference(started) >= kTakeABreakAfter) {
      _nudged = true;
      breakNudgeDue = true;
    }
    notifyListeners();
  }

  /// Stop-losses and take-profits are watched here and closed through the
  /// same server RPC as a manual trade.
  void _checkTriggers() {
    for (final h in vm.holdingsFor(SandboxModule.trading)) {
      if (_closing.contains(h.symbol)) continue;
      final hit = TradeMath.triggered(h, priceOf(h.symbol));
      if (hit == null) continue;
      final spec = instrumentBySymbol(h.symbol);
      if (spec == null) continue;
      _closing.add(h.symbol);
      vm
          .trade(spec: spec, side: h.isShort ? 'cover' : 'sell', quantity: h.quantity, note: hit)
          .then((res) {
        _closing.remove(h.symbol);
        autoCloseMessage = res.ok
            ? '${hit == 'stop_loss' ? 'Stop-loss' : 'Take-profit'} hit on ${spec.name}: '
                '${(res.realisedPnl ?? 0) >= 0 ? 'profit' : 'loss'} ${formatRs((res.realisedPnl ?? 0).abs())}'
            : 'Couldn\'t close ${spec.name}: ${res.error}';
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class TradingPractice extends StatefulWidget {
  const TradingPractice({super.key});

  @override
  State<TradingPractice> createState() => _TradingPracticeState();
}

class _TradingPracticeState extends State<TradingPractice> {
  late final TradingSession _session = TradingSession(context.read<SandboxViewModel>());
  String _symbol = kTradingInstruments.first.symbol;
  int _tpc = 60; // ticks per candle: 1m
  double? _previewSl, _previewTp;
  bool _tookBreak = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
  }

  void _onSession() {
    if (!mounted) return;
    if (_session.autoCloseMessage != null) {
      final msg = _session.autoCloseMessage!;
      _session.autoCloseMessage = null;
      sandboxSnack(context, msg, error: msg.contains('loss'));
    }
    if (_session.lossLimitJustHit) {
      _session.lossLimitJustHit = false;
      _showLossLimit();
    }
    if (_session.breakNudgeDue) {
      _session.breakNudgeDue = false;
      _showBreakNudge();
    }
  }

  Future<void> _showLossLimit() async {
    final vm = context.read<SandboxViewModel>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily loss limit reached'),
        content: Text(
          'You\'ve lost ${formatRs(vm.sessionLoss)} today — ${(kDailyLossLimitShare * 100).round()}% of your trading wallet. '
          'New trades are paused until tomorrow. You can still close positions.\n\n'
          'Stopping after a loss limit is what disciplined traders do. Chasing losses ("revenge trading") is how small losses become big ones.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              vm.acknowledgeLossLimit();
              Navigator.pop(ctx);
            },
            child: const Text('I\'ll stop for today'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBreakNudge() async {
    final takeBreak = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Time for a break?'),
        content: const Text(
            'You\'ve been trading for 30 minutes. Staring at ticks wears down judgement — step away, stretch, come back fresh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Take a break')),
        ],
      ),
    );
    if (takeBreak == true && mounted) {
      _tookBreak = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    final vm = _session.vm;
    _session.removeListener(_onSession);
    _session.dispose();
    final tookBreak = _tookBreak;
    // The tree is locked during dispose; notify listeners afterwards.
    Future.microtask(() => vm.endTradingSession(tookBreak: tookBreak));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => _build(context, vm),
    );
  }

  Widget _build(BuildContext context, SandboxViewModel vm) {
    final spec = instrumentBySymbol(_symbol)!;
    final series = _session.series[_symbol]!;
    final held = vm.holdingOf(spec);
    final price = _session.priceOf(_symbol);
    final lossShare = vm.sessionLossLimit == 0 ? 0.0 : (vm.sessionLoss / vm.sessionLossLimit).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Cash: ${formatRs(vm.balance(SandboxModule.trading))}', style: sbText(15, weight: FontWeight.w700)),
            ),
            const SimulatedLabel(compact: true),
          ],
        ),
        const SizedBox(height: 8),
        Text('Fictional instruments. One tick per second is roughly one minute of a busy market.',
            style: sbText(12, color: AppColors.onGlassFaint)),
        const SizedBox(height: 12),
        if (vm.lossLimitHit)
          _Paused(loss: vm.sessionLoss)
        else
          _LossMeter(loss: vm.sessionLoss, limit: vm.sessionLossLimit, share: lossShare),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in kTradingInstruments)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TickerChip(
                    spec: s,
                    price: _session.priceOf(s.symbol),
                    open: _session.series[s.symbol]!.at(0),
                    selected: s.symbol == _symbol,
                    onTap: () => setState(() {
                      _symbol = s.symbol;
                      _previewSl = _previewTp = null;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spec.name, style: sbText(16, weight: FontWeight.w800)),
                        Text(formatRs(price), style: sbText(20, weight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  _Toggle(
                    options: const [('1m', 60), ('5m', 300), ('15m', 900)],
                    value: _tpc,
                    onChanged: (v) => setState(() => _tpc = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CandleChart(
                series: series,
                tick: _session.tick,
                ticksPerCandle: _tpc,
                entry: held?.averagePrice,
                stopLoss: _previewSl ?? held?.stopLoss,
                takeProfit: _previewTp ?? held?.takeProfit,
                onRiskChanged: held == null ? null : (sl, tp) => setState(() {
                  _previewSl = sl;
                  _previewTp = tp;
                }),
                onRiskCommitted: held == null
                    ? null
                    : (sl, tp) async {
                        final res = await vm.setRiskLevels(held, stopLoss: sl, takeProfit: tp);
                        if (!mounted) return;
                        setState(() => _previewSl = _previewTp = null);
                        if (!res.ok) sandboxSnack(this.context, res.error!, error: true);
                      },
              ),
              Row(
                children: [
                  Text('Speed', style: sbText(12, color: AppColors.onGlassMuted)),
                  const SizedBox(width: 8),
                  _Toggle(options: const [('1×', 1), ('2×', 2), ('5×', 5)], value: _session.speed, onChanged: _session.setSpeed),
                  const Spacer(),
                  if (held != null && held.stopLoss == null && held.takeProfit == null)
                    TextButton(
                      onPressed: () async {
                        final sl = double.parse((held.isShort ? price * 1.02 : price * 0.98).toStringAsFixed(2));
                        final tp = double.parse((held.isShort ? price * 0.96 : price * 1.04).toStringAsFixed(2));
                        final res = await vm.setRiskLevels(held, stopLoss: sl, takeProfit: tp);
                        if (!res.ok && mounted) sandboxSnack(this.context, res.error!, error: true);
                      },
                      child: const Text('Add stop & target'),
                    )
                  else if (held != null)
                    Text('Drag the lines to adjust', style: sbText(11, color: AppColors.onGlassFaint)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (held != null) _PositionCard(holding: held, price: price, onClose: () => _close(vm, spec, held)),
        if (held != null) const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: vm.lossLimitHit || (held?.isShort ?? false) ? null : () => showTradeSheet(context, spec),
                child: const Text('Buy (long)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: vm.lossLimitHit || held != null && !held.isShort
                    ? null
                    : () => vm.progress.level < kShortSellingLevel
                        ? sandboxSnack(context, 'Short selling unlocks at level $kShortSellingLevel.', error: true)
                        : showTradeSheet(context, spec, side: 'short'),
                child: Text(vm.progress.level < kShortSellingLevel ? 'Short 🔒' : 'Short'),
              ),
            ),
          ],
        ),
        if (_session.news.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionTitle('Breaking'),
          NewsEventCard(event: _session.news.first),
        ],
        const SizedBox(height: 18),
        UpDownGame(session: _session, symbol: _symbol),
      ],
    );
  }

  Future<void> _close(SandboxViewModel vm, InstrumentSpec spec, SandboxHolding h) async {
    final res = await vm.trade(spec: spec, side: h.isShort ? 'cover' : 'sell', quantity: h.quantity, note: 'manual');
    if (!mounted) return;
    final pnl = res.realisedPnl ?? 0;
    sandboxSnack(context, res.ok ? 'Closed: ${pnl >= 0 ? 'profit' : 'loss'} ${formatRs(pnl.abs())}' : res.error!,
        error: !res.ok || pnl < 0);
  }
}

class _Toggle extends StatelessWidget {
  final List<(String, int)> options;
  final int value;
  final ValueChanged<int> onChanged;
  const _Toggle({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.innerFill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, v) in options)
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: v == value ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(label,
                    style: sbText(12, weight: FontWeight.w700, color: v == value ? AppColors.onLight : AppColors.onGlass)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  final InstrumentSpec spec;
  final double price;
  final double open;
  final bool selected;
  final VoidCallback onTap;
  const _TickerChip({required this.spec, required this.price, required this.open, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chg = open == 0 ? 0.0 : (price / open - 1) * 100;
    return GlassCard(
      onTap: onTap,
      borderColor: selected ? AppColors.accentTeal : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(spec.symbol, style: sbText(13, weight: FontWeight.w800)),
          Text(price.toStringAsFixed(2), style: sbText(13, weight: FontWeight.w600)),
          Text(signedPct(chg), style: sbText(11, weight: FontWeight.w700, color: pnlColor(chg))),
        ],
      ),
    );
  }
}

class _LossMeter extends StatelessWidget {
  final double loss;
  final double limit;
  final double share;
  const _LossMeter({required this.loss, required this.limit, required this.share});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's loss: ${formatRs(loss)} of your ${formatRs(limit, decimals: 0)} limit",
            style: sbText(12, color: AppColors.onGlassMuted)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6,
            color: share > 0.75 ? AppColors.loss : AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _Paused extends StatelessWidget {
  final double loss;
  const _Paused({required this.loss});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.loss,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline_rounded, color: AppColors.loss, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Trading paused for today after a ${formatRs(loss)} loss. Cool down — come back tomorrow with a plan. '
              'You can still close open positions.',
              style: sbText(13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final SandboxHolding holding;
  final double price;
  final VoidCallback onClose;
  const _PositionCard({required this.holding, required this.price, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final pnl = TradeMath.unrealisedPnl(holding, price);
    final pct = holding.costBasis == 0 ? 0.0 : pnl / holding.costBasis * 100;
    return GlassCard(
      borderColor: pnlColor(pnl).withValues(alpha: 0.6),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${holding.isShort ? 'Short' : 'Long'} ${holding.quantity.toStringAsFixed(0)} @ ${formatRs(holding.averagePrice)}',
                    style: sbText(14, weight: FontWeight.w700)),
                Text(
                  'Stop ${holding.stopLoss?.toStringAsFixed(2) ?? '—'} · Target ${holding.takeProfit?.toStringAsFixed(2) ?? '—'}',
                  style: sbText(12, color: AppColors.onGlassMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AnimatedMoney(value: pnl, signed: true, style: sbText(18, weight: FontWeight.w800, color: pnlColor(pnl))),
                    const SizedBox(width: 6),
                    Text(signedPct(pct), style: sbText(12, weight: FontWeight.w700, color: pnlColor(pnl))),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: onClose, child: const Text('Close')),
        ],
      ),
    );
  }
}
