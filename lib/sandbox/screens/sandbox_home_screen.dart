import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instrument.dart';
import '../providers/sandbox_provider.dart';
import '../utils/formatters.dart';
import '../widgets/instrument_card.dart';
import '../widgets/sandbox_theme.dart';
import '../widgets/trade_sheet.dart';
import 'portfolio_screen.dart';

class SandboxHomeScreen extends StatelessWidget {
  const SandboxHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sandbox = context.watch<SandboxProvider>();

    return Scaffold(
      backgroundColor: SandboxColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sandbox portfolio',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: SandboxColors.ink)),
                  IconButton(
                    tooltip: 'Reset sandbox',
                    icon: const Icon(Icons.refresh, color: SandboxColors.sage),
                    onPressed: () => _confirmReset(context, sandbox),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sandbox.isLive ? SandboxColors.positive : SandboxColors.sage,
                    ),
                  ),
                  Text(
                    sandbox.isLive
                        ? 'Live CBSL / CSE prices · virtual money'
                        : 'Demo prices · virtual money',
                    style: const TextStyle(fontSize: 12, color: SandboxColors.sage),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PortfolioSummaryCard(sandbox: sandbox),
              const SizedBox(height: 14),
              const Text('AVAILABLE INSTRUMENTS',
                  style: TextStyle(fontSize: 10.5, letterSpacing: 1.1, color: SandboxColors.sage, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: sandbox.instruments.length,
                  itemBuilder: (context, index) {
                    final instrument = sandbox.instruments[index];
                    final isTradable = instrument.category == InstrumentCategory.tradable;
                    return InstrumentCard(
                      instrument: instrument,
                      price: isTradable ? sandbox.priceOf(instrument.id) : null,
                      dailyChangePct: isTradable ? sandbox.dailyChangePctOf(instrument.id) : null,
                      onTap: () => showTradeSheet(context, instrument),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, SandboxProvider sandbox) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset sandbox?'),
        content: const Text('This clears all mock holdings and restores your starting balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              sandbox.resetSandbox();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _PortfolioSummaryCard extends StatelessWidget {
  final SandboxProvider sandbox;
  const _PortfolioSummaryCard({required this.sandbox});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PortfolioScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: SandboxColors.ink, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TOTAL SANDBOX VALUE',
                style: TextStyle(fontSize: 10, letterSpacing: 1, color: SandboxColors.goldLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(formatLkr(sandbox.totalValue),
                style: const TextStyle(fontSize: 28, color: SandboxColors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Cash: ${formatLkr(sandbox.cashBalance)}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                const SizedBox(width: 14),
                const Text('Tap for full breakdown →', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
