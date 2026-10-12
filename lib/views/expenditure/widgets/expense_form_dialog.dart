import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../models/expense_model.dart';
import '../../../models/expense_priority.dart';
import 'expenditure_ui.dart';

class ExpenseFormResult {
  final double amount;
  final String category;
  final DateTime date;
  final String priority;
  final String? note;
  const ExpenseFormResult(this.amount, this.category, this.date, this.priority, this.note);
}

/// Add (no [existing]) or edit an expense. Dates can be in the past but not
/// the future; priority follows the category until the user picks one.
Future<ExpenseFormResult?> showExpenseForm(BuildContext context, {ExpenseModel? existing}) {
  return showDialog<ExpenseFormResult>(
    context: context,
    builder: (_) => _ExpenseFormDialog(existing: existing),
  );
}

class _ExpenseFormDialog extends StatefulWidget {
  final ExpenseModel? existing;
  const _ExpenseFormDialog({this.existing});

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  late String _category;
  late String _priority;
  late DateTime _date;
  late bool _priorityTouched;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? kExpenseCategories.first;
    _priority = e?.priority ?? ExpensePriority.defaultFor(_category);
    _priorityTouched = e != null;
    _date = e?.effectiveDate ?? dateOnly(DateTime.now());
    _amount = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _note = TextEditingController(text: e?.note ?? '');
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
    final note = _note.text.trim();
    Navigator.pop(
      context,
      ExpenseFormResult(amount, _category, _date, _priority, note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Expense' : 'Edit Expense'),
      content: DialogBody(children: [
        DropdownButtonFormField<String>(
          initialValue: _category,
          dropdownColor: AppColors.deepNavy,
          style: expText(15),
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in kExpenseCategories)
              DropdownMenuItem(
                value: c,
                child: Row(children: [
                  Icon(categoryIcon(c), size: 18, color: AppColors.accentCyan),
                  const SizedBox(width: 10),
                  Text(c),
                ]),
              ),
          ],
          onChanged: (v) => setState(() {
            _category = v ?? _category;
            if (!_priorityTouched) _priority = ExpensePriority.defaultFor(_category);
          }),
        ),
        AmountField(controller: _amount, autofocus: widget.existing == null),
        DateField(
          label: 'Date',
          value: _date,
          onTap: () async {
            final d = await pickDate(context, initial: _date);
            if (d != null) setState(() => _date = d);
          },
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Priority', style: expText(12.5, color: AppColors.onGlassMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in ExpensePriority.values)
                ChoicePill(
                  label: ExpensePriority.label(p),
                  selected: _priority == p,
                  onTap: () => setState(() {
                    _priority = p;
                    _priorityTouched = true;
                  }),
                ),
            ]),
          ],
        ),
        TextField(
          controller: _note,
          style: expText(15),
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        if (_error != null) Text(_error!, style: expText(13, color: AppColors.loss)),
      ]),
      actions: dialogActions(context,
          saveLabel: widget.existing == null ? 'Save Expense' : 'Save Changes', onSave: _save),
    );
  }
}
