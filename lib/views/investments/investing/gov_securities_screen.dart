import 'package:flutter/material.dart';

import '../../../models/investing_models.dart';
import '../../../services/investing_data_service.dart';
import '../../../core/theme/app_theme.dart';
import 'investing_widgets.dart';

class GovSecuritiesScreen extends StatefulWidget {
  const GovSecuritiesScreen({super.key});

  @override
  State<GovSecuritiesScreen> createState() => _GovSecuritiesScreenState();
}

class _GovSecuritiesScreenState extends State<GovSecuritiesScreen> {
  final _service = InvestingDataService();
  late Stream<List<GovSecurityYield>> _stream = _service.watchGovSecurityYields();

  final _faceValue = TextEditingController(text: '100000');
  final _yield = TextEditingController(text: '8.5');
  int _days = 364;

  @override
  void dispose() {
    _faceValue.dispose();
    _yield.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _stream = _service.watchGovSecurityYields());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GovSecurityYield>>(
      stream: _stream,
      initialData: InvestingDataService.govSecurityDirectory,
      builder: (context, snapshot) {
        final yields = [...?snapshot.data]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return InvestPage(
          title: 'Government Securities',
          onRefresh: _refresh,
          children: [
            const InvestIntro(
              icon: Icons.account_balance_rounded,
              headline: 'Treasury Bills & Bonds',
              body:
                  'Lend money to the Government of Sri Lanka. Fully government-guaranteed, which makes them one of the safest places for savings.',
            ),
            _buildYieldsCard(yields),
            _buildBillsVsBonds(),
            _buildCalculator(yields),
            const KnowBeforeCard(items: _knowItems),
            const SourcesCard(sources: _sources),
          ],
        );
      },
    );
  }

  Widget _buildYieldsCard(List<GovSecurityYield> yields) {
    final hasLive = yields.any((y) => y.yieldRate != null);
    final latestAuction = yields.map((y) => y.auctionDate).whereType<DateTime>().fold<DateTime?>(
        null, (m, t) => m == null || t.isAfter(m) ? t : m);

    Widget section(String heading, Iterable<GovSecurityYield> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(heading,
                  style: investText(12, weight: FontWeight.w700, color: InvestColors.green)),
            ),
            for (final y in items)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: InvestColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(y.security, style: investText(14, weight: FontWeight.w600))),
                    if (y.change != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${y.change! >= 0 ? '▲' : '▼'} ${y.change!.abs().toStringAsFixed(2)}',
                          style: investText(12,
                              weight: FontWeight.w600,
                              color: y.change! >= 0 ? InvestColors.gain : InvestColors.red),
                        ),
                      ),
                    Text(
                      y.yieldRate == null ? '—' : '${y.yieldRate!.toStringAsFixed(2)}%',
                      style: investText(15, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        );

    final updated = yields.map((y) => y.updatedAt).whereType<DateTime>().fold<DateTime?>(
        null, (m, t) => m == null || t.isAfter(m) ? t : m);
    final bonds = yields.where((y) => y.kind == 'bond');

    return InvestCard(
      title: "This week's T-bill rates",
      trailing: LiveBadge(
        live: hasLive,
        label: hasLive ? 'Updated ${formatUpdated(updated)}' : 'Awaiting data',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasLive)
            const NoticeStrip(
                "This week's rates haven't been collected yet. Tap below to see them on Bank of Ceylon's site."),
          if (latestAuction != null)
            Text(
              'Week from ${latestAuction.day.toString().padLeft(2, '0')}/'
              '${latestAuction.month.toString().padLeft(2, '0')}/${latestAuction.year}',
              style: investText(12, weight: FontWeight.w600, color: InvestColors.muted),
            ),
          section('Treasury Bills (short term)', yields.where((y) => y.kind == 'bill')),
          if (bonds.isNotEmpty) section('Treasury Bonds (long term)', bonds),
          const SizedBox(height: 10),
          Text(
            "Retail rates published weekly by Bank of Ceylon, collected daily. "
            "For Treasury Bond yields, check CBSL or a primary dealer below.",
            style: investText(11, color: InvestColors.muted),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openExternal(InvestingDataService.tbillSourceUrl),
              style: TextButton.styleFrom(
                  foregroundColor: InvestColors.green, padding: EdgeInsets.zero),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('View on boc.lk',
                  style: investText(13, weight: FontWeight.w700, color: InvestColors.green)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsVsBonds() {
    Widget column(String title, List<String> points) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: InvestColors.tile,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: InvestColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: investText(14, weight: FontWeight.w800, color: InvestColors.green)),
                const SizedBox(height: 6),
                for (final p in points)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $p',
                        style: investText(12, color: InvestColors.muted).copyWith(height: 1.35)),
                  ),
              ],
            ),
          ),
        );

    return InvestCard(
      title: 'Bills vs. Bonds',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            column('T-Bills', [
              '91, 182 or 364 days',
              'Bought at a discount',
              'Get full face value at maturity',
            ]),
            const SizedBox(width: 10),
            column('T-Bonds', [
              '2 to 30 years',
              'Fixed coupon every 6 months',
              'Face value back at maturity',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculator(List<GovSecurityYield> yields) {
    final face = double.tryParse(_faceValue.text) ?? 0;
    final y = double.tryParse(_yield.text) ?? 0;
    final price = face / (1 + y / 100 * _days / 365);
    final profit = face - price;

    final liveForTenure = yields
        .where((g) => g.kind == 'bill' && g.security.startsWith('$_days-day'))
        .firstOrNull
        ?.yieldRate;

    return InvestCard(
      title: 'T-Bill calculator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 91, label: Text('91 days')),
              ButtonSegment(value: 182, label: Text('182 days')),
              ButtonSegment(value: 364, label: Text('364 days')),
            ],
            selected: {_days},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? Colors.white : InvestColors.greenTint),
              foregroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? AppColors.onLight : InvestColors.text),
            ),
            onSelectionChanged: (s) => setState(() {
              _days = s.first;
              final live = yields
                  .where((g) => g.security.startsWith('$_days-day'))
                  .firstOrNull
                  ?.yieldRate;
              if (live != null) _yield.text = live.toStringAsFixed(2);
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CalcField(
                  label: 'Face value', controller: _faceValue, suffix: 'Rs',
                  onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CalcField(
                  label: 'Yield', controller: _yield, suffix: '%',
                  onChanged: (_) => setState(() {})),
            ),
          ]),
          if (liveForTenure != null) ...[
            const SizedBox(height: 4),
            Text('Latest $_days-day yield: ${liveForTenure.toStringAsFixed(2)}%',
                style: investText(12, color: InvestColors.muted)),
          ],
          const SizedBox(height: 12),
          ResultRow('You pay today', formatLkr(price)),
          ResultRow('You receive in $_days days', formatLkr(face)),
          const Divider(color: InvestColors.border),
          ResultRow('Your profit', formatLkr(profit), emphasise: true),
          const SizedBox(height: 8),
          Text('Approximate, before tax and dealer charges.',
              style: investText(11, color: InvestColors.muted)),
        ],
      ),
    );
  }

  static const _knowItems = [
    KnowItem(Icons.verified_outlined, 'No default risk',
        'T-Bills (91, 182, 364 days) and T-Bonds (2 to 30 years) are fully guaranteed by the Government of Sri Lanka.'),
    KnowItem(Icons.sell_outlined, 'T-Bills are sold at a discount',
        'You pay less than face value today and get the full face value (LKR 100 per unit) at maturity. The difference is your return.'),
    KnowItem(Icons.event_repeat_rounded, 'T-Bonds pay coupons',
        'Bonds pay a fixed coupon every six months until maturity, then return the face value.'),
    KnowItem(Icons.swap_horiz_rounded, 'You can sell before maturity',
        'Primary Dealers and commercial banks buy and sell securities before maturity at secondary-market yields.'),
    KnowItem(Icons.trending_down_rounded, 'Yields move opposite to prices',
        'When market interest rates fall, existing bonds become more valuable, and the reverse happens when rates rise.'),
  ];

  static const _sources = [
    SourceLink('CBSL Public Debt Department', 'Weekly auction results, yield curves, primary dealers', 'https://www.cbsl.gov.lk'),
    SourceLink('Bank of Ceylon – T-bill rates', 'Weekly retail Treasury bill rates', InvestingDataService.tbillSourceUrl),
    SourceLink('Ministry of Finance', 'Official press releases on government borrowing', 'https://www.treasury.gov.lk'),
    SourceLink('NSB Fund Management', 'Primary dealer: buy T-bills & bonds', 'https://www.nsbfmc.lk'),
    SourceLink('First Capital', 'Primary dealer: buy T-bills & bonds', 'https://www.firstcapital.lk'),
    SourceLink('CAL', 'Investment house: rates & research', 'https://www.cal.lk'),
  ];
}
