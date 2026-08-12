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
  /// the user's own expenses/investment actions, for use as an AiService
  /// [AiService.new] `financialContext`.
  Future<String> buildSnapshot({
    List<ExpenseModel>? expenses,
    List<InvestmentActionModel>? investmentActions,
  }) async {
    final buffer = StringBuffer();

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
  }) async {
    final snapshot = await buildSnapshot(
      expenses: expenses,
      investmentActions: investmentActions,
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
