import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/sandbox/sandbox_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/sandbox_models.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import 'widgets/sandbox_widgets.dart';

enum _Filter { all, trades, income, closes }

/// Every row from sandbox_trades for the module, including history from
/// before a reset (archived, shown dimmed).
class HistoryTab extends StatefulWidget {
  final SandboxModule module;
  const HistoryTab({super.key, required this.module});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  Future<List<SandboxTrade>>? _future;
  _Filter _filter = _Filter.all;
  bool _includeArchived = false;
  int _seenTrades = -1;

  void _reload(SandboxViewModel vm) {
    _seenTrades = vm.recentTrades.length;
    _future = vm.loadHistory(widget.module);
  }

  bool _matches(SandboxTrade t) => switch (_filter) {
        _Filter.all => true,
        _Filter.trades => const {'buy', 'sell', 'short', 'cover', 'fd_open', 'tbill_buy', 'tbond_buy'}.contains(t.side),
        _Filter.income => t.isIncome || t.side.endsWith('_mature') || t.side == 'updown_payout',
        _Filter.closes => t.realisedPnl != null,
      };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    if (_future == null || _seenTrades != vm.recentTrades.length) _reload(vm);
    final batch = vm.wallets[widget.module]?.resetBatch;
    return FutureBuilder<List<SandboxTrade>>(
      future: _future,
      builder: (context, snap) {
        final all = snap.data ?? const <SandboxTrade>[];
        final rows = all.where((t) => (_includeArchived || t.resetBatch == batch) && _matches(t)).toList();
        final archivedCount = all.where((t) => t.resetBatch != batch).length;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _reload(vm));
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _Filter.values)
                    ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.all => 'All',
                        _Filter.trades => 'Buys & opens',
                        _Filter.income => 'Income & maturities',
                        _Filter.closes => 'Closed (P&L)',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  if (archivedCount > 0)
                    FilterChip(
                      label: Text('Before resets ($archivedCount)'),
                      selected: _includeArchived,
                      onSelected: (v) => setState(() => _includeArchived = v),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (snap.connectionState == ConnectionState.waiting && all.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (rows.isEmpty)
                Text('No history yet.', style: sbText(13, color: AppColors.onGlassMuted))
              else
                for (final t in rows) ...[
                  _TradeRow(trade: t, archived: t.resetBatch != batch),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _TradeRow extends StatelessWidget {
  final SandboxTrade trade;
  final bool archived;
  const _TradeRow({required this.trade, required this.archived});

  @override
  Widget build(BuildContext context) {
    final t = trade;
    final spec = instrumentBySymbol(t.symbol);
    final isPosition = t.side.startsWith('fd_') || t.side.startsWith('tbill_') || t.side.startsWith('tbond_');
    final detail = isPosition || t.side == 'dividend' || t.side.startsWith('updown')
        ? formatRs(t.cashDelta.abs())
        : '${t.quantity == t.quantity.roundToDouble() ? t.quantity.toStringAsFixed(0) : t.quantity.toStringAsFixed(3)} × ${formatRs(t.price)}'
            '${t.fee > 0 ? ' + fee ${formatRs(t.fee)}' : ''}';
    return Opacity(
      opacity: archived ? 0.6 : 1,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${t.sideLabel} · ${spec?.name ?? t.symbol}',
                      style: sbText(14, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(signedRs(t.cashDelta), style: sbText(13, weight: FontWeight.w700, color: pnlColor(t.cashDelta))),
                const SizedBox(width: 8),
              ],
            ),
            Text(
              '$detail · sim ${shortDate(t.simDate)}${archived ? ' · before reset' : ''}'
              '${t.note == 'stop_loss' ? ' · stop-loss' : t.note == 'take_profit' ? ' · take-profit' : ''}',
              style: sbText(12, color: AppColors.onGlassMuted),
            ),
            Row(
              children: [
                if (t.realisedPnl != null)
                  Text('Realised P&L ${signedRs(t.realisedPnl!)}',
                      style: sbText(12, weight: FontWeight.w700, color: pnlColor(t.realisedPnl!))),
                const Spacer(),
                if (t.realisedPnl != null)
                  AskFinBotButton(
                    dense: true,
                    prompt: 'In my investment trainer I closed ${spec?.name ?? t.symbol} with a '
                        '${t.realisedPnl! >= 0 ? 'profit' : 'loss'} of ${formatRs(t.realisedPnl!.abs())}'
                        '${t.fee > 0 ? ' after ${formatRs(t.fee)} in fees' : ''}. Why might that have happened, and what can I learn?',
                  )
                else
                  const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
