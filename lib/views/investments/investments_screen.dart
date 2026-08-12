// lib/views/investments/investments_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../models/market_data_model.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/investment_viewmodel.dart';
import 'asset_analytics_screen.dart';

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    return ChangeNotifierProvider(
      create: (_) => InvestmentViewModel()
        ..loadHistory(userId)
        ..loadMarketPulse(),
      child: GradientScaffold(
        appBar: const TopNavBar(
          current: AppSection.investments,
          title: 'My Investments',
          showBackButton: true,
        ),
        body: Consumer<InvestmentViewModel>(
          builder: (context, vm, _) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _MarketPulseStrip(vm: vm),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (int i = 0; i < InvestmentViewModel.categories.length; i++)
                      SizedBox(
                        width: 160,
                        child: BlockButton(
                          label: InvestmentViewModel.categories[i].label,
                          entranceDelay: Duration(milliseconds: i * 80),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AssetAnalyticsScreen(
                                assetType: InvestmentViewModel.categories[i].code,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                _AiInsightCard(vm: vm, userId: userId),
                const SizedBox(height: 20),
                if (userId == null)
                  const SuggestedActionCard(
                    action: 'Log in to track and save a history of your investment decisions.',
                  )
                else ...[
                  const Text('Recent Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (vm.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (vm.recentActions.isEmpty)
                    const Text('No investment actions logged yet.', style: TextStyle(fontSize: 13))
                  else
                    ...vm.recentActions.take(5).map(
                      (a) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text('${a.action.toUpperCase()} · ${a.symbol}'),
                          subtitle: Text('${a.assetType} · LKR ${a.amount.toStringAsFixed(2)}'),
                          trailing: Text(
                            '${a.createdAt.year}-${a.createdAt.month.toString().padLeft(2, '0')}-${a.createdAt.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Live ASPI / S&P SL20 index strip — the "live data analytics" surfaced
/// right on the hub page, fetched straight from the CSE via CseService.
class _MarketPulseStrip extends StatelessWidget {
  final InvestmentViewModel vm;
  const _MarketPulseStrip({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoadingIndices) {
      return const SizedBox(
        height: 64,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (vm.indices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
        ),
        child: const Text(
          'Market Pulse is offline right now — showing category data below instead.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }
    return Row(
      children: [
        for (final idx in vm.indices) ...[
          Expanded(child: _IndexTile(index: idx)),
          if (idx != vm.indices.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _IndexTile extends StatelessWidget {
  final MarketIndex index;
  const _IndexTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final color = index.isUp ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
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

/// FinBot-generated "what to know today" card — the AI agent's live-data
/// insight, requested on demand so it doesn't burn API calls on every
/// page load.
class _AiInsightCard extends StatelessWidget {
  final InvestmentViewModel vm;
  final String? userId;
  const _AiInsightCard({required this.vm, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.black87, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FinBot Insights',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: vm.isLoadingInsight ? null : () => vm.loadAiInsight(userId),
                child: Text(vm.aiInsight == null ? 'Get insights' : 'Refresh'),
              ),
            ],
          ),
          if (vm.isLoadingInsight)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (vm.aiInsight != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(vm.aiInsight!, style: const TextStyle(fontSize: 13)),
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
