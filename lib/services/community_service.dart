// lib/services/community_service.dart
//
// Supabase access for Community. Reads of group content go straight to the
// tables (RLS: members only); profile reads and every write go through
// the RPCs in supabase/migrations/20261013090000_community_groups.sql,
// which apply the visibility rules (phone, contribution bucket, blocks).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/community_models.dart';

/// A server-side rejection, with the code raised by the RPC.
class CommunityException implements Exception {
  final String code;
  const CommunityException(this.code);

  String get message => communityErrorText(code);

  @override
  String toString() => message;
}

String _codeOf(PostgrestException e) {
  // Function/table missing: the migration isn't applied yet.
  const missing = {'PGRST202', 'PGRST205', '42883', '42P01'};
  if (missing.contains(e.code)) return 'community_unavailable';
  return e.message;
}

String communityErrorText(String code) => switch (code) {
      'not_authenticated' => 'Log in to use Community.',
      'community_unavailable' =>
        'Community isn\'t set up on the server yet. Please try again later.',
      'network' => 'Couldn\'t reach the server. Check your connection and try again.',
      'profile_required' => 'Set up your community profile first.',
      'display_name_required' => 'Enter a display name.',
      'bio_too_long' => 'Keep your bio to 200 characters.',
      'invalid_photo_path' => 'That photo couldn\'t be used.',
      'under_18' => 'Group features are for users aged 18 and over.',
      'age_confirmation_required' => 'Confirm you are 18 or older to turn this on.',
      'cannot_connect_self' => 'That\'s you!',
      'message_too_long' => 'That message is too long.',
      'user_unavailable' => 'This person isn\'t available right now.',
      'already_connected' => 'You\'re already connected.',
      'request_already_sent' => 'You already sent a request.',
      'declined_recently' => 'This person declined recently. You can ask again 7 days after they declined.',
      'too_many_pending_requests' => 'You have too many pending requests. Wait for some replies first.',
      'request_not_found' || 'request_not_pending' => 'That request is no longer pending.',
      'cannot_block_self' => 'You can\'t block yourself.',
      'too_many_reports' => 'You\'ve sent a lot of reports today. Try again tomorrow.',
      'invalid_report_target' => 'That can\'t be reported.',
      'group_not_found' || 'group_unavailable' => 'This group isn\'t available.',
      'group_not_open' => 'This group isn\'t taking new members.',
      'group_full' => 'This group is full.',
      'already_member' => 'You\'re already a member.',
      'rules_not_accepted' => 'Read and accept the group rules first.',
      'invite_not_found' => 'That invite is no longer valid.',
      'not_group_member' => 'You\'re not a member of this group.',
      'not_group_officer' => 'Only the leader can do that.',
      'seettu_in_progress' =>
        'The seettu is in progress, so you can\'t leave now. Ask the leader if you need to step out.',
      'must_complete_payments' =>
        'You\'ve received the pot, so you need to finish your remaining payments before leaving.',
      'exit_request_required' => 'Request an exit so your contribution can be settled first.',
      'too_many_groups_led' => 'You can lead up to 5 groups at a time.',
      'group_name_taken' => 'A group with that name already exists.',
      'seettu_settings_required' || 'investment_settings_required' => 'Fill in the group settings first.',
      'invalid_due_day' => 'Choose a valid payment day.',
      'invalid_frequency' => 'Choose weekly or monthly.',
      'group_read_only' => 'This group is closed. Its records are read-only.',
      'empty_message' => 'Type a message first.',
      'payment_details_blocked' =>
        'That looks like a bank account or card number. Share payment details privately with the treasurer.',
      'invalid_attachment' => 'That attachment couldn\'t be used.',
      'reply_not_found' || 'message_not_found' => 'That message is no longer available.',
      'slow_down' => 'You\'re sending messages too fast. Wait a moment.',
      'cannot_delete_system_message' => 'System messages can\'t be removed.',
      'poll_needs_2_to_6_options' => 'A poll needs 2 to 6 different options.',
      'invalid_deadline' => 'Pick a deadline between 10 minutes and 30 days from now.',
      'poll_not_found' || 'vote_not_found' => 'That poll or vote no longer exists.',
      'poll_closed' || 'vote_closed' => 'Voting has closed.',
      'invalid_choice' => 'Choose a valid option.',
      'vote_still_open' => 'This vote is still open until its deadline.',
      'cannot_vote_on_own_case' => 'You can\'t vote on a decision about yourself.',
      'invalid_vote_kind' => 'That type of vote isn\'t available.',
      'too_many_open_votes' => 'This group already has 10 open votes. Wait for some to close.',
      'vote_already_open' => 'A vote like this is already open.',
      'invalid_candidate' || 'invalid_target' => 'Choose an active member (not the leader).',
      'reason_required' => 'Give a short reason.',
      'invalid_voting_method' => 'Choose a different voting method.',
      'nothing_to_change' => 'Change at least one setting.',
      'rules_too_long' => 'Rules can be at most 4,000 characters.',
      'invalid_setting' => 'One of those settings isn\'t valid.',
      'not_a_seettu' => 'This isn\'t a seettu group.',
      'seettu_already_started' => 'The seettu has already started.',
      'start_date_passed' => 'Choose a start date from today onwards.',
      'order_is_not_agreed' => 'This seettu doesn\'t use an agreed order.',
      'order_must_list_every_member' => 'The order must list every member exactly once.',
      'order_not_set' => 'The leader hasn\'t set the payout order yet.',
      'seats_not_filled' => 'Every seat must be filled before the seettu starts.',
      'not_all_confirmed' => 'Every member must confirm the terms first.',
      'not_a_random_seettu' => 'This seettu doesn\'t use a random draw.',
      'seettu_not_started' => 'The seettu hasn\'t started yet.',
      'nothing_to_draw' => 'Every round already has a recipient.',
      'no_eligible_members' => 'No members are left to receive a pot.',
      'not_an_auction_seettu' => 'This seettu doesn\'t use bidding.',
      'bidding_already_open' => 'Bidding is already open.',
      'bidding_closed' => 'Bidding for this round has closed.',
      'already_received_pot' => 'You\'ve already received a pot, so you can\'t bid.',
      'invalid_bid' => 'Bid a discount between zero and half the pot.',
      'round_not_found' || 'payment_not_found' => 'That round or payment isn\'t available.',
      'recipient_not_decided' => 'Wait until this round\'s recipient is decided.',
      'payment_already_marked' => 'This payment is already marked as paid.',
      'cannot_confirm_own_payment' => 'Someone else has to confirm your payment.',
      'payment_already_confirmed' => 'This payment is already confirmed.',
      'round_not_collecting' => 'This round isn\'t collecting payments.',
      'previous_round_open' => 'Finish the previous round first.',
      'payments_outstanding' => 'Every payment must be confirmed before handing over the pot.',
      'pot_not_handed_over' => 'The pot hasn\'t been handed over yet.',
      'not_an_investment_group' => 'This isn\'t an investment group.',
      'invalid_amount' => 'Enter an amount greater than zero.',
      'below_minimum_contribution' => 'That\'s below the group\'s minimum contribution.',
      'above_maximum_contribution' => 'That\'s above the group\'s maximum contribution.',
      'contribution_not_found' || 'contribution_not_pledged' || 'contribution_not_pending' =>
        'That contribution can\'t be changed now.',
      'risk_level_required' => 'Choose a risk level.',
      'investment_type_not_allowed' => 'This group doesn\'t invest in that type.',
      'proposal_not_found' || 'proposal_not_open' => 'That proposal isn\'t open.',
      'invalid_date' => 'Choose a date that isn\'t in the future.',
      'proposal_not_approved' => 'That proposal hasn\'t been approved by a vote.',
      'above_approved_amount' => 'That\'s more than the approved amount.',
      'vote_required' => 'This amount is above the leader\'s limit. Create a proposal for the group to vote on.',
      'insufficient_pool' => 'The group\'s confirmed pool isn\'t big enough for that.',
      'investment_not_found' || 'investment_closed' => 'That investment is closed.',
      'invalid_update' => 'Choose what you\'re recording.',
      'no_contributions' => 'No one has a confirmed contribution yet.',
      'share_not_found' => 'You don\'t have a share in that distribution.',
      'exit_already_requested' => 'You\'ve already asked to exit.',
      'cannot_decide_own_exit' => 'Someone else has to decide your exit.',
      'decided_by_vote' => 'The group is voting on this.',
      'use_leave_instead' => 'Use "Leave group" to leave.',
      'cannot_remove_leader' => 'The leader can\'t be removed this way. Start a "Change leader" vote.',
      'invalid_role' => 'Choose a valid role.',
      'treasurer_investment_only' => 'Treasurers are for investment groups.',
      'use_transfer_leadership' => 'Use "Make leader" to transfer leadership.',
      'max_below_member_count' => 'The group already has more members than that.',
      'too_many_invites' => 'You\'ve sent a lot of invites today. Try again tomorrow.',
      _ => 'Something went wrong ($code). Please try again.',
    };

