import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../util/color.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'drenchd.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE substances (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        emoji       TEXT    NOT NULL,
        unit_name   TEXT    NOT NULL DEFAULT 'g',
        color       INTEGER NOT NULL DEFAULT 8100078,
        habitual    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE intakes (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        substance_id   INTEGER NOT NULL REFERENCES substances(id) ON DELETE CASCADE,
        ts        INTEGER NOT NULL,
        day       TEXT    NOT NULL,
        quantity  INTEGER NOT NULL DEFAULT 1,
        cost      REAL,
        comments  TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_intakes_day ON intakes(day)');
    await db.execute('CREATE INDEX idx_intakes_ts ON intakes(ts)');
    await db.execute('CREATE INDEX idx_intakes_substance ON intakes(substance_id)');

    final batch = db.batch();
    for (var i = 0; i < _seed.length; i++) {
      final s = _seed[i];
      batch.insert('substances', {
        'name': s.$1,
        'emoji': s.$2,
        'unit_name': s.$3,
        'color': await emojiColorFor(s.$2),
        'habitual': s.$4 ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _upgrade(Database db, int from, int to) async {
    // Add `if (from < 2) { ... }` blocks here as the schema evolves, and bump
    // _version. Never edit _create for an existing release.
  }

  /// Wipes every row but keeps the file and schema.
  Future<void> eraseAll() async {
    final db = await database;
    await db.delete('intakes');
    await db.delete('substances');
  }
}

/// (name, emoji, unit, habitual)
const List<(String, String, String, bool)> _seed = [
  ('Weed', '☘️', 'g', false),
  ('Psilocybin', '🍄', 'g', false),
  ('LSD', '🌀', 'µg', false),
  ('MDMA', '💗', 'mg', false),
  ('Cocaine', '❄️', 'line(s)', false),
  ('Heroin', '💉', 'shot(s)', false),
  ('Meth', '⚡️', 'mg', false),
  ('Ketamine', '🪐', 'mg', false),
  ('2C-B', '🍬', 'mg', false),
  ('DMT', '👁️', 'mg', false),
  ('Mescaline', '🌵', 'mg', false),
  ('Nitrous oxide', '🎈', 'balloon(s)', false),
  ('Opium', '🟫', 'g', false),
  ('Morphine', '💤', 'mg', false),
  ('Salvia', '🪻', 'g', false),
  ('Alcohol', '🍷', 'ml', true),
  ('Nicotine', '🚬', 'cig(s)', true),
];
