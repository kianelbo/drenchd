import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repositories.dart';

class AppState extends ChangeNotifier {
  AppState({required SubstanceRepository substances, required IntakeRepository intakes})
      : _substanceRepo = substances,
        _intakeRepo = intakes;

  final SubstanceRepository _substanceRepo;
  final IntakeRepository _intakeRepo;

  bool ready = false;

  List<Substance> substances = const [];
  Map<int, Substance> _byId = const {};
  Map<int, int> usage = const {};

  /// dayKey -> marker. Held entirely in memory; a personal journal is small.
  Map<String, DayMarker> markers = const {};

  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = dateOnly(DateTime.now());
  List<DayGroup> dayGroups = const [];

  Substance? substanceById(int? id) => id == null ? null : _byId[id];
  DayMarker? markerFor(DateTime day) => markers[dayKeyOf(day)];

  /// The substances used most often overall — used for one-tap logging.
  List<Substance> get quickPicks {
    final list = substances.toList()
      ..sort((a, b) => (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0));
    return list.take(5).toList();
  }

  Future<void> bootstrap() async {
    await _reloadEverything();
    ready = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- calendar

  void selectDay(DateTime selected, DateTime focused) {
    selectedDay = dateOnly(selected);
    focusedDay = focused;
    notifyListeners();
    _reloadDay().then((_) => notifyListeners());
  }

  void setFocusedDay(DateTime day) {
    focusedDay = day;
    notifyListeners();
  }

  void jumpToToday() {
    final now = DateTime.now();
    focusedDay = now;
    selectedDay = dateOnly(now);
    notifyListeners();
    _reloadDay().then((_) => notifyListeners());
  }

  void shiftMonth(int delta) {
    focusedDay = DateTime(focusedDay.year, focusedDay.month + delta, 1);
    notifyListeners();
  }

  // ----------------------------------------------------------------- intakes

  Future<void> saveIntake(Intake intake) async {
    if (intake.id == null) {
      await _intakeRepo.insert(intake);
    } else {
      await _intakeRepo.update(intake);
    }
    // Follow the entry: if it landed on another day, show that day.
    selectedDay = dateOnly(intake.timestamp);
    focusedDay = intake.timestamp;
    await _reloadEverything();
    notifyListeners();
  }

  Future<void> deleteIntake(int id) async {
    // Drop it from the visible day first. A `Dismissible` asserts if its row is
    // still in the tree on the frame after the swipe finishes, and waiting for
    // SQLite would be a frame too late.
    final trimmed = <DayGroup>[];
    for (final g in dayGroups) {
      final remaining = g.intakes.where((i) => i.id != id).toList();
      if (remaining.isNotEmpty) {
        trimmed.add(DayGroup(substance: g.substance, intakes: remaining));
      }
    }
    dayGroups = trimmed;
    notifyListeners();

    await _intakeRepo.delete(id);
    await _reloadEverything();
    notifyListeners();
  }

  /// Re-inserts a deleted entry with its original id (undo).
  Future<void> restoreIntake(Intake intake) async {
    await _intakeRepo.insert(intake);
    await _reloadEverything();
    notifyListeners();
  }

  // ------------------------------------------------------------------- substances

  Future<int> saveSubstance(Substance substance) async {
    int id;
    if (substance.id == null) {
      id = await _substanceRepo.insert(substance);
    } else {
      await _substanceRepo.update(substance);
      id = substance.id!;
    }
    await _reloadEverything();
    notifyListeners();
    return id;
  }

  Future<void> deleteSubstance(int id) async {
    await _substanceRepo.delete(id);
    await _reloadEverything();
    notifyListeners();
  }

  // ------------------------------------------------------------------- stats

  Future<DateTime?> earliestEntry() => _intakeRepo.earliestDay();

  Future<RangeStats> statsFor(DateSpan span, Set<int> substanceIds) async {
    final rows = await _intakeRepo.statsBySubstance(span, substanceIds);
    final dailyRows = await _intakeRepo.dailyTotals(span, substanceIds);

    final perSubstance = <SubstanceStat>[];
    var total = 0;
    var cost = 0.0;
    for (final r in rows) {
      final substance = _byId[r['substance_id'] as int];
      if (substance == null) continue;
      final c = (r['c'] as int?) ?? 0;
      final money = (r['cost'] as num?)?.toDouble();
      total += c;
      cost += money ?? 0;
      perSubstance.add(SubstanceStat(
        substance: substance,
        count: c,
        quantity: r['q'] as int,
        cost: money,
        daysUsed: (r['days'] as int?) ?? 0,
      ));
    }

    final byDay = <String, int>{
      for (final r in dailyRows) r['day'] as String: (r['c'] as int?) ?? 0,
    };

    final daily = <DayCount>[];
    var cursor = dateOnly(span.start);
    final last = dateOnly(span.end);
    while (!cursor.isAfter(last)) {
      daily.add(DayCount(cursor, byDay[dayKeyOf(cursor)] ?? 0));
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    return RangeStats(
      span: span,
      totalIntakes: total,
      totalCost: cost,
      activeDays: byDay.values.where((v) => v > 0).length,
      perSubstance: perSubstance,
      daily: _bucket(daily, 62),
    );
  }

  /// Keeps the activity chart readable over long ranges by summing adjacent
  /// days into equal-width buckets.
  List<DayCount> _bucket(List<DayCount> source, int maxBars) {
    if (source.length <= maxBars) return source;
    final size = (source.length / maxBars).ceil();
    final out = <DayCount>[];
    for (var i = 0; i < source.length; i += size) {
      final end = (i + size).clamp(0, source.length);
      var sum = 0;
      for (var j = i; j < end; j++) {
        sum += source[j].count;
      }
      out.add(DayCount(source[i].day, sum));
    }
    return out;
  }

  // ----------------------------------------------------------------- loading

  Future<void> _reloadEverything() async {
    await _reloadSubstances();
    await _reloadMarkers();
    await _reloadDay();
  }

  Future<void> _reloadSubstances() async {
    substances = await _substanceRepo.all();
    _byId = {
      for (final d in substances)
        if (d.id != null) d.id!: d,
    };
    usage = await _intakeRepo.usageBySubstance();
  }

  Future<void> _reloadMarkers() async {
    final rows = await _intakeRepo.daySubstanceCounts();
    final acc = <String, _DayAcc>{};
    for (final r in rows) {
      final day = r['day'] as String;
      final substanceId = r['substance_id'] as int;
      final substance = _byId[substanceId];
      if (substance == null) continue;

      final count = (r['c'] as int?) ?? 0;
      final a = acc.putIfAbsent(day, _DayAcc.new);
      a.total += count;
      a.distinct += 1;

      if (substance.habitual) continue;
      if (count > a.topCount) {
        a.topCount = count;
        a.topSubstanceId = substanceId;
      }
    }
    markers = {
      for (final e in acc.entries)
        if (_byId[e.value.topSubstanceId] != null &&
            !_byId[e.value.topSubstanceId]!.habitual)
          e.key: DayMarker(
            topSubstance: _byId[e.value.topSubstanceId]!,
            totalCount: e.value.total,
            distinctSubstances: e.value.distinct,
          ),
    };
  }

  Future<void> _reloadDay() async {
    final intakes = await _intakeRepo.forDay(selectedDay);
    final grouped = <int, List<Intake>>{};
    for (final i in intakes) {
      grouped.putIfAbsent(i.substanceId, () => <Intake>[]).add(i);
    }
    final groups = <DayGroup>[];
    grouped.forEach((substanceId, list) {
      final substance = _byId[substanceId];
      if (substance != null) groups.add(DayGroup(substance: substance, intakes: list));
    });
    groups.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return b.intakes.first.timestamp.compareTo(a.intakes.first.timestamp);
    });
    dayGroups = groups;
  }
}

class _DayAcc {
  int total = 0;
  int distinct = 0;
  int topCount = 0;
  int topSubstanceId = -1;
}
