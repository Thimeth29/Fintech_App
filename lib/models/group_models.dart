// lib/models/group_models.dart
//
// Records inside one group (members only, by RLS). Every amount is a record
// of money members exchanged outside the app.

double _d(Object? v) => v == null ? 0 : (v as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _t(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

const Map<String, String> kInvestmentTypeLabels = {
  'cse': 'CSE stocks',
  'fd': 'Fixed deposit',
  'gold': 'Gold',
  'gov_securities': 'Government securities',
  'business': 'Business / other',
};

const Map<String, String> kRiskLabels = {'low': 'Low risk', 'medium': 'Medium risk', 'high': 'High risk'};

const Map<String, String> kVoteKindLabels = {
  'proposal': 'Investment proposal',
  'leader_change': 'Change leader',
  'rule_change': 'Rule change',
  'voting_method': 'Voting method',
  'member_removal': 'Remove member',
  'join_request': 'Join request',
  'exit': 'Member exit',
  'close_group': 'Close group',
  'custom': 'Group decision',
};

class GroupInfo {
  final String id;
  final String type;
  final String name;
  final String? description;
  final String? district;
  final int maxMembers;
  final bool discoverable;
  final String joinApproval;
  final String rules;
  final String votingMethod;
  final int quorumPct;
  final String passThreshold;
  final int voteHours;
  final String status;
  final Map<String, dynamic>? seettu;
  final Map<String, dynamic>? investment;

  const GroupInfo({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.district,
    required this.maxMembers,
    required this.discoverable,
    required this.joinApproval,
    required this.rules,
    required this.votingMethod,
    required this.quorumPct,
    required this.passThreshold,
    required this.voteHours,
    required this.status,
    this.seettu,
    this.investment,
  });

  bool get isSeettu => type == 'seettu';
  bool get isClosed => status == 'closed';
  double get seettuContribution => _d(seettu?['contribution']);
  String get seettuPayoutMethod => (seettu?['payout_method'] as String?) ?? 'agreed';
  String get seettuDrawMode => (seettu?['draw_mode'] as String?) ?? 'all';
  List<String> get allowedTypes =>
      ((investment?['allowed_types'] as List?) ?? const []).map((e) => '$e').toList();
  double get decisionThreshold => _d(investment?['decision_threshold']);
  double get minContribution => _d(investment?['min_contribution']);
  double? get maxContribution => _dn(investment?['max_contribution']);

  factory GroupInfo.fromJson(Map<String, dynamic> g, {Map<String, dynamic>? seettu, Map<String, dynamic>? investment}) =>
      GroupInfo(
        id: g['id'] as String,
        type: g['type'] as String,
        name: g['name'] as String,
        description: g['description'] as String?,
        district: g['district'] as String?,
        maxMembers: (g['max_members'] as num).toInt(),
        discoverable: g['discoverable'] == true,
        joinApproval: (g['join_approval'] as String?) ?? 'leader',
        rules: (g['rules'] as String?) ?? '',
        votingMethod: (g['voting_method'] as String?) ?? 'one_member_one_vote',
        quorumPct: (g['quorum_pct'] as num?)?.toInt() ?? 50,
        passThreshold: (g['pass_threshold'] as String?) ?? 'majority',
        voteHours: (g['vote_hours'] as num?)?.toInt() ?? 48,
        status: (g['status'] as String?) ?? 'forming',
        seettu: seettu,
        investment: investment,
      );
}

class Member {
  final String userId;
  final String name;
  final String role;
  final DateTime? joinedAt;
  final int? payoutPosition;
  final bool seettuConfirmed;
  final bool chatMuted;
  final bool logPaymentsAsExpenses;

  const Member({
    required this.userId,
    required this.name,
    required this.role,
    this.joinedAt,
    this.payoutPosition,
    this.seettuConfirmed = false,
    this.chatMuted = false,
    this.logPaymentsAsExpenses = false,
  });

  bool get isOfficer => role == 'leader' || role == 'co_leader';
  bool get canConfirmMoney => isOfficer || role == 'treasurer';
}

class ChatMessage {
  final String id;
  final String? senderId;
  final String? body;
  final String? imagePath;
  final String? replyTo;
  final bool isSystem;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const ChatMessage({
    required this.id,
    this.senderId,
    this.body,
    this.imagePath,
    this.replyTo,
    this.isSystem = false,
    this.isPinned = false,
    required this.createdAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderId: j['sender_id'] as String?,
        body: j['body'] as String?,
        imagePath: j['image_path'] as String?,
        replyTo: j['reply_to'] as String?,
        isSystem: j['is_system'] == true,
        isPinned: j['is_pinned'] == true,
        createdAt: _t(j['created_at']) ?? DateTime.now(),
        deletedAt: _t(j['deleted_at']),
      );
}

class PollOption {
  final String id;
  final String label;
  final int position;
  final int votes;
  final List<String> voterIds;
  const PollOption({required this.id, required this.label, required this.position, required this.votes, this.voterIds = const []});
}

class Poll {
  final String id;
  final String question;
  final bool multipleChoice;
  final bool anonymous;
  final DateTime deadline;
  final DateTime? closedAt;
  final String? createdBy;
  final List<PollOption> options;
  final Set<String> myChoices;

  const Poll({
    required this.id,
    required this.question,
    required this.multipleChoice,
    required this.anonymous,
    required this.deadline,
    this.closedAt,
    this.createdBy,
    required this.options,
    required this.myChoices,
  });

  bool get isOpen => closedAt == null && deadline.isAfter(DateTime.now());
  int get totalVotes => options.fold(0, (a, o) => a + o.votes);
}

class GroupVote {
  final String id;
  final String kind;
  final String title;
  final String? description;
  final Map<String, dynamic> subject;
  final String status;
  final DateTime deadline;
  final String method;
  final int quorumPct;
  final String threshold;
  final String thresholdBase;
  final double? yes;
  final double? no;
  final int? abstain;
  final int? eligibleCount;
  final String? resultNote;
  final String? myChoice;
  final Map<String, String> ballots; // user id -> choice (named voting)

  const GroupVote({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    required this.subject,
    required this.status,
    required this.deadline,
    required this.method,
    required this.quorumPct,
    required this.threshold,
    required this.thresholdBase,
    this.yes,
    this.no,
    this.abstain,
    this.eligibleCount,
    this.resultNote,
    this.myChoice,
    this.ballots = const {},
  });

  bool get isOpen => status == 'open' && deadline.isAfter(DateTime.now());
  bool get awaitingClose => status == 'open' && !deadline.isAfter(DateTime.now());

  String get ruleText {
    final share = threshold == 'two_thirds' ? 'two thirds' : 'a majority';
    final of = thresholdBase == 'eligible' ? 'of all members' : 'of votes cast';
    return 'Needs $share $of, quorum $quorumPct%${method == 'weighted' ? ', weighted by contribution' : ''}';
  }

  factory GroupVote.fromJson(Map<String, dynamic> j, {String? myChoice, Map<String, String> ballots = const {}}) => GroupVote(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        subject: _m(j['subject']),
        status: j['status'] as String,
        deadline: _t(j['deadline']) ?? DateTime.now(),
        method: j['method'] as String,
        quorumPct: (j['quorum_pct'] as num).toInt(),
        threshold: j['threshold'] as String,
        thresholdBase: j['threshold_base'] as String,
        yes: _dn(j['yes_weight']),
        no: _dn(j['no_weight']),
        abstain: (j['abstain_count'] as num?)?.toInt(),
        eligibleCount: (j['eligible_count'] as num?)?.toInt(),
        resultNote: j['result_note'] as String?,
        myChoice: myChoice,
        ballots: ballots,
      );
}

class JoinRequest {
  final String id;
  final String userId;
  final String? message;
  final String? voteId;
  final DateTime? createdAt;
  const JoinRequest({required this.id, required this.userId, this.message, this.voteId, this.createdAt});
}

class SeettuRound {
  final String id;
  final int roundNo;
  final DateTime dueDate;
  final String? recipientId;
  final double discount;
  final double pot;
  final String status;

  const SeettuRound({
    required this.id,
    required this.roundNo,
    required this.dueDate,
    this.recipientId,
    required this.discount,
    required this.pot,
    required this.status,
  });

  bool get isDone => status == 'completed';

  factory SeettuRound.fromJson(Map<String, dynamic> j) => SeettuRound(
        id: j['id'] as String,
        roundNo: (j['round_no'] as num).toInt(),
        dueDate: DateTime.parse(j['due_date'] as String),
        recipientId: j['recipient_id'] as String?,
        discount: _d(j['discount']),
        pot: _d(j['pot']),
        status: j['status'] as String,
      );
}

class SeettuPayment {
  final String id;
  final String roundId;
  final String payerId;
  final double amountDue;
  final double credit;
  final String status;
  final DateTime? markedAt;
  final DateTime? confirmedAt;
  final String? receiptPath;

  const SeettuPayment({
    required this.id,
    required this.roundId,
    required this.payerId,
    required this.amountDue,
    required this.credit,
    required this.status,
    this.markedAt,
    this.confirmedAt,
    this.receiptPath,
  });

  factory SeettuPayment.fromJson(Map<String, dynamic> j) => SeettuPayment(
        id: j['id'] as String,
        roundId: j['round_id'] as String,
        payerId: j['payer_id'] as String,
        amountDue: _d(j['amount_due']),
        credit: _d(j['credit']),
        status: j['status'] as String,
        markedAt: _t(j['marked_at']),
        confirmedAt: _t(j['confirmed_at']),
        receiptPath: j['receipt_path'] as String?,
      );
}

class SeettuBid {
  final String userId;
  final double discount;
  const SeettuBid(this.userId, this.discount);
}

class Contribution {
  final String id;
  final String userId;
  final double amount;
  final String status;
  final DateTime? pledgedAt;
  const Contribution({required this.id, required this.userId, required this.amount, required this.status, this.pledgedAt});

  factory Contribution.fromJson(Map<String, dynamic> j) => Contribution(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        amount: _d(j['amount']),
        status: j['status'] as String,
        pledgedAt: _t(j['pledged_at']),
      );
}

class Proposal {
  final String id;
  final String? createdBy;
  final String title;
  final String investmentType;
  final double amount;
  final String? holdingPeriod;
  final String riskLevel;
  final String reasoning;
  final List<String> links;
  final double? expectedReturnPct;
  final String? voteId;
  final String status;

  const Proposal({
    required this.id,
    this.createdBy,
    required this.title,
    required this.investmentType,
    required this.amount,
    this.holdingPeriod,
    required this.riskLevel,
    required this.reasoning,
    this.links = const [],
    this.expectedReturnPct,
    this.voteId,
    required this.status,
  });

  factory Proposal.fromJson(Map<String, dynamic> j) => Proposal(
        id: j['id'] as String,
        createdBy: j['created_by'] as String?,
        title: j['title'] as String,
        investmentType: j['investment_type'] as String,
        amount: _d(j['amount']),
        holdingPeriod: j['holding_period'] as String?,
        riskLevel: j['risk_level'] as String,
        reasoning: j['reasoning'] as String,
        links: ((j['links'] as List?) ?? const []).map((e) => '$e').toList(),
        expectedReturnPct: _dn(j['expected_return_pct']),
        voteId: j['vote_id'] as String?,
        status: j['status'] as String,
      );

  /// What FinBot reviews: the proposal only, no member data.
  String toFinBotBrief() => [
        'Group investment proposal: "$title"',
        'Type: ${kInvestmentTypeLabels[investmentType] ?? investmentType}',
        'Amount: LKR ${amount.toStringAsFixed(2)}',
        if (holdingPeriod != null) 'Expected holding period: $holdingPeriod',
        'Risk level stated by the proposer: ${kRiskLabels[riskLevel] ?? riskLevel}',
        if (expectedReturnPct != null) 'Proposer\'s estimated return (not guaranteed): ${expectedReturnPct!.toStringAsFixed(2)}%',
        'Reasoning: $reasoning',
      ].join('\n');
}

class GroupInvestment {
  final String id;
  final String title;
  final String investmentType;
  final double amountInvested;
  final DateTime madeOn;
  final double currentValue;
  final double incomeTotal;
  final double? closingValue;
  final String status;
  final String approvedVia;
  final String? details;

  const GroupInvestment({
    required this.id,
    required this.title,
    required this.investmentType,
    required this.amountInvested,
    required this.madeOn,
    required this.currentValue,
    required this.incomeTotal,
    this.closingValue,
    required this.status,
    required this.approvedVia,
    this.details,
  });

  bool get isOpen => status == 'open';
  double get profit => (isOpen ? currentValue : (closingValue ?? 0)) - amountInvested + incomeTotal;

  factory GroupInvestment.fromJson(Map<String, dynamic> j) => GroupInvestment(
        id: j['id'] as String,
        title: j['title'] as String,
        investmentType: j['investment_type'] as String,
        amountInvested: _d(j['amount_invested']),
        madeOn: DateTime.parse(j['made_on'] as String),
        currentValue: _d(j['current_value']),
        incomeTotal: _d(j['income_total']),
        closingValue: _dn(j['closing_value']),
        status: j['status'] as String,
        approvedVia: j['approved_via'] as String,
        details: j['details'] as String?,
      );
}

class Distribution {
  final String id;
  final double total;
  final String rule;
  final String? note;
  final String status;
  final DateTime? createdAt;
  final Map<String, double> shares; // user id -> amount
  final Set<String> confirmed;

  const Distribution({
    required this.id,
    required this.total,
    required this.rule,
    this.note,
    required this.status,
    this.createdAt,
    this.shares = const {},
    this.confirmed = const {},
  });
}

class ExitRequest {
  final String id;
  final String userId;
  final String? reason;
  final double payout;
  final Map<String, dynamic> calculation;
  final String status;
  final String? voteId;

  const ExitRequest({
    required this.id,
    required this.userId,
    this.reason,
    required this.payout,
    this.calculation = const {},
    required this.status,
    this.voteId,
  });

  factory ExitRequest.fromJson(Map<String, dynamic> j) => ExitRequest(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        reason: j['reason'] as String?,
        payout: _d(j['payout_amount']),
        calculation: _m(j['calculation']),
        status: j['status'] as String,
        voteId: j['vote_id'] as String?,
      );
}

class ActivityEntry {
  final int id;
  final String? actorId;
  final String event;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const ActivityEntry({required this.id, this.actorId, required this.event, required this.details, required this.createdAt});

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: (j['id'] as num).toInt(),
        actorId: j['actor_id'] as String?,
        event: j['event'] as String,
        details: _m(j['details']),
        createdAt: _t(j['created_at']) ?? DateTime.now(),
      );
}

class InvestDashboard {
  final double confirmedPool;
  final double pendingPledges;
  final double investedOpen;
  final double currentValue;
  final double unrealisedPl;
  final double realisedPl;
  final double cash;
  final double poolValue;
  final double distributed;
  final List<({String userId, String name, double confirmed, double sharePct, double pending})> members;

  const InvestDashboard({
    required this.confirmedPool,
    required this.pendingPledges,
    required this.investedOpen,
    required this.currentValue,
    required this.unrealisedPl,
    required this.realisedPl,
    required this.cash,
    required this.poolValue,
    required this.distributed,
    required this.members,
  });

  factory InvestDashboard.fromJson(Map<String, dynamic> j) => InvestDashboard(
        confirmedPool: _d(j['confirmed_pool']),
        pendingPledges: _d(j['pending_pledges']),
        investedOpen: _d(j['invested_open']),
        currentValue: _d(j['current_value']),
        unrealisedPl: _d(j['unrealised_pl']),
        realisedPl: _d(j['realised_pl']),
        cash: _d(j['cash']),
        poolValue: _d(j['pool_value']),
        distributed: _d(j['distributed']),
        members: [
          for (final m in (j['members'] as List? ?? const []))
            (
              userId: (m as Map)['user_id'] as String,
              name: (m['display_name'] as String?) ?? 'Member',
              confirmed: _d(m['confirmed']),
              sharePct: _d(m['share_pct']),
              pending: _d(m['pending']),
            ),
        ],
      );
}
