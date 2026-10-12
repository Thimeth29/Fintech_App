import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_backgrounds.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/market_data_model.dart';
import '../../services/asset_data_service.dart';
import '../../services/auth_service.dart';
import '../../services/market_rates_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/expense_viewmodel.dart';
import '../../viewmodels/debts_viewmodel.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import '../bot/chat_screen.dart';
import '../sandbox/sandbox_screen.dart';
import '../expenditure/expenditure_screen.dart';
import '../expenditure/explore_plans_screen.dart';
import '../investments/investing/fd_investments_screen.dart';
import '../investments/investing/gold_investments_screen.dart';
import '../investments/investing/gov_securities_screen.dart';
import '../investments/investing_options_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/theme/app_fonts.dart';

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

Map<String, Color> get _sandboxTypeColors => {
  'cash': Colors.white,
  'stock': AppColors.primary,
  'gold': AppColors.gold,
  'fixed_deposit': AppColors.accentCyan,
  'treasury_bond': AppColors.accentLavender,
  'trading': AppColors.accentTeal,
};

String _sandboxTypeLabel(String type) {
  switch (type) {
    case 'cash':
      return 'Cash';
    case 'stock':
      return 'CSE shares';
    case 'gold':
      return 'Gold';
    case 'fixed_deposit':
      return 'Fixed deposit';
    case 'treasury_bond':
      return 'T-bills & bonds';
    case 'trading':
      return 'Trading';
    default:
      return type;
  }
}

