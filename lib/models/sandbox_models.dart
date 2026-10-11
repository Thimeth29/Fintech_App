// lib/models/sandbox_models.dart
//
// Rows of the Investment Trainer tables (see the sandbox_trainer migration).

import '../core/sandbox/sandbox_config.dart';
import '../core/utils/money.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
double? _dn(dynamic v) => v == null ? null : _d(v);
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// Postgres DATE -> local midnight.
DateTime? parseSimDate(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

DateTime? _ts(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Whole days from [a] to [b], ignoring time of day and DST.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Adds calendar months, clamping the day like Postgres does
/// (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

class SandboxWallet {
  final String id;
  final SandboxModule module;
  final double balance;
  final DateTime simDate;
  final DateTime startDate;
  final Map<String, double> anchors;
  final int resetCount;
  final String resetBatch;

  const SandboxWallet({
    required this.id,
    required this.module,
    required this.balance,
    required this.simDate,
    required this.startDate,
    required this.anchors,
    required this.resetCount,
    required this.resetBatch,
  });

  /// Day index on the price path (day 0 = when the module started).
  int get simDay => daysBetween(startDate, simDate);

  factory SandboxWallet.fromJson(Map<String, dynamic> j) {
    final raw = j['price_anchors'];
    return SandboxWallet(
      id: '${j['id']}',
      module: SandboxModuleInfo.parse(j['module']?.toString()) ?? SandboxModule.cse,
      balance: _d(j['balance']),
      simDate: parseSimDate(j['sim_date']) ?? dateOnly(DateTime.now()),
      startDate: parseSimDate(j['start_date']) ?? dateOnly(DateTime.now()),
      anchors: raw is Map
          ? {for (final e in raw.entries) if (e.value is num) '${e.key}': (e.value as num).toDouble()}
          : const {},
      resetCount: _i(j['reset_count']),
      resetBatch: '${j['current_reset_batch'] ?? ''}',
    );
  }
}

class SandboxHolding {
  final String id;
  final SandboxModule module;
  final String symbol;
  final String name;
  final String type;
  final bool isShort;
  final double quantity;
  final double averagePrice;
  final double totalFees;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime openedSimDate;

  const SandboxHolding({
    required this.id,
    required this.module,
    required this.symbol,
    required this.name,
    required this.type,
    required this.isShort,
    required this.quantity,
    required this.averagePrice,
    required this.totalFees,
    required this.openedSimDate,
    this.stopLoss,
    this.takeProfit,
  });

  double get costBasis => quantity * averagePrice;

  factory SandboxHolding.fromJson(Map<String, dynamic> j) => SandboxHolding(
        id: '${j['id']}',
        module: SandboxModuleInfo.parse(j['module']?.toString()) ?? SandboxModule.cse,
        symbol: '${j['symbol']}',
        name: '${j['name'] ?? j['symbol']}',
        type: '${j['instrument_type'] ?? 'stock'}'.toLowerCase(),
        isShort: j['direction'] == 'short',
        quantity: _d(j['quantity']),
        averagePrice: _d(j['average_price']),
        totalFees: _d(j['total_fees']),
        stopLoss: _dn(j['stop_loss']),
        takeProfit: _dn(j['take_profit']),
        openedSimDate: parseSimDate(j['opened_sim_date']) ?? dateOnly(DateTime.now()),
      );
}

class SandboxPosition {
  final String id;
  final SandboxModule module;
  final String type; // fd | tbill | tbond
  final String label;
  final double principal;
  final double cost;
  final double rate;
  final double? couponRate;
  final String payoutType; // maturity | monthly | discount | semi_annual
  final int? tenureMonths;
  final int? tenureDays;
  final DateTime startSimDate;
  final DateTime maturitySimDate;
  final DateTime? lastPayoutSimDate;
  final int payoutsCount;
  final double totalPaid;
  final bool autoRenew;
  final int renewCount;
  final String status;
  final double? closedAmount;
  final DateTime? closedSimDate;
  final String resetBatch;

  const SandboxPosition({
    required this.id,
    required this.module,
    required this.type,
    required this.label,
    required this.principal,
    required this.cost,
    required this.rate,
    required this.payoutType,
    required this.startSimDate,
    required this.maturitySimDate,
    required this.payoutsCount,
    required this.totalPaid,
    required this.autoRenew,
    required this.renewCount,
    required this.status,
    required this.resetBatch,
    this.couponRate,
    this.tenureMonths,
    this.tenureDays,
    this.lastPayoutSimDate,
    this.closedAmount,
    this.closedSimDate,
  });

  bool get isOpen => status == 'open';
  bool get isFd => type == 'fd';
  bool get isTbill => type == 'tbill';
  bool get isTbond => type == 'tbond';

  SandboxPosition copyWith({
    double? principal,
    DateTime? startSimDate,
    DateTime? maturitySimDate,
    DateTime? lastPayoutSimDate,
    int? payoutsCount,
    double? totalPaid,
    int? renewCount,
    String? status,
    double? closedAmount,
    DateTime? closedSimDate,
  }) =>
      SandboxPosition(
        id: id,
        module: module,
        type: type,
        label: label,
        principal: principal ?? this.principal,
        cost: cost,
        rate: rate,
        couponRate: couponRate,
        payoutType: payoutType,
        tenureMonths: tenureMonths,
        tenureDays: tenureDays,
        startSimDate: startSimDate ?? this.startSimDate,
        maturitySimDate: maturitySimDate ?? this.maturitySimDate,
        lastPayoutSimDate: lastPayoutSimDate ?? this.lastPayoutSimDate,
        payoutsCount: payoutsCount ?? this.payoutsCount,
        totalPaid: totalPaid ?? this.totalPaid,
        autoRenew: autoRenew,
        renewCount: renewCount ?? this.renewCount,
        status: status ?? this.status,
        closedAmount: closedAmount ?? this.closedAmount,
        closedSimDate: closedSimDate ?? this.closedSimDate,
        resetBatch: resetBatch,
      );

  factory SandboxPosition.fromJson(Map<String, dynamic> j) => SandboxPosition(
        id: '${j['id']}',
        module: SandboxModuleInfo.parse(j['module']?.toString()) ?? SandboxModule.fd,
        type: '${j['type']}',
        label: '${j['label']}',
        principal: _d(j['principal']),
        cost: _d(j['cost']),
        rate: _d(j['rate']),
        couponRate: _dn(j['coupon_rate']),
        payoutType: '${j['payout_type']}',
        tenureMonths: j['tenure_months'] == null ? null : _i(j['tenure_months']),
        tenureDays: j['tenure_days'] == null ? null : _i(j['tenure_days']),
        startSimDate: parseSimDate(j['start_sim_date'])!,
        maturitySimDate: parseSimDate(j['maturity_sim_date'])!,
        lastPayoutSimDate: parseSimDate(j['last_payout_sim_date']),
        payoutsCount: _i(j['payouts_count']),
        totalPaid: _d(j['total_paid']),
        autoRenew: j['auto_renew'] == true,
        renewCount: _i(j['renew_count']),
        status: '${j['status']}',
        closedAmount: _dn(j['closed_amount']),
        closedSimDate: parseSimDate(j['closed_sim_date']),
        resetBatch: '${j['reset_batch'] ?? ''}',
      );
}

class SandboxTrade {
  final String id;
  final SandboxModule module;
  final String symbol;
  final String side;
  final double quantity;
  final double price;
  final double fee;
  final double cashDelta;
  final double? realisedPnl;
  final String? refId;
  final String? note;
  final DateTime simDate;
  final String resetBatch;
  final DateTime createdAt;

  const SandboxTrade({
    required this.id,
    required this.module,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    required this.fee,
    required this.cashDelta,
    required this.simDate,
    required this.resetBatch,
    required this.createdAt,
    this.realisedPnl,
    this.refId,
    this.note,
  });

  String get sideLabel => switch (side) {
        'buy' => 'Buy',
        'sell' => 'Sell',
        'short' => 'Short',
        'cover' => 'Cover',
        'fd_open' => 'FD opened',
        'fd_interest' => 'FD interest',
        'fd_mature' => 'FD matured',
        'fd_renew' => 'FD renewed',
        'fd_break' => 'FD broken early',
        'tbill_buy' => 'T-bill bought',
        'tbill_mature' => 'T-bill matured',
        'tbond_buy' => 'T-bond bought',
        'tbond_coupon' => 'Coupon',
        'tbond_mature' => 'T-bond matured',
        'tbond_sell' => 'T-bond sold',
        'dividend' => 'Dividend',
        'updown_stake' => 'Up/Down stake',
        'updown_payout' => 'Up/Down result',
        _ => side,
      };

  bool get isIncome => const {'fd_interest', 'tbond_coupon', 'dividend'}.contains(side);

  factory SandboxTrade.fromJson(Map<String, dynamic> j) => SandboxTrade(
        id: '${j['id']}',
        module: SandboxModuleInfo.parse(j['module']?.toString()) ?? SandboxModule.cse,
        symbol: '${j['symbol']}',
        side: '${j['side']}',
        quantity: _d(j['quantity']),
        price: _d(j['price']),
        fee: _d(j['fee']),
        cashDelta: _d(j['cash_delta']),
        realisedPnl: _dn(j['realised_pnl']),
        refId: j['ref_id']?.toString(),
        note: j['note']?.toString(),
        simDate: parseSimDate(j['sim_date']) ?? dateOnly(DateTime.now()),
        resetBatch: '${j['reset_batch'] ?? ''}',
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );
}

class SandboxProgress {
  final int xp;
  final int level;
  final int streak;
  final int bestStreak;
  final DateTime? lastActiveDate;

  const SandboxProgress({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastActiveDate,
  });

  factory SandboxProgress.fromJson(Map<String, dynamic> j) => SandboxProgress(
        xp: _i(j['xp']),
        level: _i(j['level']).clamp(1, 10),
        streak: _i(j['streak_count']),
        bestStreak: _i(j['best_streak']),
        lastActiveDate: parseSimDate(j['last_active_date']),
      );
}

class LessonProgress {
  final SandboxModule module;
  final String lessonId;
  final DateTime? readAt;
  final double? quizScore;
  final int attempts;
  final DateTime? completedAt;

  const LessonProgress({
    required this.module,
    required this.lessonId,
    this.readAt,
    this.quizScore,
    this.attempts = 0,
    this.completedAt,
  });

  bool get isRead => readAt != null;
  bool get isPassed => completedAt != null;

  factory LessonProgress.fromJson(Map<String, dynamic> j) => LessonProgress(
        module: SandboxModuleInfo.parse(j['module']?.toString()) ?? SandboxModule.cse,
        lessonId: '${j['lesson_id']}',
        readAt: _ts(j['read_at']),
        quizScore: _dn(j['quiz_score']),
        attempts: _i(j['attempts']),
        completedAt: _ts(j['completed_at']),
      );
}

class ChallengeState {
  final String id;
  final int progress;
  final int target;
  final DateTime? completedAt;

  const ChallengeState({required this.id, this.progress = 0, this.target = 1, this.completedAt});

  bool get isDone => completedAt != null;

  factory ChallengeState.fromJson(Map<String, dynamic> j) => ChallengeState(
        id: '${j['challenge_id']}',
        progress: _i(j['progress']),
        target: _i(j['target']).clamp(1, 1000),
        completedAt: _ts(j['completed_at']),
      );
}
