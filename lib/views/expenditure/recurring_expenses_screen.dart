import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/expense_priority.dart';
import '../../models/recurring_expense_model.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/expense_viewmodel.dart';
import 'widgets/expenditure_ui.dart';

/// Rent, bills and subscriptions that repeat weekly or monthly. Each due
/// occurrence is logged as an expense automatically when the app loads.
class RecurringExpensesScreen extends StatelessWidget {
  final ExpenseViewModel? viewModel;
  const RecurringExpensesScreen({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    const body = _RecurringBody();
    return viewModel != null
        ? ChangeNotifierProvider.value(value: viewModel!, child: body)
        : ChangeNotifierProvider(create: (_) => ExpenseViewModel()..load(userId ?? ''), child: body);
  }
}

class _RecurringBody extends StatelessWidget {
  const _RecurringBody();

  Future<void> _edit(BuildContext context, ExpenseViewModel vm, [RecurringExpense? existing]) async {
    final item = await showDialog<RecurringExpense>(
      context: context,
      builder: (_) => _RecurringForm(userId: vm.userId!, existing: existing),
    );
    if (item == null || !context.mounted) return;
    final ok = await vm.saveRecurring(item);
    if (context.mounted) {
      showExpSnack(context, ok ? 'Recurring expense saved' : (vm.errorMessage ?? 'Could not save.'), isError: !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
          current: AppSection.expenses, title: 'Recurring Bills', showBackButton: true, isSectionRoot: false),
      floatingActionButton: Consumer<ExpenseViewModel>(
        builder: (context, vm, _) => !vm.isLoggedIn
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.onLight,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add_rounded),
                label: Text('Add recurring', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                onPressed: () => _edit(context, vm),
              ),
      ),
      body: Consumer<ExpenseViewModel>(builder: (context, vm, _) {
        if (!vm.isLoggedIn) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: LoggedOutCard('Log in to set up recurring bills.'),
          );
        }
        final monthlyTotal = vm.recurring.where((r) => r.active).fold(0.0,
            (s, r) => s + (r.frequency == RecurringExpense.weekly ? r.amount * 52 / 12 : r.amount));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            Text(
              'Each bill is logged as an expense automatically on its due date. '
              'About ${formatRs(monthlyTotal, decimals: 0)} a month in total.',
              style: expText(13, color: AppColors.onGlass, height: 1.4).copyWith(shadows: kTitleShadow),
            ),
            const SizedBox(height: 14),
            if (vm.recurring.isEmpty)
              const EmptyNote('No recurring bills yet. Add rent, electricity, a phone plan or subscriptions.',
                  icon: Icons.event_repeat_rounded)
            else
              for (final r in vm.recurring) ...[
                Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => confirmAction(context,
                      title: 'Delete recurring expense?',
                      message: 'Expenses it already logged stay in your history.'),
                  onDismissed: (_) => vm.deleteRecurring(r.id!),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    decoration:
                        BoxDecoration(color: AppColors.lossStrong, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  child: GlassRow(
                    icon: categoryIcon(r.category),
                    iconColor: priorityColor(r.priority),
                    title: r.note?.isNotEmpty == true ? r.note! : r.category,
                    subtitle: '${formatRs(r.amount)} · ${r.frequency == RecurringExpense.weekly ? 'Weekly' : 'Monthly'}'
                        '${r.active ? ' · next ${shortDate(r.nextDueDate)}' : ' · paused'}',
                    onTap: () => _edit(context, vm, r),
                    trailing: Switch(
                      value: r.active,
                      onChanged: (v) => vm.saveRecurring(r.copyWith(active: v)),
                    ),
                    footer: Row(children: [
                      TagChip(ExpensePriority.label(r.priority), color: priorityColor(r.priority)),
                      const SizedBox(width: 6),
                      TagChip(r.category, color: AppColors.onGlassMuted),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      }),
    );
  }
}

class _RecurringForm extends StatefulWidget {
  final String userId;
  final RecurringExpense? existing;
  const _RecurringForm({required this.userId, this.existing});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  late String _category;
  late String _priority;
  late String _frequency;
  late DateTime _start;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _category = r?.category ?? 'Utilities';
    _priority = r?.priority ?? ExpensePriority.defaultFor(_category);
    _frequency = r?.frequency ?? RecurringExpense.monthly;
    _start = r?.nextDueDate ?? dateOnly(DateTime.now());
    _amount = TextEditingController(text: r == null ? '' : r.amount.toStringAsFixed(2));
    _note = TextEditingController(text: r?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final existing = widget.existing;
    final item = existing == null
        ? RecurringExpense(
            userId: widget.userId,
            category: _category,
            amount: amount,
            note: note,
            priority: _priority,
            frequency: _frequency,
            startDate: _start,
            nextDueDate: _start,
          )
        : existing.copyWith(
            category: _category,
            amount: amount,
            note: note,
            priority: _priority,
            frequency: _frequency,
            // Changing the due date re-anchors the schedule there.
            startDate: _start == existing.nextDueDate ? existing.startDate : _start,
            nextDueDate: _start,
          );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    return AlertDialog(
      title: Text(widget.existing == null ? 'New recurring expense' : 'Edit recurring expense'),
      content: DialogBody(children: [
        TextField(
          controller: _note,
          style: expText(15),
          decoration: const InputDecoration(labelText: 'Name (e.g. Rent, Dialog bill)'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _category,
          dropdownColor: AppColors.deepNavy,
          style: expText(15),
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in kExpenseCategories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() {
            _category = v ?? _category;
            _priority = ExpensePriority.defaultFor(_category);
          }),
        ),
        AmountField(controller: _amount),
        Wrap(spacing: 8, children: [
          ChoicePill(
              label: 'Monthly',
              selected: _frequency == RecurringExpense.monthly,
              onTap: () => setState(() => _frequency = RecurringExpense.monthly)),
          ChoicePill(
              label: 'Weekly',
              selected: _frequency == RecurringExpense.weekly,
              onTap: () => setState(() => _frequency = RecurringExpense.weekly)),
        ]),
        DateField(
          label: widget.existing == null ? 'First due date' : 'Next due date',
          value: _start,
          onTap: () async {
            final d = await pickDate(context,
                initial: _start, first: DateTime(today.year - 1), last: DateTime(today.year + 2));
            if (d != null) setState(() => _start = d);
          },
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in ExpensePriority.values)
            ChoicePill(label: ExpensePriority.label(p), selected: _priority == p, onTap: () => setState(() => _priority = p)),
        ]),
        if (_start.isBefore(today))
          Text('Past due dates are logged as expenses right away.',
              style: expText(12, color: AppColors.warning)),
        if (_error != null) Text(_error!, style: expText(13, color: AppColors.loss)),
      ]),
      actions: dialogActions(context, saveLabel: 'Save', onSave: _save),
    );
  }
}
