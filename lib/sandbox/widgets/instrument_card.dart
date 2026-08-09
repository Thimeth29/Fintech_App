import 'package:flutter/material.dart';
import '../models/instrument.dart';
import '../utils/formatters.dart';
import 'sandbox_theme.dart';

class InstrumentCard extends StatelessWidget {
  final Instrument instrument;
  final double? price;
  final double? dailyChangePct;
  final VoidCallback onTap;

  const InstrumentCard({
    super.key,
    required this.instrument,
    required this.onTap,
    this.price,
    this.dailyChangePct,
  });

  String _subtitleFor() {
    switch (instrument.category) {
      case InstrumentCategory.term:
        return '${instrument.issuer} · ${instrument.annualRatePct}% p.a.';
      case InstrumentCategory.community:
        return '${instrument.issuer} · ${instrument.totalRounds} rounds';
      case InstrumentCategory.tradable:
        return instrument.issuer;
    }
  }

  String _trailingFor() {
    switch (instrument.category) {
      case InstrumentCategory.term:
        return '${instrument.annualRatePct?.toStringAsFixed(1)}% yield';
      case InstrumentCategory.community:
        return formatLkr(instrument.roundContribution ?? 0);
      case InstrumentCategory.tradable:
        return dailyChangePct != null ? formatPct(dailyChangePct!) : '—';
    }
  }

  Color _trailingColor() {
    if (instrument.category != InstrumentCategory.tradable) return SandboxColors.ink;
    if (dailyChangePct == null) return SandboxColors.sage;
    return dailyChangePct! >= 0 ? SandboxColors.positive : SandboxColors.clay;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: SandboxColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SandboxColors.ink.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(instrument.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: SandboxColors.ink)),
                  const SizedBox(height: 2),
                  Text(_subtitleFor(),
                      style: const TextStyle(fontSize: 10.5, color: SandboxColors.sage)),
                ],
              ),
            ),
            Text(_trailingFor(),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: _trailingColor())),
          ],
        ),
      ),
    );
  }
}
