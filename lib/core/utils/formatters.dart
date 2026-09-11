import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final DateFormat _shortDate = DateFormat('dd/MM/yyyy', 'pt_BR');
final DateFormat _monthYear = DateFormat('MMMM yyyy', 'pt_BR');

/// Formata um valor monetário em Real brasileiro, igual ao `formatCurrency`
/// do webapp (`dinflow/src/lib/utils.ts`).
String formatCurrency(num? value) {
  if (value == null) return r'R$ 0,00';
  return _currency.format(value);
}

/// Formata uma data ISO apenas como dia/mês/ano, sem considerar timezone.
String formatDateOnly(String? dateString) {
  if (dateString == null || dateString.isEmpty) return '-';
  final parsed = DateTime.tryParse(dateString);
  if (parsed == null) return '-';
  return _shortDate.format(parsed);
}

/// Nome do mês/ano capitalizado (ex.: "Setembro 2026").
String formatMonthYear(DateTime date) {
  final raw = _monthYear.format(date);
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}
