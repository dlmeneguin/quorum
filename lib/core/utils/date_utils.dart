import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _dayMonth = DateFormat('dd/MM', 'pt_BR');
  static final _fullDate = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _monthYear = DateFormat('MMMM yyyy', 'pt_BR');
  static final _shortMonthYear = DateFormat('MMM/yy', 'pt_BR');
  static final _dayMonthName = DateFormat('dd MMM', 'pt_BR');

  // 15/03
  static String toDayMonth(DateTime date) => _dayMonth.format(date);

  // 15/03/2026
  static String toFullDate(DateTime date) => _fullDate.format(date);

  // março 2026
  static String toMonthYear(DateTime date) => _monthYear.format(date);

  // mar/26
  static String toShortMonthYear(DateTime date) =>
      _shortMonthYear.format(date);

  // 15 mar
  static String toDayMonthName(DateTime date) =>
      _dayMonthName.format(date);

  // Primeiro e último dia do mês
  static DateTime firstDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime lastDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59);

  // Timestamp Unix → DateTime
  static DateTime fromTimestamp(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);

  // DateTime → Timestamp Unix
  static int toTimestamp(DateTime date) =>
      date.millisecondsSinceEpoch;

  // Hoje como timestamp (início do dia)
  static int todayTimestamp() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
  }
}