import 'package:flutter/material.dart';

import '../../../models/investing_models.dart';
import '../../../services/investing_data_service.dart';
import '../../../core/theme/app_theme.dart';
import 'investing_widgets.dart';

enum _FdFilter { all, banks, financeCompanies }

enum _Tenure { m3, m6, m12, m24 }

extension on _Tenure {
  String get label => switch (this) {
        _Tenure.m3 => '3M',
        _Tenure.m6 => '6M',
        _Tenure.m12 => '12M',
        _Tenure.m24 => '24M',
      };

  double? of(FdRate r) => switch (this) {
        _Tenure.m3 => r.rate3m,
        _Tenure.m6 => r.rate6m,
        _Tenure.m12 => r.rate12m,
        _Tenure.m24 => r.rate24m,
      };
}

class FdInvestmentsScreen extends StatefulWidget {
  const FdInvestmentsScreen({super.key});

  @override
  State<FdInvestmentsScreen> createState() => _FdInvestmentsScreenState();
}

class _FdInvestmentsScreenState extends State<FdInvestmentsScreen> {
  final _service = InvestingDataService();
  late Stream<List<FdRate>> _stream = _service.watchFdRates();

  _FdFilter _filter = _FdFilter.all;
  _Tenure _sortBy = _Tenure.m12;

