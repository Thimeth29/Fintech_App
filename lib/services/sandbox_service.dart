// lib/services/sandbox_service.dart
//
// Supabase access for the Investment Trainer. Reads go straight to the
// sandbox_* tables (RLS: own rows only); every write is an RPC (see
// supabase/migrations/20261012090000_sandbox_trainer.sql). Nothing here
// updates local state optimistically: callers apply what the server
// returns.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/sandbox/sandbox_config.dart';
import '../models/sandbox_models.dart';
import 'sandbox/fast_forward.dart';

/// A server-side rejection, with the code raised by the RPC.
class SandboxException implements Exception {
  final String code;
  const SandboxException(this.code);

  String get message => sandboxErrorText(code);

  @override
  String toString() => message;
}

/// The RPC's own code (the RAISE message), or 'trainer_unavailable' when
/// the trainer's tables/functions aren't in the database yet.
String _codeOf(PostgrestException e) {
  const missing = {'PGRST202', 'PGRST205', '42883', '42P01'};
  if (missing.contains(e.code)) return 'trainer_unavailable';
  return e.message;
}

String sandboxErrorText(String code) => switch (code) {
      'not_authenticated' => 'Log in to start training.',
      'trainer_unavailable' =>
        'The Investment Trainer isn\'t set up on the server yet, so progress can\'t be saved. Please try again later.',
      'module_locked' => 'Finish this module\'s first lesson and quiz to unlock the simulator.',
      'lesson_required' => 'Pass the first quiz to unlock the simulator.',
      'invalid_quantity' => 'Enter a quantity greater than zero.',
      'whole_shares_only' => 'CSE shares can only be bought in whole numbers.',
      'invalid_price' => 'That price isn\'t valid. Try again.',
      'invalid_fee' => 'The fee for that trade isn\'t valid.',
      'insufficient_balance' => 'Not enough virtual cash in this module\'s wallet.',
      'insufficient_holdings' => 'You don\'t own enough of this to sell.',
      'opposite_position_open' => 'Close your existing position in this instrument first.',
      'short_locked' => 'Short selling unlocks at level $kShortSellingLevel.',
      'short_not_allowed' => 'Short selling is only available in the trading module.',
      'invalid_risk_levels' => 'Stop-loss and take-profit must be above zero.',
      'invalid_amount' => 'Enter an amount greater than zero.',
      'invalid_tenure' => 'Choose one of the listed tenures.',
      'invalid_rate' => 'That rate isn\'t valid.',
      'position_not_found' || 'position_not_open' => 'That position is already closed.',
      'hold_to_maturity' => 'T-bills are held to maturity in the trainer.',
      'invalid_days' => 'Fast-forward between 1 day and 1 year at a time.',
      'invalid_event' || 'invalid_event_date' || 'too_many_events' =>
        'The simulation got out of sync. Pull down to refresh and try again.',
      'round_not_found' || 'round_already_settled' => 'That round has already finished.',
      'network' => 'Couldn\'t reach the server. Check your connection and try again.',
      _ => 'Something went wrong ($code). Please try again.',
    };

class SandboxSnapshot {
  final List<SandboxWallet> wallets;
  final List<SandboxHolding> holdings;
  final List<SandboxPosition> positions;
  final SandboxProgress progress;
  final List<LessonProgress> lessons;
  final Set<String> badges;
  final List<ChallengeState> challenges;
  final List<SandboxTrade> recentTrades;

  const SandboxSnapshot({
    required this.wallets,
    required this.holdings,
    required this.positions,
    required this.progress,
    required this.lessons,
    required this.badges,
    required this.challenges,
    required this.recentTrades,
  });
}

