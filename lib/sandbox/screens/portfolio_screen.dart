import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sandbox_provider.dart';
import '../utils/formatters.dart';
import '../widgets/sandbox_theme.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sandbox = context.watch<SandboxProvider>();
    final holdings = sandbox.holdings.values.toList();
    final terms = sandbox.engine.portfolio.termPositions.where((t) => !t.withdrawn).toList();
    final community = sandbox.engine.portfolio.communityPositions;
    final history = sandbox.engine.portfolio.history.reversed.toList();

    return Scaffold(
      backgroundColor: SandboxColors.paper,
      appBar: AppBar(
        backgroundColor: SandboxColors.paper,
        elevation: 0,
        foregroundColor: SandboxColors.ink,
        title: const Text('Portfolio breakdown'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (holdings.isNotEmpty) ...[
            _sectionLabel('Tradable holdings'),
            for (final h in holdings)
              _row(
                title: sandbox.instruments.firstWhere((i) => i.id == h.instrumentId).name,
                subtitle: '${h.quantity.toStringAsFixed(3)} units · avg ${formatLkr(h.avgCost, decimals: 2)}',
                trailing: formatLkr(h.marketValue(sandbox.priceOf(h.instrumentId))),
                trailingColor: h.unrealizedPnl(sandbox.priceOf(h.instrumentId)) >= 0
                    ? SandboxColors.positive
                    : SandboxColors.clay,
              ),
          ],
          if (terms.isNotEmpty) ...[
            _sectionLabel('Locked term positions'),
            for (final t in terms)
              _row(
                title: sandbox.instruments.firstWhere((i) => i.id == t.instrumentId).name,
                subtitle: t.isMatured ? 'Matured — ready to withdraw' : 'Matures ${t.maturesAt.toString().split(' ').first}',
                trailing: formatLkr(t.currentAccruedValue()),
                onTap: t.isMatured ? () => sandbox.withdrawTermPosition(t.id) : null,
              ),
          ],
          if (community.isNotEmpty) ...[
            _sectionLabel('Community fund'),
            for (final c in community)
              _row(
                title: 'Community fund',
                subtitle: '${c.roundsContributed}/${c.totalRounds} rounds contributed',
                trailing: formatLkr(c.totalContributedSoFar),
                onTap: c.roundsContributed < c.totalRounds
                    ? () => sandbox.contributeToCommunityRound(c.id)
                    : (!c.hasReceivedPayout ? () => sandbox.receiveCommunityPayout(c.id) : null),
              ),
          ],
          _sectionLabel('History'),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('No trades yet.', style: TextStyle(color: SandboxColors.sage, fontSize: 12)),
            ),
          for (final t in history.take(30))
            _row(
              title: t.type.name,
              subtitle: t.timestamp.toString().split('.').first,
              trailing: formatLkr(t.amount),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 10.5, letterSpacing: 1.1, color: SandboxColors.sage, fontWeight: FontWeight.w600)),
      );

  Widget _row({
    required String title,
    required String subtitle,
    required String trailing,
    Color trailingColor = SandboxColors.ink,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SandboxColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SandboxColors.ink.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: SandboxColors.sage)),
                ],
              ),
            ),
            Text(trailing, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: trailingColor)),
          ],
        ),
      ),
    );
  }
}