  final _amount = TextEditingController(text: '100000');
  final _rate = TextEditingController(text: '9.0');
  final _months = TextEditingController(text: '12');
  final _tax = TextEditingController(text: '10');

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _months.dispose();
    _tax.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _stream = _service.watchFdRates());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FdRate>>(
      stream: _stream,
      initialData: InvestingDataService.fdDirectory,
      builder: (context, snapshot) {
        final all = snapshot.data ?? InvestingDataService.fdDirectory;
        return InvestPage(
          title: 'FD Investments',
          onRefresh: _refresh,
          children: [
            const InvestIntro(
              icon: Icons.savings_rounded,
              headline: 'Fixed Deposits',
              body:
                  'Lock money with a bank or finance company for a fixed term and earn a guaranteed interest rate.',
            ),
            _buildHighlights(all),
            _buildRatesTable(all),
            _buildCalculator(),
            _buildInsuranceCard(),
            const KnowBeforeCard(items: _knowItems),
            const SourcesCard(sources: _sources),
          ],
        );
      },
    );
  }

  // ---------- Highlights ----------

  Widget _buildHighlights(List<FdRate> all) {
    final with12m = all.where((r) => r.rate12m != null).toList()
      ..sort((a, b) => b.rate12m!.compareTo(a.rate12m!));
    final bestBank = with12m.where((r) => r.type.isBank).firstOrNull;
    final bestLfc = with12m.where((r) => !r.type.isBank).firstOrNull;
    final avg = with12m.isEmpty
        ? null
        : with12m.map((r) => r.rate12m!).reduce((a, b) => a + b) / with12m.length;

    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}%';

    return InvestCard(
      title: '12-month snapshot',
      child: StatGrid(tiles: [
        StatTile(label: 'Best bank rate', value: pct(bestBank?.rate12m), sub: bestBank?.institution),
        StatTile(label: 'Best finance co.', value: pct(bestLfc?.rate12m), sub: bestLfc?.institution),
        StatTile(label: 'Market average', value: pct(avg), sub: '${with12m.length} institutions'),
        const StatTile(label: 'Insured up to', value: 'Rs 1,100,000', sub: 'per depositor (SLDIS)'),
      ]),
    );
  }

  // ---------- Live rates table ----------

  Widget _buildRatesTable(List<FdRate> all) {
    final rows = all.where((r) => switch (_filter) {
          _FdFilter.all => true,
          _FdFilter.banks => r.type.isBank,
          _FdFilter.financeCompanies => !r.type.isBank,
        }).toList()
      ..sort((a, b) {
        final ra = _sortBy.of(a), rb = _sortBy.of(b);
        if (ra == null && rb == null) return a.institution.compareTo(b.institution);
        if (ra == null) return 1;
        if (rb == null) return -1;
        return rb.compareTo(ra);
      });

    final best = {
      for (final t in _Tenure.values)
        t: rows.map(t.of).whereType<double>().fold<double?>(
            null, (m, v) => m == null || v > m ? v : m),
    };

    final updated = all.map((r) => r.updatedAt).whereType<DateTime>().fold<DateTime?>(
        null, (m, t) => m == null || t.isAfter(m) ? t : m);
    final hasLive = all.any((r) => r.hasRates);

    return InvestCard(
      title: 'FD rates today',
      trailing: LiveBadge(
        live: hasLive,
        label: hasLive ? 'Updated ${formatUpdated(updated)}' : 'Awaiting data',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Annual % · interest paid at maturity · tap a column to sort',
              style: investText(12, color: InvestColors.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('All', _FdFilter.all),
              _filterChip('Banks', _FdFilter.banks),
              _filterChip('Finance cos.', _FdFilter.financeCompanies),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasLive) ...[
            const NoticeStrip(
                "Today's rates haven't come through from the bank websites yet. Tap any institution to open its official rate page."),
            const SizedBox(height: 12),
          ],
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: InvestColors.greenTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text('Institution',
                        style: investText(12, weight: FontWeight.w700, color: InvestColors.green))),
                for (final t in _Tenure.values)
                  InkWell(
                    onTap: () => setState(() => _sortBy = t),
                    child: SizedBox(
                      width: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(t.label,
                              style: investText(12,
                                  weight: FontWeight.w700, color: InvestColors.green)),
                          if (_sortBy == t)
                            const Icon(Icons.arrow_downward_rounded,
                                size: 12, color: InvestColors.green),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final r in rows)
            InkWell(
              onTap: () => _showInstitution(r),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: InvestColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.institution,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: investText(13, weight: FontWeight.w600)),
                          Text(r.type.shortLabel,
                              style: investText(10,
                                  weight: FontWeight.w600, color: InvestColors.muted)),
                        ],
                      ),
                    ),
                    for (final t in _Tenure.values)
                      SizedBox(
                        width: 50,
                        child: Text(
                          t.of(r)?.toStringAsFixed(2) ?? '—',
                          textAlign: TextAlign.end,
                          style: investText(13,
                              weight: t.of(r) != null && t.of(r) == best[t]
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: t.of(r) != null && t.of(r) == best[t]
                                  ? InvestColors.green
                                  : InvestColors.text),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Collected every morning from each institution\'s official website. '
            'Rows showing "—" are institutions whose sites can\'t be read automatically: tap them to see their rates. '
            'Always confirm with the bank before you deposit.',
            style: investText(11, color: InvestColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _FdFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label,
          style: investText(12,
              weight: FontWeight.w600,
              color: selected ? AppColors.onLight : InvestColors.text)),
      selected: selected,
      showCheckmark: false,
      selectedColor: Colors.white,
      backgroundColor: AppColors.glassFill,
      side: BorderSide(color: selected ? Colors.white : InvestColors.border),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  void _showInstitution(FdRate r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepNavy,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(r.institution, style: investText(20, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                '${r.type.longLabel} · ${r.sldisMember ? 'SLDIS insured' : 'Not SLDIS insured'}',
                style: investText(13, color: InvestColors.muted),
              ),
              const SizedBox(height: 16),
              StatGrid(tiles: [
                for (final entry in {
                  '1 month': r.rate1m,
                  '3 months': r.rate3m,
                  '6 months': r.rate6m,
                  '12 months': r.rate12m,
                  '24 months': r.rate24m,
                  '60 months': r.rate60m,
                }.entries)
                  StatTile(
                    label: entry.key,
                    value: entry.value == null ? '—' : '${entry.value!.toStringAsFixed(2)}%',
                  ),
              ]),
              const SizedBox(height: 12),
              Text('Last updated: ${formatUpdated(r.updatedAt)}',
                  style: investText(12, color: InvestColors.muted)),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => openExternal(r.sourceUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.onLight,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Open official rates page',
                      style: investText(14, weight: FontWeight.w700, color: AppColors.onLight)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Calculator ----------

  Widget _buildCalculator() {
    final amount = double.tryParse(_amount.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;
    final months = double.tryParse(_months.text) ?? 0;
    final tax = double.tryParse(_tax.text) ?? 0;

    final interest = amount * rate / 100 * months / 12;
    final taxAmount = interest * tax / 100;
    final maturity = amount + interest - taxAmount;

    void recalc(String _) => setState(() {});

    return InvestCard(
      title: 'FD calculator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: CalcField(label: 'Amount', controller: _amount, suffix: 'Rs', onChanged: recalc)),
            const SizedBox(width: 10),
            Expanded(child: CalcField(label: 'Rate', controller: _rate, suffix: '%', onChanged: recalc)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: CalcField(label: 'Term', controller: _months, suffix: 'months', onChanged: recalc)),
            const SizedBox(width: 10),
            Expanded(child: CalcField(label: 'Tax withheld', controller: _tax, suffix: '%', onChanged: recalc)),
          ]),
          const SizedBox(height: 14),
          ResultRow('Interest earned', formatLkr(interest)),
          ResultRow('Tax withheld (AIT/WHT)', '- ${formatLkr(taxAmount)}'),
          const Divider(color: InvestColors.border),
          ResultRow('You receive at maturity', formatLkr(maturity), emphasise: true),
          const SizedBox(height: 8),
          Text('Simple interest paid at maturity. Check ird.gov.lk for the current withholding rate.',
              style: investText(11, color: InvestColors.muted)),
        ],
      ),
    );
  }

  // ---------- Deposit insurance ----------

  Widget _buildInsuranceCard() {
    return InvestCard(
      title: 'Is my money protected?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Only deposit with a CBSL-licensed bank (LCB/LSB) or finance company (LFC). '
            'Members of the Sri Lanka Deposit Insurance Scheme (SLDIS) are covered up to:',
            style: investText(13, color: InvestColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: InvestColors.greenTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text('Rs 1,100,000',
                    style: investText(22, weight: FontWeight.w800, color: InvestColors.green)),
                Text('per depositor, per institution',
                    style: investText(12, color: InvestColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tip: if you have more than this, spread it across several institutions.',
            style: investText(12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static const _knowItems = [
    KnowItem(Icons.verified_user_outlined, 'Regulatory approval',
        'Check the institution is a Licensed Commercial Bank (LCB) or Licensed Finance Company (LFC) regulated by the Central Bank of Sri Lanka. The full list is on cbsl.gov.lk.'),
    KnowItem(Icons.shield_outlined, 'Deposit insurance (SLDIS)',
        'The Sri Lanka Deposit Insurance Scheme covers deposits up to LKR 1,100,000 per depositor per institution.'),
    KnowItem(Icons.percent_rounded, 'Effective vs. nominal rate',
        'Monthly payouts and payouts at maturity have different values. The Annual Effective Rate (AER) includes compounding, so use it to compare offers fairly.'),
    KnowItem(Icons.receipt_long_outlined, 'Tax on interest (AIT/WHT)',
        'Interest may have Advance Income Tax deducted at source, depending on current Inland Revenue Department thresholds. See ird.gov.lk.'),
    KnowItem(Icons.lock_clock_outlined, 'Breaking an FD early',
        'If you withdraw before maturity, banks usually cut the agreed rate by 1%–3%. Only lock away money you won\'t need for the term.'),
  ];

  static const _sources = [
    SourceLink('Central Bank of Sri Lanka', 'Licensed banks, finance companies & SLDIS members', 'https://www.cbsl.gov.lk'),
    SourceLink('Inland Revenue Department', 'Tax schedules and AIT/WHT rules', 'https://www.ird.gov.lk'),
    SourceLink('Bank of Ceylon – Rates', 'Example of an official bank rate page', 'https://www.boc.lk/rates-tariff'),
    SourceLink('Commercial Bank – Rates', 'Example of an official bank rate page', 'https://www.combank.lk/rates-tariff'),
  ];
}
