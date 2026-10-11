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

import '../models/expense_model.dart';
import '../models/investment_action_model.dart';
import '../models/market_data_model.dart';
import 'ai_service.dart';
import 'cse_service.dart';

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

    if (investmentActions != null && investmentActions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'User\'s recent investment actions: '
        '${investmentActions.take(8).map((a) => '${a.action} ${a.symbol} (${a.assetType}) LKR ${a.amount.toStringAsFixed(0)}').join('; ')}.',
      );
    }

    return buffer.toString();
  }

  /// One-shot "here's what to know today" insight, grounded in the same
  /// snapshot. Returned as 2-4 short bullet points as plain text.
  Future<String> generateDailyInsight({
    List<ExpenseModel>? expenses,
    List<InvestmentActionModel>? investmentActions,
    Map<String, dynamic>? profile,
  }) async {
    final snapshot = await buildSnapshot(
      expenses: expenses,
      investmentActions: investmentActions,
      profile: profile,
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
