// lib/views/investments/investments_screen.dart
//
// Pure UI for now — static sample market pulse, categories, and recent
// actions. Real CSE/Supabase/AI wiring (InvestmentViewModel) comes back
// in during the backend phase.
import 'package:flutter/material.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/market_data_model.dart';
import 'asset_analytics_screen.dart';

class _AssetCategory {
  final String code;
  final String label;
  final IconData icon;
  const _AssetCategory(this.code, this.label, this.icon);
}

const _categories = [
  _AssetCategory('CSE', 'CSE', Icons.show_chart),
  _AssetCategory('SEC', 'SEC', Icons.account_balance_outlined),
  _AssetCategory('FD', 'FD', Icons.savings_outlined),
  _AssetCategory('GOLD', 'GOLD', Icons.monetization_on_outlined),
];

final _sampleIndices = [
  MarketIndex(name: 'ASPI', value: 12480.32, change: 54.1, changePercentage: 0.44),
  MarketIndex(name: 'S&P SL20', value: 3710.88, change: -12.4, changePercentage: -0.33),
];

const _sampleRecentActions = [
  ('BUY', 'JKH.N', 'CSE', 25000.0, '2026-09-18'),
  ('CONSIDERED', 'GOLD', 'GOLD', 10000.0, '2026-09-12'),
  ('SELL', 'COMB.N', 'CSE', 8000.0, '2026-09-02'),
];

const _sampleInsight = "ASPI is up slightly today on steady banking-sector volume. "
    "Based on your recent activity, you've leaned toward CSE equities — "
    "consider balancing with a fixed-income allocation.";

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  String? _insight;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 820,
      appBar: const TopNavBar(
        current: AppSection.investments,
        title: 'My Investments',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              for (final idx in _sampleIndices) ...[
                Expanded(child: _IndexTile(index: idx)),
                if (idx != _sampleIndices.last) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (int i = 0; i < _categories.length; i++)
                SizedBox(
                  width: 160,
                  child: BlockButton(
                    label: _categories[i].label,
                    icon: _categories[i].icon,
                    entranceDelay: Duration(milliseconds: i * 80),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssetAnalyticsScreen(assetType: _categories[i].code),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          _AiInsightCard(
            insight: _insight,
            onGetInsight: () => setState(() => _insight = _sampleInsight),
          ),
          const SizedBox(height: 20),
          const Text(
            'Recent Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 8),
          ..._sampleRecentActions.map(
            (a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text('${a.$1} · ${a.$2}'),
                subtitle: Text('${a.$3} · LKR ${a.$4.toStringAsFixed(2)}'),
                trailing: Text(a.$5, style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexTile extends StatelessWidget {
  final MarketIndex index;
  const _IndexTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final color = index.isUp ? Colors.green.shade700 : Colors.red.shade700;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(index.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(index.value.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            '${index.isUp ? "+" : ""}${index.changePercentage.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  final String? insight;
  final VoidCallback onGetInsight;
  const _AiInsightCard({required this.insight, required this.onGetInsight});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FinBot Insights',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: onGetInsight,
                child: Text(insight == null ? 'Get insights' : 'Refresh'),
              ),
            ],
          ),
          if (insight != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(insight!, style: const TextStyle(fontSize: 13)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Tap "Get insights" for a live read on today\'s CSE market and how it '
                'relates to your own spending and investment activity.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
