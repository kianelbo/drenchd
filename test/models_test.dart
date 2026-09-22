import 'package:flutter_test/flutter_test.dart';

import 'package:drenchd/data/models.dart';

void main() {
  group('date helpers', () {
    test('dayKeyOf and dateOnly normalize local calendar days', () {
      final timestamp = DateTime(2026, 9, 22, 22, 45, 12);

      expect(dayKeyOf(timestamp), '2026-09-22');
      expect(dateOnly(timestamp), DateTime(2026, 9, 22));
    });

    test('isFutureDay only compares the local calendar date', () {
      final today = dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));

      expect(isFutureDay(today), isFalse);
      expect(isFutureDay(tomorrow), isTrue);
    });
  });

  group('Substance', () {
    test('copyWith and sqlite round-tripping preserve values', () {
      const original = Substance(
        id: 12,
        name: 'Tea',
        emoji: '🍵',
        unitName: 'ml',
        colorValue: 0xFFFF0000,
        habitual: true,
      );

      final updated = original.copyWith(name: 'Matcha', habitual: false);
      final map = updated.toMap();
      final restored = Substance.fromMap(map);

      expect(updated.name, 'Matcha');
      expect(updated.habitual, isFalse);
      expect(restored.name, 'Matcha');
      expect(restored.habitual, isFalse);
      expect(restored.colorValue, 0xFFFF0000);
    });
  });

  group('Intake', () {
    test('toMap trims comments and keeps the local-day key', () {
      final intake = Intake(
        id: 9,
        substanceId: 4,
        timestamp: DateTime(2026, 4, 5, 22, 30),
        quantity: 3,
        cost: 12.5,
        comments: '  close call  ',
      );

      final map = intake.toMap();

      expect(map['comments'], 'close call');
      expect(map['day'], '2026-04-05');
      expect(map['quantity'], 3);
      expect(map['cost'], 12.5);
    });
  });

  group('aggregate models', () {
    test('DayGroup totals quantities and costs', () {
      final substance = const Substance(
        id: 1,
        name: 'Tea',
        emoji: '🍵',
        unitName: 'ml',
      );
      final group = DayGroup(
        substance: substance,
        intakes: [
          Intake(
            id: 1,
            substanceId: 1,
            timestamp: DateTime(2026, 1, 1, 9),
            quantity: 2,
            cost: 3.0,
          ),
          Intake(
            id: 2,
            substanceId: 1,
            timestamp: DateTime(2026, 1, 1, 15),
            quantity: 5,
            cost: 5.5,
          ),
        ],
      );

      expect(group.count, 2);
      expect(group.totalQuantity, 7);
      expect(group.totalCost, 8.5);
    });

    test('DateSpan.days is inclusive of both endpoints', () {
      final span = DateSpan(
        DateTime(2026, 1, 10),
        DateTime(2026, 1, 12),
      );

      expect(span.days, 3);
    });

    test('RangeStats reports empty ranges when there are no intakes', () {
      final stats = RangeStats(
        span: DateSpan(DateTime(2026, 1, 1), DateTime(2026, 1, 2)),
        totalIntakes: 0,
        totalCost: 0,
        activeDays: 0,
        perSubstance: const [],
        daily: const [],
      );

      expect(stats.isEmpty, isTrue);
    });
  });
}
