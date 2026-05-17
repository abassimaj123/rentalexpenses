import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;
import '../models/property_model.dart';
import '../models/expense_model.dart';
import '../models/tenant_model.dart';
import '../models/schedule_e_entry_model.dart';

class PropertyDatabaseService {
  PropertyDatabaseService._();
  static final PropertyDatabaseService instance = PropertyDatabaseService._();

  static const _dbName = 'rental_properties.db';
  // v1 → v2: added is_recurring / recurrence_type to monthly_expenses
  // v2 → v3: added tenants table
  // v3 → v4: added schedule_e_entries table
  // v4 → v5: added receipt_path to monthly_expenses
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, _dbName);
    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE properties (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        monthlyRent REAL NOT NULL,
        squareFootage REAL NOT NULL,
        createdDate TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE monthly_expenses (
        id TEXT PRIMARY KEY,
        propertyId TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        mortgage REAL NOT NULL DEFAULT 0,
        propertyTaxes REAL NOT NULL DEFAULT 0,
        insurance REAL NOT NULL DEFAULT 0,
        hoaFees REAL NOT NULL DEFAULT 0,
        propertyMgmt REAL NOT NULL DEFAULT 0,
        maintenance REAL NOT NULL DEFAULT 0,
        vacancyLoss REAL NOT NULL DEFAULT 0,
        utilities REAL NOT NULL DEFAULT 0,
        landscaping REAL NOT NULL DEFAULT 0,
        otherExpenses REAL NOT NULL DEFAULT 0,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurrence_type TEXT,
        receipt_path TEXT,
        FOREIGN KEY (propertyId) REFERENCES properties (id) ON DELETE CASCADE,
        UNIQUE (propertyId, year, month)
      )
    ''');
    await _createTenantsTable(db);
    await _createScheduleETable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE monthly_expenses ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE monthly_expenses ADD COLUMN recurrence_type TEXT');
    }
    if (oldVersion < 3) {
      await _createTenantsTable(db);
    }
    if (oldVersion < 4) {
      await _createScheduleETable(db);
    }
    if (oldVersion < 5) {
      await db
          .execute('ALTER TABLE monthly_expenses ADD COLUMN receipt_path TEXT');
    }
  }

  Future<void> _createTenantsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tenants (
        id TEXT PRIMARY KEY,
        property_id TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        monthly_rent REAL NOT NULL DEFAULT 0,
        lease_start TEXT NOT NULL,
        lease_end TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createScheduleETable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedule_e_entries (
        id TEXT PRIMARY KEY,
        property_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurrence_type TEXT,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE
      )
    ''');
  }

  // ── Properties CRUD ──────────────────────────────────────────────────────────

  Future<void> insertProperty(Property property) async {
    final db = await database;
    await db.insert('properties', property.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProperty(Property property) async {
    final db = await database;
    await db.update(
      'properties',
      property.toMap(),
      where: 'id = ?',
      whereArgs: [property.id],
    );
  }

  Future<void> deleteProperty(String id) async {
    final db = await database;
    await db
        .delete('monthly_expenses', where: 'propertyId = ?', whereArgs: [id]);
    await db.delete('tenants', where: 'property_id = ?', whereArgs: [id]);
    await db.delete('schedule_e_entries',
        where: 'property_id = ?', whereArgs: [id]);
    await db.delete('properties', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Property>> getAllProperties() async {
    final db = await database;
    final maps = await db.query('properties', orderBy: 'createdDate DESC');
    return maps.map(Property.fromMap).toList();
  }

  Future<Property?> getProperty(String id) async {
    final db = await database;
    final maps = await db.query('properties', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Property.fromMap(maps.first);
  }

  // ── Monthly Expenses CRUD ────────────────────────────────────────────────────

  Future<void> insertExpense(MonthlyExpense expense) async {
    final db = await database;
    await db.insert('monthly_expenses', expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateExpense(MonthlyExpense expense) async {
    final db = await database;
    await db.update(
      'monthly_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete('monthly_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MonthlyExpense>> getExpensesForProperty(String propertyId) async {
    final db = await database;
    final maps = await db.query(
      'monthly_expenses',
      where: 'propertyId = ?',
      whereArgs: [propertyId],
      orderBy: 'year DESC, month DESC',
    );
    return maps.map(MonthlyExpense.fromMap).toList();
  }

  Future<MonthlyExpense?> getExpenseForMonth(
      String propertyId, int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'monthly_expenses',
      where: 'propertyId = ? AND year = ? AND month = ?',
      whereArgs: [propertyId, year, month],
    );
    if (maps.isEmpty) return null;
    return MonthlyExpense.fromMap(maps.first);
  }

  Future<List<MonthlyExpense>> getAllExpensesForMonth(
      int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'monthly_expenses',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
    return maps.map(MonthlyExpense.fromMap).toList();
  }

  /// Returns `{ year*12+month → total_expenses }` for all properties
  /// across the given date range (inclusive). Used by the trend chart.
  Future<Map<int, double>> getMonthlyExpenseTotals({
    required int fromYear,
    required int fromMonth,
    required int toYear,
    required int toMonth,
  }) async {
    final db = await database;
    final fromKey = fromYear * 12 + fromMonth;
    final toKey = toYear * 12 + toMonth;
    final maps = await db.rawQuery('''
      SELECT year, month,
        SUM(mortgage + propertyTaxes + insurance + hoaFees + propertyMgmt +
            maintenance + vacancyLoss + utilities + landscaping + otherExpenses)
        AS total
      FROM monthly_expenses
      WHERE (year * 12 + month) >= ? AND (year * 12 + month) <= ?
      GROUP BY year, month
    ''', [fromKey, toKey]);
    final result = <int, double>{};
    for (final row in maps) {
      final key = (row['year'] as int) * 12 + (row['month'] as int);
      result[key] = (row['total'] as num).toDouble();
    }
    return result;
  }

  Future<List<MonthlyExpense>> getRecurringExpenses() async {
    final db = await database;
    final maps = await db.query(
      'monthly_expenses',
      where: 'is_recurring = 1',
      orderBy: 'year DESC, month DESC',
    );
    return maps.map(MonthlyExpense.fromMap).toList();
  }

  // ── Tenants CRUD ─────────────────────────────────────────────────────────────

  Future<void> insertTenant(Tenant tenant) async {
    final db = await database;
    await db.insert('tenants', tenant.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTenant(Tenant tenant) async {
    final db = await database;
    await db.update(
      'tenants',
      tenant.toMap(),
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
  }

  Future<void> deleteTenant(String id) async {
    final db = await database;
    await db.delete('tenants', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tenant>> getTenantsForProperty(String propertyId) async {
    final db = await database;
    final maps = await db.query(
      'tenants',
      where: 'property_id = ?',
      whereArgs: [propertyId],
      orderBy: 'lease_end ASC',
    );
    return maps.map(Tenant.fromMap).toList();
  }

  Future<List<Tenant>> getAllTenants() async {
    final db = await database;
    final maps = await db.query('tenants', orderBy: 'lease_end ASC');
    return maps.map(Tenant.fromMap).toList();
  }

  // ── Schedule E Entries CRUD ──────────────────────────────────────────────────

  Future<void> insertScheduleEEntry(ScheduleEEntry entry) async {
    final db = await database;
    await db.insert('schedule_e_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateScheduleEEntry(ScheduleEEntry entry) async {
    final db = await database;
    await db.update(
      'schedule_e_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteScheduleEEntry(String id) async {
    final db = await database;
    await db.delete('schedule_e_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScheduleEEntry>> getScheduleEEntriesForProperty(
      String propertyId, int year) async {
    final db = await database;
    final maps = await db.query(
      'schedule_e_entries',
      where: 'property_id = ? AND year = ?',
      whereArgs: [propertyId, year],
      orderBy: 'category ASC',
    );
    return maps.map(ScheduleEEntry.fromMap).toList();
  }

  Future<List<ScheduleEEntry>> getAllScheduleEEntriesForYear(int year) async {
    final db = await database;
    final maps = await db.query(
      'schedule_e_entries',
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'property_id ASC, category ASC',
    );
    return maps.map(ScheduleEEntry.fromMap).toList();
  }

  Future<List<ScheduleEEntry>> getRecurringScheduleEEntries() async {
    final db = await database;
    final maps = await db.query(
      'schedule_e_entries',
      where: 'is_recurring = 1',
      orderBy: 'category ASC',
    );
    return maps.map(ScheduleEEntry.fromMap).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
