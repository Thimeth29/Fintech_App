/// LKR formatting used across the expenditure screens: `Rs 12,345.00`.
String formatRs(double value, {int decimals = 2}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  final text = parts.length > 1 ? 'Rs $whole.${parts[1]}' : 'Rs $whole';
  return negative ? '-$text' : text;
}

/// Parses user-typed amounts ("12,500", " 99.5 ") into a double, or null.
double? parseAmount(String input) =>
    double.tryParse(input.replaceAll(',', '').trim());

const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "2026-10" — the budgets table's month key.
String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Date-only value (local midnight), so comparisons ignore time of day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "2026-10-11" for Postgres DATE columns.
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);
int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// "11 Oct 2026"
String shortDate(DateTime d) =>
    '${d.day} ${kMonthNames[d.month - 1].substring(0, 3)} ${d.year}';
