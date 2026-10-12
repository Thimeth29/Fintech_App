import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/debt_model.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/debts_viewmodel.dart';
import 'widgets/expenditure_ui.dart';
import '../../core/theme/app_fonts.dart';

/// Money lent ("They owe me") and borrowed ("I owe"). None of this counts
/// as spending — the original purchase already did.
class DebtsScreen extends StatelessWidget {
  final DebtsViewModel? viewModel;
  const DebtsScreen({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    const body = _DebtsBody();
    return viewModel != null
        ? ChangeNotifierProvider.value(value: viewModel!, child: body)
        : ChangeNotifierProvider(create: (_) => DebtsViewModel()..load(userId ?? ''), child: body);
  }
}

class _DebtsBody extends StatefulWidget {
  const _DebtsBody();

  @override
  State<_DebtsBody> createState() => _DebtsBodyState();
}

class _DebtsBodyState extends State<_DebtsBody> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _add(DebtsViewModel vm) async {
    final debt = await showDialog<Debt>(
      context: context,
      builder: (_) => _DebtForm(
        userId: AuthService().currentUser!.id,
        direction: _tabs.index == 0 ? Debt.lent : Debt.borrowed,
      ),
    );
    if (debt == null || !mounted) return;
    final ok = await vm.addDebt(debt);
    if (mounted) showExpSnack(context, ok ? 'Saved' : (vm.errorMessage ?? 'Could not save.'), isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
          current: AppSection.expenses, title: 'Debts & Loans', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.expenses, isSectionRoot: false),
      floatingActionButton: Consumer<DebtsViewModel>(
        builder: (context, vm, _) => !vm.isLoggedIn
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.onLight,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add_rounded),
                label: Text('Add', style: AppFonts.text(fontWeight: FontWeight.w700)),
                onPressed: () => _add(vm),
              ),
      ),
      body: Consumer<DebtsViewModel>(builder: (context, vm, _) {
        if (!vm.isLoggedIn) {
          return const Padding(
              padding: EdgeInsets.all(20), child: LoggedOutCard('Log in to track money you lent or borrowed.'));
        }
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: GlassCard(
              padding: const EdgeInsets.all(4),
              borderRadius: 28,
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.onLight,
                unselectedLabelColor: AppColors.onGlass,
                labelStyle: AppFonts.text(fontWeight: FontWeight.w700),
                tabs: const [Tab(text: 'They owe me'), Tab(text: 'I owe')],
              ),
            ),
          ),
          if (vm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(vm.errorMessage!, style: expText(13, color: AppColors.loss)),
            ),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _DebtList(vm: vm, debts: vm.lent, total: vm.owedToMe, lent: true),
              _DebtList(vm: vm, debts: vm.borrowed, total: vm.owedByMe, lent: false),
            ]),
          ),
        ]);
      }),
    );
  }
}

class _DebtList extends StatelessWidget {
  final DebtsViewModel vm;
  final List<Debt> debts;
  final double total;
  final bool lent;
  const _DebtList({required this.vm, required this.debts, required this.total, required this.lent});

