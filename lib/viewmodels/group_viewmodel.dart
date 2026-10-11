// lib/viewmodels/group_viewmodel.dart
//
// State for one group screen. Realtime keeps chat, votes, polls and seettu
// payments live; every action awaits its RPC and reloads what changed.
// Actions return null on success or a friendly error message.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/group_models.dart';
import '../services/community_service.dart';
import '../services/group_service.dart';

class GroupViewModel extends ChangeNotifier {
  final String groupId;
  final GroupService service;
  GroupViewModel(this.groupId, {GroupService? service}) : service = service ?? GroupService();

  bool isLoading = true;
  String? errorCode;
  GroupInfo? info;
  List<Member> members = const [];
  Map<String, String> names = {};

  List<ChatMessage> messages = [];
  bool hasOlderMessages = true;
  bool loadingOlder = false;

  List<Poll> polls = const [];
  List<GroupVote> votes = const [];
  List<JoinRequest> joinRequests = const [];

  List<SeettuRound> rounds = const [];
  List<SeettuPayment> payments = const [];
  List<SeettuBid> currentBids = const [];

  InvestDashboard? dashboard;
  List<Contribution> contributions = const [];
  List<Proposal> proposals = const [];
  List<GroupInvestment> investments = const [];
  List<Distribution> distributions = const [];
  List<ExitRequest> exits = const [];

  List<ActivityEntry> activity = const [];
  bool hasOlderActivity = true;

  RealtimeChannel? _channel;
  Timer? _debounce;
  final Set<String> _pending = {};
  bool _disposed = false;

  String? get myId => service.userId;
  Member? get me => members.where((m) => m.userId == myId).firstOrNull;
  String get myRole => me?.role ?? 'member';
  bool get isOfficer => me?.isOfficer ?? false;
  bool get canConfirmMoney => me?.canConfirmMoney ?? false;
  bool get isLeader => myRole == 'leader';
  String nameOf(String? id) => id == null ? 'Mobile SAP' : (id == myId ? 'You' : names[id] ?? 'Member');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<String?> _run(Future<void> Function() action, {List<Future<void> Function()> reload = const []}) async {
    try {
      await action();
      for (final r in reload) {
        await r();
      }
      return null;
    } on CommunityException catch (e) {
      return e.message;
    } catch (_) {
      return communityErrorText('network');
    }
  }

  Future<void> load() async {
    isLoading = true;
    errorCode = null;
    _notify();
    try {
      info = await service.info(groupId);
      await Future.wait([
        loadMembers(),
        loadMessages(),
        loadDecisions(),
        loadMoney(),
        loadActivity(),
      ]);
      _channel ??= service.watchGroup(groupId, _onRealtime);
      service.markRead(groupId).catchError((_) {});
    } on CommunityException catch (e) {
      errorCode = e.code;
    } catch (_) {
      errorCode = 'network';
    }
    isLoading = false;
    _notify();
  }

  void _onRealtime(String table, Map<String, dynamic> row) {
    if (table == 'group_messages' && row['id'] != null) {
      final msg = ChatMessage.fromJson(row);
      final i = messages.indexWhere((m) => m.id == msg.id);
      if (i >= 0) {
        messages[i] = msg;
      } else {
        messages.add(msg);
        if (msg.senderId != null && !names.containsKey(msg.senderId)) loadMembers();
      }
      _notify();
      if (msg.isSystem) _schedule('all');
      return;
    }
    _schedule(table == 'seettu_payments' ? 'money' : 'decisions');
  }

