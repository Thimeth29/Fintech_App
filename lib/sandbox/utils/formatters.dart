/// Formats a number as "LKR 128,450" without pulling in the intl package.
String formatLkr(double value, {int decimals = 0}) {
  final isNegative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    final posFromEnd = whole.length - i;
    buffer.write(whole[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
  }
  final result = parts.length > 1 ? '${buffer.toString()}.${parts[1]}' : buffer.toString();
  return '${isNegative ? '-' : ''}LKR $result';
}

String formatPct(double value, {int decimals = 1}) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(decimals)}%';
}
