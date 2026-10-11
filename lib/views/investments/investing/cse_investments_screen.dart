import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/investing_models.dart';
import '../../../services/investing_data_service.dart';
import 'investing_widgets.dart';

enum _MoversTab { gainers, losers, active }

class CseInvestmentsScreen extends StatefulWidget {
  const CseInvestmentsScreen({super.key});

  @override
  State<CseInvestmentsScreen> createState() => _CseInvestmentsScreenState();
}

class _CseInvestmentsScreenState extends State<CseInvestmentsScreen> {
  /// Faster while the market trades, slower once it's closed.
  static const _refreshOpen = Duration(seconds: 30);
  static const _refreshClosed = Duration(minutes: 5);

  final _service = InvestingDataService();
  Timer? _timer;

  CseSnapshot? _snapshot;
  bool _loading = true;
  bool _lastFailed = false;
  _MoversTab _tab = _MoversTab.gainers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    final snapshot = await _service.fetchCseSnapshot();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _lastFailed = snapshot == null;
      if (snapshot != null) _snapshot = snapshot;
    });
    _timer = Timer(_marketOpen ? _refreshOpen : _refreshClosed, _load);
  }

  /// CSE's own status when we have it; otherwise trading hours
  /// (9:30 am – 2:30 pm Sri Lanka time, Mon–Fri, holidays not accounted for).
  bool get _marketOpen {
    final status = _snapshot?.marketStatus;
    if (status != null) return status.toLowerCase().contains('open');
    final sl = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    if (sl.weekday > DateTime.friday) return false;
    final minutes = sl.hour * 60 + sl.minute;
    return minutes >= 9 * 60 + 30 && minutes < 14 * 60 + 30;
  }

  String _compact(double? v) {
    if (v == null) return '—';
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return InvestPage(
      title: 'CSE Investments',
      onRefresh: _load,
      children: [
        const InvestIntro(
          icon: Icons.candlestick_chart_rounded,
          headline: 'Colombo Stock Exchange',
          body:
              'Own a share of listed Sri Lankan companies. Higher growth potential, but prices can go down as well as up.',
        ),
        _buildIndicesCard(),
        _buildMoversCard(),
        _buildHowToStart(),
        _buildCostsCard(),
        const KnowBeforeCard(items: _knowItems),
        const SourcesCard(sources: _sources),
      ],
    );
  }

  Widget _buildIndicesCard() {
    final snap = _snapshot;
    final live = snap != null;
    return InvestCard(
      title: 'Market today',
      trailing: LiveBadge(
        live: live && !_lastFailed,
        label: _loading && !live
            ? 'Loading…'
            : (live ? 'Live · ${formatUpdated(snap.fetchedAt)}' : 'Offline'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10,
                  color: _marketOpen ? InvestColors.green : InvestColors.muted),
              const SizedBox(width: 6),
              Text(
                _marketOpen
                    ? 'Market open · closes 2:30 pm'
                    : 'Market closed · trades 9:30 am – 2:30 pm, Mon–Fri',
                style: investText(12, weight: FontWeight.w600, color: InvestColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading && !live)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: InvestColors.green)),
            )
          else if (!live)
            const NoticeStrip("Couldn't reach the Colombo Stock Exchange. Pull down to try again.")
          else ...[
            StatGrid(tiles: [
              for (final idx in snap.indices)
                StatTile(
                  label: idx.name,
                  value: idx.value?.toStringAsFixed(2) ?? '—',
                  sub: '${idx.isUp ? '▲' : '▼'} ${(idx.change ?? 0).abs().toStringAsFixed(2)} '
                      '(${(idx.changePercentage ?? 0).toStringAsFixed(2)}%)',
                  subColor: idx.isUp ? InvestColors.green : InvestColors.red,
                ),
              for (final idx in snap.indices)
                if (idx.high != null && idx.low != null)
                  StatTile(
                    label: '${idx.name} day range',
                    value: '${idx.low!.toStringAsFixed(0)} – ${idx.high!.toStringAsFixed(0)}',
                  ),
              if (snap.turnover != null)
                StatTile(label: 'Turnover', value: 'Rs ${_compact(snap.turnover)}'),
              if (snap.trades != null)
                StatTile(
                  label: 'Trades',
                  value: _compact(snap.trades!.toDouble()),
                  sub: '${_compact(snap.shareVolume)} shares',
                ),
            ]),
            if (_lastFailed) ...[
              const SizedBox(height: 8),
              const NoticeStrip('Last refresh failed. Showing the most recent figures.'),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            'ASPI tracks every listed company. S&P SL20 tracks the 20 largest, most-traded ones.',
            style: investText(12, color: InvestColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMoversCard() {
    final snap = _snapshot;
    final list = switch (_tab) {
      _MoversTab.gainers => snap?.gainers ?? const <CseQuote>[],
      _MoversTab.losers => snap?.losers ?? const <CseQuote>[],
      _MoversTab.active => snap?.mostActive ?? const <CseQuote>[],
    };
    return InvestCard(
      title: "Today's top movers",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_MoversTab>(
            segments: [
              const ButtonSegment(value: _MoversTab.gainers, label: Text('Gainers')),
              const ButtonSegment(value: _MoversTab.losers, label: Text('Losers')),
              if (snap?.mostActive.isNotEmpty ?? false)
                const ButtonSegment(value: _MoversTab.active, label: Text('Most active')),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? InvestColors.green : Colors.white),
              foregroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? Colors.white : InvestColors.text),
            ),
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _loading ? 'Loading…' : 'No data right now.',
                textAlign: TextAlign.center,
                style: investText(13, color: InvestColors.muted),
              ),
            )
          else
            for (final q in list.take(8))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: InvestColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.symbol, style: investText(13, weight: FontWeight.w700)),
                          if (q.name.isNotEmpty)
                            Text(q.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: investText(11, color: InvestColors.muted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs ${q.price?.toStringAsFixed(2) ?? '—'}',
                            style: investText(13, weight: FontWeight.w600)),
                        if (_tab == _MoversTab.active && q.turnover != null)
                          Text('Rs ${_compact(q.turnover)} traded',
                              style: investText(10, color: InvestColors.muted)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${q.isUp ? '+' : ''}${(q.changePercentage ?? 0).toStringAsFixed(2)}%',
                        textAlign: TextAlign.end,
                        style: investText(13,
                            weight: FontWeight.w700,
                            color: q.isUp ? InvestColors.green : InvestColors.red),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildHowToStart() {
    const steps = [
      ('Pick a stockbroker', 'Choose an SEC-licensed broker firm (list on sec.gov.lk).'),
      ('Open a CDS account', 'The broker opens your Central Depository Systems account. Bring your NIC and bank details.'),
      ('Fund & place orders', 'Deposit money with the broker, then buy or sell through them or their app.'),
      ('Track & review', 'Follow prices and company announcements on cse.lk or the CSE mobile app.'),
    ];
    return InvestCard(
      title: 'How to start',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: InvestColors.green, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: investText(12, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: investText(14, weight: FontWeight.w700)),
                        Text(steps[i].$2,
                            style: investText(12, color: InvestColors.muted)
                                .copyWith(height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCostsCard() {
    return const InvestCard(
      title: 'Costs & tax',
      child: StatGrid(tiles: [
        StatTile(label: 'Trading fee', value: '% of trade', sub: 'CSE + SEC + broker + CDS, per buy & sell'),
        StatTile(label: 'Minimum', value: '1 share', sub: 'No minimum lot size'),
        StatTile(label: 'Dividends', value: 'Taxed', sub: 'Withheld at source'),
        StatTile(label: 'Capital gains', value: 'Generally exempt', sub: 'On listed shares'),
      ]),
    );
  }

  static const _knowItems = [
    KnowItem(Icons.show_chart_rounded, 'Market indices',
        'Watch the ASPI (All Share Price Index) for the overall market and the S&P SL20 for large, liquid companies.'),
    KnowItem(Icons.badge_outlined, 'You need a CDS account',
        'To trade directly you need a Central Depository Systems (CDS) account, opened through an SEC-licensed stockbroker.'),
    KnowItem(Icons.payments_outlined, 'Transaction costs',
        'Every trade is charged a fixed percentage of its value, covering CSE, SEC, broker and CDS fees. Frequent trading adds up.'),
    KnowItem(Icons.analytics_outlined, 'Check the fundamentals',
        'Read the company\'s financial statements: Earnings Per Share (EPS), Price-to-Earnings (P/E), dividend yield and Net Asset Value per share.'),
    KnowItem(Icons.account_balance_wallet_outlined, 'Dividends vs. capital gains',
        'Dividends are taxed at source. Capital gains on listed shares are generally exempt under current law.'),
  ];

  static const _sources = [
    SourceLink('Colombo Stock Exchange', 'Live prices, announcements & financial reports', 'https://www.cse.lk'),
    SourceLink('SEC Sri Lanka', 'Licensed stockbrokers & regulatory updates', 'https://www.sec.gov.lk'),
  ];
}
