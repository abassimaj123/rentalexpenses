import 'package:calcwise_core/calcwise_core.dart' show DatabaseAdapter;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// DatabaseAdapter implementation for RentalExpenses SmartHistory.
///
/// Uses a dedicated SQLite database (`rentalexpenses_history.db`) that is
/// completely separate from the SharedPreferences storage used by the rest of
/// the app.  The table schema matches the canonical layout documented in
/// [DatabaseAdapter].
class HistoryDatabaseAdapter implements DatabaseAdapter {
  static const _dbName = 'rentalexpenses_history.db';
  static const _dbVersion = 1;
  static const _table = 'history';

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE $_table (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            app_key     TEXT    NOT NULL,
            screen_id   TEXT    NOT NULL,
            result_hash TEXT    NOT NULL,
            l1_json     TEXT    NOT NULL,
            l2_json     TEXT    NOT NULL,
            saved_at    INTEGER NOT NULL,
            is_pinned   INTEGER NOT NULL DEFAULT 0,
            pin_label   TEXT,
            pin_order   INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE UNIQUE INDEX idx_history_hash ON $_table(app_key, result_hash)',
        );
        await db.execute(
          'CREATE INDEX idx_history_recent ON $_table(app_key, is_pinned, saved_at DESC)',
        );
      },
    );
  }

  // ── Insert ──────────────────────────────────────────────────────────────────

  @override
  Future<int> insertRow(Map<String, dynamic> row) async {
    final db = await _database;
    return db.insert(
      _table,
      {
        'app_key': row['app_key'],
        'screen_id': row['screen_id'],
        'result_hash': row['result_hash'],
        'l1_json': row['l1_json'],
        'l2_json': row['l2_json'],
        'saved_at': row['saved_at'],
        'is_pinned': row['is_pinned'] ?? 0,
        'pin_label': row['pin_label'],
        'pin_order': row['pin_order'] ?? 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ── Query ────────────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getRows({
    required String appKey,
    String? screenId,
    bool? isPinned,
    int? limit,
  }) async {
    final db = await _database;
    final conditions = ['app_key = ?'];
    final args = <dynamic>[appKey];

    if (screenId != null) {
      conditions.add('screen_id = ?');
      args.add(screenId);
    }
    if (isPinned != null) {
      conditions.add('is_pinned = ?');
      args.add(isPinned ? 1 : 0);
    }

    return db.query(
      _table,
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'is_pinned DESC, pin_order DESC, saved_at DESC',
      limit: limit,
    );
  }

  @override
  Future<Map<String, dynamic>?> getRowByHash({
    required String appKey,
    required String resultHash,
  }) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'app_key = ? AND result_hash = ?',
      whereArgs: [appKey, resultHash],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ── Update / Delete ──────────────────────────────────────────────────────────

  @override
  Future<int> updateRow(int id, Map<String, dynamic> values) async {
    final db = await _database;
    return db.update(_table, values, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> deleteRow(int id) async {
    final db = await _database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  // ── Count / Eviction ─────────────────────────────────────────────────────────

  @override
  Future<int> countRows({required String appKey, bool? isPinned}) async {
    final db = await _database;
    final conditions = ['app_key = ?'];
    final args = <dynamic>[appKey];
    if (isPinned != null) {
      conditions.add('is_pinned = ?');
      args.add(isPinned ? 1 : 0);
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_table WHERE ${conditions.join(' AND ')}',
      args,
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getOldestAutoSaves({
    required String appKey,
    required int limit,
  }) async {
    final db = await _database;
    return db.query(
      _table,
      where: 'app_key = ? AND is_pinned = 0',
      whereArgs: [appKey],
      orderBy: 'saved_at ASC',
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getOldestPinned({
    required String appKey,
    required int limit,
  }) async {
    final db = await _database;
    return db.query(
      _table,
      where: 'app_key = ? AND is_pinned = 1',
      whereArgs: [appKey],
      orderBy: 'saved_at ASC',
      limit: limit,
    );
  }
}
