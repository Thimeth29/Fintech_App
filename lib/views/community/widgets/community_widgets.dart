import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/community_models.dart';
import '../../../viewmodels/community_viewmodel.dart';
import '../../../core/theme/app_fonts.dart';

TextStyle cText(double size, {FontWeight weight = FontWeight.w500, Color color = AppColors.onGlass, double? height}) =>
    AppFonts.text(fontSize: size, fontWeight: weight, color: color, height: height);

/// Shows the result of an action: an error, or the success text.
void showResult(BuildContext context, String? error, [String? success]) {
  if (!context.mounted) return;
  final text = error ?? success;
  if (text == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Awaits an action that returns an error message (or null) and shows the
/// outcome if the screen is still there.
Future<void> act(BuildContext context, Future<String?> action, [String? success]) async {
  final error = await action;
  if (context.mounted) showResult(context, error, success);
}

/// Small footer shown under every money-related screen.
class RecordKeepingFooter extends StatelessWidget {
  const RecordKeepingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.onGlassFaint),
          const SizedBox(width: 6),
          Expanded(child: Text(kRecordKeepingNotice, style: cText(12, color: AppColors.onGlassFaint))),
        ],
      ),
    );
  }
}

class CommunityAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const CommunityAvatar({super.key, required this.name, this.size = 44, this.color = AppColors.primary});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.35)!]),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorderStrong),
      ),
      child: Text(_initials, style: cText(size * 0.36, weight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const InfoChip(this.text, {super.key, this.icon, this.color = AppColors.onGlassMuted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.innerFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: cText(11, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class VerifiedChip extends StatelessWidget {
  final bool verified;
  const VerifiedChip(this.verified, {super.key});

  @override
  Widget build(BuildContext context) => verified
      ? const InfoChip('Verified', icon: Icons.verified_rounded, color: AppColors.gain)
      : const InfoChip('Not verified', icon: Icons.help_outline_rounded, color: AppColors.onGlassFaint);
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.accentCyan),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: cText(16, weight: FontWeight.w700)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: cText(13, color: AppColors.onGlassMuted, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: cText(15, weight: FontWeight.w700))),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class PersonCard extends StatelessWidget {
  final PersonResult person;
  final Widget? action;
  final VoidCallback? onTap;
  const PersonCard({super.key, required this.person, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = person;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAvatar(name: p.displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName, style: cText(15, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [kExperienceLabels[p.experience] ?? p.experience, if (p.district != null) p.district!].join(' · '),
                      style: cText(12, color: AppColors.onGlassMuted),
                    ),
                  ],
                ),
              ),
              VerifiedChip(p.phoneVerified),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (p.contributionLabel != null)
                InfoChip('Up to ${p.contributionLabel}', icon: Icons.payments_outlined, color: AppColors.gold),
              for (final i in p.interests) InfoChip(kInterestLabels[i] ?? i),
              if (p.phone != null) InfoChip(p.phone!, icon: Icons.phone_rounded, color: AppColors.accentCyan),
            ],
          ),
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.bio!, style: cText(12.5, color: AppColors.onGlassMuted, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

String groupAmountText(GroupResult g) {
  if (g.isSeettu && g.contribution != null) {
    return '${formatRs(g.contribution!, decimals: 0)} ${g.frequency == 'weekly' ? 'weekly' : 'monthly'}';
  }
  final min = g.minContribution;
  final max = g.maxContribution;
  if (min != null && max != null) return '${formatRs(min, decimals: 0)} – ${formatRs(max, decimals: 0)}';
  if (min != null) return 'From ${formatRs(min, decimals: 0)}';
  return 'Any amount';
}

class GroupCard extends StatelessWidget {
  final GroupResult group;
  final Widget? action;
  final VoidCallback? onTap;
  const GroupCard({super.key, required this.group, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final color = g.isSeettu ? AppColors.gold : AppColors.accentLavender;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                child: Icon(g.isSeettu ? Icons.autorenew_rounded : Icons.groups_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: cText(15, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    Text('${g.isSeettu ? 'Seettu' : 'Investment group'} · led by ${g.leaderName ?? 'a member'}',
                        style: cText(12, color: AppColors.onGlassMuted)),
                  ],
                ),
              ),
              InfoChip(g.isOpen ? 'Open' : 'Closed', color: g.isOpen ? AppColors.gain : AppColors.onGlassFaint),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoChip('${g.memberCount}/${g.maxMembers} members', icon: Icons.people_alt_outlined),
              InfoChip(groupAmountText(g), icon: Icons.payments_outlined, color: AppColors.gold),
              if (g.district != null) InfoChip(g.district!, icon: Icons.place_outlined),
              if (g.leaderExperience != null)
                InfoChip('Leader: ${kExperienceLabels[g.leaderExperience] ?? g.leaderExperience}'),
            ],
          ),
          if (g.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final w in g.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(child: Text(kGroupWarningText[w] ?? w, style: cText(12, color: AppColors.warning))),
                  ],
                ),
              ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Bottom sheet to report a user or a group. Returns after sending.
Future<void> showReportSheet(BuildContext context, CommunityViewModel vm,
    {String? userId, String? groupId, bool scam = false}) async {
  const reasons = {
    'scam': 'Scam or suspicious money request',
    'harassment': 'Harassment or abuse',
    'spam': 'Spam',
    'fake_profile': 'Fake profile',
    'payment_dispute': 'Payment dispute',
    'inappropriate': 'Inappropriate content',
    'other': 'Something else',
  };
  var reason = scam ? 'scam' : 'other';
  final details = TextEditingController();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.deepNavy,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scam ? 'Report suspected scam' : 'Report', style: cText(18, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Reports go to the Mobile SAP team for review. The person isn\'t told who reported them.',
                style: cText(12.5, color: AppColors.onGlassMuted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in reasons.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: reason == e.key,
                    onSelected: (_) => setState(() => reason = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: details,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details (optional)'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send report'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (sent != true || !context.mounted) return;
  final error = await vm.report(
    targetType: userId != null ? 'user' : 'group',
    reason: reason,
    details: details.text.trim().isEmpty ? null : details.text.trim(),
    userId: userId,
    groupId: groupId,
    isScam: scam || reason == 'scam',
  );
  if (context.mounted) showResult(context, error, 'Thanks. Your report was sent.');
}

Future<bool> confirmAction(BuildContext context, String title, String body, {String confirm = 'Confirm'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
      ],
    ),
  );
  return ok == true;
}
