import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../viewmodels/finance_settings_viewmodel.dart';
import 'widgets/expenditure_ui.dart';

/// Monthly income + payday, used for safe-to-spend.
Future<void> showFinanceSettingsSheet(BuildContext context, FinanceSettingsViewModel vm) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FinanceSettingsSheet(vm: vm),
  );
}

class _FinanceSettingsSheet extends StatefulWidget {
  final FinanceSettingsViewModel vm;
  const _FinanceSettingsSheet({required this.vm});

  @override
  State<_FinanceSettingsSheet> createState() => _FinanceSettingsSheetState();
}

class _FinanceSettingsSheetState extends State<_FinanceSettingsSheet> {
  late final TextEditingController _income;
  int? _day;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.vm.settings;
    _income = TextEditingController(text: s.monthlyIncome?.toStringAsFixed(0) ?? '');
    _day = s.incomeDay;
  }

  @override
  void dispose() {
    _income.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final income = parseAmount(_income.text);
    if (income == null || income <= 0) {
      setState(() => _error = 'Enter your monthly take-home income.');
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.vm.save(monthlyIncome: income, incomeDay: _day);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      showExpSnack(context, 'Income saved — safe-to-spend updated');
    } else {
      setState(() => _error = widget.vm.errorMessage ?? 'Could not save.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.glassBorderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Income settings', style: expText(20, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Used to work out how much you can safely spend each month.',
                style: expText(13, color: AppColors.onGlassMuted, height: 1.4)),
            const SizedBox(height: 18),
            AmountField(controller: _income, label: 'Monthly take-home income (LKR)', autofocus: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _day,
              dropdownColor: AppColors.deepNavy,
              style: expText(15),
              decoration: const InputDecoration(labelText: 'Payday (day of month, optional)'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Not set')),
                for (var d = 1; d <= 28; d++) DropdownMenuItem<int?>(value: d, child: Text('$d')),
              ],
              onChanged: (v) => setState(() => _day = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: expText(13, color: AppColors.loss)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onLight))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
