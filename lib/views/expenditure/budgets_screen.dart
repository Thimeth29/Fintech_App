import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/expense_priority.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/expense_viewmodel.dart';
import 'widgets/expenditure_ui.dart';

/// Per-category monthly budgets for the current month.
class BudgetsScreen extends StatelessWidget {
  final ExpenseViewModel? viewModel;
  const BudgetsScreen({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    const body = _BudgetsBody();
    return viewModel != null
        ? ChangeNotifierProvider.value(value: viewModel!, child: body)
        : ChangeNotifierProvider(create: (_) => ExpenseViewModel()..load(userId ?? ''), child: body);
  }
}

class _BudgetsBody extends StatelessWidget {
  const _BudgetsBody();

  Future<void> _edit(BuildContext context, ExpenseViewModel vm, String category) async {
    final current = vm.budgetFor(category);
    final controller = TextEditingController(text: current?.toStringAsFixed(0) ?? '');
    String? error;
    final limit = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('$category budget'),
          content: DialogBody(children: [
            Text('Monthly limit for ${kMonthNames[vm.currentMonth.month - 1]}. '
                "You'll get an alert at 80% and 100%.",
                style: expText(13, color: AppColors.onGlassMuted, height: 1.4)),
            AmountField(controller: controller, label: 'Monthly limit (LKR)', autofocus: true),
            if (error != null) Text(error!, style: expText(13, color: AppColors.loss)),
          ]),
          actions: dialogActions(ctx, saveLabel: 'Save Budget', onSave: () {
            final v = parseAmount(controller.text);
            if (v == null || v <= 0) {
              setState(() => error = 'Enter a limit greater than zero.');
              return;
            }
            Navigator.pop(ctx, v);
          }),
        ),
      ),
    );
    controller.dispose();
    if (limit == null || !context.mounted) return;
    final ok = await vm.upsertBudget(
      userId: vm.userId!,
      category: category,
      limitAmount: limit,
      monthYear: monthKey(vm.currentMonth),
    );
    if (context.mounted) {
      showExpSnack(context, ok ? '$category budget saved' : (vm.errorMessage ?? 'Could not save.'), isError: !ok);
    }
  }

  Future<void> _remove(BuildContext context, ExpenseViewModel vm, String category) async {
    final sure = await confirmAction(context,
        title: 'Remove $category budget?', message: 'Spending stays logged; only the limit is removed.',
        confirmLabel: 'Remove');
    if (!sure || !context.mounted) return;
    final ok = await vm.deleteBudget(category: category);
    if (context.mounted) {
      showExpSnack(context, ok ? '$category budget removed' : (vm.errorMessage ?? 'Could not remove.'),
          isError: !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
          current: AppSection.expenses, title: 'Budgets', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.expenses, isSectionRoot: false),
      body: Consumer<ExpenseViewModel>(builder: (context, vm, _) {
        if (!vm.isLoggedIn) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: LoggedOutCard('Log in to set monthly budgets for each category.'),
          );
        }
        final spent = vm.byCategoryInMonth(vm.currentMonth);
        final totalBudget = vm.totalBudget;
        final totalSpent = vm.budgetedSpend;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            GlassCard(
              gradient: AppGradients.heroCard,
              borderColor: AppColors.glassBorderStrong,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${kMonthNames[vm.currentMonth.month - 1].toUpperCase()} BUDGET',
                    style: expText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted)),
                const SizedBox(height: 6),
                Text(totalBudget > 0 ? formatRs(totalBudget) : 'No budgets yet',
                    style: expText(28, weight: FontWeight.w800)),
                if (totalBudget > 0) ...[
                  const SizedBox(height: 10),
                  RatioBar(totalSpent / totalBudget),
                  const SizedBox(height: 6),
                  Text(
                    '${formatRs(totalSpent)} spent in budgeted categories · '
                    '${totalBudget - totalSpent >= 0 ? '${formatRs(totalBudget - totalSpent)} left' : '${formatRs(totalSpent - totalBudget)} over'}',
                    style: expText(13, color: AppColors.onGlassMuted),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            const SectionTitle('Categories'),
            for (final c in kExpenseCategories) ...[
              _BudgetRow(
                category: c,
                limit: vm.budgetFor(c),
                spent: spent[c] ?? 0,
                onEdit: () => _edit(context, vm, c),
                onRemove: () => _remove(context, vm, c),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      }),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String category;
  final double? limit;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _BudgetRow({
    required this.category,
    required this.limit,
    required this.spent,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l = limit;
    final ratio = l == null || l <= 0 ? 0.0 : spent / l;
    return GlassRow(
      icon: categoryIcon(category),
      iconColor: priorityColor(ExpensePriority.defaultFor(category)),
      title: category,
      subtitle: l == null
          ? '${formatRs(spent)} spent · no limit'
          : '${formatRs(spent)} of ${formatRs(l)} · ${(ratio * 100).round()}%',
      onTap: onEdit,
      trailing: l == null
          ? TextButton(onPressed: onEdit, child: const Text('Set'))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (ratio >= 1)
                const TagChip('Over', color: AppColors.loss)
              else if (ratio >= 0.8)
                const TagChip('80%+', color: AppColors.warning),
              IconButton(
                tooltip: 'Remove budget',
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.onGlassMuted),
                onPressed: onRemove,
              ),
            ]),
      footer: l == null ? null : RatioBar(ratio),
    );
  }
}
