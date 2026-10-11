// lib/services/financial_insight_service.dart
//
// The "agent" layer: pulls together live CSE market data with the
// signed-in user's own expenses and investment history into one text
// snapshot, then hands that snapshot to FinBot (via AiService) so it can
// perform financial tasks — spotting overspending, flagging portfolio
// concentration, comparing today's market movers against what the user
// already holds — instead of answering from generic knowledge alone.
//
// Used two ways:
//   1. buildSnapshot() — grounds every FinBot chat session in real data.
//   2. generateDailyInsight() — a one-shot "what should I know today"
//      summary shown as an AI Insights card on the Investments hub.

import '../core/utils/money.dart';
import '../models/expense_model.dart';
import '../models/expense_priority.dart';
import '../models/investment_action_model.dart';
import '../models/market_data_model.dart';
import 'ai_service.dart';
import 'cse_service.dart';
import 'expense_forecast_service.dart';
import 'expense_service.dart';
import 'expenditure/goal_math.dart';
import 'expenditure/safe_to_spend.dart';
import 'finance_data_services.dart';
import 'community_service.dart';

class FinancialInsightService {
  final CseService _cse = CseService();

  /// Builds a plain-text snapshot of live market data plus (when supplied)
  /// the user's own profile, expenses and investment actions, for use as
  /// an AiService [AiService.new] `financialContext`. [profile] is the raw
  /// row from `profiles` (via AuthService.fetchProfile()) — this is what
  /// makes FinBot's advice reflect *who* the user is (a student with no
  /// income vs. a working adult with dependents and no emergency fund),
  /// not just what they've spent or traded.
  Future<String> buildSnapshot({
    List<ExpenseModel>? expenses,
    List<InvestmentActionModel>? investmentActions,
    Map<String, dynamic>? profile,
    String? userId,
    String? sandboxSummary,
  }) async {
    final buffer = StringBuffer();

    if (profile != null) {
      final lines = <String>[];
      void addIfPresent(String label, dynamic value) {
        if (value == null) return;
        final text = value is List ? value.join(', ') : value.toString();
        if (text.trim().isEmpty) return;
        lines.add('$label: $text');
      }

      addIfPresent('Name', profile['full_name']);
      addIfPresent('Role', profile['user_role']);
      addIfPresent('Occupation', profile['occupation']);
      addIfPresent('District', profile['district']);
      if (profile['is_under_18'] == true) lines.add('Under 18 (use simpler language, avoid suggesting real-money trading)');
      addIfPresent('Monthly income bracket (LKR)', profile['monthly_income']);
      addIfPresent('Main income source', profile['income_source']);
      addIfPresent('Typical monthly spending (LKR)', profile['typical_monthly_spending']);
      addIfPresent('Emergency savings', profile['emergency_savings']);
      addIfPresent('Dependents', profile['dependents']);
      addIfPresent('Assets already held', profile['selected_assets']);

      if (lines.isNotEmpty) {
        buffer.writeln('User profile:');
        for (final line in lines) {
          buffer.writeln('- $line');
        }
        buffer.writeln();
      }
    }

    try {
      final results = await Future.wait([
        _cse.fetchIndices(),
        _cse.fetchTopGainers(),
        _cse.fetchTopLosers(),
      ]);
      final indices = results[0] as List<MarketIndex>;
      final gainers = results[1] as List<StockQuote>;
      final losers = results[2] as List<StockQuote>;

      if (indices.isNotEmpty) {
        buffer.writeln('CSE indices right now:');
        for (final idx in indices) {
          buffer.writeln(
            '- ${idx.name}: ${idx.value.toStringAsFixed(2)} '
            '(${idx.isUp ? "+" : ""}${idx.changePercentage.toStringAsFixed(2)}%)',
          );
        }
      }
      if (gainers.isNotEmpty) {
        buffer.writeln(
          'Top CSE gainers today: ${gainers.take(5).map((s) => '${s.symbol} +${s.changePercentage.toStringAsFixed(2)}%').join(', ')}',
        );
      }
      if (losers.isNotEmpty) {
        buffer.writeln(
          'Top CSE losers today: ${losers.take(5).map((s) => '${s.symbol} ${s.changePercentage.toStringAsFixed(2)}%').join(', ')}',
        );
      }
      if (indices.isEmpty && gainers.isEmpty && losers.isEmpty) {
        buffer.writeln(
          'Live CSE data is unavailable right now (offline or endpoint change) — '
          'mention this if the user asks about today\'s market.',
        );
      }
    } catch (_) {
      buffer.writeln('Live CSE data could not be loaded this session.');
    }

    if (expenses != null && expenses.isNotEmpty) {
      final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
      final byCategory = <String, double>{};
      for (final e in expenses) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      }
      final sorted = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln();
      buffer.writeln(
        'User\'s recorded spending: LKR ${total.toStringAsFixed(2)} total '
        'across ${expenses.length} entries. By category: '
        '${sorted.map((e) => '${e.key} LKR ${e.value.toStringAsFixed(0)}').join(', ')}.',
      );
    }

