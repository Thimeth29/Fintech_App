import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/suggested_action_card.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/expense_model.dart';
import '../../models/expense_priority.dart';
import '../../services/auth_service.dart';
import '../../services/expense_forecast_service.dart';
import '../../viewmodels/expense_viewmodel.dart';
import 'budgets_screen.dart';
import 'recurring_expenses_screen.dart';
import 'widgets/expenditure_ui.dart';
import 'widgets/expense_form_dialog.dart';
import '../../core/theme/app_fonts.dart';

class PlanExpensesScreen extends StatelessWidget {
  /// Shared view model from the Expenditure hub; when null (e.g. opened
  /// from Home) the screen creates and loads its own.
  final ExpenseViewModel? viewModel;
  const PlanExpensesScreen({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    const body = _PlanBody();
    return viewModel != null
        ? ChangeNotifierProvider.value(value: viewModel!, child: body)
        : ChangeNotifierProvider(create: (_) => ExpenseViewModel()..load(userId ?? ''), child: body);
  }
}

class _PlanBody extends StatefulWidget {
  const _PlanBody();

  @override
  State<_PlanBody> createState() => _PlanBodyState();
}

class _PlanBodyState extends State<_PlanBody> {
  bool _allTime = false;

  Future<void> _add(ExpenseViewModel vm) async {
    final r = await showExpenseForm(context);
    if (r == null || !mounted) return;
    final ok = await vm.addExpense(
      userId: vm.userId!,
      amount: r.amount,
      category: r.category,
      note: r.note,
      expenseDate: r.date,
      priority: r.priority,
    );
    if (!mounted) return;
    _afterSave(vm, ok, 'Expense added');
  }

  Future<void> _edit(ExpenseViewModel vm, ExpenseModel e) async {
    final r = await showExpenseForm(context, existing: e);
    if (r == null || !mounted) return;
    final ok = await vm.updateExpense(e.copyWith(
      amount: r.amount,
      category: r.category,
      expenseDate: r.date,
      priority: r.priority,
      note: r.note,
      clearNote: r.note == null,
    ));
    if (!mounted) return;
    _afterSave(vm, ok, 'Expense updated');
  }

  void _afterSave(ExpenseViewModel vm, bool ok, String message) {
    if (!ok) {
      showExpSnack(context, vm.errorMessage ?? 'Something went wrong.', isError: true);
      return;
    }
    final alert = vm.takeBudgetAlert();
    showExpSnack(context, alert ?? message, isError: alert != null && alert.contains('over budget'));
  }

  Future<bool> _confirmDelete(ExpenseModel e) => confirmAction(
        context,
        title: 'Delete expense?',
        message: '${e.category} · ${formatRs(e.amount)} on ${shortDate(e.effectiveDate)}',
      );

