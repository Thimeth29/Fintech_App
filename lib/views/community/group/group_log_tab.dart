import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../models/group_models.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../widgets/community_widgets.dart';

/// The group's append-only activity log. Nobody can edit or delete it.
class GroupLogTab extends StatelessWidget {
  const GroupLogTab({super.key});

  static String describe(ActivityEntry a, GroupViewModel vm) {
    final d = a.details;
    String who(Object? id) => vm.nameOf(id as String?);
    String rs(Object? v) => v == null ? '' : formatRs((v as num).toDouble());
    return switch (a.event) {
      'group_created' => 'Created the group',
      'member_joined' => '${who(d['user_id'])} joined',
      'member_left' => 'Left the group',
      'member_removed' => 'Removed ${who(d['user_id'])}: ${d['reason'] ?? ''}',
      'member_invited' => 'Invited ${who(d['user_id'])}',
      'join_requested' => 'Asked to join',
      'join_approved' => 'Approved ${who(d['user_id'])}\'s request',
      'join_declined' => 'Declined ${who(d['user_id'])}\'s request',
      'role_changed' => '${who(d['user_id'])}: ${d['from']} → ${d['to']}',
      'leader_changed' => 'Leadership moved from ${who(d['from'])} to ${who(d['to'])} (${d['how']})',
      'leader_replaced' => '${who(d['new_leader'])} replaced ${who(d['old_leader'])} as leader (${d['reason']})',
      'vote_opened' => 'Opened a vote: ${d['title'] ?? ''}',
      'vote_closed' => 'Vote ${d['passed'] == true ? 'passed' : 'failed'} (yes ${d['yes'] ?? '-'}, no ${d['no'] ?? '-'})',
      'rules_changed' => 'Rules or settings changed by vote',
      'voting_method_changed' => 'Voting method changed by vote',
      'details_updated' => 'Group details updated',
      'message_removed' => 'Removed a message',
      'payout_order_set' => 'Set the payout order',
      'seettu_terms_confirmed' => 'Confirmed the seettu terms',
      'seettu_settings_changed' => 'Changed the seettu terms',
      'seettu_started' => 'Started the seettu',
      'seettu_draw' => 'Draw: round ${d['round_no']} → ${who(d['recipient_id'])}',
      'seettu_bidding_opened' => 'Opened bidding for round ${d['round_no']}',
      'seettu_bidding_closed' => 'Round ${d['round_no']} → ${who(d['recipient_id'])} (discount ${rs(d['discount'])})',
      'seettu_last_round_assigned' => 'Round ${d['round_no']} → ${who(d['recipient_id'])}',
      'seettu_payment_marked' => 'Marked round ${d['round_no']} paid',
      'seettu_payment_confirmed' => 'Confirmed ${who(d['payer_id'])}\'s round ${d['round_no']} payment (${rs(d['amount'])})',
      'seettu_payment_late' => '${who(d['payer_id'])}\'s round ${d['round_no']} payment is late',
      'seettu_pot_handed_over' => 'Handed over the round ${d['round_no']} pot (${rs(d['pot'])})',
      'seettu_pot_received' => 'Confirmed receiving the round ${d['round_no']} pot',
      'contribution_pledged' => 'Pledged ${rs(d['amount'])}',
      'contribution_marked_paid' => 'Marked a ${rs(d['amount'])} contribution paid',
      'contribution_confirmed' => 'Confirmed ${who(d['user_id'])}\'s ${rs(d['amount'])} contribution',
      'contribution_cancelled' => 'Cancelled a ${rs(d['amount'])} pledge',
      'proposal_withdrawn' => 'Withdrew a proposal',
      'investment_recorded' => 'Recorded an investment of ${rs(d['amount'])}',
      'investment_value' => 'Updated an investment\'s value to ${rs(d['amount'])}',
      'investment_income' => 'Recorded ${rs(d['amount'])} income',
      'investment_close' => 'Closed an investment at ${rs(d['amount'])}',
      'distribution_created' => 'Created a ${rs(d['total'])} distribution',
      'distribution_received' => 'Confirmed receiving ${rs(d['amount'])}',
      'exit_requested' => 'Asked to exit',
      'exit_approved' => 'Exit approved',
      'exit_declined' => 'Exit declined',
      'exit_completed' => 'Confirmed exit payout of ${rs(d['payout'])}',
      'group_closed' => 'The group was closed',
      _ => a.event.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    return RefreshIndicator(
      onRefresh: vm.loadActivity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Text('Every important event, in order. Nobody can edit or delete this log.',
              style: cText(12.5, color: AppColors.onGlassMuted)),
          const SizedBox(height: 8),
          for (final a in vm.activity)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 8, color: AppColors.accentCyan),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(describe(a, vm), style: cText(13)),
                    Text('${a.actorId == null ? 'Mobile SAP' : vm.nameOf(a.actorId)} · ${shortDate(a.createdAt)} '
                        '${a.createdAt.hour.toString().padLeft(2, '0')}:${a.createdAt.minute.toString().padLeft(2, '0')}',
                        style: cText(11, color: AppColors.onGlassFaint)),
                  ]),
                ),
              ]),
            ),
          if (vm.hasOlderActivity && vm.activity.isNotEmpty)
            Center(
              child: TextButton(onPressed: () => vm.loadActivity(older: true), child: const Text('Load older')),
            ),
        ],
      ),
    );
  }
}
