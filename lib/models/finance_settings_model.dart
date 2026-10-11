/// Per-user income settings (`public.finance_settings`), used for
/// safe-to-spend.
class FinanceSettings {
  final double? monthlyIncome;

  /// Day of the month income usually arrives (1–28).
  final int? incomeDay;

  const FinanceSettings({this.monthlyIncome, this.incomeDay});

  bool get hasIncome => (monthlyIncome ?? 0) > 0;

  factory FinanceSettings.fromJson(Map<String, dynamic> json) => FinanceSettings(
        monthlyIncome: (json['monthly_income'] as num?)?.toDouble(),
        incomeDay: json['income_day'] as int?,
      );
}