  @override
  Widget build(BuildContext context) {
    final open = debts.where((d) => d.isOpen).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
    final settled = debts.where((d) => !d.isOpen).toList();
    final today = vm.now();
    final overdue = open.where((d) => d.isOverdue(today)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 96),
      children: [
        GlassCard(
          gradient: AppGradients.heroCard,
          borderColor: AppColors.glassBorderStrong,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lent ? 'OWED TO YOU' : 'YOU OWE', style: expText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted)),
            const SizedBox(height: 6),
            Text(formatRs(total), style: expText(28, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${open.length} open${overdue > 0 ? ' · $overdue overdue' : ''}',
                style: expText(13, color: overdue > 0 ? AppColors.loss : AppColors.onGlassMuted)),
          ]),
        ),
        const SizedBox(height: 14),
        if (open.isEmpty)
          EmptyNote(
              lent ? 'Nobody owes you anything right now.' : "You don't owe anyone right now.",
              icon: Icons.handshake_outlined)
        else
          for (final d in open) ...[_DebtCard(vm: vm, debt: d), const SizedBox(height: 10)],
        if (settled.isNotEmpty) ...[
          const SectionTitle('Settled'),
          for (final d in settled) ...[_DebtCard(vm: vm, debt: d), const SizedBox(height: 10)],
        ],
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  final DebtsViewModel vm;
  final Debt debt;
  const _DebtCard({required this.vm, required this.debt});

  @override
  Widget build(BuildContext context) {
    final d = debt;
    final today = vm.now();
    final ratio = d.principalAmount <= 0 ? 0.0 : d.paidAmount / d.principalAmount;
    return GlassRow(
      icon: d.isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
      iconColor: d.isLent ? AppColors.gain : AppColors.warning,
      title: d.personName,
      subtitle: d.dueDate == null ? 'No due date' : 'Due ${shortDate(d.dueDate!)}',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ChangeNotifierProvider.value(value: vm, child: _DebtSheet(debtId: d.id!)),
      ),
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatRs(d.outstanding), style: expText(15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (!d.isOpen)
          const TagChip('Settled', color: AppColors.gain, icon: Icons.check_rounded)
        else if (d.isOverdue(today))
          const TagChip('Overdue', color: AppColors.loss)
        else if (d.isDueWithin(today, 7))
          const TagChip('Due soon', color: AppColors.warning),
      ]),
      footer: d.payments.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RatioBar(ratio, color: AppColors.gain, height: 6),
              const SizedBox(height: 4),
              Text('${formatRs(d.paidAmount)} of ${formatRs(d.principalAmount)} repaid',
                  style: expText(11.5, color: AppColors.onGlassMuted)),
            ]),
    );
  }
}

class _DebtSheet extends StatefulWidget {
  final String debtId;
  const _DebtSheet({required this.debtId});

  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  final _amount = TextEditingController();
  DateTime _paidOn = dateOnly(DateTime.now());
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pay(DebtsViewModel vm, Debt d) async {
    final v = parseAmount(_amount.text);
    if (v == null) return setState(() => _error = 'Enter an amount.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await vm.recordPayment(d, amount: v, on: _paidOn);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return setState(() => _error = vm.errorMessage);
    _amount.clear();
    final now = vm.debts.firstWhere((x) => x.id == d.id, orElse: () => d);
    showExpSnack(context, now.isOpen ? 'Payment recorded' : 'Fully repaid — marked settled 🎉');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtsViewModel>(builder: (context, vm, _) {
      final d = vm.debts.where((x) => x.id == widget.debtId).firstOrNull;
      if (d == null) return const SizedBox.shrink();
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            Text(d.personName, style: expText(20, weight: FontWeight.w700)),
            Text(d.isLent ? 'They owe you' : 'You owe them', style: expText(13, color: AppColors.onGlassMuted)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _stat('Outstanding', formatRs(d.outstanding))),
              Expanded(child: _stat('Lent / borrowed', formatRs(d.principalAmount))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _stat('Started', shortDate(d.startDate))),
              Expanded(child: _stat('Due', d.dueDate == null ? 'No due date' : shortDate(d.dueDate!))),
            ]),
            if (d.note != null && d.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(d.note!, style: expText(13, color: AppColors.onGlassMuted)),
            ],
            if (d.isOpen) ...[
              const SectionTitle('Record a payment'),
              AmountField(controller: _amount, label: 'Amount repaid (max ${formatRs(d.outstanding)})'),
              const SizedBox(height: 10),
              DateField(
                label: 'Paid on',
                value: _paidOn,
                onTap: () async {
                  final p = await pickDate(context, initial: _paidOn, first: d.startDate);
                  if (p != null) setState(() => _paidOn = p);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: expText(13, color: AppColors.loss)),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _pay(vm, d),
                    child: const Text('Record payment'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            _amount.text = d.outstanding.toStringAsFixed(2);
                            _pay(vm, d);
                          },
                    child: const Text('Repay in full'),
                  ),
                ),
              ]),
            ],
            const SectionTitle('Payment history'),
            if (d.payments.isEmpty)
              Text('No payments yet.', style: expText(13, color: AppColors.onGlassMuted))
            else
              for (final p in d.payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined, color: AppColors.gain),
                  title: Text(formatRs(p.amount), style: expText(15, weight: FontWeight.w700)),
                  subtitle: Text(shortDate(p.paidOn), style: expText(12, color: AppColors.onGlassMuted)),
                  trailing: IconButton(
                    tooltip: 'Delete payment',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.onGlassMuted),
                    onPressed: () async {
                      if (await confirmAction(context,
                          title: 'Delete this payment?', message: 'The outstanding balance goes back up.')) {
                        await vm.deletePayment(d, p);
                      }
                    },
                  ),
                ),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(
                onPressed: () => vm.setSettled(d, d.isOpen),
                icon: Icon(d.isOpen ? Icons.check_circle_outline_rounded : Icons.undo_rounded),
                label: Text(d.isOpen ? 'Mark settled' : 'Reopen'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.loss),
                onPressed: () async {
                  if (await confirmAction(context,
                      title: 'Delete this record?', message: 'Its payment history will be deleted too.')) {
                    await vm.deleteDebt(d);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ]),
          ],
        ),
      );
    });
  }

  Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: expText(12, color: AppColors.onGlassMuted)),
        const SizedBox(height: 2),
        Text(value, style: expText(15, weight: FontWeight.w700)),
      ]);
}

