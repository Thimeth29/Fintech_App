import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/expense_viewmodel.dart';

const List<String> _categories = [
  'Food', 'Transport', 'Housing', 'Utilities', 'Entertainment', 'Other',
];

class PlanExpensesScreen extends StatelessWidget {
  const PlanExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    return ChangeNotifierProvider(
      create: (_) => ExpenseViewModel()..load(userId ?? ''),
      child: GradientScaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('Plan My Expenses')),
        floatingActionButton: userId == null
            ? null
            : Builder(
                builder: (context) => FloatingActionButton(
                  onPressed: () => _showAddExpenseDialog(context, userId),
                  child: const Icon(Icons.add),
                ),
              ),
        body: Consumer<ExpenseViewModel>(
          builder: (context, vm, _) {
            if (userId == null) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: SuggestedActionCard(
                  action: 'Log in to start tracking and planning your expenses.',
                ),
              );
            }
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Total spent: LKR ${vm.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _PredictionCard(vm: vm),
                const SizedBox(height: 16),
                if (vm.byCategory.isNotEmpty) _CategoryPie(byCategory: vm.byCategory),
                const SizedBox(height: 16),
                const Text('Recent Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (vm.expenses.isEmpty)
                  const Text('No expenses logged yet — tap + to add one.', style: TextStyle(fontSize: 13)),
                ...vm.expenses.map(
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
                SuggestedActionCard(action: vm.suggestedAction),
                const SizedBox(height: 16),
                const AskBotButton(seedContext: "You're looking at your expense plan."),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, String userId) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = _categories.first;
    final vm = context.read<ExpenseViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
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
                onChanged: (v) => setState(() => category = v ?? category),
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
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                Navigator.pop(dialogContext);
                if (amount > 0) {
                  await vm.addExpense(
                    userId: userId,
                    amount: amount,
                    category: category,
                    note: noteController.text.trim(),
                  );
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

/// Shows the on-device LSTM's forecast for next month's total spending
/// (see ExpenditurePredictionService), or an explanatory message when
/// there isn't enough history yet or the model asset isn't bundled.
class _PredictionCard extends StatelessWidget {
  final ExpenseViewModel vm;
  const _PredictionCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: vm.isLoadingPrediction
                ? const Text('Forecasting next month…', style: TextStyle(fontSize: 13))
                : vm.predictedNextMonthTotal != null
                    ? Text(
                        'Predicted next month: LKR ${vm.predictedNextMonthTotal!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      )
                    : Text(
                        vm.predictionMessage ?? 'Spending forecast unavailable.',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
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
