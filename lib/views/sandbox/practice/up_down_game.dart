// "Up or Down?" — the binary-options lesson. Guess whether the price will
// be higher in 30 or 60 seconds. A win pays 1.8x the stake, less than the
// 2x a fair 50/50 bet would need, so the player loses ~10% of everything
// staked in the long run. After 10 rounds the stats screen shows exactly
// that.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/top_nav_bar.dart';
import '../../../services/sandbox/sim_math.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../widgets/sandbox_widgets.dart';
import 'trading_practice.dart';

class _Round {
  final String stakeId;
  final String symbol;
  final bool up;
  final double stake;
  final int startTick;
  final int endTick;
  final double startPrice;
  const _Round(this.stakeId, this.symbol, this.up, this.stake, this.startTick, this.endTick, this.startPrice);
}

class UpDownGame extends StatefulWidget {
  final TradingSession session;
  final String symbol;
  const UpDownGame({super.key, required this.session, required this.symbol});

  @override
  State<UpDownGame> createState() => _UpDownGameState();
}

class _UpDownGameState extends State<UpDownGame> {
  final _stake = TextEditingController(text: '1,000');
  int _seconds = 30;
  _Round? _round;
  UpDownRound? _last;
  bool _starting = false;
  late final SandboxViewModel _vm = context.read<SandboxViewModel>();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onTick);
    // Leaving mid-round: the tick path is deterministic, so the round is
    // settled with the price it will have at its end tick.
    final r = _round;
    if (r != null) _settle(r, mounted: false);
    _stake.dispose();
    super.dispose();
  }

  void _onTick() {
    final r = _round;
    if (r != null && widget.session.tick >= r.endTick) _settle(r);
  }

  Future<void> _settle(_Round r, {bool mounted = true}) async {
    _round = null;
    final end = widget.session.series[r.symbol]!.at(r.endTick);
    final won = r.up ? end > r.startPrice : end < r.startPrice; // a tie loses
    final round = UpDownRound(
        symbol: r.symbol, predictedUp: r.up, stake: r.stake, startPrice: r.startPrice, endPrice: end, won: won);
    final res = await _vm.settleUpDown(r.stakeId, round);
    if (!mounted || !this.mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _last = round);
    if (!res.ok) sandboxSnack(context, res.error!, error: true);
  }

  Future<void> _play(bool up) async {
    final stake = parseAmount(_stake.text);
    if (stake == null || stake <= 0) {
      sandboxSnack(context, 'Enter a stake greater than zero.', error: true);
      return;
    }
    setState(() => _starting = true);
    final res = await _vm.startUpDown(widget.symbol, stake, predictUp: up);
    if (!mounted) return;
    setState(() => _starting = false);
    if (!res.ok) {
      sandboxSnack(context, res.error!, error: true);
      return;
    }
    final t = widget.session.tick;
    setState(() {
      _last = null;
      _round =
          _Round(res.data as String, widget.symbol, up, stake, t, t + _seconds, widget.session.priceOf(widget.symbol));
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final r = _round;
    final rounds = vm.upDownRounds.length;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.casino_outlined, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(child: Text('Up or Down?', style: sbText(17, weight: FontWeight.w800))),
              Text('$rounds played', style: sbText(12, color: AppColors.onGlassFaint)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Guess where ${widget.symbol} will be in $_seconds seconds. A win pays ${kUpDownPayout}x your stake; '
            'a loss (or a tie) loses it. This is how "binary options" apps work.',
            style: sbText(13, color: AppColors.onGlassMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          if (r != null)
            _Countdown(session: widget.session, round: r)
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stake,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Stake (Rs)'),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30s')),
                    ButtonSegment(value: 60, label: Text('60s'))
                  ],
                  selected: {_seconds},
                  onSelectionChanged: (v) => setState(() => _seconds = v.first),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gainStrong, foregroundColor: Colors.white),
                    onPressed: _starting || vm.lossLimitHit ? null : () => _play(true),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: const Text('Up'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.lossStrong, foregroundColor: Colors.white),
                    onPressed: _starting || vm.lossLimitHit ? null : () => _play(false),
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: const Text('Down'),
                  ),
                ),
              ],
            ),
          ],
          if (_last != null) _Result(round: _last!),
          if (rounds >= kUpDownStatsRounds) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showStats(context, vm),
                icon: const Icon(Icons.query_stats_rounded),
                label: Text(vm.upDownStatsSeen ? 'Your stats' : 'See your stats — why this game loses'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  'Play $kUpDownStatsRounds rounds to unlock the stats screen (${kUpDownStatsRounds - rounds} to go).',
                  style: sbText(12, color: AppColors.onGlassFaint)),
            ),
        ],
      ),
    );
  }

  Future<void> _showStats(BuildContext context, SandboxViewModel vm) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpDownStatsScreen()));
    if (!vm.upDownStatsSeen) await vm.markUpDownStatsRead();
  }
}

