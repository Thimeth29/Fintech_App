import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/market_data_model.dart';
import '../../services/asset_data_service.dart';
import '../../services/auth_service.dart';
import '../../services/market_rates_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/expense_viewmodel.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import '../bot/chat_screen.dart';
import '../sandbox/sandbox_screen.dart';
import '../expenditure/expenditure_screen.dart';
import '../expenditure/explore_plans_screen.dart';
import '../profile/profile_screen.dart';

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

Map<String, Color> get _sandboxTypeColors => {
  'cash': AppColors.textDark,
  'stock': AppColors.primary,
  'gold': AppColors.goldAccent,
  'fixed_deposit': const Color(0xFF2563EB),
  'treasury_bond': const Color(0xFF7C3AED),
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
      return 'Treasury bond';
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

double? _parseMoney(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Rough number of months of spending covered by the signup "emergency
/// savings" bracket — used to estimate, not track, an emergency fund.
double _monthsCoveredForBracket(String bracket) {
  switch (bracket) {
    case 'None yet':
      return 0;
    case 'Under 1 month of spending':
      return 0.5;
    case '1–3 months':
      return 2;
    case '3+ months':
      return 3;
    default:
      return 0;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ExpenseViewModel _expenseViewModel;
  late final SandboxViewModel _sandboxViewModel;

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
    _sandboxViewModel = SandboxViewModel();
    if (userId != null) {
      _expenseViewModel.load(userId);
    }
    _sandboxViewModel.loadSandboxData();
    _loadMarketRates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().loadUserProfile();
    });
  }

  @override
  void dispose() {
    _expenseViewModel.dispose();
    _sandboxViewModel.dispose();
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
        .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, double> _currentMonthByCategory(ExpenseViewModel vm) {
    final now = DateTime.now();
    final map = <String, double>{};
    for (final e in vm.expenses) {
      if (e.createdAt.year == now.year && e.createdAt.month == now.month) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
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
    final displayName = authVm.displayName.isNotEmpty ? authVm.displayName : 'there';
    final initials = _initialsOf(displayName == 'there' ? '' : displayName);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
        label: Text(
          'Ask FinBot AI',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_expenseViewModel, _sandboxViewModel]),
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBar(context, displayName, initials),
                      const SizedBox(height: 20),

                      _buildSpendingCard(_expenseViewModel),
                      const SizedBox(height: 20),

                      _buildQuickActionsRow(context),
                      const SizedBox(height: 16),

                      _buildAiAssistantBanner(context),
                      const SizedBox(height: 20),

                      _buildForecastCard(_expenseViewModel),
                      const SizedBox(height: 20),

                      _buildBudgetsCard(context, _expenseViewModel),
                      const SizedBox(height: 20),

                      _buildEmergencyFundCard(authVm.userProfile),
                      const SizedBox(height: 20),

                      _buildSuggestedCard(context, _expenseViewModel),
                      const SizedBox(height: 20),

                      _buildSandboxPortfolioCard(context, _sandboxViewModel),
                      const SizedBox(height: 20),

                      _buildMarketTodayCard(context),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            );
          },
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
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              displayName,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.5,
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
                    color: AppColors.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.textDark, size: 22),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
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
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
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
    final ratio = hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final remaining = hasBudget ? (budget - spent) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName spending',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                daysLeft > 0 ? '$daysLeft days left' : 'Last day of the month',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
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
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (hasBudget) ...[
                const SizedBox(width: 8),
                Text(
                  'of Rs ${_formatMoney(budget)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
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
                        color: ratio >= 0.9
                            ? AppColors.goldAccent
                            : const Color(0xFF147A4D),
                      ),
                    ),
                    Expanded(
                      flex: (100 - (ratio * 100).round()).clamp(0, 99),
                      child: Container(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'No monthly budget set yet — set one in Plan My Expenses to track against a goal.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.white70, height: 1.4),
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
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. QUICK ACTIONS ROW
  // ==========================================
  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionTile(
          context: context,
          icon: Icons.add_rounded,
          label: 'Add expense',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
          ),
        ),
        _buildActionTile(
          context: context,
          icon: Icons.trending_up_rounded,
          label: 'Practise trade',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SandboxScreen()),
          ),
        ),
        _buildActionTile(
          context: context,
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Ask coach',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          ),
        ),
        _buildActionTile(
          context: context,
          icon: Icons.menu_book_rounded,
          label: 'Learn',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const ExploreExpenditurePlansScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3b. AI COACH QUICK SHORTCUT BANNER
  // ==========================================
  Widget _buildAiAssistantBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.mintBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FinBot AI Financial Advisor',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ask anything about CSE stocks, budgets or taxes',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.cardBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. NEXT MONTH FORECAST CARD
  // ==========================================
  Widget _buildForecastCard(ExpenseViewModel vm) {
    final months = vm.monthlyTotals;
    final hasEnoughHistory = months.length >= 3;
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    final nextMonthName = _monthNames[nextMonth.month - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$nextMonthName forecast',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Predicted from your own spending history',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          if (vm.isLoadingPrediction)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (!hasEnoughHistory || vm.predictedNextMonthTotal == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                vm.predictionMessage ??
                    'Log expenses across at least 3 different months to unlock a spending forecast.',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.4),
              ),
            )
          else ...[
            Text(
              'Rs ${_formatMoney(vm.predictedNextMonthTotal!)}',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
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
              'Based on your spending across the last ${months.length > 5 ? 5 : months.length} month(s) you\'ve logged.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
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
                ? AppColors.primary
                : (isForecast ? Colors.transparent : const Color(0xFFC6E7D5)),
            borderRadius: BorderRadius.circular(8),
            border: isForecast
                ? Border.all(
                    color: AppColors.primary,
                    width: 1.5,
                    style: BorderStyle.solid)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 5. BUDGETS CARD
  // ==========================================
  Widget _buildBudgetsCard(BuildContext context, ExpenseViewModel vm) {
    final spentByCategory = _currentMonthByCategory(vm);
    final budgetsToShow = vm.budgets.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budgets',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
                ),
                child: Text(
                  'See all',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (budgetsToShow.isEmpty)
            Text(
              'No budgets set yet — set one from Plan My Expenses to track your spending against a goal.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            )
          else
            for (int i = 0; i < budgetsToShow.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              Builder(builder: (context) {
                final b = budgetsToShow[i];
                final category = (b['category'] as String?) ?? 'Other';
                final limit = (b['limit_amount'] as num?)?.toDouble() ?? 0;
                final spent = spentByCategory[category] ?? 0;
                final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                final isWarning = limit > 0 && ratio >= 0.85;
                return _buildBudgetItem(
                  category,
                  'Rs ${_formatMoney(spent)} / ${_formatMoney(limit)}',
                  ratio,
                  isWarning ? AppColors.rose : AppColors.primary,
                  warningText: isWarning
                      ? '${(ratio * 100).round()}% used${daysLeftNote()}'
                      : null,
                );
              }),
            ],
        ],
      ),
    );
  }

  String daysLeftNote() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    return daysLeft > 0 ? ' with $daysLeft days to go' : '';
  }

  Widget _buildBudgetItem(
      String label, String amountText, double ratio, Color color,
      {String? warningText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            Text(
              amountText,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: warningText != null ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (warningText != null) ...[
          const SizedBox(height: 4),
          Text(
            warningText,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // 6. EMERGENCY FUND CARD
  // ==========================================
  Widget _buildEmergencyFundCard(Map<String, dynamic>? profile) {
    final bracket = profile?['emergency_savings'] as String?;
    final monthlySpend = _parseMoney(profile?['typical_monthly_spending'] as String?);
    final hasData = bracket != null && bracket.isNotEmpty && monthlySpend != null && monthlySpend > 0;

    double ratio = 0;
    double goal = 0;
    double estimatedSaved = 0;
    double monthsCovered = 0;
    if (hasData) {
      monthsCovered = _monthsCoveredForBracket(bracket);
      goal = monthlySpend * 3;
      estimatedSaved = (monthsCovered * monthlySpend).clamp(0, goal);
      ratio = goal > 0 ? (estimatedSaved / goal).clamp(0.0, 1.0) : 0.0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency fund',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (hasData)
                Text(
                  '${(ratio * 100).round()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (!hasData)
            Text(
              'Answer the money questions during signup (or update your profile) to see this.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            )
          else ...[
            Text(
              'Rs ${_formatMoney(estimatedSaved)} of a Rs ${_formatMoney(goal)} goal (3 months of spending) — estimated from what you told us, not a tracked balance.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              monthsCovered >= 3
                  ? 'You\'re at or above a 3-month safety net based on what you told us — nice work.'
                  : 'Aim to build this toward 3 months of spending for a solid safety net.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 7. SUGGESTED FOR YOU CARD
  // ==========================================
  Widget _buildSuggestedCard(BuildContext context, ExpenseViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED FOR YOU',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vm.suggestedAction,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Plan my expenses',
                      style: GoogleFonts.outfit(
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
                          builder: (_) => ChatScreen(seedContext: vm.suggestedAction)),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.cardBg,
                      side: const BorderSide(color: AppColors.borderLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Ask FinBot about this',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
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
    final portfolioValue = svm.portfolioValue;
    final returnPct = svm.totalReturnPercent;
    final isUp = returnPct >= 0;

    final valueByType = <String, double>{'cash': svm.virtualBalance};
    for (final h in svm.holdings) {
      final value = h.quantity * h.instrument.currentPrice;
      valueByType[h.instrument.type] = (valueByType[h.instrument.type] ?? 0) + value;
    }
    final safeTotal = portfolioValue > 0 ? portfolioValue : 1.0;
    final entries = valueByType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SandboxScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sandbox portfolio',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Virtual',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rs ${_formatMoney(portfolioValue)}',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isUp ? "+" : ""}${returnPct.toStringAsFixed(1)}% since start',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isUp ? AppColors.primary : AppColors.rose,
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
                            color: _sandboxTypeColors[e.key] ?? AppColors.textMuted),
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
                    _sandboxTypeColors[e.key] ?? AppColors.textMuted,
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
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 9. MARKET TODAY CARD
  // ==========================================
  Widget _buildMarketTodayCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market today',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),

          if (_marketLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _buildMarketTile('USD / LKR',
                    _usdLkr != null ? 'Rs ${_usdLkr!.toStringAsFixed(2)}' : 'Unavailable'),
                _buildMarketTile('Gold (per gram)',
                    _goldPricePerGram != null ? 'Rs ${_formatMoney(_goldPricePerGram!)}' : 'Unavailable'),
                _buildMarketTile(_fdLabel ?? 'Fixed deposit',
                    _fdRate != null ? '${_fdRate!.toStringAsFixed(2)}%' : 'Unavailable'),
                _buildMarketTile(_tbillLabel ?? 'Treasury bill',
                    _tbillRate != null ? '${_tbillRate!.toStringAsFixed(2)}%' : 'Unavailable'),
              ],
            ),
          const SizedBox(height: 14),
          Text(
            'USD/LKR updates live. Gold, FD and T-Bill are reference rates, not real-time.',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mintBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
