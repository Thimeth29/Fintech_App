// Buy / sell (and short / cover in Trading) sheet. Shows exactly what the
// trade costs, validates the quantity before sending, and only reports
// success after the server accepts the trade.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../services/sandbox/sim_math.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import 'sandbox_widgets.dart';

Future<void> showTradeSheet(BuildContext context, InstrumentSpec spec, {String side = 'buy'}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: TradeSheet(spec: spec, initialSide: side),
    ),
  );
}

class TradeSheet extends StatefulWidget {
  final InstrumentSpec spec;
  final String initialSide;
  const TradeSheet({super.key, required this.spec, this.initialSide = 'buy'});

  @override
  State<TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<TradeSheet> {
  late String _side = widget.initialSide;
  final _qty = TextEditingController();
  final _sl = TextEditingController();
  final _tp = TextEditingController();
  String? _error;
  bool _sending = false;

  InstrumentSpec get spec => widget.spec;
  bool get _isTrading => spec.module == SandboxModule.trading;
  bool get _opening => _side == 'buy' || _side == 'short';

  @override
  void dispose() {
    _qty.dispose();
    _sl.dispose();
    _tp.dispose();
    super.dispose();
  }

  double? get _quantity => parseAmount(_qty.text);
  double? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : parseAmount(c.text);

  String? _validate(SandboxViewModel vm, double? qty, TradeQuote? q) {
    if (qty == null || !qty.isFinite || qty <= 0) return 'Enter a quantity greater than zero.';
    if (spec.module == SandboxModule.cse && qty != qty.roundToDouble()) return 'CSE shares are whole numbers only.';
    if (q != null && _opening && q.total > vm.balance(spec.module)) {
      return 'That costs ${formatRs(q.total)}; you have ${formatRs(vm.balance(spec.module))}.';
    }
    final held = vm.holdingOf(spec);
    if (!_opening && (held == null || held.quantity < qty)) {
      return 'You only have ${held == null ? 0 : _fmtQty(held.quantity)} to ${_side == 'cover' ? 'cover' : 'sell'}.';
    }
    if (_isTrading && _opening) {
      final sl = _opt(_sl), tp = _opt(_tp);
      final price = q?.price ?? 0;
      final short = _side == 'short';
      if (sl != null && (sl <= 0 || (short ? sl <= price : sl >= price))) {
        return short ? 'A short\'s stop-loss must be above the price.' : 'Stop-loss must be below the current price.';
      }
      if (tp != null && (tp <= 0 || (short ? tp >= price : tp <= price))) {
        return short ? 'A short\'s take-profit must be below the price.' : 'Take-profit must be above the current price.';
      }
    }
    return null;
  }

  Future<void> _submit(SandboxViewModel vm) async {
    final qty = _quantity;
    final quote = qty == null || qty <= 0 ? null : vm.quoteTrade(spec, _side, qty);
    final err = _validate(vm, qty, quote);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final res = await vm.trade(
      spec: spec,
      side: _side,
      quantity: qty!,
      stopLoss: _isTrading && _opening ? _opt(_sl) : null,
      takeProfit: _isTrading && _opening ? _opt(_tp) : null,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!res.ok) {
      // Keep the sheet open with the server's reason.
      setState(() => _error = res.error);
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final pnl = res.realisedPnl;
    final verb = switch (_side) { 'buy' => 'Bought', 'sell' => 'Sold', 'short' => 'Shorted', _ => 'Covered' };
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: pnl != null && pnl < 0 ? AppColors.lossStrong : AppColors.gainStrong,
        content: Text(
          '$verb ${_fmtQty(qty)} ${spec.name}'
          '${pnl == null ? '' : ' · ${pnl >= 0 ? 'profit' : 'loss'} ${formatRs(pnl.abs())}'}',
        ),
        action: SnackBarAction(
          label: 'Ask FinBot',
          textColor: Colors.white,
          onPressed: () => AskFinBotButton.open(
            nav.context,
            pnl == null
                ? 'In my investment trainer I just ${verb.toLowerCase()} ${_fmtQty(qty)} ${spec.name}. What should I watch now?'
                : 'In my investment trainer I ${verb.toLowerCase()} ${spec.name} for a ${pnl >= 0 ? 'profit' : 'loss'} of '
                    '${formatRs(pnl.abs())}. What can I learn from this trade?',
          ),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    final qty = _quantity;
    final quote = qty == null || qty <= 0 ? null : vm.quoteTrade(spec, _side, qty);
    final unitPrice = vm.quoteTrade(spec, _side, 1).price;
    final held = vm.holdingOf(spec);
    final sides = <String>[
      if (held == null || !held.isShort) ...['buy', 'sell'],
      if (_isTrading && (held == null || held.isShort)) ...['short', 'cover'],
    ];
    if (!sides.contains(_side)) _side = sides.first;
    final shortLocked = vm.progress.level < kShortSellingLevel;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.name, style: sbText(20, weight: FontWeight.w800)),
            Text(
              '${spec.fictional ? 'Fictional instrument · ' : ''}${_opening ? 'Buy' : 'Sell'} price ${formatRs(unitPrice)}'
              '${spec.unit == 'g' ? ' per gram' : ''}',
              style: sbText(13, color: AppColors.onGlassMuted),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                for (final s in sides)
                  ButtonSegment(
                    value: s,
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    enabled: !(s == 'short' && shortLocked),
                  ),
              ],
              selected: {_side},
              onSelectionChanged: (v) => setState(() {
                _side = v.first;
                _error = null;
              }),
            ),
            if (_isTrading && shortLocked)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Short selling is an advanced skill: unlocks at level $kShortSellingLevel.',
                    style: sbText(12, color: AppColors.onGlassFaint)),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _qty,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: spec.module != SandboxModule.cse),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(spec.module == SandboxModule.cse ? r'[0-9,]' : r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: spec.unit == 'g' ? 'Grams' : (spec.unit == 'share' ? 'Number of shares' : 'Units'),
                helperText: held == null ? null : 'You hold ${_fmtQty(held.quantity)}',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final q in _quickAmounts(vm, unitPrice, held?.quantity))
                  ActionChip(
                    label: Text(q.$1),
                    onPressed: () => setState(() {
                      _qty.text = _fmtQty(q.$2);
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_isTrading && _opening) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Stop-loss (optional)'),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _tp,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Take-profit (optional)'),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _riskLine(vm, quote, qty),
            ],
            const SizedBox(height: 14),
            if (quote != null) _Breakdown(spec: spec, quote: quote, opening: _opening),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: sbText(13, weight: FontWeight.w600, color: AppColors.loss)),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending || vm.busy ? null : () => _submit(vm),
                child: _sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Text(quote == null
                        ? 'Enter a quantity'
                        : '${_side[0].toUpperCase()}${_side.substring(1)} for ${formatRs(quote.total)}'),
              ),
            ),
            const SizedBox(height: 10),
            const Center(child: SimulatedLabel()),
          ],
        ),
      ),
    );
  }

  Widget _riskLine(SandboxViewModel vm, TradeQuote? quote, double? qty) {
    final sl = _opt(_sl);
    if (quote == null || qty == null || sl == null) {
      return Text('Tip: a stop-loss risking 2% or less of your wallet is a good habit (and earns XP).',
          style: sbText(12, color: AppColors.onGlassFaint));
    }
    final short = _side == 'short';
    final risk = TradeMath.riskShare(
        entry: quote.price, stopLoss: sl, quantity: qty, equity: vm.moduleValue(SandboxModule.trading), isShort: short);
    final rr = TradeMath.rewardToRisk(entry: quote.price, stopLoss: sl, takeProfit: _opt(_tp), isShort: short);
    final ok = risk <= kMaxRiskPerTrade;
    return Text(
      'Risk if stopped out: ${(risk * 100).toStringAsFixed(2)}% of your wallet${ok ? ' ✓' : ' — above 2%'}'
      '${rr == null ? '' : ' · reward:risk ${rr.toStringAsFixed(1)}:1'}',
      style: sbText(12, weight: FontWeight.w600, color: ok ? AppColors.gain : AppColors.warning),
    );
  }

  List<(String, double)> _quickAmounts(SandboxViewModel vm, double unitPrice, double? held) {
    if (!_opening) {
      if (held == null) return const [];
      final whole = spec.module == SandboxModule.cse;
      final half = whole ? (held / 2).floorToDouble() : roundRs(held / 2);
      return [if (half > 0) ('Half', half), ('All', held)];
    }
    switch (spec.module) {
      case SandboxModule.gold:
        return const [('1 g', 1), ('1 sovereign (8 g)', 8)];
      case SandboxModule.cse:
        return const [('10', 10), ('50', 50), ('100', 100)];
      default:
        // Sized so a 2% stop-loss below the price risks ~1% of the wallet.
        final units = (vm.moduleValue(SandboxModule.trading) * 0.5 / unitPrice).floorToDouble();
        return [if (units > 0) ('50% of wallet', units)];
    }
  }
}

