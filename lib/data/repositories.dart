import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DrugRepository {
  DrugRepository(this._db);
  final Database _db;

  Future<List<Drug>> all({bool includeArchived = true}) async {
    final rows = await _db.query(
      'drugs',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'archived ASC, sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Drug.fromMap).toList();
  }

  Future<int> insert(Drug drug) async {
    final order = drug.sortOrder != 0 ? drug.sortOrder : await _nextSortOrder();
    return _db.insert('drugs', drug.copyWith(sortOrder: order).toMap());
  }

  Future<void> update(Drug drug) => _db.update(
        'drugs',
        drug.toMap(),
        where: 'id = ?',
        whereArgs: [drug.id],
      );

  /// Cascades to every intake of this drug.
  Future<void> delete(int id) =>
      _db.delete('drugs', where: 'id = ?', whereArgs: [id]);

  Future<void> applyOrder(List<int> idsInOrder) async {
    final batch = _db.batch();
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.update('drugs', {'sort_order': i},
          where: 'id = ?', whereArgs: [idsInOrder[i]]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> _nextSortOrder() async {
    final r = await _db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM drugs');
    return (r.first['n'] as int?) ?? 0;
  }
}

class IntakeRepository {
  IntakeRepository(this._db);
  final Database _db;

  Future<int> insert(Intake intake) => _db.insert('intakes', intake.toMap());

  Future<void> update(Intake intake) => _db.update(
        'intakes',
        intake.toMap(),
        where: 'id = ?',
        whereArgs: [intake.id],
      );

  Future<void> delete(int id) =>
      _db.delete('intakes', where: 'id = ?', whereArgs: [id]);

  Future<List<Intake>> forDay(DateTime day) async {
    final rows = await _db.query(
      'intakes',
      where: 'day = ?',
      whereArgs: [dayKeyOf(day)],
      orderBy: 'ts DESC',
    );
    return rows.map(Intake.fromMap).toList();
  }

  /// Every (day, drug, count) triple, ordered so the busiest drug of each day
  /// comes first. The dataset is tiny for a personal journal, so loading it in
  /// one pass keeps month-to-month swiping instant.
  Future<List<Map<String, Object?>>> dayDrugCounts() {
    return _db.rawQuery(
      'SELECT day, drug_id, COUNT(*) AS c FROM intakes '
      'GROUP BY day, drug_id '
      'ORDER BY day ASC, c DESC, drug_id ASC',
    );
  }

  Future<Map<int, int>> usageByDrug() async {
    final rows = await _db.rawQuery(
      'SELECT drug_id, COUNT(*) AS c FROM intakes GROUP BY drug_id',
    );
    return {
      for (final r in rows) r['drug_id'] as int: (r['c'] as int?) ?? 0,
    };
  }

  Future<DateTime?> earliestDay() async {
    final rows =
        await _db.rawQuery('SELECT MIN(ts) AS t FROM intakes');
    final t = rows.first['t'] as int?;
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<List<Map<String, Object?>>> statsByDrug(
    DateSpan span,
    Set<int> drugIds,
  ) {
    final (where, args) = _rangeWhere(span, drugIds);
    return _db.rawQuery(
      'SELECT drug_id, COUNT(*) AS c, SUM(quantity) AS q, SUM(cost) AS cost, '
      'COUNT(DISTINCT day) AS days '
      'FROM intakes WHERE $where '
      'GROUP BY drug_id ORDER BY c DESC',
      args,
    );
  }

  Future<List<Map<String, Object?>>> dailyTotals(
    DateSpan span,
    Set<int> drugIds,
  ) {
    final (where, args) = _rangeWhere(span, drugIds);
    return _db.rawQuery(
      'SELECT day, COUNT(*) AS c FROM intakes WHERE $where '
      'GROUP BY day ORDER BY day ASC',
      args,
    );
  }

  (String, List<Object?>) _rangeWhere(DateSpan span, Set<int> drugIds) {
    final buffer = StringBuffer('day >= ? AND day <= ?');
    final args = <Object?>[dayKeyOf(span.start), dayKeyOf(span.end)];
    if (drugIds.isNotEmpty) {
      final marks = List.filled(drugIds.length, '?').join(',');
      buffer.write(' AND drug_id IN ($marks)');
      args.addAll(drugIds);
    }
    return (buffer.toString(), args);
  }
}
