import 'package:flutter_test/flutter_test.dart';

import 'package:drenchd/util/formatters.dart';

void main() {
  group('formatters', () {
    test('fmtMoney keeps the currency symbol and preserves decimals', () {
      expect(fmtMoney(12), '12€');
      expect(fmtMoney(12.5), '12.50€');
    });

    test('fmtAmount includes the unit name in the output', () {
      expect(fmtAmount(3, 'mg'), '3 mg');
      expect(fmtAmount(12, 'cig(s)'), '12 cig(s)');
    });

    test('relativeDayLabel handles today, yesterday, and future dates', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      expect(relativeDayLabel(DateTime(today.year, today.month, today.day)), 'Today');
      expect(relativeDayLabel(DateTime(yesterday.year, yesterday.month, yesterday.day)), 'Yesterday');
      expect(relativeDayLabel(DateTime(tomorrow.year, tomorrow.month, tomorrow.day)), 'Tomorrow');
    });
  });
}
