import 'package:flutter/material.dart';

import '../../core/community/community_math.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/community_models.dart';
import '../../models/group_models.dart';
import '../../services/community_service.dart';
import '../../services/group_service.dart';
import 'widgets/community_widgets.dart';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Start a seettu or an investment group. Pops the new group's id.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _form = GlobalKey<FormState>();
  String _type = 'seettu';
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  int _maxMembers = 10;
  bool _discoverable = true;
  String _joinApproval = 'leader';
  String _votingMethod = 'one_member_one_vote';
  String? _district;

  // Seettu
  final _contribution = TextEditingController();
  String _frequency = 'monthly';
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  int _dueDay = 5;
  String _payoutMethod = 'agreed';
  String _drawMode = 'all';
  final _lateRule = TextEditingController();
  final _lateFee = TextEditingController();

  // Investment
  final _purpose = TextEditingController();
  final _target = TextEditingController();
  final _minContribution = TextEditingController(text: '5000');
  final _maxContribution = TextEditingController();
  final Set<String> _allowed = {'fd', 'gov_securities'};
  String _risk = 'low';
  String _distribution = 'pro_rata';
  int _lockIn = 0;
  String _exitMethod = 'share_of_value';
  final _penalty = TextEditingController(text: '0');
  final _exitRule = TextEditingController();
  final _threshold = TextEditingController(text: '0');
  String _proposalsBy = 'any';
  String _exitApproval = 'leader';

  bool _understood = false;
  bool _saving = false;

  bool get _seettu => _type == 'seettu';

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_understood) {
      showResult(context, 'Please confirm you understand how group money works here.');
      return;
    }
    if (!_seettu && _allowed.isEmpty) {
      showResult(context, 'Choose at least one investment type.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await GroupService().createGroup(
        type: _type,
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        maxMembers: _maxMembers,
        discoverable: _discoverable,
        joinApproval: _joinApproval,
        rules: _rules.text.trim(),
        votingMethod: _votingMethod,
        district: _district,
        seettu: _seettu
            ? {
                'contribution': parseAmount(_contribution.text),
                'frequency': _frequency,
                'start_date': isoDate(_start),
                'due_day': _dueDay,
                'payout_method': _payoutMethod,
                'draw_mode': _drawMode,
                'late_rule': _lateRule.text.trim(),
                'late_fee': parseAmount(_lateFee.text),
              }
            : null,
        investment: _seettu
            ? null
            : {
                'purpose': _purpose.text.trim(),
                'target_amount': parseAmount(_target.text),
                'min_contribution': parseAmount(_minContribution.text) ?? 1000,
                'max_contribution': parseAmount(_maxContribution.text),
                'allowed_types': _allowed.toList(),
                'risk_level': _risk,
                'distribution_rule': _distribution,
                'lock_in_months': _lockIn,
                'exit_rule': _exitRule.text.trim(),
                'exit_payout_method': _exitMethod,
                'early_exit_penalty_pct': parseAmount(_penalty.text) ?? 0,
                'decision_threshold': parseAmount(_threshold.text) ?? 0,
                'proposals_by': _proposalsBy,
                'exit_approval': _exitApproval,
              },
      );
      if (mounted) Navigator.of(context).pop(id);
    } on CommunityException catch (e) {
      if (mounted) showResult(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 720,
      appBar: const TopNavBar(current: AppSection.community, title: 'Start a group', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.community, isSectionRoot: false),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'seettu', label: Text('Seettu'), icon: Icon(Icons.autorenew_rounded)),
                ButtonSegment(value: 'investment', label: Text('Investment group'), icon: Icon(Icons.groups_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _seettu
                  ? 'A rotating savings group: everyone pays the same amount each round and one member receives the whole pot, until everyone has had a turn.'
                  : 'Pool money with other members, decide together what to invest in, and share profits by an agreed rule.',
              style: cText(12.5, color: AppColors.onGlassMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            _section('Basics', [
              TextFormField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Group name'),
                validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 characters' : null,
              ),
              TextFormField(controller: _description, maxLines: 2, maxLength: 1000, decoration: const InputDecoration(labelText: 'Description')),
              Row(children: [
                Expanded(child: Text(_seettu ? 'Members (= number of rounds)' : 'Maximum members', style: cText(13.5))),
                IconButton(onPressed: _maxMembers > 2 ? () => setState(() => _maxMembers--) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('$_maxMembers', style: cText(16, weight: FontWeight.w800)),
                IconButton(onPressed: _maxMembers < 50 ? () => setState(() => _maxMembers++) : null, icon: const Icon(Icons.add_circle_outline)),
              ]),
              DropdownButtonFormField<String?>(
                initialValue: _district,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'District (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Not shown')),
                  for (final d in kSriLankaDistricts) DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => setState(() => _district = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show in Discover'),
                subtitle: const Text('Off: people can only join by invite'),
                value: _discoverable,
                onChanged: (v) => setState(() => _discoverable = v),
              ),
            ]),
            if (_seettu) _seettuSection() else _investmentSection(),
            _section('Decisions', [
              DropdownButtonFormField<String>(
                initialValue: _joinApproval,
                decoration: const InputDecoration(labelText: 'New members'),
                items: const [
                  DropdownMenuItem(value: 'leader', child: Text('Leader approves')),
                  DropdownMenuItem(value: 'vote', child: Text('Members vote')),
                ],
                onChanged: (v) => setState(() => _joinApproval = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _votingMethod,
                decoration: const InputDecoration(labelText: 'Voting method (changeable only by a vote)'),
                items: [
                  const DropdownMenuItem(value: 'one_member_one_vote', child: Text('One member, one vote')),
                  if (!_seettu) const DropdownMenuItem(value: 'weighted', child: Text('Weighted by contribution')),
                ],
                onChanged: (v) => setState(() => _votingMethod = v!),
              ),
              Text('Quorum 50%, simple majority; changing the leader needs 2/3 of all members. Votes stay open 48 hours.',
                  style: cText(12, color: AppColors.onGlassMuted)),
            ]),
            _section('Rules', [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.innerFill, borderRadius: BorderRadius.circular(12)),
                child: Text('$kRecordKeepingNotice This notice is always shown above your rules.',
                    style: cText(12.5, color: AppColors.accentCyan, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rules,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: 'Your group rules', alignLabelWithHint: true),
              ),
            ]),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: Text(
                'I understand Mobile SAP only keeps records. Members pay each other directly, and I won\'t promise anyone guaranteed returns.',
                style: cText(13),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Creating…' : 'Create group')),
            const SizedBox(height: 6),
            Text('You become the leader. You can lead up to 5 groups at a time.', style: cText(12, color: AppColors.onGlassFaint)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: cText(15, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );

  Widget _seettuSection() {
    final amount = parseAmount(_contribution.text);
    final dates = [
      for (var i = 1; i <= 3 && i <= _maxMembers; i++)
        seettuDueDate(_start, _frequency, _frequency == 'weekly' ? _dueDay.clamp(1, 7) : _dueDay, i),
    ];
    return _section('Seettu', [
      TextFormField(
        controller: _contribution,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Contribution per member per round (Rs)'),
        validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter an amount' : null,
      ),
      DropdownButtonFormField<String>(
        initialValue: _frequency,
        decoration: const InputDecoration(labelText: 'Frequency'),
        items: const [
          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
        ],
        onChanged: (v) => setState(() {
          _frequency = v!;
          _dueDay = _frequency == 'weekly' ? 1 : 5;
        }),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Start date'),
        subtitle: Text(shortDate(_start)),
        trailing: const Icon(Icons.calendar_month_rounded),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _start,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) setState(() => _start = d);
        },
      ),
      DropdownButtonFormField<int>(
        initialValue: _dueDay,
        decoration: InputDecoration(labelText: _frequency == 'weekly' ? 'Payment day' : 'Payment day of the month'),
        items: _frequency == 'weekly'
            ? [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text(_weekdays[i - 1]))]
            : [for (var i = 1; i <= 28; i++) DropdownMenuItem(value: i, child: Text('$i'))],
        onChanged: (v) => setState(() => _dueDay = v!),
      ),
      DropdownButtonFormField<String>(
        initialValue: _payoutMethod,
        decoration: const InputDecoration(labelText: 'Who gets the pot when'),
        items: const [
          DropdownMenuItem(value: 'agreed', child: Text('Agreed order (leader sets, members confirm)')),
          DropdownMenuItem(value: 'random', child: Text('Random draw')),
          DropdownMenuItem(value: 'bidding', child: Text('Bidding (auction seettu)')),
        ],
        onChanged: (v) => setState(() => _payoutMethod = v!),
      ),
      if (_payoutMethod == 'random')
        DropdownButtonFormField<String>(
          initialValue: _drawMode,
          decoration: const InputDecoration(labelText: 'Draw'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All rounds at the start')),
            DropdownMenuItem(value: 'each_round', child: Text('One round at a time')),
          ],
          onChanged: (v) => setState(() => _drawMode = v!),
        ),
      if (_payoutMethod == 'bidding')
        Text(
          'Each round, members who haven\'t received the pot bid the discount they\'ll accept. The biggest discount wins, '
          'and it\'s shared as a credit on everyone else\'s instalment for that round.',
          style: cText(12, color: AppColors.onGlassMuted, height: 1.4),
        ),
      TextFormField(controller: _lateRule, maxLines: 2, decoration: const InputDecoration(labelText: 'Late payment rule (optional)')),
      TextFormField(controller: _lateFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Late fee (Rs, recorded only)')),
      if (amount != null && amount > 0) ...[
        const SizedBox(height: 10),
        Text('Each pot: ${formatRs(seettuPot(amount, _maxMembers))} · $_maxMembers rounds', style: cText(13, weight: FontWeight.w700)),
        Text('First due dates: ${dates.map(shortDate).join(', ')}', style: cText(12, color: AppColors.onGlassMuted)),
      ],
    ]);
  }

  Widget _investmentSection() => _section('Investing', [
        TextFormField(controller: _purpose, maxLength: 500, decoration: const InputDecoration(labelText: 'Purpose')),
        TextFormField(controller: _target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target amount (Rs, optional)')),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _minContribution,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Min per member (Rs)'),
              validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _maxContribution,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max per member (Rs)'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text('Allowed investments', style: cText(13, weight: FontWeight.w700)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in kInvestmentTypeLabels.entries)
            FilterChip(
              label: Text(t.value),
              selected: _allowed.contains(t.key),
              onSelected: (on) => setState(() => on ? _allowed.add(t.key) : _allowed.remove(t.key)),
            ),
        ]),
        const SizedBox(height: 10),
        Text('Risk the group accepts', style: cText(13, weight: FontWeight.w700)),
        Wrap(spacing: 6, children: [
          for (final r in kRiskLabels.entries)
            ChoiceChip(label: Text(r.value), selected: _risk == r.key, onSelected: (_) => setState(() => _risk = r.key)),
        ]),
        DropdownButtonFormField<String>(
          initialValue: _distribution,
          decoration: const InputDecoration(labelText: 'Profit split'),
          items: const [
            DropdownMenuItem(value: 'pro_rata', child: Text('Pro-rata to contribution')),
            DropdownMenuItem(value: 'equal', child: Text('Equal split')),
          ],
          onChanged: (v) => setState(() => _distribution = v!),
        ),
        DropdownButtonFormField<int>(
          initialValue: _lockIn,
          decoration: const InputDecoration(labelText: 'Lock-in period'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('None')),
            DropdownMenuItem(value: 3, child: Text('3 months')),
            DropdownMenuItem(value: 6, child: Text('6 months')),
            DropdownMenuItem(value: 12, child: Text('12 months')),
            DropdownMenuItem(value: 24, child: Text('24 months')),
          ],
          onChanged: (v) => setState(() => _lockIn = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: _exitMethod,
          decoration: const InputDecoration(labelText: 'Early exit pays'),
          items: const [
            DropdownMenuItem(value: 'share_of_value', child: Text('Their share of the current value')),
            DropdownMenuItem(value: 'contribution_back', child: Text('What they paid in')),
          ],
          onChanged: (v) => setState(() => _exitMethod = v!),
        ),
        if (_lockIn > 0)
          TextFormField(controller: _penalty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Penalty for leaving during lock-in (%)')),
        TextFormField(controller: _exitRule, maxLines: 2, decoration: const InputDecoration(labelText: 'Exit rule in your words (optional)')),
        TextFormField(
          controller: _threshold,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Leader can act alone up to (Rs)', helperText: 'Anything above needs a vote. 0 = always vote.'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _proposalsBy,
          decoration: const InputDecoration(labelText: 'Who can propose investments'),
          items: const [
            DropdownMenuItem(value: 'any', child: Text('Any member')),
            DropdownMenuItem(value: 'leader', child: Text('Leader and co-leaders')),
          ],
          onChanged: (v) => setState(() => _proposalsBy = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: _exitApproval,
          decoration: const InputDecoration(labelText: 'Exits approved by'),
          items: const [
            DropdownMenuItem(value: 'leader', child: Text('Leader')),
            DropdownMenuItem(value: 'vote', child: Text('Group vote')),
          ],
          onChanged: (v) => setState(() => _exitApproval = v!),
        ),
        const SizedBox(height: 6),
        Text('No returns are guaranteed. Every proposal must state its risk level.', style: cText(12, color: AppColors.warning)),
      ]);
}