class SandboxService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  String? get userId {
    try {
      return _client?.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => userId != null;

  Future<SandboxSnapshot> load() async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) throw const SandboxException('not_authenticated');
    try {
      final results = await Future.wait<dynamic>([
        client.from('sandbox_wallets').select().eq('user_id', uid),
        client.from('sandbox_holdings').select().eq('user_id', uid),
        client.from('sandbox_positions').select().eq('user_id', uid).neq('status', 'archived'),
        client.from('sandbox_progress').select().eq('user_id', uid).maybeSingle(),
        client.from('sandbox_lesson_progress').select().eq('user_id', uid),
        client.from('sandbox_badges').select('badge_id').eq('user_id', uid),
        client.from('sandbox_challenges').select().eq('user_id', uid),
        client
            .from('sandbox_trades')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(500),
      ]);
      List<Map<String, dynamic>> rows(int i) => List<Map<String, dynamic>>.from(results[i] as List);
      final wallets = rows(0).map(SandboxWallet.fromJson).toList();
      final batches = {for (final w in wallets) w.resetBatch};
      return SandboxSnapshot(
        wallets: wallets,
        holdings: rows(1).map(SandboxHolding.fromJson).toList(),
        positions: rows(2).map(SandboxPosition.fromJson).where((p) => batches.contains(p.resetBatch)).toList(),
        progress: results[3] == null
            ? const SandboxProgress()
            : SandboxProgress.fromJson(Map<String, dynamic>.from(results[3] as Map)),
        lessons: rows(4).map(LessonProgress.fromJson).toList(),
        badges: {for (final r in rows(5)) '${r['badge_id']}'},
        challenges: rows(6).map(ChallengeState.fromJson).toList(),
        recentTrades:
            rows(7).map(SandboxTrade.fromJson).where((t) => batches.contains(t.resetBatch)).toList(),
      );
    } on PostgrestException catch (e) {
      throw SandboxException(_codeOf(e));
    } catch (e) {
      if (e is SandboxException) rethrow;
      throw const SandboxException('network');
    }
  }

  /// Full history for one module, newest first, including archived resets.
  Future<List<SandboxTrade>> fetchTrades(SandboxModule module, {int limit = 300}) async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return const [];
    try {
      final rows = await client
          .from('sandbox_trades')
          .select()
          .eq('user_id', uid)
          .eq('module', module.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows).map(SandboxTrade.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> params) async {
    final client = _client;
    if (client == null || userId == null) throw const SandboxException('not_authenticated');
    try {
      final res = await client.rpc(fn, params: params);
      return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    } on PostgrestException catch (e) {
      throw SandboxException(_codeOf(e));
    } catch (e) {
      if (e is SandboxException) rethrow;
      throw const SandboxException('network');
    }
  }

  Future<SandboxWallet> unlockModule(SandboxModule m, Map<String, double> anchors) async =>
      SandboxWallet.fromJson(await _rpc('sandbox_unlock_module', {'p_module': m.id, 'p_anchors': anchors}));

  /// Buy / sell / short / cover. The price is the simulated price shown to
  /// the user; the server trusts it (virtual money only — see migration).
  Future<Map<String, dynamic>> trade({
    required SandboxModule module,
    required InstrumentSpec spec,
    required String side,
    required double quantity,
    required double price,
    required double fee,
    double? stopLoss,
    double? takeProfit,
    String? note,
  }) =>
      _rpc('sandbox_trade', {
        'p_module': module.id,
        'p_symbol': spec.symbol,
        'p_name': spec.name,
        'p_instrument_type': spec.type,
        'p_side': side,
        'p_quantity': quantity,
        'p_price': price,
        'p_fee': fee,
        'p_stop_loss': stopLoss,
        'p_take_profit': takeProfit,
        'p_note': note,
      });

  Future<Map<String, dynamic>> setRiskLevels(String symbol, double? stopLoss, double? takeProfit) =>
      _rpc('sandbox_set_risk_levels', {'p_symbol': symbol, 'p_stop_loss': stopLoss, 'p_take_profit': takeProfit});

  Future<Map<String, dynamic>> openPosition({
    required SandboxModule module,
    required String type,
    required String label,
    required double principal,
    required double cost,
    required double rate,
    required String payoutType,
    int? tenureMonths,
    int? tenureDays,
    double? couponRate,
    bool autoRenew = false,
  }) =>
      _rpc('sandbox_open_position', {
        'p_module': module.id,
        'p_type': type,
        'p_label': label,
        'p_principal': principal,
        'p_cost': cost,
        'p_rate': rate,
        'p_payout_type': payoutType,
        'p_tenure_months': tenureMonths,
        'p_tenure_days': tenureDays,
        'p_coupon_rate': couponRate,
        'p_auto_renew': autoRenew,
      });

  Future<Map<String, dynamic>> closePosition(String positionId, double amount) =>
      _rpc('sandbox_close_position', {'p_position_id': positionId, 'p_amount': amount});

  Future<Map<String, dynamic>> fastForward(SandboxModule m, int days, List<SimEvent> events) =>
      _rpc('sandbox_fast_forward', {
        'p_module': m.id,
        'p_days': days,
        'p_events': [for (final e in events) e.toJson()],
      });

  Future<Map<String, dynamic>> updownStake(String symbol, double stake, String note) =>
      _rpc('sandbox_updown_stake', {'p_symbol': symbol, 'p_stake': stake, 'p_note': note});

  Future<Map<String, dynamic>> updownSettle(String stakeId, bool won) =>
      _rpc('sandbox_updown_settle', {'p_stake_id': stakeId, 'p_won': won});

  Future<Map<String, dynamic>> reset({SandboxModule? module, bool resetLearning = false}) =>
      _rpc('sandbox_reset', {'p_module': module?.id, 'p_reset_learning': resetLearning});

  Future<Map<String, dynamic>> lessonRead(SandboxModule m, String lessonId) =>
      _rpc('sandbox_lesson_read', {'p_module': m.id, 'p_lesson_id': lessonId});

  Future<Map<String, dynamic>> submitQuiz(SandboxModule m, String lessonId, double score) =>
      _rpc('sandbox_submit_quiz', {'p_module': m.id, 'p_lesson_id': lessonId, 'p_score': score});

  Future<Map<String, dynamic>> challengeProgress(String id, int progress, int target) =>
      _rpc('sandbox_challenge_progress', {'p_challenge_id': id, 'p_progress': progress, 'p_target': target});

  Future<Map<String, dynamic>> awardBadge(String id) => _rpc('sandbox_award_badge', {'p_badge_id': id});

  Future<Map<String, dynamic>> awardHabitXp(String reason, int amount) =>
      _rpc('sandbox_award_habit_xp', {'p_reason': reason, 'p_amount': amount});
}
