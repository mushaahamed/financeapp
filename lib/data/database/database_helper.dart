import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_settings_model.dart';
import '../models/expense_model.dart';
import '../models/investment_asset_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'paisa_v2.db');
    return openDatabase(path,
        version: 3, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE investments ADD COLUMN invested_at TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE expenses ADD COLUMN is_income INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY,
        current_cash REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        weekly_update_day INTEGER NOT NULL DEFAULT 0,
        weekly_update_time TEXT NOT NULL DEFAULT '09:00',
        auto_update_enabled INTEGER NOT NULL DEFAULT 1,
        gemini_model TEXT NOT NULL DEFAULT 'gemini-2.5-flash',
        last_portfolio_update TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        category TEXT,
        notes TEXT,
        is_income INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'other',
        symbol TEXT,
        currency TEXT NOT NULL DEFAULT 'INR',
        amount_invested REAL NOT NULL DEFAULT 0,
        current_value REAL,
        created_at TEXT NOT NULL,
        invested_at TEXT,
        last_updated_at TEXT,
        notes TEXT
      )
    ''');
  }

  // ─── UserSettings ────────────────────────────────────────────────────────────

  Future<UserSettings?> getSettings() async {
    final db = await database;
    final rows = await db.query('user_settings', where: 'id = 1');
    if (rows.isEmpty) return null;
    return UserSettings.fromMap(rows.first);
  }

  Future<void> upsertSettings(UserSettings s) async {
    final db = await database;
    await db.insert('user_settings', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCash(double cash) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE user_settings SET current_cash = ? WHERE id = 1', [cash]);
  }

  Future<void> adjustCash(double delta) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE user_settings SET current_cash = current_cash + ? WHERE id = 1',
        [delta]);
  }

  Future<void> updateLastPortfolioUpdate(DateTime dt) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE user_settings SET last_portfolio_update = ? WHERE id = 1',
        [dt.toIso8601String()]);
  }

  // ─── Expenses ────────────────────────────────────────────────────────────────

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query('expenses', orderBy: 'timestamp DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesBetween(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> insertExpense(Expense e) async {
    final db = await database;
    return db.insert('expenses', e.toMap());
  }

  Future<void> updateExpense(Expense e) async {
    final db = await database;
    await db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Investments ─────────────────────────────────────────────────────────────

  Future<List<InvestmentAsset>> getAllInvestments() async {
    final db = await database;
    final rows = await db.query('investments', orderBy: 'name ASC');
    return rows.map(InvestmentAsset.fromMap).toList();
  }

  Future<InvestmentAsset?> getInvestmentById(int id) async {
    final db = await database;
    final rows =
        await db.query('investments', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InvestmentAsset.fromMap(rows.first);
  }

  Future<int> insertInvestment(InvestmentAsset a) async {
    final db = await database;
    return db.insert('investments', a.toMap());
  }

  Future<void> updateInvestment(InvestmentAsset a) async {
    final db = await database;
    await db.update('investments', a.toMap(),
        where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> deleteInvestment(int id) async {
    final db = await database;
    await db.delete('investments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateInvestmentValue(
      int id, double currentValue, DateTime updatedAt) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE investments SET current_value = ?, last_updated_at = ? WHERE id = ?',
      [currentValue, updatedAt.toIso8601String(), id],
    );
  }

  Future<void> addToInvestment(int id, double extraAmount) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE investments SET amount_invested = amount_invested + ? WHERE id = ?',
        [extraAmount, id]);
  }
}
