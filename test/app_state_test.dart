import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:drenchd/data/models.dart';
import 'package:drenchd/data/repositories.dart';
import 'package:drenchd/state/app_state.dart';

class _FakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSubstanceRepo extends SubstanceRepository {
  _FakeSubstanceRepo(this._items) : super(_FakeDatabase());

  final List<Substance> _items;

  @override
  Future<List<Substance>> all() async => List<Substance>.from(_items);

  @override
  Future<int> insert(Substance substance) async {
    final id = _items.length + 1;
    _items.add(substance.copyWith(id: id));
    return id;
  }

  @override
  Future<void> update(Substance substance) async {
    final index = _items.indexWhere((item) => item.id == substance.id);
    if (index >= 0) {
      _items[index] = substance;
    }
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((item) => item.id == id);
  }
}

class _FakeIntakeRepo extends IntakeRepository {
  _FakeIntakeRepo(this._items) : super(_FakeDatabase());

  final List<Intake> _items;

  @override
  Future<int> insert(Intake intake) async {
    final id = (_items.isEmpty ? 0 : _items.map((item) => item.id ?? 0).reduce((a, b) => a > b ? a : b)) + 1;
    _items.add(
      Intake(
        id: id,
        substanceId: intake.substanceId,
        timestamp: intake.timestamp,
        quantity: intake.quantity,
        cost: intake.cost,
        comments: intake.comments,
      ),
    );
    return id;
  }

