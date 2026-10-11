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
import '../widgets/sandbox_widgets.dart';

class FdPractice extends StatefulWidget {
  const FdPractice({super.key});

  @override
  State<FdPractice> createState() => _FdPracticeState();
}

class _FdPracticeState extends State<FdPractice> {
  String _bank = kFdFallbackRates.keys.elementAt(2);
  int _months = 12;
  bool _monthly = false;
  bool _autoRenew = false;
  bool _realReturn = false;
  bool _compare = false;
  final _amount = TextEditingController(text: '25,000');
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _open(SandboxViewModel vm) async {
    final amount = parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() => _error = null);
    final res = await vm.openFd(bank: _bank, months: _months, amount: amount, monthly: _monthly, autoRenew: _autoRenew);
    if (!mounted) return;
    if (res.ok) {
      sandboxSnack(context, 'FD opened: ${formatRs(amount)} at $_bank for $_months months');
    } else {
      setState(() => _error = res.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SandboxViewModel>();
    const m = SandboxModule.fd;
    final amount = parseAmount(_amount.text) ?? 0;
    final rate = vm.fdRate(_bank, _months);
    final effRate = _monthly ? FdMath.monthlyPayoutRate(rate) : rate;
    final interest = FdMath.totalInterest(amount, rate, _months, monthly: _monthly);
    final annualAfterTax = effRate * (1 - kInterestWhtRate);
    final real = FdMath.realReturn(annualAfterTax, kAssumedInflation);
    final open = vm.openPositions(m)..sort((a, b) => a.maturitySimDate.compareTo(b.maturitySimDate));
    final news = vm.recentNews(m, days: 365).take(2).toList();

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
        const SectionTitle('Today\'s rates (% p.a., interest at maturity)'),
        GlassCard(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: sbText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted),
              dataTextStyle: sbText(13),
              columnSpacing: 18,
              horizontalMargin: 8,
              showCheckboxColumn: false,
              columns: [
                const DataColumn(label: Text('Bank')),
                for (final t in kFdTenures) DataColumn(label: Text('${t}m'), numeric: true),
              ],
              rows: [
                for (final bank in kFdFallbackRates.keys)
                  DataRow(
                    selected: bank == _bank,
                    onSelectChanged: (_) => setState(() => _bank = bank),
                    cells: [
                      DataCell(
                          Text(bank, style: sbText(13, weight: bank == _bank ? FontWeight.w800 : FontWeight.w500))),
                      for (final t in kFdTenures)
                        DataCell(
                          Text(vm.fdRate(bank, t).toStringAsFixed(2),
                              style: sbText(13,
                                  weight: bank == _bank && t == _months ? FontWeight.w800 : FontWeight.w500,
                                  color: bank == _bank && t == _months ? AppColors.accentCyan : AppColors.onGlass)),
                          onTap: () => setState(() {
                            _bank = bank;
                            _months = t;
                          }),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Rates start from the latest published rates and move with the simulated economy.',
            style: sbText(12, color: AppColors.onGlassFaint)),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Open an FD at $_bank', style: sbText(16, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (Rs)'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in kFdTenures)
                    ChoiceChip(
                      label: Text('$t month${t == 1 ? '' : 's'}'),
                      selected: _months == t,
                      onSelected: (_) => setState(() => _months = t),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Interest at maturity')),
                  ButtonSegment(value: true, label: Text('Monthly interest')),
                ],
                selected: {_monthly},
                onSelectionChanged: (v) => setState(() => _monthly = v.first),
              ),
              // ListTiles need a Material ancestor for their ink.
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoRenew,
                  onChanged: (v) => setState(() => _autoRenew = v),
                  title: Text('Auto-renew at maturity', style: sbText(14, weight: FontWeight.w600)),
                  subtitle: Text(
                      _monthly
                          ? 'Renews the deposit for another term.'
                          : 'Interest is added to the deposit — compounding.',
                      style: sbText(12, color: AppColors.onGlassMuted)),
                ),
              ),
              TileGrid(children: [
                StatTile(
                    label: 'Rate',
                    value: '${effRate.toStringAsFixed(2)}%',
                    sub: _monthly ? '${kFdMonthlyRateDiscount}pp lower for monthly' : 'paid at maturity'),
                StatTile(label: 'Interest after ${(kInterestWhtRate * 100).round()}% tax', value: formatRs(interest)),
                if (_monthly)
                  StatTile(label: 'Each month', value: formatRs(FdMath.monthlyPayment(amount, effRate)))
                else
                  StatTile(label: 'At maturity', value: formatRs(FdMath.maturityAmount(amount, rate, _months))),
                StatTile(
                  label: _realReturn
                      ? 'Real return (vs ${kAssumedInflation.toStringAsFixed(0)}% inflation)'
                      : 'After-tax rate',
                  value: _realReturn ? signedPct(real) : '${annualAfterTax.toStringAsFixed(2)}%',
                  valueColor: _realReturn ? pnlColor(real) : null,
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _realReturn = !_realReturn),
                    icon: Icon(_realReturn ? Icons.toggle_on : Icons.toggle_off_outlined),
                    label: const Text('Compare with inflation'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _compare = !_compare);
                      if (_compare) vm.markChallengeEvent('fd_compare_payout');
                    },
                    icon: const Icon(Icons.compare_arrows_rounded),
                    label: const Text('Monthly vs maturity'),
                  ),
                ],
              ),
              if (_compare) _PayoutCompare(amount: amount, rate: rate, months: _months),
              if (_realReturn) _GrowthBars(amount: amount, rate: effRate, months: _months),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: sbText(13, weight: FontWeight.w600, color: AppColors.loss)),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.busy ? null : () => _open(vm),
                  child: Text('Open FD for ${formatRs(amount)}'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FastForwardBar(module: m, onForward: (d) => runFastForward(context, m, d)),
        const SizedBox(height: 18),
        SectionTitle('Your FDs (${open.length})'),
        if (open.isEmpty)
          Text('No open FDs. Tip: three FDs maturing at different times make a ladder.',
              style: sbText(13, color: AppColors.onGlassMuted)),
        for (final p in open) ...[
          _FdTile(p: p, vm: vm),
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
}

class _PayoutCompare extends StatelessWidget {
  final double amount;
  final double rate;
  final int months;
  const _PayoutCompare({required this.amount, required this.rate, required this.months});

  @override
  Widget build(BuildContext context) {
    final atMaturity = FdMath.totalInterest(amount, rate, months, monthly: false);
    final monthly = FdMath.totalInterest(amount, rate, months, monthly: true);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.innerFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Over $months months, after tax:', style: sbText(13, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('At maturity (${rate.toStringAsFixed(2)}%): ${formatRs(atMaturity)} in one payment',
              style: sbText(13, color: AppColors.onGlassMuted)),
          Text(
            'Monthly (${FdMath.monthlyPayoutRate(rate).toStringAsFixed(2)}%): ${formatRs(monthly)} in $months payments',
            style: sbText(13, color: AppColors.onGlassMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly gives regular income but ${formatRs(atMaturity - monthly)} less in total.',
            style: sbText(13, weight: FontWeight.w600, color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}

/// Stacked bars: principal, interest after tax, and inflation's bite.
class _GrowthBars extends StatelessWidget {
  final double amount;
  final double rate;
  final int months;
  const _GrowthBars({required this.amount, required this.rate, required this.months});

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final interest = FdMath.afterTax(FdMath.simpleInterest(amount, rate, months));
    final inflationLoss = (amount + interest) * (1 - 1 / (1 + kAssumedInflation / 100 * months / 12));
    final total = amount + interest;
    Widget bar(String label, List<(double, Color)> parts) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(label, style: sbText(12, color: AppColors.onGlassMuted))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 800),
                    builder: (_, t, __) => Row(
                      children: [
                        for (final (v, c) in parts)
                          Expanded(
                              flex: (v / total * 1000 * t).round().clamp(1, 1000),
                              child: Container(height: 14, color: c)),
                        Expanded(flex: ((1 - t) * 1000).round().clamp(0, 1000) + 1, child: const SizedBox(height: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar('In rupees', [(amount, AppColors.primary), (interest, AppColors.gain)]),
          bar('Buying power',
              [(amount + interest - inflationLoss, AppColors.primary), (inflationLoss, AppColors.loss)]),
          Text(
              'Blue: your deposit · green: interest after tax · red: lost to ${kAssumedInflation.toStringAsFixed(0)}% inflation',
              style: sbText(11, color: AppColors.onGlassFaint)),
        ],
      ),
    );
  }
}

class _FdTile extends StatelessWidget {
  final SandboxPosition p;
  final SandboxViewModel vm;
  const _FdTile({required this.p, required this.vm});

  @override
  Widget build(BuildContext context) {
    final now = vm.simDate(p.module);
    final total = daysBetween(p.startSimDate, p.maturitySimDate);
    final done = daysBetween(p.startSimDate, now).clamp(0, total);
    return GlassCard(
      onTap: () => showPositionSheet(context, p),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${p.label} · ${p.tenureMonths}m', style: sbText(15, weight: FontWeight.w700))),
              Text(formatRs(vm.positionValue(p)), style: sbText(14, weight: FontWeight.w800)),
            ],
          ),
          Text(
            '${formatRs(p.principal)} at ${p.rate.toStringAsFixed(2)}% · ${p.payoutType == 'monthly' ? 'monthly' : 'at maturity'}'
            '${p.autoRenew ? ' · auto-renew' : ''} · matures ${shortDate(p.maturitySimDate)}',
            style: sbText(12, color: AppColors.onGlassMuted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: total == 0 ? 1 : done / total, minHeight: 6, color: AppColors.accentCyan),
          ),
        ],
      ),
    );
  }
}
