import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/investing_models.dart';
import '../../../services/investing_data_service.dart';
import 'investing_widgets.dart';

class GoldInvestmentsScreen extends StatefulWidget {
  const GoldInvestmentsScreen({super.key});

  @override
  State<GoldInvestmentsScreen> createState() => _GoldInvestmentsScreenState();
}

class _GoldInvestmentsScreenState extends State<GoldInvestmentsScreen> {
  static const _refreshEvery = Duration(seconds: 60);

  final _service = InvestingDataService();
  final _grams = TextEditingController(text: '8');
  Timer? _timer;

  GoldQuote? _quote;
  bool _loading = true;
  bool _failed = false;
  DateTime? _fetchedAt;
  bool _is24k = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _grams.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final quote = await _service.fetchGoldQuote();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = quote == null;
      if (quote != null) {
        _quote = quote;
        _fetchedAt = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InvestPage(
      title: 'Gold Investments',
      onRefresh: _load,
      children: [
        const InvestIntro(
          icon: Icons.diamond_outlined,
          headline: 'Gold',
          body:
              'A popular way to protect savings from inflation and a falling rupee. Prices move with global markets every day.',
        ),
        _buildPriceCard(),
        _buildMarketInputs(),
        _buildCalculator(),
        _buildPurityCard(),
        const KnowBeforeCard(items: _knowItems),
        const SourcesCard(sources: _sources),
      ],
    );
  }

  Widget _buildPriceCard() {
    final q = _quote;
    return InvestCard(
      title: 'Gold price today',
      trailing: LiveBadge(
        live: q != null && !_failed,
        label: _loading
            ? 'Loading…'
            : (q == null ? 'Offline' : 'Live · ${formatUpdated(_fetchedAt)}'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading && q == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: InvestColors.green)),
            )
          else if (q == null)
            const NoticeStrip("Couldn't reach the live gold feed. Pull down to try again.")
          else ...[
            StatGrid(tiles: [
              StatTile(label: '22K · 1 sovereign (8g)', value: formatLkr(q.lkrPerSovereign22k), sub: 'Jewellery grade'),
              StatTile(label: '24K · 1 sovereign (8g)', value: formatLkr(q.lkrPerSovereign24k), sub: 'Bullion / coins'),
              StatTile(label: '22K · per gram', value: formatLkr(q.lkrPerGram22k)),
              StatTile(label: '24K · per gram', value: formatLkr(q.lkrPerGram24k)),
            ]),
            const SizedBox(height: 12),
            if (_failed) ...[
              const NoticeStrip('Last refresh failed. Showing the most recent prices.'),
              const SizedBox(height: 8),
            ],
            const NoticeStrip(
                'Estimate from the international spot price × USD/LKR. Sea Street and jeweller prices are usually higher because of import levies and dealer margins.'),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketInputs() {
    final q = _quote;
    return InvestCard(
      title: 'What drives the price',
      child: StatGrid(tiles: [
        StatTile(
          label: 'Spot gold (XAU/USD)',
          value: q == null ? '—' : '\$${q.spotUsdPerOunce.toStringAsFixed(2)}',
          sub: 'per troy ounce · ${formatUpdated(q?.spotUpdatedAt)}',
        ),
        StatTile(
          label: 'USD / LKR',
          value: q == null ? '—' : 'Rs ${q.usdLkr.toStringAsFixed(2)}',
          sub: 'market rate · ${formatUpdated(q?.fxUpdatedAt)}',
        ),
      ]),
    );
  }

  Widget _buildCalculator() {
    final q = _quote;
    final grams = double.tryParse(_grams.text) ?? 0;
    final perGram = q == null ? null : (_is24k ? q.lkrPerGram24k : q.lkrPerGram22k);

    return InvestCard(
      title: 'What is my gold worth?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('22K')),
              ButtonSegment(value: true, label: Text('24K')),
            ],
            selected: {_is24k},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? InvestColors.green : Colors.white),
              foregroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? Colors.white : InvestColors.text),
            ),
            onSelectionChanged: (s) => setState(() => _is24k = s.first),
          ),
          const SizedBox(height: 12),
          CalcField(
            label: 'Weight',
            controller: _grams,
            suffix: 'grams',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text('${(grams / GoldQuote.gramsPerSovereign).toStringAsFixed(2)} sovereigns',
              style: investText(12, color: InvestColors.muted)),
          const SizedBox(height: 10),
          ResultRow('Market value (estimate)',
              perGram == null ? '—' : formatLkr(grams * perGram),
              emphasise: true),
          ResultRow('If sold as jewellery (−5% to −15%)',
              perGram == null
                  ? '—'
                  : '${formatLkr(grams * perGram * 0.85)} – ${formatLkr(grams * perGram * 0.95)}'),
        ],
      ),
    );
  }

  Widget _buildPurityCard() {
    Widget row(String karat, String purity, String use) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 48, child: Text(karat, style: investText(14, weight: FontWeight.w800, color: InvestColors.green))),
              SizedBox(width: 70, child: Text(purity, style: investText(13, weight: FontWeight.w600))),
              Expanded(child: Text(use, style: investText(13, color: InvestColors.muted))),
            ],
          ),
        );

    return InvestCard(
      title: 'Purity at a glance',
      child: Column(
        children: [
          row('24K', '99.9%', 'Bullion bars and coins'),
          row('22K', '91.6%', 'Most Sri Lankan jewellery'),
          row('18K', '75.0%', 'Stone-set / fashion jewellery'),
        ],
      ),
    );
  }

  static const _knowItems = [
    KnowItem(Icons.workspace_premium_outlined, 'Purity & hallmarks',
        '24K is 99.9% pure bullion; 22K is 91.6% (jewellery grade). Always ask for a hallmark or certificate.'),
    KnowItem(Icons.account_balance_outlined, 'Pawn value vs. market value',
        'Banks lend against gold using a CBSL-regulated advance rate per sovereign (8 g), which is usually below the retail market price.'),
    KnowItem(Icons.public_rounded, 'Local premium & import levies',
        'Local prices follow the international spot price (USD/oz) and the CBSL exchange rate, plus import tariffs and jeweller margins.'),
    KnowItem(Icons.lock_outline_rounded, 'Storage & insurance',
        'Physical gold has holding costs and theft risk unless kept in a bank locker.'),
    KnowItem(Icons.content_cut_rounded, 'Making charges & wastage',
        'Jewellery carries 5%–15% making charges (Gashthu) that you don\'t get back when you sell. Coins and bars hold their value better.'),
  ];

  static const _sources = [
    SourceLink('CBSL exchange rates', 'Official daily LKR/USD rates', 'https://www.cbsl.gov.lk'),
    SourceLink('World Gold Council', 'International gold prices & research', 'https://www.gold.org'),
    SourceLink('Vogue Jewellers', 'Daily local 22K/24K price', 'https://www.voguejewellers.lk'),
    SourceLink('Raja Jewellers', 'Daily local 22K/24K price', 'https://www.rajajewellers.com'),
  ];
}
