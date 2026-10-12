import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/block_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../services/auth_service.dart';
import '../../services/expenditure/expenditure_overview.dart';
import '../../services/group_service.dart';
import '../../viewmodels/debts_viewmodel.dart';
import '../../viewmodels/expense_viewmodel.dart';
import '../../viewmodels/finance_settings_viewmodel.dart';
import '../../viewmodels/savings_goals_viewmodel.dart';
import 'budgets_screen.dart';
import 'debts_screen.dart';
import 'explore_plans_screen.dart';
import 'finance_settings_sheet.dart';
import 'plan_expenses_screen.dart';
import 'recurring_expenses_screen.dart';
import 'savings_goals_screen.dart';
import 'widgets/expenditure_ui.dart';
import '../../core/theme/app_fonts.dart';

/// "My Expenditures" hub: this month's real numbers, alerts, and the
/// entry points to every expenditure feature. Owns the view models and
/// shares them with the screens it opens, so changes show here on return.
class ExpenditureScreen extends StatefulWidget {
  /// Pre-loaded view models for widget tests; normally null.
  final ({
    ExpenseViewModel expenses,
    SavingsGoalsViewModel goals,
    DebtsViewModel debts,
    FinanceSettingsViewModel settings,
  })? testViewModels;

  const ExpenditureScreen({super.key, @visibleForTesting this.testViewModels});

  @override
  State<ExpenditureScreen> createState() => _ExpenditureScreenState();
}

class _ExpenditureScreenState extends State<ExpenditureScreen> {
  late final ExpenseViewModel _expenses = widget.testViewModels?.expenses ?? ExpenseViewModel();
  late final SavingsGoalsViewModel _goals = widget.testViewModels?.goals ?? SavingsGoalsViewModel();
  late final DebtsViewModel _debts = widget.testViewModels?.debts ?? DebtsViewModel();
  late final FinanceSettingsViewModel _settings =
      widget.testViewModels?.settings ?? FinanceSettingsViewModel();
  late final String _userId =
      widget.testViewModels?.expenses.userId ?? AuthService().currentUser?.id ?? '';

  /// Unpaid seettu instalments this month (see SafeToSpend.upcomingSeettu).
  double _upcomingSeettu = 0;

  @override
  void initState() {
    super.initState();
    if (widget.testViewModels == null) {
      _loadAll();
      _loadSeettu();
    }
  }

  Future<void> _loadSeettu() async {
    final amount = await GroupService().myUnlinkedSeettuDueThisMonth();
    if (mounted && amount != _upcomingSeettu) setState(() => _upcomingSeettu = amount);
  }

  Future<void> _loadAll() => widget.testViewModels != null ? Future.value() : Future.wait([
        _expenses.load(_userId),
        _goals.load(_userId),
        _debts.load(_userId),
        _settings.load(_userId),
      ]);

