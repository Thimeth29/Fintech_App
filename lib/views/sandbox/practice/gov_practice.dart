import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sandbox/sandbox_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/sandbox_models.dart';
import '../../../services/sandbox/sim_math.dart';
import '../../../viewmodels/sandbox_viewmodel.dart';
import '../widgets/detail_sheets.dart';
import '../widgets/fast_forward_sheet.dart';
import '../widgets/price_chart.dart';
import '../widgets/sandbox_widgets.dart';

class GovPractice extends StatefulWidget {
  const GovPractice({super.key});

  @override
  State<GovPractice> createState() => _GovPracticeState();
}

class _GovPracticeState extends State<GovPractice> {
  bool _bond = false;
  int _billDays = 364;
  int _bondYears = 5;
  final _face = TextEditingController(text: '50,000');
  String? _error;
  bool _compare = false;

  @override
  void dispose() {
    _face.dispose();
    super.dispose();
  }

  Future<void> _buy(SandboxViewModel vm) async {
    final face = parseAmount(_face.text);
    if (face == null || face <= 0) {
      setState(() => _error = 'Enter a face value greater than zero.');
      return;
    }
    setState(() => _error = null);
    final res = _bond ? await vm.buyTbond(years: _bondYears, face: face) : await vm.buyTbill(days: _billDays, face: face);
    if (!mounted) return;
    if (res.ok) {
      sandboxSnack(context, _bond ? 'Bought a $_bondYears-year T-bond' : 'Bought a $_billDays-day T-bill');
    } else {
      setState(() => _error = res.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    const m = SandboxModule.govSecurities;
    final face = parseAmount(_face.text) ?? 0;
    final open = vm.openPositions(m)..sort((a, b) => a.maturitySimDate.compareTo(b.maturitySimDate));
    final day = vm.simDay(m);
    final yieldHistory = [for (var d = day - 180; d <= day; d += 3) vm.tbondYield(5, day: d)];
    final news = vm.recentNews(m, days: 365).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Cash: ${formatRs(vm.balance(m))}', style: sbText(15, weight: FontWeight.w700))),
            const SimulatedLabel(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Market yields today', style: sbText(16, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              TileGrid(minTileWidth: 120, children: [
                for (final d in kTbillTenures) StatTile(label: '$d-day T-bill', value: '${vm.tbillYield(d).toStringAsFixed(2)}%'),
                for (final y in kTbondTenureYears)
                  StatTile(label: '$y-year T-bond', value: '${vm.tbondYield(y).toStringAsFixed(2)}%'),
              ]),
              const SizedBox(height: 12),
              Text('5-year yield, last 180 sim-days', style: sbText(12, color: AppColors.onGlassMuted)),
              SandboxLineChart(values: yieldHistory, color: AppColors.accentLavender, height: 110),
              Text('When this line rises, existing bonds lose value. When it falls, they gain.',
                  style: sbText(12, color: AppColors.onGlassFaint)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('T-bill')),
                  ButtonSegment(value: true, label: Text('T-bond')),
                ],
                selected: {_bond},
                onSelectionChanged: (v) => setState(() {
                  _bond = v.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bond
                    ? [
                        for (final y in kTbondTenureYears)
                          ChoiceChip(label: Text('$y years'), selected: _bondYears == y, onSelected: (_) => setState(() => _bondYears = y)),
                      ]
                    : [
                        for (final d in kTbillTenures)
                          ChoiceChip(label: Text('$d days'), selected: _billDays == d, onSelected: (_) => setState(() => _billDays = d)),
                      ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _face,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Face value (Rs)'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              _bond ? _bondPreview(vm, face) : _billPreview(vm, face),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: sbText(13, weight: FontWeight.w600, color: AppColors.loss)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.busy ? null : () => _buy(vm),
                  child: Text(_bond ? 'Buy T-bond' : 'Buy T-bill'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('1-year T-bill vs 12-month FD', style: sbText(16, weight: FontWeight.w700))),
                  TextButton(
                    onPressed: () {
                      setState(() => _compare = !_compare);
                      if (_compare) vm.markChallengeEvent('gov_compare');
                    },
                    child: Text(_compare ? 'Hide' : 'Compare'),
                  ),
                ],
              ),
              if (_compare) _Compare(vm: vm),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FastForwardBar(module: m, onForward: (d) => runFastForward(context, m, d)),
        const SizedBox(height: 18),
        SectionTitle('Your securities (${open.length})'),
        if (open.isEmpty) Text('Nothing yet.', style: sbText(13, color: AppColors.onGlassMuted)),
        for (final p in open) ...[
          _PositionTile(p: p, vm: vm),
          const SizedBox(height: 8),
        ],
        if (news.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionTitle('Rate news'),
          for (final n in news) ...[
            NewsEventCard(event: n, dateLabel: shortDate(addDays(vm.wallets[m]!.startDate, n.day))),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _billPreview(SandboxViewModel vm, double face) {
    final y = vm.tbillYield(_billDays);
    final cost = GovMath.tbillPrice(face, y, _billDays);
    final net = GovMath.tbillMaturityAmount(face, cost);
    return _Preview(lines: [
      ('Pay now', formatRs(cost)),
      ('Receive on ${shortDate(addDays(vm.simDate(SandboxModule.govSecurities), _billDays))}', formatRs(face)),
      ('After ${(kGovSecWhtRate * 100).round()}% tax on the ${formatRs(face - cost)} discount', formatRs(net)),
    ], note: 'You buy below face value; the discount is your return. No payments in between.');
  }

  Widget _bondPreview(SandboxViewModel vm, double face) {
    final y = vm.tbondYield(_bondYears);
    final coupon = (y * 4).roundToDouble() / 4;
    return _Preview(lines: [
      ('Pay now (at face value)', formatRs(face)),
      ('Coupon rate', '${coupon.toStringAsFixed(2)}% a year'),
      ('Every 6 months, after tax', formatRs(GovMath.couponPayment(face, coupon))),
      ('At maturity in $_bondYears years', formatRs(face)),
    ], note: 'Sell early and you get the market price, which falls if yields rise above your coupon.');
  }
}

class _Preview extends StatelessWidget {
  final List<(String, String)> lines;
  final String note;
  const _Preview({required this.lines, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.innerFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (l, v) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(l, style: sbText(13, color: AppColors.onGlassMuted))),
                  Text(v, style: sbText(13, weight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(note, style: sbText(12, color: AppColors.onGlassFaint)),
        ],
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  final SandboxViewModel vm;
  const _Compare({required this.vm});

  @override
  Widget build(BuildContext context) {
    const face = 100000.0;
    final y = vm.tbillYield(364);
    final cost = GovMath.tbillPrice(face, y, 364);
    final billGain = GovMath.tbillMaturityAmount(face, cost) - cost;
    final billPct = billGain / cost * 100 * 365 / 364;
    final banks = kFdFallbackRates.keys.toList()..sort((a, b) => vm.fdRate(b, 12).compareTo(vm.fdRate(a, 12)));
    String fdLine(String bank) {
      final r = vm.fdRate(bank, 12);
      return '$bank 12-month FD at ${r.toStringAsFixed(2)}%: ${(r * (1 - kInterestWhtRate)).toStringAsFixed(2)}% after tax';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('364-day T-bill at ${y.toStringAsFixed(2)}% yield: ${billPct.toStringAsFixed(2)}% after tax on what you pay',
            style: sbText(13, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(fdLine(banks.first), style: sbText(13, color: AppColors.onGlassMuted)),
        Text(fdLine(banks.last), style: sbText(13, color: AppColors.onGlassMuted)),
        const SizedBox(height: 6),
        Text(
          'The T-bill lends to the government (lowest risk). Higher FD rates usually come from finance companies, '
          'which carry more risk. FDs are only covered by deposit insurance up to a limit.',
          style: sbText(12, color: AppColors.onGlassFaint, height: 1.35),
        ),
      ],
    );
  }
}

class _PositionTile extends StatelessWidget {
  final SandboxPosition p;
  final SandboxViewModel vm;
  const _PositionTile({required this.p, required this.vm});

  @override
  Widget build(BuildContext context) {
    final value = vm.positionValue(p);
    final vsCost = value - p.cost;
    return GlassCard(
      onTap: () => showPositionSheet(context, p),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(p.isTbill ? Icons.receipt_long_outlined : Icons.account_balance_outlined, color: AppColors.accentLavender),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.label, style: sbText(15, weight: FontWeight.w700)),
                Text(
                  'Face ${formatRs(p.principal)} · ${p.isTbond ? '${p.payoutsCount} coupon(s) paid · ' : ''}'
                  'matures ${shortDate(p.maturitySimDate)}',
                  style: sbText(12, color: AppColors.onGlassMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatRs(value), style: sbText(14, weight: FontWeight.w800)),
              Text(signedRs(vsCost), style: sbText(12, weight: FontWeight.w700, color: pnlColor(vsCost))),
            ],
          ),
        ],
      ),
    );
  }
}
