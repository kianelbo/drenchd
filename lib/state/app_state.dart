import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repositories.dart';

class AppState extends ChangeNotifier {
  AppState({required DrugRepository drugs, required IntakeRepository intakes})
      : _drugRepo = drugs,
        _intakeRepo = intakes;

  final DrugRepository _drugRepo;
  final IntakeRepository _intakeRepo;

  bool ready = false;

  List<Drug> drugs = const [];
  Map<int, Drug> _byId = const {};
  Map<int, int> usage = const {};

  /// dayKey -> marker. Held entirely in memory; a personal journal is small.
  Map<String, DayMarker> markers = const {};

  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = dateOnly(DateTime.now());
  List<DayGroup> dayGroups = const [];

  List<Drug> get activeDrugs => drugs.where((d) => !d.archived).toList();
  Drug? drugById(int? id) => id == null ? null : _byId[id];
  DayMarker? markerFor(DateTime day) => markers[dayKeyOf(day)];

  int get selectedDayCount =>
      dayGroups.fold(0, (sum, g) => sum + g.count);

  /// The drugs used most often overall — used for one-tap logging.
  List<Drug> get quickPicks {
    final list = activeDrugs.toList()
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
        trimmed.add(DayGroup(drug: g.drug, intakes: remaining));
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

  // ------------------------------------------------------------------- drugs

  Future<int> saveDrug(Drug drug) async {
    int id;
    if (drug.id == null) {
      id = await _drugRepo.insert(drug);
    } else {
      await _drugRepo.update(drug);
      id = drug.id!;
    }
    await _reloadEverything();
    notifyListeners();
    return id;
  }

  Future<void> deleteDrug(int id) async {
    await _drugRepo.delete(id);
    await _reloadEverything();
    notifyListeners();
  }

  Future<void> reorderDrugs(int oldIndex, int newIndex) async {
    final list = drugs.toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    drugs = list;
    notifyListeners();
    await _drugRepo.applyOrder([for (final d in list) d.id!]);
    await _reloadEverything();
    notifyListeners();
  }

  // ------------------------------------------------------------------- stats

  Future<DateTime?> earliestEntry() => _intakeRepo.earliestDay();

  Future<RangeStats> statsFor(DateSpan span, Set<int> drugIds) async {
    final rows = await _intakeRepo.statsByDrug(span, drugIds);
    final dailyRows = await _intakeRepo.dailyTotals(span, drugIds);

    final perDrug = <DrugStat>[];
    var total = 0;
    var cost = 0.0;
    for (final r in rows) {
      final drug = _byId[r['drug_id'] as int];
      if (drug == null) continue;
      final c = (r['c'] as int?) ?? 0;
      final money = (r['cost'] as num?)?.toDouble();
      total += c;
      cost += money ?? 0;
      perDrug.add(DrugStat(
        drug: drug,
        count: c,
        quantity: (r['q'] as num?)?.toDouble(),
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
      perDrug: perDrug,
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
    await _reloadDrugs();
    await _reloadMarkers();
    await _reloadDay();
  }

  Future<void> _reloadDrugs() async {
    drugs = await _drugRepo.all();
    _byId = {
      for (final d in drugs)
        if (d.id != null) d.id!: d,
    };
    usage = await _intakeRepo.usageByDrug();
  }

  Future<void> _reloadMarkers() async {
    final rows = await _intakeRepo.dayDrugCounts();
    final acc = <String, _DayAcc>{};
    for (final r in rows) {
      final day = r['day'] as String;
      final drugId = r['drug_id'] as int;
      final count = (r['c'] as int?) ?? 0;
      final a = acc.putIfAbsent(day, _DayAcc.new);
      a.total += count;
      a.distinct += 1;
      if (count > a.topCount) {
        a.topCount = count;
        a.topDrugId = drugId;
      }
    }
    markers = {
      for (final e in acc.entries)
        if (_byId[e.value.topDrugId] != null)
          e.key: DayMarker(
            topDrug: _byId[e.value.topDrugId]!,
            totalCount: e.value.total,
            distinctDrugs: e.value.distinct,
          ),
    };
  }

  Future<void> _reloadDay() async {
    final intakes = await _intakeRepo.forDay(selectedDay);
    final grouped = <int, List<Intake>>{};
    for (final i in intakes) {
      grouped.putIfAbsent(i.drugId, () => <Intake>[]).add(i);
    }
    final groups = <DayGroup>[];
    grouped.forEach((drugId, list) {
      final drug = _byId[drugId];
      if (drug != null) groups.add(DayGroup(drug: drug, intakes: list));
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
  int topDrugId = -1;
}
