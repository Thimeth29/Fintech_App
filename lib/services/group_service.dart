// lib/services/group_service.dart
//
// One group's records (members only, enforced by RLS) and every group
// action (SECURITY DEFINER RPCs that check role and state). See
// supabase/migrations/20261013090000_community_groups.sql.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_models.dart';
import 'community_service.dart';

class GroupService extends CommunityService {
  // ------------------------------------------------------------------ loads
  Future<GroupInfo> info(String groupId) => query((c) async {
        final g = Map<String, dynamic>.from(await c.from('groups').select().eq('id', groupId).single());
        Map<String, dynamic>? seettu;
        Map<String, dynamic>? investment;
        if (g['type'] == 'seettu') {
          seettu = await c.from('seettu_settings').select().eq('group_id', groupId).maybeSingle();
        } else {
          investment = await c.from('investment_settings').select().eq('group_id', groupId).maybeSingle();
        }
        return GroupInfo.fromJson(g, seettu: seettu, investment: investment);
      });

  Future<List<Member>> groupMembers(String groupId) => query((c) async {
        final list = rows(await c
            .from('group_members')
            .select('user_id, role, joined_at, payout_position, seettu_confirmed_at, chat_muted, log_payments_as_expenses')
            .eq('group_id', groupId)
            .eq('status', 'active')
            .order('joined_at'));
        final names = await namesFor(list.map((r) => r['user_id'] as String).toList());
        return [
          for (final r in list)
            Member(
              userId: r['user_id'] as String,
              name: names[r['user_id']] ?? 'Member',
              role: r['role'] as String,
              joinedAt: DateTime.tryParse('${r['joined_at']}'),
              payoutPosition: (r['payout_position'] as num?)?.toInt(),
              seettuConfirmed: r['seettu_confirmed_at'] != null,
              chatMuted: r['chat_muted'] == true,
              logPaymentsAsExpenses: r['log_payments_as_expenses'] == true,
            ),
        ];
      });

  /// Display names for user ids the caller may see (RLS on community_profiles).
  Future<Map<String, String>> namesFor(List<String> ids) => query((c) async {
        if (ids.isEmpty) return <String, String>{};
        final list = rows(await c.from('community_profiles').select('user_id, display_name').inFilter('user_id', ids.toSet().toList()));
        return {for (final p in list) p['user_id'] as String: p['display_name'] as String};
      });

  Future<List<ChatMessage>> messages(String groupId, {DateTime? before, int limit = 30}) => query((c) async {
        var q = c.from('group_messages').select().eq('group_id', groupId);
        if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
        final list = rows(await q.order('created_at', ascending: false).limit(limit));
        return list.map(ChatMessage.fromJson).toList().reversed.toList();
      });

  Future<List<Poll>> polls(String groupId) => query((c) async {
        final ps = rows(await c.from('polls').select().eq('group_id', groupId).order('created_at', ascending: false).limit(30));
        if (ps.isEmpty) return <Poll>[];
        final ids = ps.map((p) => p['id'] as String).toList();
        final opts = rows(await c.from('poll_options').select().inFilter('poll_id', ids).order('position'));
        // Visible votes: my own, plus everyone's on named polls.
        final votes = rows(await c
            .from('poll_votes')
            .select('poll_id, option_id, user_id')
            .inFilter('poll_id', ids)
            .isFilter('retracted_at', null));
        final uid = userId;
        return [
          for (final p in ps)
            Poll(
              id: p['id'] as String,
              question: p['question'] as String,
              multipleChoice: p['multiple_choice'] == true,
              anonymous: p['anonymous'] == true,
              deadline: DateTime.parse(p['deadline'] as String).toLocal(),
              closedAt: DateTime.tryParse('${p['closed_at']}')?.toLocal(),
              createdBy: p['created_by'] as String?,
              options: [
                for (final o in opts.where((o) => o['poll_id'] == p['id']))
                  PollOption(
                    id: o['id'] as String,
                    label: o['label'] as String,
                    position: (o['position'] as num).toInt(),
                    votes: (o['vote_count'] as num).toInt(),
                    voterIds: [
                      for (final v in votes.where((v) => v['option_id'] == o['id'])) v['user_id'] as String,
                    ],
                  ),
              ],
              myChoices: {
                for (final v in votes.where((v) => v['poll_id'] == p['id'] && v['user_id'] == uid)) v['option_id'] as String,
              },
            ),
        ];
      });

