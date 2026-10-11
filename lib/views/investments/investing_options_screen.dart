import 'package:flutter/material.dart';

import 'investing/cse_investments_screen.dart';
import 'investing/fd_investments_screen.dart';
import 'investing/gold_investments_screen.dart';
import 'investing/gov_securities_screen.dart';
import 'investing/investing_widgets.dart';
import 'investing/news_carousel.dart';

class InvestingOptionsScreen extends StatelessWidget {
  const InvestingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InvestPage(
      title: 'Investing options',
      children: [
        Text('Choose where to grow your money',
            style: investText(14, color: InvestColors.muted)),
        const NewsCarousel(),
        _OptionBlock(
          icon: Icons.savings_rounded,
          title: 'FD Investments',
          subtitle: 'Compare fixed deposit rates from every bank',
          risk: 'Low risk',
          entry: 'From Rs 1,000',
          builder: (_) => const FdInvestmentsScreen(),
        ),
        _OptionBlock(
          icon: Icons.diamond_outlined,
          title: 'Gold Investments',
          subtitle: 'Live 22K & 24K prices per sovereign',
          risk: 'Price swings',
          entry: 'From 1 gram',
          builder: (_) => const GoldInvestmentsScreen(),
        ),
        _OptionBlock(
          icon: Icons.candlestick_chart_rounded,
          title: 'CSE Investments',
          subtitle: 'Live ASPI, S&P SL20 and top movers',
          risk: 'Higher risk',
          entry: 'From 1 share',
          builder: (_) => const CseInvestmentsScreen(),
        ),
        _OptionBlock(
          icon: Icons.account_balance_rounded,
          title: 'Government Securities',
          subtitle: "This week's Treasury bill rates",
          risk: 'Lowest risk',
          entry: 'From Rs 10,000',
          builder: (_) => const GovSecuritiesScreen(),
        ),
        const _ComparisonCard(),
      ],
    );
  }
}

class _OptionBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String risk;
  final String entry;
  final WidgetBuilder builder;

  const _OptionBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.risk,
    required this.entry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text,
              style: investText(11, weight: FontWeight.w600, color: InvestColors.muted)),
        );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: InvestColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: InvestColors.greenTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: InvestColors.green, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: investText(16, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: investText(12, color: InvestColors.muted)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: [chip(risk), chip(entry)]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: InvestColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  static const _columns = ['FD', 'Gold', 'CSE', 'Gov. Sec.'];
  static const _rows = [
    ('Main risk', ['Credit / Inflation', 'Price swings', 'Market loss', 'Inflation / Rates']),
    ('Liquidity', ['Low (exit penalty)', 'High', 'Moderate–High', 'High (secondary mkt)']),
    ('Regulator', ['CBSL', 'CBSL / Customs', 'SEC', 'CBSL']),
    ('Start with', ['Rs 1,000+', '1 g / 1 sovereign', '1 share', 'Rs 10,000+']),
  ];

  @override
  Widget build(BuildContext context) {
    return InvestCard(
      title: 'Quick comparison',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(104),
          columnWidths: const {0: FixedColumnWidth(84)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: InvestColors.greenTint,
                borderRadius: BorderRadius.circular(10),
              ),
              children: [
                const SizedBox(),
                for (final c in _columns)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Text(c,
                        style: investText(12, weight: FontWeight.w700, color: InvestColors.green)),
                  ),
              ],
            ),
            for (final row in _rows)
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: InvestColors.border)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Text(row.$1, style: investText(12, weight: FontWeight.w700)),
                  ),
                  for (final cell in row.$2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      child: Text(cell, style: investText(12, color: InvestColors.muted)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
