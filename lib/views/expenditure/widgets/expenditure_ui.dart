// Shared building blocks for the expenditure screens, so Plan, Budgets,
// Recurring, Goals and Debts all look and behave the same way.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/expense_priority.dart';
import '../../../core/theme/app_fonts.dart';

TextStyle expText(double size,
        {FontWeight weight = FontWeight.w500, Color color = AppColors.onGlass, double? height}) =>
    AppFonts.text(fontSize: size, fontWeight: weight, color: color, height: height);

IconData categoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant_rounded;
    case 'Transport':
      return Icons.directions_bus_rounded;
    case 'Housing':
      return Icons.home_rounded;
    case 'Utilities':
      return Icons.bolt_rounded;
    case 'Entertainment':
      return Icons.movie_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Readable-on-glass colour for each priority.
Color priorityColor(String priority) {
  switch (priority) {
    case ExpensePriority.essential:
      return AppColors.accentCyan;
    case ExpensePriority.important:
      return AppColors.accentLavender;
    default:
      return AppColors.gold;
  }
}

/// Section heading that sits directly on the background.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: AppFonts.text(
                    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.onGlass, shadows: kTitleShadow)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small coloured label ("Essential", "Overdue", "On track").
class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const TagChip(this.label, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: expText(11, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar; turns warning/danger coloured past 80%/100%.
class RatioBar extends StatelessWidget {
  final double ratio;
  final Color? color;
  final double height;
  const RatioBar(this.ratio, {super.key, this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (ratio >= 1 ? AppColors.loss : (ratio >= 0.8 ? AppColors.warning : AppColors.accentCyan));
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          backgroundColor: AppColors.innerFillSelected,
          valueColor: AlwaysStoppedAnimation(c),
        ),
      ),
    );
  }
}

/// Pill-shaped toggle chip used for filters and segmented choices.
class ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onLight : AppColors.onGlass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : AppColors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.white : AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 5)],
              Text(label, style: expText(12.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card shown instead of data when nobody is logged in (demo mode).
class LoggedOutCard extends StatelessWidget {
  final String message;
  const LoggedOutCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.accentCyan),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: expText(14, height: 1.4))),
        ],
      ),
    );
  }
}

/// Muted centred message for empty lists.
class EmptyNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyNote(this.text, {super.key, this.icon = Icons.inbox_rounded});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(icon, color: AppColors.onGlassMuted, size: 30),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: expText(13.5, color: AppColors.onGlassMuted, height: 1.4)),
        ],
      ),
    );
  }
}

/// Glass list row: leading icon in a circle, title/subtitle, trailing.
class GlassRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;
  const GlassRow({
    super.key,
    required this.icon,
    this.iconColor = AppColors.accentCyan,
    required this.title,
    this.subtitle,
    this.trailing,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(color: AppColors.innerFillSelected, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: expText(15, weight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: expText(12, color: AppColors.onGlassMuted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog helpers
// ---------------------------------------------------------------------------

void showExpSnack(BuildContext context, String message,
    {bool isError = false, SnackBarAction? action, Duration duration = const Duration(seconds: 4)}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message, style: AppFonts.text(color: Colors.white)),
    backgroundColor: isError ? AppColors.lossStrong : AppColors.deepNavy,
    action: action,
    duration: duration,
  ));
}

Future<bool> confirmAction(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Delete', bool destructive = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: expText(14, color: AppColors.onGlassMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AppColors.lossStrong : Colors.white,
            foregroundColor: destructive ? Colors.white : AppColors.onLight,
            minimumSize: const Size(64, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Date picker limited to [first]..[last] (no future dates by default).
Future<DateTime?> pickDate(BuildContext context,
    {required DateTime initial, DateTime? first, DateTime? last}) {
  final today = dateOnly(DateTime.now());
  final lastDate = last ?? today;
  final firstDate = first ?? DateTime(today.year - 5);
  var init = initial;
  if (init.isAfter(lastDate)) init = lastDate;
  if (init.isBefore(firstDate)) init = firstDate;
  return showDatePicker(context: context, initialDate: init, firstDate: firstDate, lastDate: lastDate);
}

/// Labelled amount input (LKR).
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  const AmountField({super.key, required this.controller, this.label = 'Amount (LKR)', this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: expText(15),
      decoration: InputDecoration(labelText: label, prefixText: 'Rs '),
    );
  }
}

/// Tappable read-only field that opens a date picker.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const DateField({super.key, required this.label, required this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null && onClear != null
              ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear)
              : const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(value == null ? 'Not set' : shortDate(value!),
            style: expText(15, color: value == null ? AppColors.onGlassMuted : AppColors.onGlass)),
      ),
    );
  }
}

/// Keeps a dialog's content scrollable and reasonably narrow on desktop.
class DialogBody extends StatelessWidget {
  final List<Widget> children;
  const DialogBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in children) ...[c, const SizedBox(height: 12)],
        ]),
      ),
    );
  }
}

/// Primary (white pill) + cancel actions for form dialogs.
List<Widget> dialogActions(BuildContext context, {required String saveLabel, required VoidCallback onSave}) => [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: expText(14, color: AppColors.onGlassMuted)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(64, 44)),
        onPressed: onSave,
        child: Text(saveLabel),
      ),
    ];
