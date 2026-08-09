import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instrument.dart';
import '../providers/sandbox_provider.dart';
import '../utils/formatters.dart';
import 'sandbox_theme.dart';

/// Opens the correct trade flow for [instrument]'s category.
Future<void> showTradeSheet(BuildContext context, Instrument instrument) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: SandboxColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TradeSheetBody(instrument: instrument),
    ),
  );
}

class _TradeSheetBody extends StatefulWidget {
  final Instrument instrument;
  const _TradeSheetBody({required this.instrument});

  @override
  State<_TradeSheetBody> createState() => _TradeSheetBodyState();
}

class _TradeSheetBodyState extends State<_TradeSheetBody> {
  final _amountCtrl = TextEditingController();
  bool _isBuy = true;

  @override
  Widget build(BuildContext context) {
    final sandbox = context.watch<SandboxProvider>();
    final instrument = widget.instrument;

    switch (instrument.category) {
      case InstrumentCategory.tradable:
        return _buildTradableSheet(sandbox, instrument);
      case InstrumentCategory.term:
        return _buildTermSheet(sandbox, instrument);
      case InstrumentCategory.community:
        return _buildCommunitySheet(sandbox, instrument);
    }
  }

  Widget _buildTradableSheet(SandboxProvider sandbox, Instrument instrument) {
    final price = sandbox.priceOf(instrument.id);
    final holding = sandbox.holdings[instrument.id];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(instrument.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SandboxColors.ink)),
          Text('${formatLkr(price, decimals: 2)} ${instrument.unitLabel}',
              style: const TextStyle(fontSize: 12.5, color: SandboxColors.sage)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _segButton('Buy', _isBuy, () => setState(() => _isBuy = true))),
              const SizedBox(width: 8),
              Expanded(child: _segButton('Sell', !_isBuy, () => setState(() => _isBuy = false))),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _isBuy ? 'Amount to spend (LKR)' : 'Quantity to sell',
              filled: true,
              fillColor: SandboxColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          if (!_isBuy && holding != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('You hold ${holding.quantity.toStringAsFixed(3)}', style: const TextStyle(fontSize: 11, color: SandboxColors.sage)),
            ),
          if (sandbox.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(sandbox.lastError!, style: const TextStyle(color: SandboxColors.clay, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SandboxColors.ink,
                foregroundColor: SandboxColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              onPressed: () {
                final value = double.tryParse(_amountCtrl.text) ?? 0;
                final ok = _isBuy
                    ? sandbox.buyTradable(instrument.id, value)
                    : sandbox.sellTradable(instrument.id, value);
                if (ok) Navigator.of(context).pop();
              },
              child: Text(_isBuy ? 'Buy (sandbox)' : 'Sell (sandbox)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermSheet(SandboxProvider sandbox, Instrument instrument) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(instrument.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SandboxColors.ink)),
          Text('${instrument.issuer} · ${instrument.annualRatePct}% p.a. · ${instrument.termDays} day term',
              style: const TextStyle(fontSize: 12.5, color: SandboxColors.sage)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount to lock (LKR)',
              filled: true,
              fillColor: SandboxColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          if (sandbox.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(sandbox.lastError!, style: const TextStyle(color: SandboxColors.clay, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SandboxColors.gold,
                foregroundColor: SandboxColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              onPressed: () {
                final value = double.tryParse(_amountCtrl.text) ?? 0;
                final ok = sandbox.openTermPosition(instrument.id, value);
                if (ok) Navigator.of(context).pop();
              },
              child: const Text('Lock funds (sandbox)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitySheet(SandboxProvider sandbox, Instrument instrument) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(instrument.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SandboxColors.ink)),
          Text(
            '${formatLkr(instrument.roundContribution ?? 0)} per round · ${instrument.totalRounds} rounds total',
            style: const TextStyle(fontSize: 12.5, color: SandboxColors.sage),
          ),
          const SizedBox(height: 6),
          Text(instrument.description, style: const TextStyle(fontSize: 12, color: Color(0xFF5A655E), height: 1.4)),
          if (sandbox.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(sandbox.lastError!, style: const TextStyle(color: SandboxColors.clay, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SandboxColors.ink,
                foregroundColor: SandboxColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              onPressed: () {
                sandbox.joinCommunityFund(instrument.id);
                Navigator.of(context).pop();
              },
              child: const Text('Join this fund (sandbox)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? SandboxColors.ink : SandboxColors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: SandboxColors.ink.withOpacity(0.15)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? SandboxColors.white : SandboxColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