  Future<List<GroupVote>> votes(String groupId) => query((c) async {
        final vs = rows(await c.from('group_votes').select().eq('group_id', groupId).order('created_at', ascending: false).limit(40));
        if (vs.isEmpty) return <GroupVote>[];
        final ballots = rows(await c
            .from('group_vote_ballots')
            .select('vote_id, user_id, choice')
            .inFilter('vote_id', vs.map((v) => v['id'] as String).toList()));
        final uid = userId;
        return [
          for (final v in vs)
            GroupVote.fromJson(
              v,
              myChoice: ballots.where((b) => b['vote_id'] == v['id'] && b['user_id'] == uid).map((b) => b['choice'] as String).firstOrNull,
              ballots: {
                for (final b in ballots.where((b) => b['vote_id'] == v['id'])) b['user_id'] as String: b['choice'] as String,
              },
            ),
        ];
      });

  Future<List<JoinRequest>> joinRequests(String groupId) => query((c) async => rows(await c
          .from('group_join_requests')
          .select('id, user_id, message, vote_id, created_at')
          .eq('group_id', groupId)
          .eq('status', 'pending')
          .order('created_at'))
      .map((r) => JoinRequest(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            message: r['message'] as String?,
            voteId: r['vote_id'] as String?,
            createdAt: DateTime.tryParse('${r['created_at']}'),
          ))
      .toList());

  Future<List<SeettuRound>> rounds(String groupId) => query((c) async =>
      rows(await c.from('seettu_rounds').select().eq('group_id', groupId).order('round_no')).map(SeettuRound.fromJson).toList());

  Future<List<SeettuPayment>> payments(String groupId) => query((c) async =>
      rows(await c.from('seettu_payments').select().eq('group_id', groupId)).map(SeettuPayment.fromJson).toList());

  Future<List<SeettuBid>> bids(String roundId) => query((c) async => rows(await c
          .from('seettu_bids')
          .select('user_id, discount')
          .eq('round_id', roundId)
          .order('discount', ascending: false))
      .map((b) => SeettuBid(b['user_id'] as String, (b['discount'] as num).toDouble()))
      .toList());

  Future<InvestDashboard> dashboard(String groupId) async =>
      InvestDashboard.fromJson(Map<String, dynamic>.from(await rpc('invest_dashboard', {'p_group': groupId}) as Map));

  Future<List<Contribution>> contributions(String groupId) => query((c) async => rows(await c
          .from('group_contributions')
          .select()
          .eq('group_id', groupId)
          .neq('status', 'cancelled')
          .order('pledged_at', ascending: false))
      .map(Contribution.fromJson)
      .toList());