    if (userId != null && userId.isNotEmpty) {
      final lines = await _expenditureLines(userId, expenses ?? const []);
      for (final l in lines) {
        buffer.writeln(l);
      }
    }

    if (investmentActions != null && investmentActions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'User\'s recent investment actions: '
        '${investmentActions.take(8).map((a) => '${a.action} ${a.symbol} (${a.assetType}) LKR ${a.amount.toStringAsFixed(0)}').join('; ')}.',
      );
    }

    // Practice-only data from the Investment Trainer, labelled as simulated
    // so FinBot never treats it as the user's real money.
    if (sandboxSummary != null && sandboxSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(sandboxSummary);
    }

    // The user's own community groups only (never other members' data).
    if (userId != null) {
      final line = await _communityLine();
      if (line != null) {
        buffer.writeln();
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  /// "Community: 2 groups; next seettu payment Rs 5,000 due 2026-11-05;
  /// confirmed group contributions Rs 60,000". Null when the user has no
  /// groups or Community isn't available.
  Future<String?> _communityLine() async {
    try {
      final s = Map<String, dynamic>.from(await CommunityService().rpc('community_my_snapshot') as Map);
      final groups = (s['groups'] as num?)?.toInt() ?? 0;
      if (groups == 0) return null;
      final parts = <String>['Community: member of $groups group${groups == 1 ? '' : 's'} (records only — members pay each other outside the app)'];
      final next = s['next_seettu_payment'];
      if (next is Map) {
        parts.add('next seettu payment LKR ${(next['amount'] as num).toStringAsFixed(2)} '
            'for ${next['group']} round ${next['round_no']}, due ${next['due_date']} (${next['status']})');
      }
      final contributions = (s['confirmed_contributions'] as num?)?.toDouble() ?? 0;
      if (contributions > 0) parts.add('confirmed investment-group contributions LKR ${contributions.toStringAsFixed(2)}');
      return parts.join('; ');
    } catch (_) {
      return null;
    }
  }

  /// Compact budget / priority / goals / debts / forecast lines. Each part
  /// is optional: a missing table (not migrated yet) or a network error
  /// just leaves that line out.
  Future<List<String>> _expenditureLines(String userId, List<ExpenseModel> expenses) async {
    final now = DateTime.now();
    final lines = <String>[];
    final month = kMonthNames[now.month - 1];
    final thisMonth = expenses
        .where((e) => e.effectiveDate.year == now.year && e.effectiveDate.month == now.month)
        .toList();
    final spent = thisMonth.fold<double>(0, (s, e) => s + e.amount);

    Future<T?> safe<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final expenseService = ExpenseService();
    final budgets = await safe(() => expenseService.fetchBudgets(userId, monthKey(now))) ?? const [];
    final recurring = await safe(() => expenseService.fetchRecurring(userId)) ?? const [];
    final goals = await safe(() => SavingsGoalService().fetchGoals(userId)) ?? const [];
    final debts = await safe(() => DebtService().fetchDebts(userId)) ?? const [];
    final settings = await safe(() => FinanceSettingsService().fetch(userId));

    final budget = budgets.fold<double>(0, (s, b) => s + ((b['limit_amount'] as num?)?.toDouble() ?? 0));
    lines.add(budget > 0
        ? '$month so far: LKR ${spent.toStringAsFixed(0)} spent of LKR ${budget.toStringAsFixed(0)} budget '
            '(${(spent / budget * 100).round()}%).'
        : '$month so far: LKR ${spent.toStringAsFixed(0)} spent; no monthly budget set.');

    if (spent > 0) {
      final split = {for (final p in ExpensePriority.values) p: 0.0};
      for (final e in thisMonth) {
        split[e.priority] = (split[e.priority] ?? 0) + e.amount;
      }
      lines.add('Priority split this month: '
          '${ExpensePriority.values.map((p) => '${ExpensePriority.label(p).toLowerCase()} ${((split[p]! / spent) * 100).round()}%').join(', ')} '
          '(guideline 50/30/20).');
    }

    final sts = computeSafeToSpend(
      monthlyIncome: settings?.monthlyIncome,
      expenses: expenses,
      recurring: recurring,
      goals: goals,
      debts: debts,
      now: now,
    );
    if (sts != null) {
      lines.add('Monthly income LKR ${sts.income.toStringAsFixed(0)}; safe-to-spend left this month '
          'LKR ${sts.leftToSpend.toStringAsFixed(0)}.');
    }

    final activeGoals = goals.where((g) => g.isActive).take(3).toList();
    if (activeGoals.isNotEmpty) {
      lines.add('Savings goals: ${activeGoals.map((g) {
        final p = computeGoalProgress(g, now);
        final pace = g.deadline == null
            ? ''
            : (p.isOnTrack
                ? ', on track for ${shortDate(g.deadline!)}'
                : ', behind (on pace for ${((p.projectedShareAtDeadline ?? p.share) * 100).round()}% by ${shortDate(g.deadline!)})');
        return '${g.name} ${(p.share * 100).round()}% of LKR ${g.targetAmount.toStringAsFixed(0)}$pace';
      }).join('; ')}.');
    }

    final openDebts = debts.where((d) => d.isOpen).toList();
    if (openDebts.isNotEmpty) {
      final owedToMe = openDebts.where((d) => d.isLent).fold<double>(0, (s, d) => s + d.outstanding);
      final owedByMe = openDebts.where((d) => !d.isLent).fold<double>(0, (s, d) => s + d.outstanding);
      final overdue = openDebts.where((d) => d.isOverdue(now)).length;
      lines.add('Debts: others owe the user LKR ${owedToMe.toStringAsFixed(0)}; user owes '
          'LKR ${owedByMe.toStringAsFixed(0)}${overdue > 0 ? '; $overdue overdue' : ''}.');
    }

    final f = ExpenseForecastService().forecastNextMonth(expenses: expenses, recurring: recurring, now: now);
    if (f != null) {
      lines.add('${kMonthNames[f.month.month - 1]} spending forecast: LKR ${f.total.toStringAsFixed(0)} '
          '(range ${f.low.toStringAsFixed(0)}–${f.high.toStringAsFixed(0)}, ${f.confidenceLabel.toLowerCase()} confidence).');
    }
    return lines;
  }

  /// One-shot "here's what to know today" insight, grounded in the same
  /// snapshot. Returned as 2-4 short bullet points as plain text.
  Future<String> generateDailyInsight({
    List<ExpenseModel>? expenses,
    List<InvestmentActionModel>? investmentActions,
    Map<String, dynamic>? profile,
    String? userId,
  }) async {
    final snapshot = await buildSnapshot(
      expenses: expenses,
      investmentActions: investmentActions,
      profile: profile,
      userId: userId,
    );
    final ai = AiService(financialContext: snapshot);
    return ai.ask(
      'Give me 2-4 short bullet points on what I should know or consider '
      'today, based on the live snapshot and (if present) my spending and '
      'investment activity. Be specific and reference actual numbers from '
      'the snapshot where possible.',
    );
  }
}
