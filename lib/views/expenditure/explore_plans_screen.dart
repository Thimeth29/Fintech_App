import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';

class ExploreExpenditurePlansScreen extends StatelessWidget {
  const ExploreExpenditurePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
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
          'Explore Budgeting Models',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The 50 / 30 / 20 Rule',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'A standard framework: 50% Needs, 30% Wants, 20% Investments & Savings.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: Colors.white,
              child: SizedBox(
                height: 190,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    sections: [
                      PieChartSectionData(
                        value: 50,
                        color: AppColors.primary,
                        title: '50%\nNeeds',
                        radius: 56,
                        titleStyle: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        value: 30,
                        color: const Color(0xFF16A34A),
                        title: '30%\nWants',
                        radius: 56,
                        titleStyle: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        value: 20,
                        color: const Color(0xFFF3C06B),
                        title: '20%\nSavings',
                        radius: 56,
                        titleStyle: GoogleFonts.outfit(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Alternative Budgeting Strategies',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
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
        backgroundColor: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.mintBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.35),
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