  Future<List<Proposal>> proposals(String groupId) => query((c) async => rows(await c
          .from('group_proposals')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false))
      .map(Proposal.fromJson)
      .toList());

  Future<List<GroupInvestment>> investments(String groupId) => query((c) async => rows(await c
          .from('group_investments')
          .select()
          .eq('group_id', groupId)
          .order('made_on', ascending: false))
      .map(GroupInvestment.fromJson)
      .toList());

  Future<List<Distribution>> distributions(String groupId) => query((c) async {
        final ds = rows(await c.from('group_distributions').select().eq('group_id', groupId).order('created_at', ascending: false));
        if (ds.isEmpty) return <Distribution>[];
        final shares = rows(await c
            .from('group_distribution_shares')
            .select('distribution_id, user_id, amount, confirmed_at')
            .inFilter('distribution_id', ds.map((d) => d['id'] as String).toList()));
        return [
          for (final d in ds)
            Distribution(
              id: d['id'] as String,
              total: (d['total_amount'] as num).toDouble(),
              rule: d['rule'] as String,
              note: d['note'] as String?,
              status: d['status'] as String,
              createdAt: DateTime.tryParse('${d['created_at']}'),
              shares: {
                for (final s in shares.where((s) => s['distribution_id'] == d['id']))
                  s['user_id'] as String: (s['amount'] as num).toDouble(),
              },
              confirmed: {
                for (final s in shares.where((s) => s['distribution_id'] == d['id'] && s['confirmed_at'] != null))
                  s['user_id'] as String,
              },
            ),
        ];
      });

  Future<List<ExitRequest>> exits(String groupId) => query((c) async => rows(await c
          .from('group_exit_requests')
          .select()
          .eq('group_id', groupId)
          .inFilter('status', ['pending', 'approved'])
          .order('created_at'))
      .map(ExitRequest.fromJson)
      .toList());

  Future<List<ActivityEntry>> activity(String groupId, {int? beforeId, int limit = 50}) => query((c) async {
        var q = c.from('group_activity_log').select().eq('group_id', groupId);
        if (beforeId != null) q = q.lt('id', beforeId);
        return rows(await q.order('id', ascending: false).limit(limit)).map(ActivityEntry.fromJson).toList();
      });

  /// Live changes inside one group: chat, votes, polls and payments.
  RealtimeChannel? watchGroup(String groupId, void Function(String table, Map<String, dynamic> row) onChange) {
    final c = client;
    if (c == null || userId == null) return null;
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId);
    var channel = c.channel('group-$groupId');
    for (final table in const ['group_messages', 'group_votes', 'group_vote_ballots', 'poll_options', 'seettu_payments']) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (p) => onChange(table, p.newRecord),
      );
    }
    return channel.subscribe();
  }

  // ---------------------------------------------------------------- actions
  Future<String> createGroup({
    required String type,
    required String name,
    String? description,
    required int maxMembers,
    required bool discoverable,
    required String joinApproval,
    required String rules,
    required String votingMethod,
    String? district,
    Map<String, dynamic>? seettu,
    Map<String, dynamic>? investment,
  }) async =>
      await rpc('group_create', {
        'p_type': type,
        'p_name': name,
        'p_description': description,
        'p_photo_path': null,
        'p_max_members': maxMembers,
        'p_discoverable': discoverable,
        'p_join_approval': joinApproval,
        'p_rules': rules,
        'p_voting_method': votingMethod,
        'p_district': district,
        'p_seettu': seettu,
        'p_investment': investment,
      }) as String;

  Future<void> updateDetails(String groupId, {String? description, bool? discoverable, String? district}) =>
      rpc('group_update_details', {
        'p_group': groupId,
        'p_description': description,
        'p_photo_path': null,
        'p_discoverable': discoverable,
        'p_district': district,
        'p_max_members': null,
      });

  Future<void> decideJoin(String requestId, bool approve) =>
      rpc('group_decide_join', {'p_request': requestId, 'p_approve': approve});
  Future<void> removeMember(String groupId, String userId, String reason) =>
      rpc('group_remove_member', {'p_group': groupId, 'p_user': userId, 'p_reason': reason});
  Future<void> setRole(String groupId, String userId, String role) =>
      rpc('group_set_role', {'p_group': groupId, 'p_user': userId, 'p_role': role});
  Future<void> transferLeadership(String groupId, String userId) =>
      rpc('group_transfer_leadership', {'p_group': groupId, 'p_user': userId});
  Future<void> setMuted(String groupId, bool muted) => rpc('group_set_chat_muted', {'p_group': groupId, 'p_muted': muted});
  Future<void> setExpenseLink(String groupId, {String? recurringExpenseId, required bool logPayments}) =>
      rpc('group_set_expense_link', {'p_group': groupId, 'p_recurring_expense': recurringExpenseId, 'p_log_payments': logPayments});

  Future<void> sendMessage(String groupId, String body, {String? replyTo}) =>
      rpc('group_send_message', {'p_group': groupId, 'p_body': body, 'p_image_path': null, 'p_reply_to': replyTo});
  Future<void> removeMessage(String messageId) => rpc('group_delete_message', {'p_message': messageId});
  Future<void> pinMessage(String messageId, bool pinned) => rpc('group_pin_message', {'p_message': messageId, 'p_pinned': pinned});
  Future<void> markRead(String groupId) => rpc('group_mark_read', {'p_group': groupId});
  Future<void> reportMessage(String messageId, String reason, String? details) => rpc('community_report', {
        'p_target_type': 'message',
        'p_reason': reason,
        'p_details': details,
        'p_target_user': null,
        'p_target_group': null,
        'p_target_message': messageId,
        'p_is_scam': false,
      });

  Future<void> createPoll(String groupId, String question, List<String> options,
          {required bool multiple, required bool anonymous, required DateTime deadline}) =>
      rpc('poll_create', {
        'p_group': groupId,
        'p_question': question,
        'p_options': options,
        'p_multiple': multiple,
        'p_anonymous': anonymous,
        'p_deadline': deadline.toUtc().toIso8601String(),
      });
  Future<void> votePoll(String pollId, List<String> optionIds) => rpc('poll_vote', {'p_poll': pollId, 'p_option_ids': optionIds});
  Future<void> closePoll(String pollId) => rpc('poll_close', {'p_poll': pollId});

  Future<void> startVote(String groupId, String kind, String title, {String? description, Map<String, dynamic>? subject}) =>
      rpc('group_start_vote', {
        'p_group': groupId,
        'p_kind': kind,
        'p_title': title,
        'p_description': description,
        'p_subject': subject ?? <String, dynamic>{},
      });
  Future<void> castVote(String voteId, String choice) => rpc('vote_cast', {'p_vote': voteId, 'p_choice': choice});
  Future<void> closeVote(String voteId) => rpc('vote_close', {'p_vote': voteId});

  // Seettu
  Future<void> updateSeettu(String groupId, Map<String, dynamic> settings) =>
      rpc('seettu_update_settings', {'p_group': groupId, 'p_settings': settings});
  Future<void> setOrder(String groupId, List<String> userIds) => rpc('seettu_set_order', {'p_group': groupId, 'p_user_ids': userIds});
  Future<void> confirmSeettu(String groupId) => rpc('seettu_confirm', {'p_group': groupId});
  Future<void> startSeettu(String groupId) => rpc('seettu_start', {'p_group': groupId});
  Future<List<Map<String, dynamic>>> draw(String groupId) async => rows(await rpc('seettu_draw', {'p_group': groupId}));
  Future<void> openBidding(String groupId) => rpc('seettu_open_bidding', {'p_group': groupId});
  Future<void> placeBid(String roundId, double discount) => rpc('seettu_place_bid', {'p_round': roundId, 'p_discount': discount});
  Future<void> closeBidding(String roundId) => rpc('seettu_close_bidding', {'p_round': roundId});
  Future<void> markPaid(String paymentId) => rpc('seettu_mark_paid', {'p_payment': paymentId, 'p_receipt_path': null});
  Future<void> confirmPayment(String paymentId) => rpc('seettu_confirm_payment', {'p_payment': paymentId});
  Future<void> handOver(String roundId) => rpc('seettu_hand_over', {'p_round': roundId});
  Future<void> confirmReceived(String roundId) => rpc('seettu_confirm_received', {'p_round': roundId});

  // Investment
  Future<void> pledge(String groupId, double amount) => rpc('invest_pledge', {'p_group': groupId, 'p_amount': amount});
  Future<void> markContributionPaid(String id) => rpc('invest_mark_paid', {'p_contribution': id, 'p_receipt_path': null});
  Future<void> confirmContribution(String id) => rpc('invest_confirm_contribution', {'p_contribution': id});
  Future<void> cancelPledge(String id) => rpc('invest_cancel_pledge', {'p_contribution': id});
  Future<void> createProposal(String groupId,
          {required String title,
          required String type,
          required double amount,
          required String risk,
          required String reasoning,
          String? holdingPeriod,
          List<String> links = const [],
          double? expectedReturnPct}) =>
      rpc('invest_create_proposal', {
        'p_group': groupId,
        'p_title': title,
        'p_investment_type': type,
        'p_amount': amount,
        'p_risk_level': risk,
        'p_reasoning': reasoning,
        'p_holding_period': holdingPeriod,
        'p_links': links,
        'p_expected_return_pct': expectedReturnPct,
      });
  Future<void> withdrawProposal(String id) => rpc('invest_withdraw_proposal', {'p_proposal': id});
  Future<void> recordInvestment(String groupId,
          {required String title,
          required String type,
          required double amount,
          required DateTime madeOn,
          String? details,
          String? proposalId}) =>
      rpc('invest_record_investment', {
        'p_group': groupId,
        'p_title': title,
        'p_investment_type': type,
        'p_amount': amount,
        'p_made_on': '${madeOn.year}-${madeOn.month.toString().padLeft(2, '0')}-${madeOn.day.toString().padLeft(2, '0')}',
        'p_details': details,
        'p_proof_path': null,
        'p_proposal': proposalId,
      });
  Future<void> recordUpdate(String investmentId, String kind, double amount, {String? note}) =>
      rpc('invest_record_update', {'p_investment': investmentId, 'p_kind': kind, 'p_amount': amount, 'p_note': note});
  Future<void> createDistribution(String groupId, double total, {String? note}) =>
      rpc('invest_create_distribution', {'p_group': groupId, 'p_total': total, 'p_note': note});
  Future<void> confirmDistribution(String id) => rpc('invest_confirm_distribution', {'p_distribution': id});
  Future<void> requestExit(String groupId, {String? reason}) => rpc('invest_request_exit', {'p_group': groupId, 'p_reason': reason});
  Future<void> decideExit(String id, bool approve) => rpc('invest_decide_exit', {'p_request': id, 'p_approve': approve});
  Future<void> confirmExitPayout(String id) => rpc('invest_confirm_exit_payout', {'p_request': id});

  /// My unpaid seettu instalments due this month, in groups whose
  /// instalment isn't already a recurring expense. 0 on any error, so
  /// Expenditure never breaks because of Community.
  Future<double> myUnlinkedSeettuDueThisMonth() async {
    final uid = userId;
    if (uid == null) return 0;
    try {
      return await query((c) async {
        final linked = rows(await c
                .from('group_members')
                .select('group_id')
                .eq('user_id', uid)
                .eq('status', 'active')
                .not('recurring_expense_id', 'is', null))
            .map((r) => r['group_id'] as String)
            .toSet();
        final now = DateTime.now();
        String day(DateTime d) => d.toIso8601String().substring(0, 10);
        final list = rows(await c
            .from('seettu_payments')
            .select('group_id, amount_due, seettu_rounds!inner(due_date)')
            .eq('payer_id', uid)
            .neq('status', 'confirmed')
            .gte('seettu_rounds.due_date', day(DateTime(now.year, now.month)))
            .lte('seettu_rounds.due_date', day(DateTime(now.year, now.month + 1, 0))));
        return list
            .where((p) => !linked.contains(p['group_id']))
            .fold<double>(0, (sum, p) => sum + (p['amount_due'] as num).toDouble());
      });
    } catch (_) {
      return 0;
    }
  }

  /// Best-effort: adds the seettu instalment as a recurring essential
  /// expense. Returns its id, or null if the Expenditure upgrade isn't
  /// installed on the server yet.
  Future<String?> addRecurringInstalment({
    required String groupName,
    required double amount,
    required String frequency,
    required DateTime firstDue,
  }) async {
    try {
      return await query((c) async {
        final row = await c
            .from('recurring_expenses')
            .insert({
              'user_id': userId,
              'category': 'Seettu',
              'amount': amount,
              'note': 'Seettu: $groupName',
              'priority': 'essential',
              'frequency': frequency,
              'start_date': firstDue.toIso8601String().substring(0, 10),
              'next_due_date': firstDue.toIso8601String().substring(0, 10),
            })
            .select('id')
            .single();
        return row['id'] as String;
      });
    } on CommunityException {
      return null;
    }
  }
}