  Future<void> _delete(ExpenseViewModel vm, ExpenseModel e) async {
    final ok = await vm.deleteExpense(userId: vm.userId!, id: e.id!);
    if (!mounted) return;
    if (!ok) {
      showExpSnack(context, vm.errorMessage ?? 'Could not delete.', isError: true);
      return;
    }
    showExpSnack(
      context,
      'Expense deleted',
      action: SnackBarAction(label: 'UNDO', onPressed: () => vm.restoreExpense(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<ExpenseViewModel>().userId;
    final loggedIn = userId != null && userId.isNotEmpty;
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
        current: AppSection.expenses,
        title: 'Plan My Expenses',
        showBackButton: true,
        isSectionRoot: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppSection.expenses, isSectionRoot: false),
      floatingActionButton: !loggedIn
          ? null
          : Consumer<ExpenseViewModel>(
              builder: (context, vm, _) => FloatingActionButton.extended(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.onLight,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add_rounded, color: AppColors.onLight),
                label: Text('Add Expense',
                    style: AppFonts.text(fontWeight: FontWeight.w700, color: AppColors.onLight)),
                onPressed: () => _add(vm),
              ),
            ),
      body: Consumer<ExpenseViewModel>(
        builder: (context, vm, _) {
          if (!loggedIn) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: SuggestedActionCard(action: 'Log in to start tracking and planning your real expenses.'),
            );
          }
          if (vm.isLoading && vm.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
          }
          return RefreshIndicator(
            color: AppColors.onLight,
            backgroundColor: Colors.white,
            onRefresh: () => vm.load(userId),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                _totalCard(vm),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoicePill(
                    label: 'Budgets',
                    icon: Icons.pie_chart_outline_rounded,
                    selected: false,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => BudgetsScreen(viewModel: vm))),
                  ),
                  ChoicePill(
                    label: 'Recurring bills',
                    icon: Icons.event_repeat_rounded,
                    selected: false,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => RecurringExpensesScreen(viewModel: vm))),
                  ),
                ]),
                const SizedBox(height: 16),
                _ForecastCard(vm: vm),
                const SizedBox(height: 16),
                if (vm.errorMessage != null) ...[
                  Text(vm.errorMessage!, style: expText(13, color: AppColors.loss)),
                  const SizedBox(height: 12),
                ],
                _filters(vm),
                const SizedBox(height: 14),
                _PrioritySplitCard(split: vm.byPriorityInMonth(vm.selectedMonth)),
                const SizedBox(height: 14),
                if (vm.byCategoryInMonth(vm.selectedMonth).isNotEmpty) ...[
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${kMonthNames[vm.selectedMonth.month - 1]} by category',
                            style: expText(16, weight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        _CategoryPie(byCategory: vm.byCategoryInMonth(vm.selectedMonth)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                SectionTitle('Logged Expenses',
                    trailing: Text('${vm.filteredExpenses.length} items',
                        style: expText(12, color: AppColors.onGlassMuted))),
                if (vm.filteredExpenses.isEmpty)
                  EmptyNote(
                    vm.filterCategory != null || vm.filterPriority != null
                        ? 'No expenses match these filters.'
                        : 'No expenses logged for ${kMonthNames[vm.selectedMonth.month - 1]} yet — tap Add Expense.',
                    icon: Icons.receipt_long_rounded,
                  )
                else
                  for (final day in vm.filteredByDay) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(_dayLabel(day.key),
                              style: expText(13, weight: FontWeight.w700, color: AppColors.onGlassMuted)),
                        ),
                        Text(formatRs(day.value.fold(0.0, (s, e) => s + e.amount)),
                            style: expText(13, weight: FontWeight.w700, color: AppColors.onGlassMuted)),
                      ]),
                    ),
                    for (final e in day.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(e),
                          onDismissed: (_) => _delete(vm, e),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 22),
                            decoration: BoxDecoration(
                              color: AppColors.lossStrong,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          child: _ExpenseRow(expense: e, onTap: () => _edit(vm, e)),
                        ),
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalCard(ExpenseViewModel vm) {
    final month = vm.currentMonth;
    final value = _allTime ? vm.allTimeTotal : vm.currentMonthSpend;
    return GlassCard(
      gradient: AppGradients.heroCard,
      borderColor: AppColors.glassBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                _allTime ? 'TOTAL LOGGED · ALL TIME' : 'SPENT IN ${kMonthNames[month.month - 1].toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: expText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted),
              ),
            ),
            const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value == null ? '…' : formatRs(value), style: expText(30, weight: FontWeight.w800)),
          ),
          if (!_allTime && vm.totalBudget > 0) ...[
            const SizedBox(height: 10),
            RatioBar(vm.currentMonthSpend / vm.totalBudget),
            const SizedBox(height: 6),
            Text('of ${formatRs(vm.totalBudget)} budget', style: expText(12.5, color: AppColors.onGlassMuted)),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            ChoicePill(label: 'This month', selected: !_allTime, onTap: () => setState(() => _allTime = false)),
            ChoicePill(
              label: 'All time',
              selected: _allTime,
              onTap: () {
                setState(() => _allTime = true);
                if (vm.allTimeTotal == null) vm.loadAllTimeTotal();
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _filters(ExpenseViewModel vm) {
    final months = vm.availableMonths;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.filter_list_rounded, color: AppColors.onGlassMuted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DateTime>(
                  value: months.contains(vm.selectedMonth) ? vm.selectedMonth : months.first,
                  isExpanded: true,
                  dropdownColor: AppColors.deepNavy,
                  style: expText(14, weight: FontWeight.w700),
                  items: [
                    for (final m in months)
                      DropdownMenuItem(value: m, child: Text('${kMonthNames[m.month - 1]} ${m.year}')),
                  ],
                  onChanged: (m) => m == null ? null : vm.setSelectedMonth(m),
                ),
              ),
            ),
            if (vm.filterCategory != null || vm.filterPriority != null)
              TextButton(onPressed: () => vm.setFilters(), child: const Text('Clear')),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in kExpenseCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoicePill(
                    label: c,
                    icon: categoryIcon(c),
                    selected: vm.filterCategory == c,
                    onTap: () => vm.setFilters(
                        category: vm.filterCategory == c ? null : c, priority: vm.filterPriority),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in ExpensePriority.values)
              ChoicePill(
                label: ExpensePriority.label(p),
                selected: vm.filterPriority == p,
                onTap: () => vm.setFilters(
                    category: vm.filterCategory, priority: vm.filterPriority == p ? null : p),
              ),
          ]),
        ],
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${shortDate(d)}';
  }
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  const _ExpenseRow({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = expense;
    return GlassRow(
      icon: categoryIcon(e.category),
      title: e.note?.isNotEmpty == true ? e.note! : e.category,
      subtitle: e.note?.isNotEmpty == true ? e.category : null,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatRs(e.amount), style: expText(15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (e.isRecurring) ...[
              const Icon(Icons.event_repeat_rounded, size: 14, color: AppColors.onGlassMuted),
              const SizedBox(width: 4),
            ],
            TagChip(ExpensePriority.label(e.priority), color: priorityColor(e.priority)),
          ]),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final ExpenseViewModel vm;
  const _ForecastCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final f = vm.forecast;
    if (vm.isLoadingPrediction) {
      return const GlassCard(
          child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)));
    }
    return GlassCard(
      borderColor: AppColors.accentViolet.withValues(alpha: 0.6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(gradient: AppGradients.action, shape: BoxShape.circle),
            child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: f == null
                ? Text(vm.predictionMessage ?? 'Spending forecast unavailable.',
                    style: expText(13.5, color: AppColors.onGlassMuted, height: 1.4))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${kMonthNames[f.month.month - 1]} forecast',
                          style: expText(13, weight: FontWeight.w700, color: AppColors.accentCyan)),
                      const SizedBox(height: 4),
                      Text('Expected: ${formatRs(f.total, decimals: 0)}',
                          style: expText(18, weight: FontWeight.w800)),
                      Text('(${formatRs(f.low, decimals: 0)} – ${formatRs(f.high, decimals: 0)})',
                          style: expText(13, color: AppColors.onGlassMuted)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        TagChip('${f.confidenceLabel} confidence',
                            color: f.confidence == ForecastConfidence.high
                                ? AppColors.gain
                                : (f.confidence == ForecastConfidence.medium ? AppColors.warning : AppColors.loss)),
                        if (f.recurringTotal > 0)
                          TagChip('Bills ${formatRs(f.recurringTotal, decimals: 0)}', color: AppColors.accentCyan),
                        if (f.seasonalBumpApplied) const TagChip('Seasonal +15%', color: AppColors.gold),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        f.usedPartialMonth
                            ? 'Based on this month so far, scaled to a full month.'
                            : 'Based on ${f.monthsUsed} recent month${f.monthsUsed == 1 ? '' : 's'} of spending.',
                        style: expText(12, color: AppColors.onGlassMuted),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Essential / Important / Flexible split vs the 50/30/20 guideline.
class _PrioritySplitCard extends StatelessWidget {
  final Map<String, double> split;
  const _PrioritySplitCard({required this.split});

  static const _guideline = {
    ExpensePriority.essential: 0.5,
    ExpensePriority.important: 0.3,
    ExpensePriority.flexible: 0.2,
  };

  @override
  Widget build(BuildContext context) {
    final total = split.values.fold(0.0, (s, v) => s + v);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Needs vs wants', style: expText(16, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Compared with the 50 / 30 / 20 guideline', style: expText(12, color: AppColors.onGlassMuted)),
          const SizedBox(height: 12),
          if (total <= 0)
            Text('No spending in this month yet.', style: expText(13, color: AppColors.onGlassMuted))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(children: [
                  for (final p in ExpensePriority.values)
                    if ((split[p] ?? 0) > 0)
                      Expanded(
                        flex: (((split[p] ?? 0) / total) * 1000).round().clamp(1, 1000),
                        child: Container(color: priorityColor(p)),
                      ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            for (final p in ExpensePriority.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: priorityColor(p), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ExpensePriority.label(p), style: expText(13))),
                  Text('${(((split[p] ?? 0) / total) * 100).round()}%',
                      style: expText(13, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 74,
                    child: Text('guide ${((_guideline[p] ?? 0) * 100).round()}%',
                        textAlign: TextAlign.right, style: expText(12, color: AppColors.onGlassMuted)),
                  ),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  final Map<String, double> byCategory;
  const _CategoryPie({required this.byCategory});
  static List<Color> get _colors => AppColors.chartSeries;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (s, e) => s + e.value);
    return Column(
      children: [
        SizedBox(
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
                    title: '${((entries[i].value / total) * 100).round()}%',
                    radius: 56,
                    titleStyle: AppFonts.text(
                        fontSize: 11,
                        color: AppColors.onFill(_colors[i % _colors.length]),
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 8, children: [
          for (int i = 0; i < entries.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${entries[i].key} ${formatRs(entries[i].value, decimals: 0)}', style: expText(12.5)),
            ]),
        ]),
      ],
    );
  }
}
