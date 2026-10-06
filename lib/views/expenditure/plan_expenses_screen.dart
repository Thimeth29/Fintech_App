// lib/views/expenditure/plan_expenses_screen.dart
//
// Pure UI for now — in-memory sample expenses so adding one updates the
// list/chart live. Real Supabase persistence + ML prediction
// (ExpenseViewModel) comes back in during the backend phase.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/expense_model.dart';

const List<String> _categories = [
  'Food', 'Transport', 'Housing', 'Utilities', 'Entertainment', 'Other',
];

const _sampleSuggestedAction =
    'Housing is your biggest category this month — see if any recurring '
    'subscriptions under Entertainment can be trimmed.';

class PlanExpensesScreen extends StatefulWidget {
  const PlanExpensesScreen({super.key});

  @override
  State<PlanExpensesScreen> createState() => _PlanExpensesScreenState();
}

class _PlanExpensesScreenState extends State<PlanExpensesScreen> {
  final _expenses = <ExpenseModel>[
    ExpenseModel(userId: 'sample', amount: 18500, category: 'Housing', note: 'Rent'),
    ExpenseModel(userId: 'sample', amount: 6200, category: 'Food', note: 'Groceries'),
    ExpenseModel(userId: 'sample', amount: 3400, category: 'Transport'),
    ExpenseModel(userId: 'sample', amount: 2100, category: 'Entertainment', note: 'Streaming'),
  ];

  double get _total => _expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Plan My Expenses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Total spent: LKR ${_total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          const _PredictionCard(),
          const SizedBox(height: 16),
          if (_byCategory.isNotEmpty) GlassCard(child: _CategoryPie(byCategory: _byCategory)),
          const SizedBox(height: 16),
          const Text('Recent Expenses', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          if (_expenses.isEmpty)
            Text(
              'No expenses logged yet — tap + to add one.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ..._expenses.map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(e.category),
                subtitle: e.note != null && e.note!.isNotEmpty ? Text(e.note!) : null,
                trailing: Text('LKR ${e.amount.toStringAsFixed(2)}'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SuggestedActionCard(action: _sampleSuggestedAction),
          const SizedBox(height: 16),
          const AskBotButton(seedContext: "You're looking at your expense plan."),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = _categories.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (LKR)'),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                Navigator.pop(dialogContext);
                if (amount > 0) {
                  setState(() {
                    _expenses.insert(
                      0,
                      ExpenseModel(
                        userId: 'sample',
                        amount: amount,
                        category: category,
                        note: noteController.text.trim(),
                      ),
                    );
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static placeholder — the real on-device LSTM forecast
/// (ExpenditurePredictionService) comes back in during the backend phase.
class _PredictionCard extends StatelessWidget {
  const _PredictionCard();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.trending_up, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Spending forecast will appear here once prediction is connected.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  final Map<String, double> byCategory;
  const _CategoryPie({required this.byCategory});
  static const _colors = [
    Colors.deepPurple, Colors.blue, Colors.teal, Colors.orange, Colors.pink, Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList();
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: [
            for (int i = 0; i < entries.length; i++)
              PieChartSectionData(
                value: entries[i].value,
                color: _colors[i % _colors.length],
                title: entries[i].key,
                radius: 60,
                titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
