import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
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
        title: Text('Plan My Expenses', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Expense', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
        onPressed: () => _showAddExpenseDialog(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total spent hero tile
            GlassCard(
              padding: const EdgeInsets.all(22),
              gradient: AppGradients.heroCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL MONTHLY SPENT',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${_total.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const _PredictionCard(),
            const SizedBox(height: 20),

            // Category Breakdown Chart
            if (_byCategory.isNotEmpty)
              GlassCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Category Breakdown',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 14),
                    _CategoryPie(byCategory: _byCategory),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            Text(
              'Logged Expenses',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 10),

            if (_expenses.isEmpty)
              Text(
                'No expenses logged yet — tap + to log an expense.',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
              ),

            ..._expenses.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: Colors.white,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.mintBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getCategoryIcon(e.category), color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.category,
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            if (e.note != null && e.note!.isNotEmpty)
                              Text(
                                e.note!,
                                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${e.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const SuggestedActionCard(action: _sampleSuggestedAction),
            const SizedBox(height: 16),
            const AskBotButton(seedContext: "You're looking at your expense plan."),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Housing':
        return Icons.home_rounded;
      case 'Utilities':
        return Icons.bolt_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = _categories.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add Expense', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                dropdownColor: Colors.white,
                style: GoogleFonts.outfit(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                style: GoogleFonts.outfit(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
              child: Text('Save Expense', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.mintBg,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'On-device AI forecast model is calculating your next month expenditure trend.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: AppColors.textDark, fontWeight: FontWeight.w500),
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
    AppColors.primary, Color(0xFF16A34A), Color(0xFFF3C06B), Color(0xFF0284C7), Color(0xFF9333EA), Color(0xFFEA580C),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList();
    return SizedBox(
      height: 190,
      child: PieChart(
        PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 36,
          sections: [
            for (int i = 0; i < entries.length; i++)
              PieChartSectionData(
                value: entries[i].value,
                color: _colors[i % _colors.length],
                title: '${entries[i].key}\n${entries[i].value.toInt()}',
                radius: 56,
                titleStyle: GoogleFonts.outfit(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}