  /// Bursts of realtime events (e.g. a vote closing) collapse into one reload.
  void _schedule(String what) {
    _pending.add(what);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final todo = Set.of(_pending);
      _pending.clear();
      if (todo.contains('all')) {
        try {
          info = await service.info(groupId);
        } catch (_) {}
        await Future.wait([loadMembers(), loadDecisions(), loadMoney(), loadActivity()]);
      } else {
        if (todo.contains('decisions')) await loadDecisions();
        if (todo.contains('money')) await loadMoney();
      }
    });
  }

  Future<void> loadMembers() async {
    try {
      members = await service.groupMembers(groupId);
      names = {...names, for (final m in members) m.userId: m.name};
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> _ensureNames(Iterable<String?> ids) async {
    final missing = ids.whereType<String>().where((id) => !names.containsKey(id)).toSet().toList();
    if (missing.isEmpty) return;
    try {
      names = {...names, ...await service.namesFor(missing)};
    } catch (_) {}
  }

  Future<void> loadMessages() async {
    try {
      messages = await service.messages(groupId);
      hasOlderMessages = messages.length >= 30;
      await _ensureNames(messages.map((m) => m.senderId));
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> loadOlderMessages() async {
    if (loadingOlder || !hasOlderMessages || messages.isEmpty) return;
    loadingOlder = true;
    _notify();
    try {
      final older = await service.messages(groupId, before: messages.first.createdAt);
      hasOlderMessages = older.length >= 30;
      messages = [...older, ...messages];
      await _ensureNames(older.map((m) => m.senderId));
    } catch (_) {}
    loadingOlder = false;
    _notify();
  }

  Future<void> loadDecisions() async {
    try {
      final results = await Future.wait([service.polls(groupId), service.votes(groupId), service.joinRequests(groupId)]);
      polls = results[0] as List<Poll>;
      votes = results[1] as List<GroupVote>;
      joinRequests = results[2] as List<JoinRequest>;
      await _ensureNames([...joinRequests.map((r) => r.userId), ...votes.expand((v) => v.ballots.keys)]);
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> loadMoney() async {
    final g = info;
    if (g == null) return;
    try {
      if (g.isSeettu) {
        final results = await Future.wait([service.rounds(groupId), service.payments(groupId)]);
        rounds = results[0] as List<SeettuRound>;
        payments = results[1] as List<SeettuPayment>;
        final bidding = rounds.where((r) => r.status == 'bidding').firstOrNull;
        currentBids = bidding == null ? const [] : await service.bids(bidding.id);
        await _ensureNames([...rounds.map((r) => r.recipientId), ...payments.map((p) => p.payerId)]);
      } else {
        final results = await Future.wait([
          service.dashboard(groupId),
          service.contributions(groupId),
          service.proposals(groupId),
          service.investments(groupId),
          service.distributions(groupId),
          service.exits(groupId),
        ]);
        dashboard = results[0] as InvestDashboard;
        contributions = results[1] as List<Contribution>;
        proposals = results[2] as List<Proposal>;
        investments = results[3] as List<GroupInvestment>;
        distributions = results[4] as List<Distribution>;
        exits = results[5] as List<ExitRequest>;
        await _ensureNames([...contributions.map((c) => c.userId), ...exits.map((e) => e.userId)]);
      }
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> loadActivity({bool older = false}) async {
    try {
      final page = await service.activity(groupId, beforeId: older && activity.isNotEmpty ? activity.last.id : null);
      activity = older ? [...activity, ...page] : page;
      hasOlderActivity = page.length >= 50;
      await _ensureNames(page.map((a) => a.actorId));
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> refreshAll() async {
    try {
      info = await service.info(groupId);
    } catch (_) {}
    await Future.wait([loadMembers(), loadMessages(), loadDecisions(), loadMoney(), loadActivity()]);
  }

  // ------------------------------------------------------------- seettu
  SeettuRound? get currentRound => rounds.where((r) => !r.isDone).firstOrNull;
  List<SeettuPayment> paymentsFor(String roundId) => payments.where((p) => p.roundId == roundId).toList();
  SeettuPayment? myPaymentFor(String roundId) =>
      payments.where((p) => p.roundId == roundId && p.payerId == myId).firstOrNull;

  /// My next unpaid instalment (pending, late or awaiting confirmation).
  ({SeettuRound round, SeettuPayment payment})? get myNextPayment {
    for (final r in rounds) {
      final p = myPaymentFor(r.id);
      if (p != null && p.status != 'confirmed') return (round: r, payment: p);
    }
    return null;
  }

  double get myTotalPaid =>
      payments.where((p) => p.payerId == myId && p.status == 'confirmed').fold(0.0, (a, p) => a + p.amountDue);
  double get myTotalDue => payments.where((p) => p.payerId == myId).fold(0.0, (a, p) => a + p.amountDue);
  SeettuRound? get myPotRound => rounds.where((r) => r.recipientId == myId).firstOrNull;
  bool get mustCompletePayments =>
      (myPotRound?.status == 'handed_over' || myPotRound?.status == 'completed') &&
      payments.any((p) => p.payerId == myId && p.status != 'confirmed');

  /// Share of instalments (due so far or confirmed) that were paid on time.
  double? get onTimeRate {
    final today = DateTime.now();
    var due = 0;
    var onTime = 0;
    for (final p in payments) {
      final r = rounds.where((r) => r.id == p.roundId).firstOrNull;
      if (r == null) continue;
      if (p.status == 'confirmed' || r.dueDate.isBefore(DateTime(today.year, today.month, today.day))) {
        due++;
        final marked = p.markedAt;
        if (p.status == 'confirmed' && marked != null && !DateTime(marked.year, marked.month, marked.day).isAfter(r.dueDate)) {
          onTime++;
        }
      }
    }
    return due == 0 ? null : onTime / due;
  }

  // ------------------------------------------------------------ actions
  Future<String?> send(String body, {String? replyTo}) => _run(() => service.sendMessage(groupId, body, replyTo: replyTo));
  Future<String?> removeMessage(String id) => _run(() => service.removeMessage(id), reload: [loadMessages]);
  Future<String?> pin(String id, bool pinned) => _run(() => service.pinMessage(id, pinned), reload: [loadMessages]);
  Future<String?> reportMessage(String id, String reason, String? details) =>
      _run(() => service.reportMessage(id, reason, details));
  Future<String?> setMuted(bool muted) => _run(() => service.setMuted(groupId, muted), reload: [loadMembers]);

  Future<String?> createPoll(String q, List<String> options, {required bool multiple, required bool anonymous, required DateTime deadline}) =>
      _run(() => service.createPoll(groupId, q, options, multiple: multiple, anonymous: anonymous, deadline: deadline),
          reload: [loadDecisions]);
  Future<String?> votePoll(String pollId, List<String> optionIds) =>
      _run(() => service.votePoll(pollId, optionIds), reload: [loadDecisions]);
  Future<String?> closePoll(String pollId) => _run(() => service.closePoll(pollId), reload: [loadDecisions]);
  Future<String?> startVote(String kind, String title, {String? description, Map<String, dynamic>? subject}) =>
      _run(() => service.startVote(groupId, kind, title, description: description, subject: subject),
          reload: [loadDecisions, loadActivity]);
  Future<String?> castVote(String voteId, String choice) => _run(() => service.castVote(voteId, choice), reload: [loadDecisions]);
  Future<String?> closeVote(String voteId) => _run(() => service.closeVote(voteId), reload: [refreshAll]);

  Future<String?> decideJoin(String requestId, bool approve) =>
      _run(() => service.decideJoin(requestId, approve), reload: [loadMembers, loadDecisions]);
  Future<String?> removeMember(String userId, String reason) =>
      _run(() => service.removeMember(groupId, userId, reason), reload: [loadMembers]);
  Future<String?> setRole(String userId, String role) => _run(() => service.setRole(groupId, userId, role), reload: [loadMembers]);
  Future<String?> transferLeadership(String userId) =>
      _run(() => service.transferLeadership(groupId, userId), reload: [loadMembers]);
  Future<String?> updateDetails({String? description, bool? discoverable, String? district}) => _run(
        () => service.updateDetails(groupId, description: description, discoverable: discoverable, district: district),
        reload: [refreshAll],
      );
  Future<String?> leave() => _run(() => service.leaveGroup(groupId));

  Future<String?> updateSeettu(Map<String, dynamic> settings) =>
      _run(() => service.updateSeettu(groupId, settings), reload: [refreshAll]);
  Future<String?> setOrder(List<String> userIds) => _run(() => service.setOrder(groupId, userIds), reload: [loadMembers]);
  Future<String?> confirmSeettu() => _run(() => service.confirmSeettu(groupId), reload: [loadMembers]);
  Future<String?> startSeettu() => _run(() => service.startSeettu(groupId), reload: [refreshAll]);
  Future<String?> draw() => _run(() => service.draw(groupId), reload: [loadMoney]);
  Future<String?> openBidding() => _run(() => service.openBidding(groupId), reload: [loadMoney]);
  Future<String?> placeBid(String roundId, double discount) =>
      _run(() => service.placeBid(roundId, discount), reload: [loadMoney]);
  Future<String?> closeBidding(String roundId) => _run(() => service.closeBidding(roundId), reload: [loadMoney]);
  Future<String?> markPaid(String paymentId) => _run(() => service.markPaid(paymentId), reload: [loadMoney]);
  Future<String?> confirmPayment(String paymentId) => _run(() => service.confirmPayment(paymentId), reload: [loadMoney]);
  Future<String?> handOver(String roundId) => _run(() => service.handOver(roundId), reload: [loadMoney]);
  Future<String?> confirmReceived(String roundId) => _run(() => service.confirmReceived(roundId), reload: [refreshAll]);
  Future<String?> setExpenseLink({String? recurringExpenseId, required bool logPayments}) => _run(
        () => service.setExpenseLink(groupId, recurringExpenseId: recurringExpenseId, logPayments: logPayments),
        reload: [loadMembers],
      );

  Future<String?> pledge(double amount) => _run(() => service.pledge(groupId, amount), reload: [loadMoney]);
  Future<String?> markContributionPaid(String id) => _run(() => service.markContributionPaid(id), reload: [loadMoney]);
  Future<String?> confirmContribution(String id) => _run(() => service.confirmContribution(id), reload: [loadMoney]);
  Future<String?> cancelPledge(String id) => _run(() => service.cancelPledge(id), reload: [loadMoney]);
  Future<String?> createProposal({
    required String title,
    required String type,
    required double amount,
    required String risk,
    required String reasoning,
    String? holdingPeriod,
    List<String> links = const [],
    double? expectedReturnPct,
  }) =>
      _run(
        () => service.createProposal(groupId,
            title: title,
            type: type,
            amount: amount,
            risk: risk,
            reasoning: reasoning,
            holdingPeriod: holdingPeriod,
            links: links,
            expectedReturnPct: expectedReturnPct),
        reload: [loadMoney, loadDecisions],
      );
  Future<String?> withdrawProposal(String id) => _run(() => service.withdrawProposal(id), reload: [loadMoney, loadDecisions]);
  Future<String?> recordInvestment({
    required String title,
    required String type,
    required double amount,
    required DateTime madeOn,
    String? details,
    String? proposalId,
  }) =>
      _run(
        () => service.recordInvestment(groupId,
            title: title, type: type, amount: amount, madeOn: madeOn, details: details, proposalId: proposalId),
        reload: [loadMoney],
      );
  Future<String?> recordUpdate(String investmentId, String kind, double amount, {String? note}) =>
      _run(() => service.recordUpdate(investmentId, kind, amount, note: note), reload: [loadMoney]);
  Future<String?> createDistribution(double total, {String? note}) =>
      _run(() => service.createDistribution(groupId, total, note: note), reload: [loadMoney]);
  Future<String?> confirmDistribution(String id) => _run(() => service.confirmDistribution(id), reload: [loadMoney]);
  Future<String?> requestExit({String? reason}) =>
      _run(() => service.requestExit(groupId, reason: reason), reload: [loadMoney, loadDecisions]);
  Future<String?> decideExit(String id, bool approve) => _run(() => service.decideExit(id, approve), reload: [loadMoney]);
  Future<String?> confirmExitPayout(String id) => _run(() => service.confirmExitPayout(id));

  /// CSV of the group's records, for the "Export records" action.
  String exportCsv() {
    String esc(Object? v) {
      final s = '${v ?? ''}';
      return s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String row(List<Object?> cells) => cells.map(esc).join(',');
    final g = info;
    final b = StringBuffer()
      ..writeln(row(['Mobile SAP group records', g?.name, DateTime.now().toIso8601String()]))
      ..writeln(row(['Mobile SAP keeps records only. Money is exchanged directly between members.']))
      ..writeln();
    if (g?.isSeettu ?? false) {
      b.writeln(row(['Round', 'Due date', 'Recipient', 'Pot', 'Discount', 'Status']));
      for (final r in rounds) {
        b.writeln(row([r.roundNo, r.dueDate.toIso8601String().substring(0, 10), nameOf(r.recipientId), r.pot, r.discount, r.status]));
      }
      b
        ..writeln()
        ..writeln(row(['Round', 'Payer', 'Amount due', 'Credit', 'Status', 'Marked paid', 'Confirmed']));
      for (final p in payments) {
        final r = rounds.where((r) => r.id == p.roundId).firstOrNull;
        b.writeln(row([r?.roundNo, nameOf(p.payerId), p.amountDue, p.credit, p.status, p.markedAt?.toIso8601String(), p.confirmedAt?.toIso8601String()]));
      }
    } else {
      b.writeln(row(['Contributions']));
      b.writeln(row(['Member', 'Amount', 'Status', 'Pledged']));
      for (final c in contributions) {
        b.writeln(row([nameOf(c.userId), c.amount, c.status, c.pledgedAt?.toIso8601String()]));
      }
      b
        ..writeln()
        ..writeln(row(['Investments']))
        ..writeln(row(['Title', 'Type', 'Invested', 'Made on', 'Current value', 'Income', 'Closing value', 'Status']));
      for (final i in investments) {
        b.writeln(row([i.title, i.investmentType, i.amountInvested, i.madeOn.toIso8601String().substring(0, 10), i.currentValue, i.incomeTotal, i.closingValue, i.status]));
      }
      b
        ..writeln()
        ..writeln(row(['Distributions']))
        ..writeln(row(['Date', 'Total', 'Rule', 'Member', 'Amount', 'Received']));
      for (final d in distributions) {
        for (final e in d.shares.entries) {
          b.writeln(row([d.createdAt?.toIso8601String(), d.total, d.rule, nameOf(e.key), e.value, d.confirmed.contains(e.key) ? 'yes' : 'no']));
        }
      }
    }
    b
      ..writeln()
      ..writeln(row(['Activity log']))
      ..writeln(row(['When', 'Who', 'Event', 'Details']));
    for (final a in activity) {
      b.writeln(row([a.createdAt.toIso8601String(), nameOf(a.actorId), a.event, a.details]));
    }
    return b.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    final channel = _channel;
    if (channel != null) service.removeChannel(channel);
    super.dispose();
  }
}