String _fmtQty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(3);

class _Breakdown extends StatelessWidget {
  final InstrumentSpec spec;
  final TradeQuote quote;
  final bool opening;
  const _Breakdown({required this.spec, required this.quote, required this.opening});

  @override
  Widget build(BuildContext context) {
    final feeLabel = switch (spec.module) {
      SandboxModule.cse => 'CSE fees (${(kCseFeeRate * 100).toStringAsFixed(2)}%)',
      SandboxModule.gold => 'Making charge (${(kJewelleryMakingCharge * 100).round()}%, not refunded)',
      _ => 'Trading fee (${(kTradingFeeRate * 100).toStringAsFixed(1)}%, min ${formatRs(kTradingMinFee, decimals: 0)})',
    };
    Widget row(String l, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(l, style: sbText(13, color: AppColors.onGlassMuted))),
              Text(v, style: sbText(bold ? 15 : 13, weight: bold ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.innerFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          row('Value', formatRs(quote.gross)),
          if (quote.fee > 0 || spec.module != SandboxModule.gold) row(feeLabel, formatRs(quote.fee)),
          if (spec.module == SandboxModule.gold)
            row('Includes dealer spread', '${(kGoldSpread * 50).toStringAsFixed(1)}% each way'),
          row(opening ? 'Total cost' : 'You receive', formatRs(quote.total), bold: true),
        ],
      ),
    );
  }
}
