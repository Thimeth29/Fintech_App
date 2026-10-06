// lib/views/investments/asset_analytics_screen.dart
//
// Pure UI for now — static sample gainers/losers and insights. Real
// CSE/Supabase wiring (AssetAnalyticsViewModel) comes back in during the
// backend phase.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/market_data_model.dart';

const Map<String, String> _titles = {
  'CSE': 'CSE Analytics',
  'SEC': 'Government Securities (SEC)',
  'FD': 'Fixed Deposit Analytics',
  'GOLD': 'Gold Analytics',
};

const List<String> _topics = [
  'Shares',
  'Dividends',
  'Growth Investing',
  'Value Investing',
  'Trading',
];

const Map<String, String> _topicBlurbs = {
  'Shares': 'A share is a unit of ownership in a company. Its price moves with '
      'company performance, sector trends, and overall market sentiment.',
  'Dividends': 'A dividend is a portion of profit a company pays out to '
      'shareholders — usually a sign of stable, mature earnings.',
  'Growth Investing': 'Growth investing targets companies expected to expand '
      'faster than the market, often reinvesting profit instead of paying dividends.',
  'Value Investing': 'Value investing looks for companies trading below their '
      'underlying worth, based on fundamentals like earnings and assets.',
  'Trading': 'Trading means buying and selling more frequently to profit from '
      'short-term price moves — higher potential reward, but higher risk too.',
};

final _sampleGainers = [
  StockQuote(symbol: 'JKH.N', name: 'John Keells Holdings', price: 145.50, changePercentage: 2.3, volume: 182000),
  StockQuote(symbol: 'COMB.N', name: 'Commercial Bank', price: 98.20, changePercentage: 1.1, volume: 94000),
];
final _sampleLosers = [
  StockQuote(symbol: 'DIAL.N', name: 'Dialog Axiata', price: 12.40, changePercentage: -1.8, volume: 210000),
  StockQuote(symbol: 'HNB.N', name: 'HNB', price: 210.75, changePercentage: -0.6, volume: 40000),
];

const _sampleInsights = [
  'Banking-sector counters led gains today on improved liquidity.',
  'Telecom names softened slightly amid broader sector rotation.',
];

const _sampleSuggestedAction = 'Diversify across at least 2-3 sectors before increasing position size.';

class AssetAnalyticsScreen extends StatelessWidget {
  final String assetType;
  const AssetAnalyticsScreen({super.key, required this.assetType});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 820,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_titles[assetType] ?? '$assetType Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Showing sample figures — connect a live rate source to replace these.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _topics
                .map(
                  (t) => ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(t),
                        content: Text(_topicBlurbs[t] ?? ''),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            '% Change Snapshot',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          GlassCard(child: _ChangeChart(gainers: _sampleGainers, losers: _sampleLosers)),
          const SizedBox(height: 20),
          const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          ..._sampleInsights.map(
            (tip) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tip, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Log an investment action'),
            onPressed: () => _showLogActionDialog(context),
          ),
          const SizedBox(height: 20),
          const SuggestedActionCard(action: _sampleSuggestedAction),
          const SizedBox(height: 16),
          AskBotButton(seedContext: "You're looking at $assetType analytics."),
        ],
      ),
    );
  }

  void _showLogActionDialog(BuildContext context) {
    final symbolController = TextEditingController();
    final amountController = TextEditingController();
    String action = 'considered';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Log an action'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolController,
                decoration: const InputDecoration(labelText: 'Symbol / Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (LKR)'),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: action,
                items: const [
                  DropdownMenuItem(value: 'buy', child: Text('Buy')),
                  DropdownMenuItem(value: 'sell', child: Text('Sell')),
                  DropdownMenuItem(value: 'considered', child: Text('Considered')),
                ],
                onChanged: (v) => setState(() => action = v ?? 'considered'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              // Pure UI for now — just closes. Persisting via Supabase
              // comes back in during the backend phase.
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeChart extends StatelessWidget {
  final List<StockQuote> gainers;
  final List<StockQuote> losers;

  const _ChangeChart({required this.gainers, required this.losers});

  @override
  Widget build(BuildContext context) {
    final quotes = [...gainers.take(3), ...losers.take(3)];
    if (quotes.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No data to chart yet')),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= quotes.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      quotes[i].symbol,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < quotes.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: quotes[i].changePercentage,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                    color: quotes[i].isUp ? Colors.green : Colors.red,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
