import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;
import '../models/property_model.dart';
import '../models/expense_model.dart';

class PropertyDatabaseService {
  PropertyDatabaseService._();
  static final PropertyDatabaseService instance = PropertyDatabaseService._();

  static const _dbName = 'rental_properties.db';
  static const _dbVersion = 1;

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
        FOREIGN KEY (propertyId) REFERENCES properties (id) ON DELETE CASCADE,
        UNIQUE (propertyId, year, month)
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
    // Delete expenses first (cascade)
    await db.delete('monthly_expenses', where: 'propertyId = ?', whereArgs: [id]);
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

  /// Returns all expenses across all properties for a given month.
  Future<List<MonthlyExpense>> getAllExpensesForMonth(int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'monthly_expenses',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
    return maps.map(MonthlyExpense.fromMap).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