/// "42350.0" -> "42,350"
String _formatMoney(double value) {
  final rounded = value.round().abs();
  final str = rounded.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ExpenseViewModel _expenseViewModel;
  final DebtsViewModel _debtsViewModel = DebtsViewModel();

  double? _usdLkr;
  double? _goldPricePerGram;
  double? _fdRate;
  String? _fdLabel;
  double? _tbillRate;
  String? _tbillLabel;
  bool _marketLoading = true;

  @override
  void initState() {
    super.initState();
    final userId = AuthService().currentUser?.id;
    _expenseViewModel = ExpenseViewModel();
    if (userId != null) {
      _expenseViewModel.load(userId);
      _debtsViewModel.load(userId);
    }
    _loadMarketRates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().loadUserProfile();
      context.read<SandboxViewModel>().load();
    });
  }

  @override
  void dispose() {
    _expenseViewModel.dispose();
    _debtsViewModel.dispose();
    super.dispose();
  }

  Future<void> _loadMarketRates() async {
    try {
      final results = await Future.wait([
        MarketRatesService().fetchUsdLkr(),
        GoldAssetDataService().fetchTopGainers(),
        FixedDepositAssetDataService().fetchTopGainers(),
        SecuritiesAssetDataService().fetchTopGainers(),
      ]);
      if (!mounted) return;
      final gold = results[1] as List<StockQuote>;
      final fd = results[2] as List<StockQuote>;
      final tbill = results[3] as List<StockQuote>;
      setState(() {
        _usdLkr = results[0] as double?;
        _goldPricePerGram = gold.isNotEmpty ? gold.first.price : null;
        _fdRate = fd.isNotEmpty ? fd.first.price : null;
        _fdLabel = fd.isNotEmpty ? fd.first.name : null;
        _tbillRate = tbill.isNotEmpty ? tbill.first.price : null;
        _tbillLabel = tbill.isNotEmpty ? tbill.first.name : null;
        _marketLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _marketLoading = false);
    }
  }

  double _currentMonthSpend(ExpenseViewModel vm) {
    final now = DateTime.now();
    return vm.expenses
        .where((e) => e.effectiveDate.year == now.year && e.effectiveDate.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _totalBudget(ExpenseViewModel vm) =>
      vm.budgets.fold(0.0, (sum, b) => sum + ((b['limit_amount'] as num?)?.toDouble() ?? 0));

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// "Nimal Perera" -> "NP"; falls back to "?" if there's nothing to show.
  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final sandboxVm = context.watch<SandboxViewModel>();
    final displayName = authVm.displayName.isNotEmpty ? authVm.displayName : 'there';
    final initials = _initialsOf(displayName == 'there' ? '' : displayName);
    return AppBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const TopNavBar(current: AppSection.home, title: ''),
      bottomNavigationBar: const AppBottomNav(current: AppSection.home),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_expenseViewModel, _debtsViewModel]),
          builder: (context, _) {
            // Left: what's happening now. Right: plans and portfolio.
            // Phones and tablets stack both lists in this order.
            List<Widget> spaced(List<Widget> cards) => [
                  for (final c in cards) ...[c, const SizedBox(height: 20)],
                ];
            final primary = <Widget>[
              _buildSpendingCard(_expenseViewModel),
              _buildQuickActionsGrid(context),
              _buildForecastCard(_expenseViewModel),
            ];
            final secondary = <Widget>[
              _buildSuggestedCard(context, _expenseViewModel),
              _buildSandboxPortfolioCard(context, sandboxVm),
              _buildMarketTodayCard(context),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              physics: const BouncingScrollPhysics(),
              child: AdaptiveLayout(
                mobile: (_) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderBar(context, displayName, initials),
                        const SizedBox(height: 20),
                        ...spaced(primary),
                        ...spaced(secondary),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
                desktop: (_) => Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: Responsive.desktopMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderBar(context, displayName, initials),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: spaced(primary),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: spaced(secondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER BAR
  // ==========================================
  Widget _buildHeaderBar(BuildContext context, String displayName, String initials) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: AppFonts.text(
                fontSize: 13,
                color: AppColors.onGlass,
                shadows: kTitleShadow,
              ),
            ),
            Text(
              displayName,
              style: AppFonts.text(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.onGlass,
                letterSpacing: -0.5,
                shadows: kTitleShadow,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.onGlass, size: 22),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.loss,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppGradients.action,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: AppFonts.text(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. THIS MONTH'S SPENDING CARD
  // ==========================================
  Widget _buildSpendingCard(ExpenseViewModel vm) {
    final now = DateTime.now();
    final monthName = _monthNames[now.month - 1];
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    final spent = _currentMonthSpend(vm);
    final budget = _totalBudget(vm);
    final hasBudget = budget > 0;
    // Compare the budget with spending in budgeted categories only.
    final budgetedSpent = vm.budgetedSpend;
    final ratio = hasBudget ? (budgetedSpent / budget).clamp(0.0, 1.0) : 0.0;
    final remaining = hasBudget ? (budget - budgetedSpent) : 0.0;

    final frosted = AppGlass.useBlur(context);
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      gradient: frosted ? AppGradients.heroGlass : AppGradients.heroCard,
      sheen: frosted ? AppGradients.heroSheen : null,
      blur: 28,
      borderRadius: 28,
      borderColor: Colors.white.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName spending',
                style: AppFonts.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onGlassMuted,
                ),
              ),
              Text(
                daysLeft > 0 ? '$daysLeft days left' : 'Last day of the month',
                style: AppFonts.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onGlassMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rs ${_formatMoney(spent)}',
                style: AppFonts.text(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (hasBudget) ...[
                const SizedBox(width: 8),
                Text(
                  'of Rs ${_formatMoney(budget)}',
                  style: AppFonts.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onGlassMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          if (hasBudget)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (ratio * 100).round().clamp(1, 100),
                      child: Container(
                        color: ratio >= 0.9 ? AppColors.gold : AppColors.accentCyan,
                      ),
                    ),
                    Expanded(
                      flex: (100 - (ratio * 100).round()).clamp(0, 99),
                      child: Container(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'No monthly budget set yet — set one in Plan My Expenses to track against a goal.',
              style: AppFonts.text(fontSize: 12.5, color: AppColors.onGlassMuted, height: 1.4),
            ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('Spent', 'Rs ${_formatMoney(spent)}'),
              _buildMetricColumn('Budget', hasBudget ? 'Rs ${_formatMoney(budget)}' : 'Not set'),
              _buildMetricColumn('Remaining', hasBudget ? 'Rs ${_formatMoney(remaining)}' : '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.text(fontSize: 12, color: AppColors.onGlassMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppFonts.text(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 4. NEXT MONTH FORECAST CARD
  // ==========================================
  Widget _buildForecastCard(ExpenseViewModel vm) {
    final months = vm.monthlyTotals;
    final forecast = vm.forecast;
    final hasEnoughHistory = vm.predictedNextMonthTotal != null;
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    final nextMonthName = _monthNames[nextMonth.month - 1];

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$nextMonthName forecast',
            style: AppFonts.text(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onGlass,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Predicted from your own spending history',
            style: AppFonts.text(
              fontSize: 13,
              color: AppColors.onGlassMuted,
            ),
          ),
          const SizedBox(height: 12),

          if (vm.isLoadingPrediction)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)),
            )
          else if (!hasEnoughHistory || vm.predictedNextMonthTotal == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                vm.predictionMessage ?? 'Log a few expenses to unlock a spending forecast.',
                style: AppFonts.text(fontSize: 13, color: AppColors.onGlassMuted, height: 1.4),
              ),
            )
          else ...[
            Text(
              'Rs ${_formatMoney(vm.predictedNextMonthTotal!)}',
              style: AppFonts.text(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.onGlass,
              ),
            ),
            if (forecast != null)
              Text(
                'Range Rs ${_formatMoney(forecast.low)} – ${_formatMoney(forecast.high)} · '
                '${forecast.confidenceLabel} confidence',
                style: AppFonts.text(fontSize: 12.5, color: AppColors.onGlassMuted),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 115,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _buildForecastBars(months, vm.predictedNextMonthTotal!, nextMonthName),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              forecast == null
                  ? 'Based on your logged spending.'
                  : forecast.usedPartialMonth
                      ? 'Based on this month so far, scaled to a full month, plus upcoming bills.'
                      : 'Based on your last ${forecast.monthsUsed} month${forecast.monthsUsed == 1 ? '' : 's'} of spending, plus upcoming bills.',
              style: AppFonts.text(fontSize: 12.5, color: AppColors.onGlassMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildForecastBars(
      List<MapEntry<DateTime, double>> months, double predicted, String nextMonthName) {
    final recent = months.length > 5 ? months.sublist(months.length - 5) : months;
    final maxVal = [...recent.map((e) => e.value), predicted].reduce((a, b) => a > b ? a : b);
    double scaledHeight(double v) => maxVal > 0 ? (v / maxVal) * 85 + 20 : 20;

    final bars = <Widget>[];
    for (int i = 0; i < recent.length; i++) {
      final entry = recent[i];
      final label = _monthNames[entry.key.month - 1].substring(0, 3);
      bars.add(_buildBarCol(label, scaledHeight(entry.value), false, isSolidDark: i == recent.length - 1));
    }
    bars.add(_buildBarCol('${nextMonthName.substring(0, 3)}*', scaledHeight(predicted), true));
    return bars;
  }

  Widget _buildBarCol(String label, double height, bool isForecast,
      {bool isSolidDark = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 44,
          height: height,
          decoration: BoxDecoration(
            color: isSolidDark
                ? AppColors.accentCyan
                : (isForecast ? Colors.transparent : AppColors.chartPast),
            borderRadius: BorderRadius.circular(8),
            border: isForecast
                ? Border.all(
                    color: AppColors.accentCyan,
                    width: 1.5,
                    style: BorderStyle.solid)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppFonts.text(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onGlassMuted,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 7. SUGGESTED FOR YOU CARD
  // ==========================================
  /// Debt reminders (due within 7 days or overdue) take priority over the
  /// spending suggestion.
  String _suggestion(ExpenseViewModel vm) => _debtsViewModel.reminderText ?? vm.suggestedAction;

  Widget _buildSuggestedCard(BuildContext context, ExpenseViewModel vm) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED FOR YOU',
            style: AppFonts.text(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accentCyan,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _suggestion(vm),
            style: AppFonts.text(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onGlass,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Plan my expenses',
                      textAlign: TextAlign.center,
                      style: AppFonts.text(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ChatScreen(seedContext: _suggestion(vm))),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.innerFill,
                      side: const BorderSide(color: AppColors.glassBorderStrong),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Ask FinBot about this',
                      textAlign: TextAlign.center,
                      style: AppFonts.text(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onGlass,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. SANDBOX PORTFOLIO CARD
  // ==========================================
  Widget _buildSandboxPortfolioCard(BuildContext context, SandboxViewModel svm) {
    // Total across every unlocked trainer module; % is against
    // Rs 100,000 per unlocked module.
    final portfolioValue = svm.totalValue;
    final returnPct = svm.totalReturnPercent;
    final isUp = returnPct >= 0;

    final valueByType = svm.allocationByType;
    final safeTotal = portfolioValue > 0 ? portfolioValue : 1.0;
    final entries = valueByType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SandboxScreen()),
      ),
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Sandbox portfolio',
                    style: AppFonts.text(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onGlass,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (svm.isLoggedIn) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Lv ${svm.progress.level}',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onGlass,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Virtual',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onGlass,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  'Rs ${_formatMoney(portfolioValue)}',
                  style: AppFonts.text(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onGlass,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  svm.wallets.isEmpty
                      ? 'Start the Investment Trainer'
                      : '${isUp ? "+" : ""}${returnPct.toStringAsFixed(1)}% since start',
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: svm.wallets.isEmpty
                        ? AppColors.onGlassMuted
                        : (isUp ? AppColors.gain : AppColors.loss),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        flex: ((e.value / safeTotal) * 100).round().clamp(1, 100),
                        child: Container(
                            color: _sandboxTypeColors[e.key] ?? AppColors.onGlassMuted),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final e in entries)
                  _buildLegendItem(
                    '${_sandboxTypeLabel(e.key)} ${((e.value / safeTotal) * 100).round()}%',
                    _sandboxTypeColors[e.key] ?? AppColors.onGlassMuted,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.text(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onGlassMuted,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. QUICK ACTIONS GRID
  // ==========================================
  Widget _buildQuickActionsGrid(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    final actions = [
      _QuickAction(
        icon: Icons.receipt_long_rounded,
        title: 'Manage Personal Expenses',
        onTap: () => open(const ExpenditureScreen()),
      ),
      _QuickAction(
        icon: Icons.candlestick_chart_rounded,
        title: 'SandBox Environment',
        onTap: () => open(const SandboxScreen()),
      ),
      _QuickAction(
        icon: Icons.smart_toy_rounded,
        title: 'Financial AI Coach',
        onTap: () => open(const ChatScreen()),
      ),
      _QuickAction(
        icon: Icons.account_balance_rounded,
        title: 'My Investing',
        onTap: () => open(const InvestingOptionsScreen()),
      ),
      _QuickAction(
        icon: Icons.menu_book_rounded,
        title: 'Get Knowledge',
        onTap: () => open(const ExploreExpenditurePlansScreen()),
      ),
    ];

    // Two per row, each row as tall as its taller tile; an odd last tile
    // takes the full width.
    const gap = 12.0;
    return Column(
      children: [
        for (int i = 0; i < actions.length; i += 2) ...[
          if (i > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _QuickActionTile(action: actions[i])),
                if (i + 1 < actions.length) ...[
                  const SizedBox(width: gap),
                  Expanded(child: _QuickActionTile(action: actions[i + 1])),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // 9. MARKET TODAY CARD
  // ==========================================
  Widget _buildMarketTodayCard(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GlassIcon(icon: Icons.show_chart_rounded, size: 34, iconSize: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Market today',
                  style: AppFonts.text(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGlass,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh rates',
                onPressed: _marketLoading
                    ? null
                    : () {
                        setState(() => _marketLoading = true);
                        _loadMarketRates();
                      },
                icon: const Icon(Icons.refresh_rounded, color: AppColors.onGlass, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_marketLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // Wider tiles in the desktop half-column; taller on phones so
              // large accessibility text still fits.
              childAspectRatio: context.isDesktop ? 2.4 : 1.45,
              children: [
                _buildMarketTile(
                  icon: Icons.currency_exchange_rounded,
                  color: const Color(0xFF34D399),
                  label: 'USD / LKR',
                  value: _usdLkr != null ? 'Rs ${_usdLkr!.toStringAsFixed(2)}' : 'Unavailable',
                  onTap: () => open(const InvestingOptionsScreen()),
                ),
                _buildMarketTile(
                  icon: Icons.diamond_rounded,
                  color: AppColors.gold,
                  label: 'Gold (per gram)',
                  value: _goldPricePerGram != null
                      ? 'Rs ${_formatMoney(_goldPricePerGram!)}'
                      : 'Unavailable',
                  onTap: () => open(const GoldInvestmentsScreen()),
                ),
                _buildMarketTile(
                  icon: Icons.savings_rounded,
                  color: AppColors.accentCyan,
                  label: _fdLabel ?? 'Fixed deposit',
                  value: _fdRate != null ? '${_fdRate!.toStringAsFixed(2)}%' : 'Unavailable',
                  onTap: () => open(const FdInvestmentsScreen()),
                ),
                _buildMarketTile(
                  icon: Icons.account_balance_rounded,
                  color: AppColors.accentLavender,
                  label: _tbillLabel ?? 'Treasury bill',
                  value: _tbillRate != null ? '${_tbillRate!.toStringAsFixed(2)}%' : 'Unavailable',
                  onTap: () => open(const GovSecuritiesScreen()),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMarketTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 16,
      fill: AppColors.innerFill,
      accent: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                _GlassIcon(icon: icon, size: 26, iconSize: 14, circle: true),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onGlassMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppFonts.text(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.onGlass,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

/// Frosted-glass icon chip: white icon on a translucent white pane with a
/// bright rim and a faint cyan glow, so every tile matches the glass theme
/// instead of carrying its own color.
class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final bool circle;

  const _GlassIcon({
    required this.icon,
    this.size = 50,
    this.iconSize = 26,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.glassIcon,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.22),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
        shadows: const [Shadow(color: Color(0x660B1F4D), blurRadius: 6, offset: Offset(0, 1))],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: action.onTap,
      borderRadius: 22,
      fill: AppColors.glassFill,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassIcon(icon: action.icon),
                const Spacer(),
                const Icon(Icons.arrow_outward_rounded, color: AppColors.onGlassMuted, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              action.title,
              style: AppFonts.text(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onGlass,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable glass surface that shrinks slightly while pressed and lights up
/// its border on hover, so Home's tiles feel like buttons.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final Color fill;
  final Color? accent;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
    required this.fill,
    this.accent,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final accent = widget.accent ?? AppColors.accentCyan;
    final lit = _pressed || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: widget.fill,
            borderRadius: radius,
            border: Border.all(
              color: lit ? accent.withValues(alpha: 0.8) : AppColors.glassBorder,
              width: 1.2,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              splashColor: accent.withValues(alpha: 0.2),
              highlightColor: accent.withValues(alpha: 0.08),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