class CommunityService {
  SupabaseClient? get client {
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  String? get userId => client?.auth.currentUser?.id;

  Future<dynamic> rpc(String fn, [Map<String, dynamic> params = const {}]) async {
    final c = client;
    if (c == null || userId == null) throw const CommunityException('not_authenticated');
    try {
      return await c.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw CommunityException(_codeOf(e));
    } catch (e) {
      if (e is CommunityException) rethrow;
      throw const CommunityException('network');
    }
  }

  Future<T> query<T>(Future<T> Function(SupabaseClient c) run) async {
    final c = client;
    if (c == null || userId == null) throw const CommunityException('not_authenticated');
    try {
      return await run(c);
    } on PostgrestException catch (e) {
      throw CommunityException(_codeOf(e));
    } catch (e) {
      if (e is CommunityException) rethrow;
      throw const CommunityException('network');
    }
  }

  List<Map<String, dynamic>> rows(dynamic res) =>
      res is List ? res.map((e) => Map<String, dynamic>.from(e as Map)).toList() : const [];

  // ---------------------------------------------------------------- profile
  Future<MyCommunityProfile> myProfile() async =>
      MyCommunityProfile.fromJson(Map<String, dynamic>.from(await rpc('community_my_profile') as Map));

  Future<MyCommunityProfile> saveProfile({
    required String displayName,
    String? phone,
    required bool phoneVisibleInSearch,
    double? maxContribution,
    required String experience,
    required List<String> interests,
    String? district,
    String? bio,
  }) async =>
      MyCommunityProfile.fromJson(Map<String, dynamic>.from(await rpc('community_save_profile', {
        'p_display_name': displayName,
        'p_phone': phone,
        'p_phone_visible_in_search': phoneVisibleInSearch,
        'p_photo_path': null,
        'p_max_contribution': maxContribution,
        'p_experience': experience,
        'p_interests': interests,
        'p_district': district,
        'p_bio': bio,
      }) as Map));

  Future<MyCommunityProfile> confirmAge() async =>
      MyCommunityProfile.fromJson(Map<String, dynamic>.from(await rpc('community_confirm_age') as Map));

  Future<MyCommunityProfile> setAvailable(bool available) async => MyCommunityProfile.fromJson(
      Map<String, dynamic>.from(await rpc('community_set_available', {'p_available': available}) as Map));

  Future<void> markExplainerSeen() async => rpc('community_mark_explainer_seen');

  Future<Map<String, dynamic>?> profileOf(String userId) async {
    final res = await rpc('community_get_profile', {'p_user': userId});
    return res is Map ? Map<String, dynamic>.from(res) : null;
  }

  // ---------------------------------------------------------------- search
  Future<List<PersonResult>> searchPeople({
    String? query,
    int? minBucket,
    int? maxBucket,
    List<String>? experience,
    List<String>? interests,
    String? district,
    bool verifiedOnly = false,
    int limit = 20,
    int offset = 0,
  }) async =>
      rows(await rpc('community_search_people', {
        'p_query': query,
        'p_min_bucket': minBucket,
        'p_max_bucket': maxBucket,
        'p_experience': (experience?.isEmpty ?? true) ? null : experience,
        'p_interests': (interests?.isEmpty ?? true) ? null : interests,
        'p_district': district,
        'p_verified_only': verifiedOnly,
        'p_limit': limit,
        'p_offset': offset,
      })).map(PersonResult.fromJson).toList();

  Future<List<GroupResult>> searchGroups({
    String? query,
    String? type,
    double? minAmount,
    double? maxAmount,
    String? frequency,
    bool openOnly = false,
    String? district,
    List<String>? leaderExperience,
    int limit = 20,
    int offset = 0,
  }) async =>
      rows(await rpc('community_search_groups', {
        'p_query': query,
        'p_type': type,
        'p_min_amount': minAmount,
        'p_max_amount': maxAmount,
        'p_frequency': frequency,
        'p_open_only': openOnly,
        'p_district': district,
        'p_leader_experience': (leaderExperience?.isEmpty ?? true) ? null : leaderExperience,
        'p_limit': limit,
        'p_offset': offset,
      })).map(GroupResult.fromJson).toList();

  Future<GroupSummary?> groupSummary(String groupId) async {
    final res = await rpc('community_group_summary', {'p_group': groupId});
    return res is Map ? GroupSummary(Map<String, dynamic>.from(res)) : null;
  }

  // ---------------------------------------------------------- connections
  Future<List<ConnectionEntry>> connections() async =>
      rows(await rpc('community_list_connections')).map(ConnectionEntry.fromJson).toList();

  Future<void> requestConnection(String userId, {String? message}) =>
      rpc('connection_request', {'p_user': userId, 'p_message': message});

  Future<void> respondConnection(String connectionId, bool accept) =>
      rpc('connection_respond', {'p_connection': connectionId, 'p_accept': accept});

  Future<void> cancelConnection(String connectionId) =>
      rpc('connection_cancel', {'p_connection': connectionId});

  Future<void> removeConnection(String userId) => rpc('connection_remove', {'p_user': userId});

  Future<void> block(String userId) => rpc('community_block', {'p_user': userId});

  Future<void> unblock(String userId) => rpc('community_unblock', {'p_user': userId});

  Future<List<BlockedUser>> blocked() async => rows(await rpc('community_list_blocked'))
      .map((r) => BlockedUser(r['user_id'] as String, (r['display_name'] as String?) ?? 'Member'))
      .toList();

  Future<void> report({
    required String targetType,
    required String reason,
    String? details,
    String? userId,
    String? groupId,
    String? messageId,
    bool isScam = false,
  }) =>
      rpc('community_report', {
        'p_target_type': targetType,
        'p_reason': reason,
        'p_details': details,
        'p_target_user': userId,
        'p_target_group': groupId,
        'p_target_message': messageId,
        'p_is_scam': isScam,
      });

  // --------------------------------------------------------------- groups
  Future<List<MyGroup>> myGroups() => query((c) async {
        final res = await c
            .from('group_members')
            .select('role, groups!inner(id, name, type, status, max_members)')
            .eq('user_id', userId!)
            .eq('status', 'active');
        return rows(res).map((r) {
          final g = Map<String, dynamic>.from(r['groups'] as Map);
          return MyGroup(
            id: g['id'] as String,
            name: g['name'] as String,
            type: g['type'] as String,
            status: g['status'] as String,
            role: r['role'] as String,
            maxMembers: (g['max_members'] as num).toInt(),
          );
        }).toList();
      });

  Future<List<GroupInvite>> myInvites() async {
    final list = await query((c) async => rows(await c
        .from('group_invites')
        .select('id, group_id, created_at')
        .eq('invitee_id', userId!)
        .eq('status', 'pending')
        .order('created_at', ascending: false)));
    return Future.wait(list.map((r) async => GroupInvite(
          id: r['id'] as String,
          groupId: r['group_id'] as String,
          createdAt: DateTime.tryParse('${r['created_at']}'),
          summary: await groupSummary(r['group_id'] as String),
        )));
  }

  Future<List<GroupMember>> members(String groupId) => query((c) async {
        final list = rows(await c
            .from('group_members')
            .select('user_id, role, joined_at')
            .eq('group_id', groupId)
            .eq('status', 'active')
            .order('joined_at'));
        final ids = list.map((r) => r['user_id'] as String).toList();
        final names = <String, String>{};
        if (ids.isNotEmpty) {
          for (final p in rows(await c.from('community_profiles').select('user_id, display_name').inFilter('user_id', ids))) {
            names[p['user_id'] as String] = p['display_name'] as String;
          }
        }
        return list
            .map((r) => GroupMember(
                  userId: r['user_id'] as String,
                  displayName: names[r['user_id']] ?? 'Member',
                  role: r['role'] as String,
                  joinedAt: DateTime.tryParse('${r['joined_at']}'),
                ))
            .toList();
      });

  Future<String> requestJoin(String groupId, {String? message}) async =>
      await rpc('group_request_join', {'p_group': groupId, 'p_message': message, 'p_accept_rules': true}) as String;

  Future<void> cancelJoinRequest(String requestId) =>
      rpc('group_cancel_join_request', {'p_request': requestId});

  Future<Map<String, dynamic>> respondInvite(String inviteId, bool accept) async => Map<String, dynamic>.from(
      await rpc('group_respond_invite', {'p_invite': inviteId, 'p_accept': accept, 'p_accept_rules': accept}) as Map);

  Future<void> invite(String groupId, String userId) =>
      rpc('group_invite', {'p_group': groupId, 'p_user': userId});

  Future<void> leaveGroup(String groupId) => rpc('group_leave', {'p_group': groupId});

  // -------------------------------------------------------- notifications
  Future<Map<String, dynamic>> unreadSummary() async =>
      Map<String, dynamic>.from(await rpc('community_unread_summary') as Map);

  Future<List<AppNotification>> notifications({int limit = 50}) => query((c) async => rows(await c
          .from('notifications')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false)
          .limit(limit))
      .map(AppNotification.fromJson)
      .toList());

  Future<void> markNotificationsRead(List<String> ids) => query((c) async {
        if (ids.isEmpty) return;
        await c
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .inFilter('id', ids);
      });

  /// Live inserts into my notifications. Returns the channel to remove later.
  RealtimeChannel? watchNotifications(void Function() onInsert) {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) return null;
    return c
        .channel('notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => onInsert(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    try {
      await client?.removeChannel(channel);
    } catch (_) {}
  }
}
