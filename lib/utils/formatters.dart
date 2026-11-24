const List<String> _monthsPt = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const List<String> _monthsShortPt = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

String formatCurrency(double value, {bool showSign = false}) {
  final isNegative = value < 0;
  final absVal = value.abs();
  final fixed = absVal.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];

  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    final posFromEnd = intPart.length - i;
    buffer.write(intPart[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  final prefix = isNegative
      ? '− R\$ '
      : (showSign && value > 0 ? '+ R\$ ' : 'R\$ ');
  return '$prefix$buffer,$decPart';
}

String formatPercent(double percent) {
  return '${percent.toStringAsFixed(1).replaceAll('.', ',')}%';
}

String formatMonthYear(DateTime date) {
  return '${_monthsPt[date.month - 1]} ${date.year}';
}

String formatDateShort(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = _monthsShortPt[date.month - 1];
  return '$day $month ${date.year}';
}

String formatDateNumeric(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

double? parseBrazilianAmount(String raw) {
  final cleaned = raw
      .replaceAll('R\$', '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.isEmpty) return null;

  // Handle both "1.234,56" and "1234.56" cleanly.
  if (cleaned.contains(',')) {
    final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
  return double.tryParse(cleaned);
}