class _Countdown extends StatelessWidget {
  final TradingSession session;
  final _Round round;
  const _Countdown({required this.session, required this.round});

  @override
  Widget build(BuildContext context) {
    final total = round.endTick - round.startTick;
    final left = (round.endTick - session.tick).clamp(0, total);
    final now = session.priceOf(round.symbol);
    final winning = round.up ? now > round.startPrice : now < round.startPrice;
    return Row(
      children: [
        ProgressRing(
          value: total == 0 ? 0 : left / total,
          size: 72,
          stroke: 7,
          color: winning ? AppColors.gain : AppColors.loss,
          child: Text('${left}s', style: sbText(18, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You picked ${round.up ? 'UP' : 'DOWN'} with ${formatRs(round.stake)}',
                  style: sbText(14, weight: FontWeight.w700)),
              Text('Start ${round.startPrice.toStringAsFixed(2)} → now ${now.toStringAsFixed(2)}',
                  style: sbText(13, color: AppColors.onGlassMuted)),
              Text(winning ? 'Winning… for now' : 'Losing… for now',
                  style: sbText(13, weight: FontWeight.w700, color: winning ? AppColors.gain : AppColors.loss)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  final UpDownRound round;
  const _Result({required this.round});

  @override
  Widget build(BuildContext context) {
    final w = round.won;
    final card = Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (w ? AppColors.gainStrong : AppColors.lossStrong).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(w ? Icons.check_circle_rounded : Icons.cancel_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              w
                  ? 'Won! +${formatRs(round.net)} (paid ${formatRs(round.stake * kUpDownPayout)} on a ${formatRs(round.stake)} stake)'
                  : 'Lost ${formatRs(round.stake)}. Price went ${round.endPrice.toStringAsFixed(2)} vs ${round.startPrice.toStringAsFixed(2)}.',
              style: sbText(14, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (reduceMotion(context)) return card;
    return card.animate().scaleXY(begin: 0.85, end: 1, duration: 300.ms, curve: Curves.easeOutBack).fadeIn();
  }
}

class UpDownStatsScreen extends StatelessWidget {
  const UpDownStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final rounds = vm.upDownRounds;
    final staked = rounds.fold(0.0, (s, r) => s + r.stake);
    final net = rounds.fold(0.0, (s, r) => s + r.net);
    final wins = rounds.where((r) => r.won).length;
    final ev = rounds.fold(0.0, (s, r) => s + UpDownMath.expectedValue(r.stake));
    final edge = UpDownMath.houseEdge();
    return GradientScaffold(
      maxContentWidth: 760,
      appBar: const TopNavBar(
          current: AppSection.sandbox, title: 'Your Up-or-Down stats', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.sandbox, isSectionRoot: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TileGrid(children: [
            StatTile(label: 'Rounds', value: '${rounds.length}'),
            StatTile(label: 'Wins', value: '$wins (${rounds.isEmpty ? 0 : (wins / rounds.length * 100).round()}%)'),
            StatTile(label: 'Total staked', value: formatRs(staked)),
            StatTile(label: 'Actual result', value: signedRs(net), valueColor: pnlColor(net)),
            StatTile(
                label: 'Expected value', value: signedRs(ev), valueColor: pnlColor(ev), sub: 'what the maths predicts'),
            StatTile(
                label: 'Break-even win rate', value: '${(UpDownMath.breakEvenWinRate() * 100).toStringAsFixed(1)}%'),
          ]),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why the house always wins', style: sbText(17, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Each round is roughly a coin flip. A fair coin-flip bet would pay 2x. This one pays ${kUpDownPayout}x.\n\n'
                  'Expected value per round = 50% × $kUpDownPayout × stake − stake = −${(edge * 100).round()}% of the stake. '
                  'You might be ahead after a lucky streak, but over many rounds you lose about '
                  '${(edge * 100).round()}% of everything you stake — guaranteed by the payout structure, not by bad luck.\n\n'
                  'To break even you\'d need to be right ${(UpDownMath.breakEvenWinRate() * 100).toStringAsFixed(1)}% of the time '
                  'on movements that are essentially random over 30–60 seconds.\n\n'
                  'Real "binary options" and "fixed-time trading" apps work exactly like this, often with worse payouts. '
                  'Many are unlicensed. That\'s why they\'re one of the warning signs in the scams lesson.',
                  style: sbText(14, color: AppColors.onGlassMuted, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AskFinBotButton(
            prompt: 'I played ${rounds.length} rounds of a 60-second up/down game paying ${kUpDownPayout}x. '
                'I ${net >= 0 ? 'made' : 'lost'} ${formatRs(net.abs())}. Explain why games like this lose money long-term.',
          ),
          const SimulatedLabel(),
        ],
      ),
    );
  }
}
