import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final _formatterCompact = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 0,
  );

  // R$ 1.234,56
  static String format(double value) => _formatter.format(value);

  // R$ 1.234 (sem centavos, para espaços menores)
  static String formatCompact(double value) =>
      _formatterCompact.format(value);

  // Para exibir positivo/negativo com cor
  static String formatSigned(double value) {
    final formatted = _formatter.format(value.abs());
    return value >= 0 ? '+$formatted' : '-$formatted';
  }

  // Converte string digitada pelo usuário em double
  // Aceita "1.234,56" ou "1234,56" ou "1234.56"
  static double? parse(String input) {
    if (input.isEmpty) return null;
    final cleaned = input
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}