  @override
  Future<void> update(Intake intake) async {
    final index = _items.indexWhere((item) => item.id == intake.id);
    if (index >= 0) {
      _items[index] = intake;
    }
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<Intake>> forDay(DateTime day) async {
    final dayKey = dayKeyOf(day);
    return _items
        .where((intake) => dayKeyOf(intake.timestamp) == dayKey)
        .toList();
  }

  @override
  Future<Map<int, int>> usageBySubstance() async {
    final counts = <int, int>{};
    for (final intake in _items) {
      counts[intake.substanceId] = (counts[intake.substanceId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<Map<String, Object?>>> daySubstanceCounts() async {
    final counts = <String, Map<int, int>>{};
    for (final intake in _items) {
      final day = dayKeyOf(intake.timestamp);
      counts.putIfAbsent(day, () => <int, int>{});
      counts[day]![intake.substanceId] =
          (counts[day]![intake.substanceId] ?? 0) + 1;
    }

    final rows = <Map<String, Object?>>[];
    for (final entry in counts.entries) {
      for (final substanceEntry in entry.value.entries) {
        rows.add({
          'day': entry.key,
          'substance_id': substanceEntry.key,
          'c': substanceEntry.value,
        });
      }
    }

    rows.sort((a, b) {
      final dayCompare = (a['day'] as String).compareTo(b['day'] as String);
      if (dayCompare != 0) return dayCompare;
      final countCompare = (b['c'] as int).compareTo(a['c'] as int);
      if (countCompare != 0) return countCompare;
      return (a['substance_id'] as int).compareTo(b['substance_id'] as int);
    });

    return rows;
  }

  @override
  Future<DateTime?> earliestDay() async {
    if (_items.isEmpty) return null;
    return _items
        .map((intake) => intake.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  @override
  Future<List<Map<String, Object?>>> statsBySubstance(
    DateSpan span,
    Set<int> substanceIds,
  ) async {
    final rows = <Map<String, Object?>>[];
    final startKey = dayKeyOf(dateOnly(span.start));
    final endKey = dayKeyOf(dateOnly(span.end));
    final relevant = _items.where((intake) {
      final dayKey = dayKeyOf(intake.timestamp);
      final inRange = dayKey.compareTo(startKey) >= 0 &&
          dayKey.compareTo(endKey) <= 0;
      if (!inRange) return false;
      if (substanceIds.isEmpty) return true;
      return substanceIds.contains(intake.substanceId);
    });

    final grouped = <int, Map<String, Object?>>{};
    for (final intake in relevant) {
      final entry = grouped.putIfAbsent(intake.substanceId, () => {
        'substance_id': intake.substanceId,
        'c': 0,
        'q': 0,
        'cost': 0.0,
        'days': <String>{},
      });
      final daySet = entry['days'] as Set<String>;
      daySet.add(dayKeyOf(intake.timestamp));
      entry['c'] = (entry['c'] as int) + 1;
      entry['q'] = (entry['q'] as int) + intake.quantity;
      entry['cost'] = ((entry['cost'] as double) + (intake.cost ?? 0.0));
    }

    for (final item in grouped.values) {
      rows.add({
        'substance_id': item['substance_id'],
        'c': item['c'],
        'q': item['q'],
        'cost': item['cost'],
        'days': (item['days'] as Set<String>).length,
      });
    }

    rows.sort((a, b) => (b['c'] as int).compareTo(a['c'] as int));
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> dailyTotals(
    DateSpan span,
    Set<int> substanceIds,
  ) async {
    final totals = <String, int>{};
    final startKey = dayKeyOf(dateOnly(span.start));
    final endKey = dayKeyOf(dateOnly(span.end));
    for (final intake in _items) {
      final day = dayKeyOf(intake.timestamp);
      final inRange = day.compareTo(startKey) >= 0 && day.compareTo(endKey) <= 0;
      final matchesSubstance = substanceIds.isEmpty || substanceIds.contains(intake.substanceId);
      if (inRange && matchesSubstance) {
        totals[day] = (totals[day] ?? 0) + 1;
      }
    }

    final rows = totals.entries
        .map((entry) => {'day': entry.key, 'c': entry.value})
        .toList();
    rows.sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
    return rows;
  }
}

void main() {
  group('AppState', () {
    test('bootstrap loads substances and sorts quick picks by usage', () async {
      final substances = [
        const Substance(id: 1, name: 'Tea', emoji: '🍵', unitName: 'ml'),
        const Substance(id: 2, name: 'Coffee', emoji: '☕', unitName: 'ml'),
        const Substance(id: 3, name: 'Wine', emoji: '🍷', unitName: 'ml'),
      ];
      final intakes = [
        Intake(id: 1, substanceId: 2, timestamp: DateTime(2026, 1, 15, 9, 0), quantity: 1),
        Intake(id: 2, substanceId: 2, timestamp: DateTime(2026, 1, 15, 9, 15), quantity: 1),
        Intake(id: 3, substanceId: 1, timestamp: DateTime(2026, 1, 15, 9, 30), quantity: 1),
        Intake(id: 4, substanceId: 1, timestamp: DateTime(2026, 1, 15, 9, 45), quantity: 1),
        Intake(id: 5, substanceId: 1, timestamp: DateTime(2026, 1, 15, 10, 0), quantity: 1),
      ];

      final state = AppState(
        substances: _FakeSubstanceRepo(substances),
        intakes: _FakeIntakeRepo(intakes),
      );

      await state.bootstrap();

      expect(state.ready, isTrue);
      expect(state.quickPicks.map((substance) => substance.id), [1, 2, 3]);
      expect(state.usage[1], 3);
      expect(state.usage[2], 2);
    });

    test('markerFor exposes the top substance for a day', () async {
      final substances = [
        const Substance(id: 1, name: 'Tea', emoji: '🍵', unitName: 'ml'),
        const Substance(id: 2, name: 'Cigarettes', emoji: '🚬', unitName: 'cig(s)', habitual: true),
      ];
      final intakes = [
        Intake(substanceId: 1, timestamp: DateTime(2026, 1, 15, 8), quantity: 1),
        Intake(substanceId: 1, timestamp: DateTime(2026, 1, 15, 12), quantity: 1),
        Intake(substanceId: 2, timestamp: DateTime(2026, 1, 15, 18), quantity: 1),
      ];

      final state = AppState(
        substances: _FakeSubstanceRepo(substances),
        intakes: _FakeIntakeRepo(intakes),
      );
      state.selectedDay = DateTime(2026, 1, 15);

      await state.bootstrap();

      final marker = state.markerFor(DateTime(2026, 1, 15));
      expect(marker, isNotNull);
      expect(marker!.topSubstance.name, 'Tea');
      expect(marker.totalCount, 3);
      expect(marker.distinctSubstances, 2);
    });

    test('saveIntake regenerates the selected day and updates state', () async {
      final substances = [
        const Substance(id: 1, name: 'Tea', emoji: '🍵', unitName: 'ml'),
      ];
      final intakes = [
        Intake(substanceId: 1, timestamp: DateTime(2026, 1, 12, 10), quantity: 2),
      ];

      final state = AppState(
        substances: _FakeSubstanceRepo(substances),
        intakes: _FakeIntakeRepo(intakes),
      );
      state.selectedDay = DateTime(2026, 1, 12);

      await state.bootstrap();
      await state.saveIntake(
        Intake(substanceId: 1, timestamp: DateTime(2026, 1, 12, 16), quantity: 4),
      );

      expect(state.selectedDay, DateTime(2026, 1, 12));
      expect(state.dayGroups.single.intakes.length, 2);
      expect(state.dayGroups.single.totalQuantity, 6);
    });

    test('statsFor aggregates per-substance and daily totals', () async {
      final substances = [
        const Substance(id: 1, name: 'Tea', emoji: '🍵', unitName: 'ml'),
        const Substance(id: 2, name: 'Coffee', emoji: '☕', unitName: 'ml'),
      ];
      final intakes = [
        Intake(substanceId: 1, timestamp: DateTime(2026, 1, 15, 9), quantity: 2, cost: 4.0),
        Intake(substanceId: 1, timestamp: DateTime(2026, 1, 15, 11), quantity: 1, cost: 2.0),
        Intake(substanceId: 2, timestamp: DateTime(2026, 1, 16, 8), quantity: 5, cost: 3.0),
      ];

      final state = AppState(
        substances: _FakeSubstanceRepo(substances),
        intakes: _FakeIntakeRepo(intakes),
      );
      state.selectedDay = DateTime(2026, 1, 15);
      await state.bootstrap();

      final span = DateSpan(DateTime(2026, 1, 15), DateTime(2026, 1, 16));
      final stats = await state.statsFor(span, {1, 2});

      expect(stats.totalIntakes, 3);
      expect(stats.activeDays, 2);
      expect(stats.perSubstance.map((item) => item.substance.id), [1, 2]);
      expect(stats.daily.map((item) => item.count), [2, 1]);
    });
  });
}
