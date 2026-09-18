import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../util/color.dart';

/// Opens (and creates) the local SQLite file. Nothing here ever touches a
/// network: the database lives in the app's private sandbox directory.
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
      CREATE TABLE drugs (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        emoji       TEXT    NOT NULL,
        unit_name   TEXT    NOT NULL DEFAULT 'g',
        color       INTEGER NOT NULL DEFAULT 8100078
      )
    ''');

    await db.execute('''
      CREATE TABLE intakes (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        drug_id   INTEGER NOT NULL REFERENCES drugs(id) ON DELETE CASCADE,
        ts        INTEGER NOT NULL,
        day       TEXT    NOT NULL,
        quantity  INTEGER,
        cost      REAL,
        comments  TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_intakes_day ON intakes(day)');
    await db.execute('CREATE INDEX idx_intakes_ts ON intakes(ts)');
    await db.execute('CREATE INDEX idx_intakes_drug ON intakes(drug_id)');

    final batch = db.batch();
    for (var i = 0; i < _seed.length; i++) {
      final s = _seed[i];
      batch.insert('drugs', {
        'name': s.$1,
        'emoji': s.$2,
        'unit_name': s.$3,
        'color': await emojiColorFor(s.$2),
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
    await db.delete('drugs');
  }
}

/// (name, emoji, unit)
const List<(String, String, String)> _seed = [
  ('Weed', '☘️', 'g'),
  ('Psilocybin', '🍄', 'g'),
  ('LSD', '🌀', 'µg'),
  ('MDMA', '💗', 'mg'),
  ('Cocaine', '❄️', 'line(s)'),
  ('Heroin', '💉', 'shot(s)'),
  ('Meth', '⚡️', 'mg'),
  ('Ketamine', '🪐', 'mg'),
  ('2C-B', '🍬', 'mg'),
  ('DMT', '👁️', 'mg'),
  ('5-MeO-DMT', '🐸', 'mg'),
  ('Mescaline', '🌵', 'mg'),
  ('Nitrous oxide', '🎈', 'puff(s)'),
  ('Opium', '💤', 'g'),
  ('Morphine', '😌', 'g'),
  ('Kratom', '🌱', 'g'),
  ('Salvia', '🪻', 'g'),
  ('Benzodiazepines', '💊', 'mg'),
  ('Beer', '🍺', 'ml'),
  ('Alcohol', '🍷', 'ml'),
  ('Nicotine', '🚬', 'cig(s)'),
];
