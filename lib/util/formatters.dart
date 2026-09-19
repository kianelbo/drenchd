import 'package:intl/intl.dart';

/// Change this one constant to switch currency symbol.
const String kCurrency = '€';

final DateFormat dfMonthYear = DateFormat('MMMM yyyy');
final DateFormat dfDayLong = DateFormat('EEEE d MMMM');
final DateFormat dfDayShort = DateFormat('d MMM');
final DateFormat dfDayMedium = DateFormat('d MMM yyyy');
final DateFormat dfTime = DateFormat('HH:mm');

String fmtMoney(double value) {
  final whole = value == value.roundToDouble();
  return '${whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}$kCurrency';
}

String fmtAmount(num quantity, String unit) => '$quantity $unit';

String relativeDayLabel(DateTime day) {
  final today = DateTime.now();
  final diff = DateTime(day.year, day.month, day.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  switch (diff) {
    case 0:
      return 'Today';
    case -1:
      return 'Yesterday';
    case 1:
      return 'Tomorrow';
    default:
      return dfDayLong.format(day);
  }
}
