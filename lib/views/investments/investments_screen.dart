import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../models/market_data_model.dart';
import 'asset_analytics_screen.dart';

class _AssetCategory {
  final String code;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  const _AssetCategory(this.code, this.label, this.subtitle, this.icon, this.backgroundColor, this.textColor);
}

final List<_AssetCategory> _categories = [
  const _AssetCategory('CSE', 'CSE Equities', 'Colombo Stock Exchange', Icons.show_chart_rounded, AppColors.primary, Colors.white),
  const _AssetCategory('SEC', 'Govt Treasury', 'T-Bills & Bonds', Icons.account_balance_outlined, Colors.white, AppColors.textDark),
  const _AssetCategory('FD', 'Fixed Deposits', 'Sri Lanka Bank FDs', Icons.savings_outlined, Colors.white, AppColors.textDark),
  const _AssetCategory('GOLD', 'Gold & Metals', 'Asset Protection', Icons.monetization_on_outlined, Colors.white, AppColors.textDark),
];

final _sampleIndices = [
  MarketIndex(name: 'ASPI (CSE)', value: 12480.32, change: 54.1, changePercentage: 0.44),
  MarketIndex(name: 'S&P SL20', value: 3710.88, change: -12.4, changePercentage: -0.33),
];

const _sampleRecentActions = [
  ('BUY', 'JKH.N', 'CSE Equities', 25000.0, '2026-09-18'),
  ('CONSIDERED', 'GOLD 24K', 'Gold Asset', 10000.0, '2026-09-12'),
  ('SELL', 'COMB.N', 'CSE Equities', 8000.0, '2026-09-02'),
];

const _sampleInsight = "ASPI is up slightly today on steady banking-sector volume. "
    "Based on your recent activity, you've leaned toward CSE equities — "
    "consider balancing with a fixed-income allocation like 364-day Treasury Bills.";

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
      maxContentWidth: 860,
      appBar: const TopNavBar(
        current: AppSection.investments,
        title: 'My Investments',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Pulse (Sri Lanka)',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 10),

            // Market Ticker Cards
            Row(
              children: [
                for (final idx in _sampleIndices) ...[
                  Expanded(child: _IndexTile(index: idx)),
                  if (idx != _sampleIndices.last) const SizedBox(width: 12),
                ],
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Explore Asset Classes',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),

            // Category Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return BlockButton(
                  label: cat.label,
                  subtitle: cat.subtitle,
                  icon: cat.icon,
                  backgroundColor: cat.backgroundColor,
                  textColor: cat.textColor,
                  entranceDelay: Duration(milliseconds: i * 60),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AssetAnalyticsScreen(assetType: cat.code),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // AI Insight Widget
            _AiInsightCard(
              insight: _insight,
              onGetInsight: () => setState(() => _insight = _sampleInsight),
            ),

            const SizedBox(height: 24),

            Text(
              'Recent Investment Logs',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 10),

            ..._sampleRecentActions.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: Colors.white,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getActionColor(a.$1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getActionColor(a.$1).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          a.$1,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _getActionColor(a.$1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.$2,
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            Text(
                              '${a.$3} • ${a.$5}',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${a.$4.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String type) {
    switch (type) {
      case 'BUY':
        return AppColors.primary;
      case 'SELL':
        return AppColors.rose;
      default:
        return Colors.amber[800]!;
    }
  }
}

class _IndexTile extends StatelessWidget {
  final MarketIndex index;
  const _IndexTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final isUp = index.isUp;
    final accentColor = isUp ? AppColors.primary : AppColors.rose;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      borderColor: accentColor.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                index.name,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              Icon(
                isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: accentColor,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            index.value.toStringAsFixed(2),
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isUp ? "+" : ""}${index.changePercentage.toStringAsFixed(2)}%',
              style: GoogleFonts.outfit(fontSize: 11, color: accentColor, fontWeight: FontWeight.w700),
            ),
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
      padding: const EdgeInsets.all(18),
      backgroundColor: AppColors.mintBg,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FinBot AI Market Insights',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                ),
              ),
              TextButton(
                onPressed: onGetInsight,
                child: Text(
                  insight == null ? 'Analyze Market' : 'Refresh',
                  style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (insight != null)
            Text(
              insight!,
              style: GoogleFonts.outfit(fontSize: 13.5, color: AppColors.textDark, height: 1.4),
            )
          else
            Text(
              'Tap "Analyze Market" for a live AI read on today\'s Colombo Stock Exchange trends and how they impact your portfolio.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.35),
            ),
        ],
      ),
    );
  }
}


