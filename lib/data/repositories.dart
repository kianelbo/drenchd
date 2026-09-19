import 'package:sqflite/sqflite.dart';

import 'models.dart';

class SubstanceRepository {
  final Database _db;
  SubstanceRepository(this._db);

  Future<List<Substance>> all() async {
    final rows = await _db.query('substances', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Substance.fromMap).toList();
  }

  Future<int> insert(Substance substance) => _db.insert('substances', substance.toMap());

  Future<void> update(Substance substance) => _db.update(
        'substances',
        substance.toMap(),
        where: 'id = ?',
        whereArgs: [substance.id],
      );

  /// Cascades to every intake of this substance.
  Future<void> delete(int id) =>
      _db.delete('substances', where: 'id = ?', whereArgs: [id]);
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

  /// Every (day, substance, count) triple, ordered so the busiest substance of each day
  /// comes first. The dataset is tiny for a personal journal, so loading it in
  /// one pass keeps month-to-month swiping instant.
  Future<List<Map<String, Object?>>> daySubstanceCounts() {
    return _db.rawQuery(
      'SELECT day, substance_id, COUNT(*) AS c FROM intakes '
      'GROUP BY day, substance_id '
      'ORDER BY day ASC, c DESC, substance_id ASC',
    );
  }

  Future<Map<int, int>> usageBySubstance() async {
    final rows = await _db.rawQuery(
      'SELECT substance_id, COUNT(*) AS c FROM intakes GROUP BY substance_id',
    );
    return {
      for (final r in rows) r['substance_id'] as int: (r['c'] as int?) ?? 0,
    };
  }

  Future<DateTime?> earliestDay() async {
    final rows =
        await _db.rawQuery('SELECT MIN(ts) AS t FROM intakes');
    final t = rows.first['t'] as int?;
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<List<Map<String, Object?>>> statsBySubstance(DateSpan span, Set<int> substanceIds) {
    final (where, args) = _rangeWhere(span, substanceIds);
    return _db.rawQuery(
      'SELECT substance_id, COUNT(*) AS c, SUM(quantity) AS q, SUM(cost) AS cost, '
      'COUNT(DISTINCT day) AS days '
      'FROM intakes WHERE $where '
      'GROUP BY substance_id ORDER BY c DESC',
      args,
    );
  }

  Future<List<Map<String, Object?>>> dailyTotals(
    DateSpan span,
    Set<int> substanceIds,
  ) {
    final (where, args) = _rangeWhere(span, substanceIds);
    return _db.rawQuery(
      'SELECT day, COUNT(*) AS c FROM intakes WHERE $where '
      'GROUP BY day ORDER BY day ASC',
      args,
    );
  }

  (String, List<Object?>) _rangeWhere(DateSpan span, Set<int> substanceIds) {
    final buffer = StringBuffer('day >= ? AND day <= ?');
    final args = <Object?>[dayKeyOf(span.start), dayKeyOf(span.end)];
    if (substanceIds.isNotEmpty) {
      final marks = List.filled(substanceIds.length, '?').join(',');
      buffer.write(' AND substance_id IN ($marks)');
      args.addAll(substanceIds);
    }
    return (buffer.toString(), args);
  }
}