  @override
  void dispose() {
    if (widget.testViewModels == null) {
      _expenses.dispose();
      _goals.dispose();
      _debts.dispose();
      _settings.dispose();
    }
    super.dispose();
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openTarget(AlertTarget t) {
    switch (t) {
      case AlertTarget.budgets:
        _open(BudgetsScreen(viewModel: _expenses));
      case AlertTarget.plan:
        _open(PlanExpensesScreen(viewModel: _expenses));
      case AlertTarget.recurring:
        _open(RecurringExpensesScreen(viewModel: _expenses));
      case AlertTarget.goals:
        _open(SavingsGoalsScreen(viewModel: _goals));
      case AlertTarget.debts:
        _open(DebtsScreen(viewModel: _debts));
      case AlertTarget.settings:
        showFinanceSettingsSheet(context, _settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
        current: AppSection.expenses,
        title: 'My Expenditures',
        showBackButton: true,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppSection.expenses),
      body: ListenableBuilder(
        listenable: Listenable.merge([_expenses, _goals, _debts, _settings]),
        builder: (context, _) {
          final loggedIn = _userId.isNotEmpty;
          final overview = buildExpenditureOverview(
            expenses: _expenses.expenses,
            budgetLimits: {for (final b in _expenses.budgetStatuses) b.category: b.limit},
            recurring: _expenses.recurring,
            goals: _goals.goals,
            debts: _debts.debts,
            monthlyIncome: _settings.settings.monthlyIncome,
            now: DateTime.now(),
            upcomingSeettu: _upcomingSeettu,
          );
          return RefreshIndicator(
            color: AppColors.onLight,
            backgroundColor: Colors.white,
            onRefresh: _loadAll,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                if (!loggedIn)
                  const LoggedOutCard('Log in to see your real spending, budgets, goals and debts.')
                else if (_expenses.isLoading && _expenses.expenses.isEmpty)
                  const GlassCard(
                    child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
                  )
                else
                  _SummaryCard(
                    overview: overview,
                    hasIncome: _settings.settings.hasIncome,
                    onSetIncome: () => showFinanceSettingsSheet(context, _settings),
                  ),
                if (loggedIn && overview.alerts.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionTitle('Alerts', trailing: Text('${overview.alerts.length}',
                      style: expText(13, weight: FontWeight.w700, color: AppColors.onGlassMuted))),
                  for (final a in overview.alerts.take(6)) ...[
                    _AlertRow(alert: a, onTap: () => _openTarget(a.target)),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 18),
                Text(
                  'Manage & Plan',
                  style: AppFonts.text(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGlass,
                    shadows: kTitleShadow,
                  ),
                ),
                const SizedBox(height: 14),
                _tiles(context, overview),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tiles(BuildContext context, ExpenditureOverview overview) {
    final over = _expenses.budgetStatuses.where((b) => b.isOver).length;
    final tiles = <Widget>[
      BlockButton(
        label: 'Plan My Expenses',
        icon: Icons.edit_note_rounded,
        backgroundColor: AppColors.primary,
        onTap: () => _open(PlanExpensesScreen(viewModel: _expenses)),
      ),
      BlockButton(
        label: 'Budgets',
        subtitle: _expenses.budgets.isEmpty ? null : (over > 0 ? '$over over budget' : '${_expenses.budgets.length} set'),
        icon: Icons.pie_chart_outline_rounded,
        entranceDelay: const Duration(milliseconds: 60),
        onTap: () => _open(BudgetsScreen(viewModel: _expenses)),
      ),
      BlockButton(
        label: 'Savings Goals',
        subtitle: _goals.activeGoals.isEmpty
            ? null
            : '${_goals.activeGoals.length} active · ${formatRs(_goals.totalSaved, decimals: 0)}',
        icon: Icons.flag_rounded,
        entranceDelay: const Duration(milliseconds: 120),
        onTap: () => _open(SavingsGoalsScreen(viewModel: _goals)),
      ),
      BlockButton(
        label: 'Debts & Loans',
        subtitle: _debts.debts.isEmpty
            ? null
            : 'Owed ${formatRs(_debts.owedToMe, decimals: 0)} · Owe ${formatRs(_debts.owedByMe, decimals: 0)}',
        icon: Icons.handshake_outlined,
        entranceDelay: const Duration(milliseconds: 180),
        onTap: () => _open(DebtsScreen(viewModel: _debts)),
      ),
      BlockButton(
        label: 'Explore Budgeting',
        subtitle: '50/30/20 & Zero-Based',
        icon: Icons.lightbulb_outline_rounded,
        entranceDelay: const Duration(milliseconds: 240),
        onTap: () => _open(const ExploreExpenditurePlansScreen()),
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= Responsive.tablet ? 3 : 2;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, height: 96, child: t)],
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  final ExpenditureOverview overview;
  final bool hasIncome;
  final VoidCallback onSetIncome;
  const _SummaryCard({required this.overview, required this.hasIncome, required this.onSetIncome});

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final badge = switch (o.badge) {
      BudgetBadge.healthy => ('Healthy budget', AppColors.gain),
      BudgetBadge.warning => ('Close to budget', AppColors.warning),
      BudgetBadge.over => ('Over budget', AppColors.loss),
      null => ('No budget set', AppColors.onGlassMuted),
    };
    final safe = o.safeToSpend;
    return GlassCard(
      padding: const EdgeInsets.all(22),
      gradient: AppGradients.heroCard,
      borderColor: AppColors.glassBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Flexible(
              child: Text(
                '${kMonthNames[o.month.month - 1].toUpperCase()} EXPENSE TRACKER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: expText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted),
              ),
            ),
            const SizedBox(width: 8),
            TagChip(badge.$1, color: badge.$2),
          ]),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatRs(o.monthSpend), style: expText(32, weight: FontWeight.w800)),
          ),
          if (o.totalBudget > 0) ...[
            const SizedBox(height: 10),
            RatioBar(o.budgetRatio),
            const SizedBox(height: 8),
            Text(
              o.remainingBudget >= 0
                  ? '${formatRs(o.remainingBudget)} left of ${formatRs(o.totalBudget)} budget'
                  : '${formatRs(-o.remainingBudget)} over the ${formatRs(o.totalBudget)} budget',
              style: expText(13, weight: FontWeight.w600,
                  color: o.remainingBudget >= 0 ? AppColors.gain : AppColors.loss),
            ),
            if (o.budgetedSpend < o.monthSpend - 0.005)
              Text(
                '${formatRs(o.monthSpend - o.budgetedSpend, decimals: 0)} spent in categories without a budget',
                style: expText(12, color: AppColors.onGlassMuted),
              ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.innerFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: !hasIncome || safe == null
                ? Row(children: [
                    const Icon(Icons.savings_outlined, color: AppColors.accentCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Set your monthly income to see how much is safe to spend.',
                          style: expText(13, height: 1.4)),
                    ),
                    TextButton(onPressed: onSetIncome, child: const Text('Set')),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text('SAFE TO SPEND THIS MONTH',
                            style: expText(11.5, weight: FontWeight.w700, color: AppColors.onGlassMuted)),
                      ),
                      InkWell(
                        onTap: onSetIncome,
                        child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.onGlassMuted),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatRs(safe.leftToSpend),
                          style: expText(24, weight: FontWeight.w800,
                              color: safe.leftToSpend < 0
                                  ? AppColors.loss
                                  : (safe.isLow ? AppColors.warning : AppColors.gain))),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatRs(safe.safeToSpend, decimals: 0)} free after essentials, bills, goals & debts · '
                      '${formatRs(safe.nonEssentialSpent, decimals: 0)} already spent on non-essentials',
                      style: expText(12, color: AppColors.onGlassMuted, height: 1.35),
                    ),
                    if (o.cutSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Cut first: ${o.cutSuggestions.map((e) => '${e.key} (${formatRs(e.value, decimals: 0)})').join(', ')}',
                        style: expText(12.5, weight: FontWeight.w600, color: AppColors.warning),
                      ),
                    ],
                  ]),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final ExpenditureAlert alert;
  final VoidCallback onTap;
  const _AlertRow({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (alert.level) {
      AlertLevel.danger => (AppColors.loss, Icons.error_outline_rounded),
      AlertLevel.warning => (AppColors.warning, Icons.warning_amber_rounded),
      AlertLevel.info => (AppColors.accentCyan, Icons.info_outline_rounded),
    };
    return GlassRow(
      icon: icon,
      iconColor: color,
      title: alert.title,
      subtitle: alert.detail,
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.onGlassMuted),
    );
  }
}
