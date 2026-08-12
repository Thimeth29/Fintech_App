import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';

class ExploreExpenditurePlansScreen extends StatelessWidget {
  const ExploreExpenditurePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Explore Expenditure Plans')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'The 50/30/20 Rule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'A simple starting budget: needs, wants, and savings/debt payoff.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(value: 50, color: Colors.blue, title: '50%\nNeeds', radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white)),
                  PieChartSectionData(value: 30, color: Colors.teal, title: '30%\nWants', radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white)),
                  PieChartSectionData(value: 20, color: Colors.deepPurple, title: '20%\nSavings', radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Other approaches', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _planCard(
            'Zero-based budgeting',
            'Every rupee of income is assigned a job (spend, save, or invest) before the month starts — nothing is left unplanned.',
          ),
          _planCard(
            'Pay-yourself-first',
            'Move a fixed percentage to savings/investments the moment income arrives, then budget the rest.',
          ),
          _planCard(
            'Envelope method',
            'Split cash (or virtual "envelopes") per category so overspending in one area is visible immediately.',
          ),
          const SizedBox(height: 12),
          const SuggestedActionCard(
            action: 'Pick one budgeting method and try it for a full month before switching — '
                'consistency matters more than finding the "perfect" system.',
          ),
          const SizedBox(height: 16),
          const AskBotButton(seedContext: "You're exploring budgeting plans."),
        ],
      ),
    );
  }

  Widget _planCard(String title, String desc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
