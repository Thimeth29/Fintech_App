import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;
    final primaryColor = Color(int.parse(p.color.replaceAll('#', '0xFF')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 2),
        Text(
          p.role,
          style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Balance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total balance',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 10.5,
                  letterSpacing: 0.1,
                  color: AppTheme.goldLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'LKR ${p.balance}',
                style: GoogleFonts.newsreader(
                  color: AppTheme.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBalanceItem(
                    label: 'Saved this month',
                    value: p.change,
                    valueColor: p.change.startsWith('-') ? const Color(0xFFE2A37A) : const Color(0xFF9FD6AE),
                  ),
                  _buildBalanceItem(
                    label: 'Set aside',
                    value: 'LKR ${p.saved}',
                    valueColor: AppTheme.white,
                  ),
                  _buildBalanceItem(
                    label: 'Spent',
                    value: 'LKR ${p.spent}',
                    valueColor: AppTheme.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Predict strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.paperAlt,
            border: Border.all(color: AppTheme.sage, style: BorderStyle.solid), // dashed in web, solid here is cleaner
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.ibmPlexSans(color: AppTheme.text, fontSize: 11.5, height: 1.4),
                    children: _parseBoldTags(p.predict),
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Section label
        Text(
          'RECENT ACTIVITY',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 10.5,
            letterSpacing: 0.08,
            color: AppTheme.sage,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Transactions list Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: p.txns.map((t) => _buildTransactionItem(t)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceItem({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(color: AppTheme.white.withAlpha(179), fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(dynamic t) {
    final isPos = t.amount.startsWith('+');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.paperAlt,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(t.emoji, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text)),
                  Text(t.category, style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 10.5)),
                ],
              )
            ],
          ),
          Text(
            t.amount,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isPos ? AppTheme.ink : AppTheme.clay,
            ),
          )
        ],
      ),
    );
  }

  // Simple parser to extract <b> tags
  List<TextSpan> _parseBoldTags(String text) {
    final List<TextSpan> spans = [];
    final regExp = RegExp(r'<b>(.*?)</b>');
    int lastIndex = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }
}
