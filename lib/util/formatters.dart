import 'package:intl/intl.dart';

/// Change this one constant to switch currency symbol.
const String kCurrency = '€';

final DateFormat dfMonthYear = DateFormat('MMMM yyyy');
final DateFormat dfDayLong = DateFormat('EEEE d MMMM');
final DateFormat dfDayShort = DateFormat('d MMM');
final DateFormat dfDayMedium = DateFormat('d MMM yyyy');
final DateFormat dfTime = DateFormat('HH:mm');

/// Drops trailing zeros: 1.50 -> "1.5", 3.0 -> "3", 0.125 -> "0.125".
String fmtQty(double value) {
  var s = value.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

String fmtMoney(double value) {
  final whole = value == value.roundToDouble();
  return '${whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}$kCurrency';
}

/// "1.5 g", or null when no quantity was recorded.
String? fmtAmount(double? quantity, String unit) =>
    quantity == null ? null : '${fmtQty(quantity)} $unit';

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
