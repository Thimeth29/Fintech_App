import 'package:flutter/material.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/block_button.dart';
import 'plan_expenses_screen.dart';
import 'explore_plans_screen.dart';

class ExpenditureScreen extends StatelessWidget {
  const ExpenditureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: const TopNavBar(
        current: AppSection.expenses,
        title: 'My Expenditures',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: BlockButton(
                label: 'Plan My Expenses',
                icon: Icons.edit_note,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlanExpensesScreen()),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: BlockButton(
                label: 'Explore Expenditure Plans',
                icon: Icons.lightbulb_outline,
                entranceDelay: const Duration(milliseconds: 100),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExploreExpenditurePlansScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