class _DebtForm extends StatefulWidget {
  final String userId;
  final String direction;
  const _DebtForm({required this.userId, required this.direction});

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  late String _direction = widget.direction;
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _start = dateOnly(DateTime.now());
  DateTime? _due;
  String? _error;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final person = _person.text.trim();
    final amount = parseAmount(_amount.text);
    if (person.isEmpty) return setState(() => _error = 'Who is it with?');
    if (amount == null || amount <= 0) return setState(() => _error = 'Enter an amount greater than zero.');
    if (_due != null && _due!.isBefore(_start)) return setState(() => _error = 'Due date is before the start date.');
    Navigator.pop(
      context,
      Debt(
        userId: widget.userId,
        direction: _direction,
        personName: person,
        principalAmount: amount,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        startDate: _start,
        dueDate: _due,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    return AlertDialog(
      title: const Text('Add a debt or loan'),
      content: DialogBody(children: [
        Wrap(spacing: 8, children: [
          ChoicePill(label: 'I lent money', selected: _direction == Debt.lent,
              onTap: () => setState(() => _direction = Debt.lent)),
          ChoicePill(label: 'I borrowed', selected: _direction == Debt.borrowed,
              onTap: () => setState(() => _direction = Debt.borrowed)),
        ]),
        TextField(controller: _person, style: expText(15), decoration: const InputDecoration(labelText: 'Person')),
        AmountField(controller: _amount),
        DateField(
          label: _direction == Debt.lent ? 'Date lent' : 'Date borrowed',
          value: _start,
          onTap: () async {
            final d = await pickDate(context, initial: _start);
            if (d != null) setState(() => _start = d);
          },
        ),
        DateField(
          label: 'Due date (optional)',
          value: _due,
          onTap: () async {
            final d = await pickDate(context,
                initial: _due ?? today.add(const Duration(days: 30)), first: _start, last: DateTime(today.year + 10));
            if (d != null) setState(() => _due = d);
          },
          onClear: () => setState(() => _due = null),
        ),
        TextField(controller: _note, style: expText(15), decoration: const InputDecoration(labelText: 'Note (optional)')),
        Text(
          _direction == Debt.lent
              ? 'Lending money is not counted as an expense.'
              : 'Repayments reduce your safe-to-spend in the month they are due, but are not expenses.',
          style: expText(12, color: AppColors.onGlassMuted, height: 1.4),
        ),
        if (_error != null) Text(_error!, style: expText(13, color: AppColors.loss)),
      ]),
      actions: dialogActions(context, saveLabel: 'Save', onSave: _save),
    );
  }
}
