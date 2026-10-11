import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/community_models.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'widgets/community_widgets.dart';

/// My public community profile, availability and privacy.
class PublicProfileTab extends StatefulWidget {
  const PublicProfileTab({super.key});

  @override
  State<PublicProfileTab> createState() => _PublicProfileTabState();
}

class _PublicProfileTabState extends State<PublicProfileTab> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _max = TextEditingController();
  final _bio = TextEditingController();
  bool _phoneVisible = false;
  String _experience = 'none';
  final Set<String> _interests = {};
  String? _district;
  bool _saving = false;
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _max.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _fill(MyCommunityProfile p) {
    if (_filled) return;
    _filled = true;
    _name.text = p.exists ? p.displayName : p.defaultDisplayName;
    _phone.text = (p.exists ? p.phone : p.defaultPhone) ?? '';
    _max.text = p.maxContribution == null ? '' : p.maxContribution!.toStringAsFixed(0);
    _bio.text = p.bio ?? '';
    _phoneVisible = p.phoneVisibleInSearch;
    _experience = p.experience;
    _interests
      ..clear()
      ..addAll(p.interests);
    _district = p.district;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final vm = context.read<CommunityViewModel>();
    final wasNew = !vm.hasProfile;
    final error = await vm.saveProfile(
      displayName: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      phoneVisibleInSearch: _phoneVisible,
      maxContribution: parseAmount(_max.text),
      experience: _experience,
      interests: _interests.toList(),
      district: _district,
      bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showResult(context, error, wasNew ? 'Profile created. Turn on availability to appear in search.' : 'Profile saved.');
  }

  Future<void> _toggleAvailable(bool value) async {
    final vm = context.read<CommunityViewModel>();
    final error = await vm.setAvailable(value);
    if (mounted) {
      showResult(context, error, value ? 'You now appear in search.' : 'You\'re hidden from search.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityViewModel>();
    final p = vm.profile;
    if (p == null) return const SizedBox.shrink();
    _fill(p);
    final bucket = contributionBucket(parseAmount(_max.text));

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _availabilityCard(vm, p),
          const SizedBox(height: 12),
          if (p.exists) ...[_trustCard(p), const SizedBox(height: 12)],
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.exists ? 'Public profile' : 'Create your public profile', style: cText(16, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a display name' : null,
                ),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number', hintText: '07X XXX XXXX'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return RegExp(r'^\+?[0-9 ]{9,16}$').hasMatch(t) ? null : 'Enter a valid phone number';
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _phoneVisible,
                  onChanged: (v) => setState(() => _phoneVisible = v),
                  title: Text('Show my phone number in search', style: cText(14, weight: FontWeight.w600)),
                  subtitle: Text('Off: only your connections and fellow group members see it.',
                      style: cText(12, color: AppColors.onGlassMuted)),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _max,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Maximum I\'m willing to contribute (Rs)',
                    helperText: bucket == null ? 'Others only see a range, never the exact amount.' : 'Others will see: ${kContributionBuckets[bucket]}',
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final a = parseAmount(v!);
                    return a == null || a <= 0 ? 'Enter an amount greater than zero' : null;
                  },
                ),
                const SizedBox(height: 14),
                Text('Investing experience', style: cText(13, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in kExperienceLabels.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _experience == e.key,
                      onSelected: (_) => setState(() => _experience = e.key),
                    ),
                ]),
                const SizedBox(height: 14),
                Text('Interests', style: cText(13, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in kInterestLabels.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _interests.contains(e.key),
                      onSelected: (on) => setState(() => on ? _interests.add(e.key) : _interests.remove(e.key)),
                    ),
                ]),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _district,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'District (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Don\'t show')),
                    for (final d in kSriLankaDistricts) DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (d) => setState(() => _district = d),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bio,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Short bio (optional)'),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : (p.exists ? 'Save profile' : 'Create profile')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Never shown to anyone: your email, expenses, budgets, savings goals, debts, sandbox activity and sign-up answers.',
                  style: cText(12.5, color: AppColors.onGlassMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          const RecordKeepingFooter(),
        ],
      ),
    );
  }

  Widget _availabilityCard(CommunityViewModel vm, MyCommunityProfile p) {
    Widget body;
    if (p.isUnder18) {
      body = Text('Group investments are for users aged 18 and over.', style: cText(12.5, color: AppColors.warning));
    } else if (!p.exists) {
      body = Text('Create your profile below first.', style: cText(12.5, color: AppColors.onGlassMuted));
    } else if (!p.canBeAvailable) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirm your age to turn this on.', style: cText(12.5, color: AppColors.onGlassMuted)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            if (!await confirmAction(context, 'Confirm your age', 'I confirm I am 18 years old or older.', confirm: 'I\'m 18+')) {
              return;
            }
            final error = await vm.confirmAge();
            if (mounted) showResult(context, error, 'Thanks, you can now turn on availability.');
          },
          icon: const Icon(Icons.verified_user_outlined, size: 18),
          label: const Text('I\'m 18 or older'),
        ),
      ]);
    } else {
      body = Text(
        p.availableForGroups
            ? 'People can find you by name and see your contribution range, experience, district and interests.'
            : 'Hidden from search. Your connections and groups keep working.',
        style: cText(12.5, color: AppColors.onGlassMuted, height: 1.4),
      );
    }

    final canToggle = p.exists && p.canBeAvailable && !p.isUnder18;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      gradient: AppGradients.heroCard,
      borderColor: AppColors.glassBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Available for group investments', style: cText(15, weight: FontWeight.w700))),
            Switch(
              value: p.availableForGroups,
              onChanged: canToggle ? _toggleAvailable : null,
            ),
          ]),
          const SizedBox(height: 4),
          body,
          if (p.exists && !p.phoneVerified) ...[
            const SizedBox(height: 8),
            Row(children: [
              const VerifiedChip(false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.requirePhoneVerification
                      ? 'Verify your phone number to appear in search.'
                      : 'Phone verification is coming soon.',
                  style: cText(12, color: AppColors.onGlassFaint),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _trustCard(MyCommunityProfile p) {
    final t = p.trust;
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: cText(17, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: cText(11.5, color: AppColors.onGlassMuted)),
          ]),
        );
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your trust indicators', style: cText(14, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          stat(t.memberSince == null ? '—' : shortDate(t.memberSince!), 'Member since'),
          stat('${t.groupsCompleted}', 'Groups completed'),
          stat(t.seettuOnTimePct == null ? '—' : '${t.seettuOnTimePct}%', 'Seettu on time'),
        ]),
      ]),
    );
  }
}
