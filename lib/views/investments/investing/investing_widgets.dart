// Shared building blocks for the Investing Options pages, so FD, Gold,
// CSE and Government Securities all look and read the same way.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_backgrounds.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/top_nav_bar.dart';
import '../../../core/theme/app_fonts.dart';

/// Investing-page palette — thin aliases over [AppColors] so the glass
/// theme is defined in one place. The old field names are kept so the
/// four investing screens didn't need renaming; [green] is now the cyan
/// foreground accent (links, emphasised figures, icons).
class InvestColors {
  static const green = AppColors.accentCyan;
  static const greenTint = AppColors.glassFillStrong;
  static const text = AppColors.onGlass;
  static const muted = AppColors.onGlassMuted;
  static const border = AppColors.glassBorder;
  static const background = AppColors.deepNavy;
  static const red = AppColors.loss;
  static const gain = AppColors.gain;
  static const amber = AppColors.warning;
  static const amberTint = AppColors.warningTint;
  static const liveTint = AppColors.accentCyanTint;
  static const tile = AppColors.innerFill;
}

TextStyle investText(double size,
        {FontWeight weight = FontWeight.w500, Color color = InvestColors.text}) =>
    AppFonts.text(fontSize: size, fontWeight: weight, color: color);

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String formatLkr(double value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return parts.length > 1 ? 'Rs $whole.${parts[1]}' : 'Rs $whole';
}

String formatUpdated(DateTime? t) {
  if (t == null) return 'not yet updated';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
}

/// Page shell: app bar, pull-to-refresh, centred column.
class InvestPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  /// True only for Investing options, the page the Investments tab opens.
  final bool isSectionRoot;

  const InvestPage({
    super.key,
    required this.title,
    required this.children,
    this.onRefresh,
    this.isSectionRoot = false,
  });

  @override
  Widget build(BuildContext context) {
    // Single column of cards; a little wider on tablets/desktops.
    final maxWidth = MediaQuery.sizeOf(context).width >= 600 ? 720.0 : 520.0;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children) ...[child, const SizedBox(height: 16)],
              ],
            ),
          ),
        ),
      ],
    );

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: TopNavBar(
          current: AppSection.investments,
          title: title,
          showBackButton: true,
          isSectionRoot: isSectionRoot,
        ),
        bottomNavigationBar:
            AppBottomNav(current: AppSection.investments, isSectionRoot: isSectionRoot),
        body: SafeArea(
          child: onRefresh == null
              ? list
              : RefreshIndicator(
                  color: AppColors.onLight,
                  backgroundColor: Colors.white,
                  onRefresh: onRefresh!,
                  child: list),
        ),
      ),
    );
  }
}

/// Glass card with an optional heading and trailing widget.
class InvestCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const InvestCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                    child: Text(title!,
                        style: investText(16, weight: FontWeight.w700))),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Blue hero banner at the top of each page.
class InvestIntro extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String body;

  const InvestIntro(
      {super.key, required this.icon, required this.headline, required this.body});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppGradients.heroCard,
      borderColor: AppColors.glassBorderStrong,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: investText(16,
                        weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(body,
                    style: investText(13, color: AppColors.onGlassMuted)
                        .copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Live · 2 min ago" / "Offline" pill.
class LiveBadge extends StatelessWidget {
  final bool live;
  final String label;

  const LiveBadge({super.key, required this.live, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.accentCyan : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: live ? InvestColors.liveTint : InvestColors.amberTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: investText(11, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Small figure tile, used in 2-column grids.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;

  const StatTile(
      {super.key, required this.label, required this.value, this.sub, this.subColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InvestColors.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InvestColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: investText(11, weight: FontWeight.w600, color: InvestColors.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: investText(17, weight: FontWeight.w800)),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: investText(11,
                    weight: FontWeight.w600, color: subColor ?? InvestColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// Two tiles per row.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;
  const StatGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(
                    child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class KnowItem {
  final IconData icon;
  final String title;
  final String body;
  const KnowItem(this.icon, this.title, this.body);
}

/// "What you should know before investing" — collapsible rows so the page
/// stays short and scannable.
class KnowBeforeCard extends StatelessWidget {
  final List<KnowItem> items;
  const KnowBeforeCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return InvestCard(
      title: 'Know before you invest',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (final item in items)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 40, bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                iconColor: InvestColors.green,
                collapsedIconColor: InvestColors.muted,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: InvestColors.tile, shape: BoxShape.circle),
                  child: Icon(item.icon, size: 16, color: InvestColors.green),
                ),
                title: Text(item.title, style: investText(14, weight: FontWeight.w600)),
                children: [
                  Text(item.body,
                      style: investText(13, color: InvestColors.muted)
                          .copyWith(height: 1.45)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SourceLink {
  final String label;
  final String description;
  final String url;
  const SourceLink(this.label, this.description, this.url);
}

/// "Where to check official data" — tappable links that open in the browser.
class SourcesCard extends StatelessWidget {
  final List<SourceLink> sources;
  const SourcesCard({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    return InvestCard(
      title: 'Official sources',
      child: Column(
        children: [
          for (var i = 0; i < sources.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: InvestColors.border),
            InkWell(
              onTap: () => openExternal(sources[i].url),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sources[i].label,
                            style: investText(14,
                                weight: FontWeight.w700, color: InvestColors.green)),
                        const SizedBox(height: 2),
                        Text(sources[i].description,
                            style: investText(12, color: InvestColors.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded,
                      size: 18, color: InvestColors.muted),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Amber info strip for caveats ("estimate only", "data not loaded yet").
class NoticeStrip extends StatelessWidget {
  final String text;
  final IconData icon;
  const NoticeStrip(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InvestColors.amberTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: InvestColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: investText(12, color: InvestColors.amber)
                    .copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Labelled numeric input used by the calculators.
class CalcField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffix;
  final ValueChanged<String> onChanged;

  const CalcField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: investText(15, weight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: investText(13, color: InvestColors.muted),
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: AppColors.glassFillStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: InvestColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: InvestColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: InvestColors.green, width: 1.5),
        ),
      ),
    );
  }
}

/// Label / value row for calculator results.
class ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  const ResultRow(this.label, this.value, {super.key, this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: investText(13,
                      color: emphasise ? InvestColors.text : InvestColors.muted,
                      weight: emphasise ? FontWeight.w700 : FontWeight.w500))),
          Text(value,
              style: investText(emphasise ? 16 : 14,
                  weight: emphasise ? FontWeight.w800 : FontWeight.w600,
                  color: emphasise ? InvestColors.green : InvestColors.text)),
        ],
      ),
    );
  }
}
