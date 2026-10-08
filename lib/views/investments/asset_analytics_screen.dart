import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../models/market_data_model.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/asset_analytics_viewmodel.dart';

const Map<String, String> _titles = {
  'CSE': 'CSE Stock Analytics',
  'SEC': 'Government Securities (SEC)',
  'FD': 'Fixed Deposit Analytics',
  'GOLD': 'Gold Asset Analytics',
};

const List<String> _topics = [
  'Shares',
  'Dividends',
  'Growth Investing',
  'Value Investing',
  'Trading Strategy',
];

const Map<String, String> _topicBlurbs = {
  'Shares': 'A share is a unit of ownership in a company. Its market price fluctuates based on company revenue, sector trends, and overall Sri Lanka Economic Outlook.',
  'Dividends': 'A dividend is cash paid out from company net profits to shareholders — usually indicating mature, stable corporate performance.',
  'Growth Investing': 'Growth investing targets companies expanding faster than market averages, prioritizing capital gain over dividend payouts.',
  'Value Investing': 'Value investing identifies undervalued companies trading below intrinsic book value based on net assets and balance sheet strength.',
  'Trading Strategy': 'Trading involves active market entry and exit to profit from short-term volatility — higher return potential, accompanied by higher market risk.',
};

class AssetAnalyticsScreen extends StatelessWidget {
  final String assetType;
  const AssetAnalyticsScreen({super.key, required this.assetType});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;

    return ChangeNotifierProvider(
      create: (_) => AssetAnalyticsViewModel(assetType)..load(userId: userId),
      child: GradientScaffold(
        maxContentWidth: 860,
        appBar: AppBar(
          leading: Container(
            margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const BackButton(color: AppColors.textDark),
          ),
          title: Text(
            _titles[assetType] ?? '$assetType Analytics',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
        body: Consumer<AssetAnalyticsViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live vs reference data notice banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vm.isLiveData
                                ? 'Displaying live market quotes (Sri Lanka CSE feed).'
                                : 'Showing reference figures for $assetType — connect a live rate source to replace these.',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Financial Literacy Topics Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _topics
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.borderLight),
                                label: Text(t, style: GoogleFonts.outfit(fontSize: 12.5, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Text(t, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                    content: Text(_topicBlurbs[t] ?? '', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Understood', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Market Performance Snapshot (% Change)',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: Colors.white,
                    child: _ChangeChart(gainers: vm.gainers, losers: vm.losers),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Market Intelligence & Insights',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 10),

                  ...vm.insights.map(
                    (tip) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        backgroundColor: Colors.white,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.mintBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip,
                                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textDark, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (userId != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                        label: Text('Log Personal Investment Action', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                        onPressed: () => _showLogActionDialog(context, vm, userId),
                      ),
                    ),

                    if (vm.history.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Your $assetType History',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      ...vm.history.map(
                        (a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.white,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${a.action.toUpperCase()} • ${a.symbol}',
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  ),
                                ),
                                Text(
                                  'Rs ${a.amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),
                  SuggestedActionCard(action: vm.suggestedAction),
                  const SizedBox(height: 16),
                  AskBotButton(seedContext: "You're looking at $assetType analytics."),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showLogActionDialog(BuildContext context, AssetAnalyticsViewModel vm, String userId) {
    final symbolController = TextEditingController();
    final amountController = TextEditingController();
    String action = 'considered';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Log Investment Action', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolController,
                style: GoogleFonts.outfit(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'Asset Name / Symbol',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  hintText: 'e.g. JKH.N or 364-Day T-Bill',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'Amount (LKR)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  prefixText: 'Rs. ',
                  prefixStyle: GoogleFonts.outfit(color: AppColors.textDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: action,
                dropdownColor: Colors.white,
                style: GoogleFonts.outfit(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'Action Type',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'buy', child: Text('Bought Position')),
                  DropdownMenuItem(value: 'sell', child: Text('Sold Position')),
                  DropdownMenuItem(value: 'considered', child: Text('Watchlist / Considered')),
                ],
                onChanged: (v) => setState(() => action = v ?? 'considered'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                final symbol = symbolController.text.trim();
                Navigator.pop(dialogContext);
                if (symbol.isNotEmpty && amount > 0) {
                  await vm.logAction(userId: userId, symbol: symbol, action: action, amount: amount);
                }
              },
              child: Text('Save Action', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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
      return SizedBox(
        height: 160,
        child: Center(child: Text('No market data to chart yet', style: GoogleFonts.outfit(color: AppColors.textMuted))),
      );
    }

    return SizedBox(
      height: 190,
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
                      style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textDark, fontWeight: FontWeight.w600),
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
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                    color: quotes[i].isUp ? AppColors.primary : AppColors.rose,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
