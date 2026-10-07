import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import 'plan_expenses_screen.dart';
import 'explore_plans_screen.dart';

class ExpenditureScreen extends StatelessWidget {
  const ExpenditureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
        current: AppSection.expenses,
        title: 'My Expenditures',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expenditure Hero Overview Card
            GlassCard(
              padding: const EdgeInsets.all(22),
              gradient: AppGradients.heroCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OCTOBER EXPENSE TRACKER',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Healthy Budget',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Rs 42,350',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF86EFAC)),
                      const SizedBox(width: 6),
                      Text(
                        'Rs 22,650.00 left under budget',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF86EFAC),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Manage & Plan Expenses',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),

            // Action Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.35,
              children: [
                BlockButton(
                  label: 'Plan My Expenses',
                  subtitle: 'Log & Track Spend',
                  icon: Icons.edit_note_rounded,
                  backgroundColor: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlanExpensesScreen()),
                  ),
                ),
                BlockButton(
                  label: 'Explore Budgeting',
                  subtitle: '50/30/20 & Zero-Based',
                  icon: Icons.lightbulb_outline_rounded,
                  backgroundColor: Colors.white,
                  entranceDelay: const Duration(milliseconds: 80),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExploreExpenditurePlansScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


