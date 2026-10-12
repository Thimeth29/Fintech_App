import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/theme/app_fonts.dart';

class ExploreExpenditurePlansScreen extends StatelessWidget {
  const ExploreExpenditurePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
        current: AppSection.expenses,
        title: 'Explore Budgeting Models',
        showBackButton: true,
        isSectionRoot: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppSection.expenses, isSectionRoot: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The 50 / 30 / 20 Rule',
              style: AppFonts.text(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onGlass),
            ),
            const SizedBox(height: 4),
            Text(
              'A standard framework: 50% Needs, 30% Wants, 20% Investments & Savings.',
              style: AppFonts.text(fontSize: 13, color: AppColors.onGlassMuted),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 190,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    sections: [
                      PieChartSectionData(
                        value: 50,
                        color: AppColors.chartSeries[0],
                        title: '50%\nNeeds',
                        radius: 56,
                        titleStyle: AppFonts.text(fontSize: 11, color: AppColors.onFill(AppColors.chartSeries[0]), fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        value: 30,
                        color: AppColors.chartSeries[1],
                        title: '30%\nWants',
                        radius: 56,
                        titleStyle: AppFonts.text(fontSize: 11, color: AppColors.onFill(AppColors.chartSeries[1]), fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        value: 20,
                        color: AppColors.chartSeries[3],
                        title: '20%\nSavings',
                        radius: 56,
                        titleStyle: AppFonts.text(fontSize: 11, color: AppColors.onFill(AppColors.chartSeries[3]), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Alternative Budgeting Strategies',
              style: AppFonts.text(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.onGlass),
            ),
            const SizedBox(height: 12),
            _planCard(
              'Zero-Based Budgeting',
              'Every rupee of monthly income is assigned a specific job (spend, save, or invest) before the month begins — leaving zero unallocated funds.',
              Icons.balance_rounded,
            ),
            _planCard(
              'Pay-Yourself-First Method',
              'Automatically divert 20%+ of your paycheck to investments (CSE / Fixed Deposits) the day your salary lands, then live on the rest.',
              Icons.savings_rounded,
            ),
            _planCard(
              'Envelope Budgeting',
              'Allocate fixed digital spending caps per category so overspending in entertainment or dining out is immediately restricted.',
              Icons.mark_email_read_rounded,
            ),
            const SizedBox(height: 20),
            const SuggestedActionCard(
              action: 'Pick one budgeting method and stick with it for at least 3 months in Sri Lanka before adjusting — '
                  'consistency builds long-term wealth.',
            ),
            const SizedBox(height: 16),
            const AskBotButton(seedContext: "You're exploring budgeting plans."),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _planCard(String title, String desc, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.glassFillStrong,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.accentCyan, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.text(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.onGlass),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppFonts.text(fontSize: 13, color: AppColors.onGlassMuted, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


