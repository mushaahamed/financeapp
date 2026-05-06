import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_settings_model.dart';
import '../models/expense_model.dart';
import '../models/investment_asset_model.dart';
import '../models/investment_transaction_model.dart';
import '../../core/constants.dart';

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
    final path = join(await getDatabasesPath(), kDbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY,
        current_cash REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        weekly_update_day INTEGER NOT NULL DEFAULT 0,
        weekly_update_time TEXT NOT NULL DEFAULT '09:00',
        auto_update_enabled INTEGER NOT NULL DEFAULT 1,
        gemini_model TEXT NOT NULL DEFAULT 'gemini-2.0-flash',
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
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE investment_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        symbol TEXT,
        currency TEXT NOT NULL DEFAULT 'INR',
        units_held REAL NOT NULL DEFAULT 0,
        avg_buy_price_per_unit REAL NOT NULL DEFAULT 0,
        total_invested REAL NOT NULL DEFAULT 0,
        last_known_price_per_unit REAL,
        last_price_update_at TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE investment_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        units REAL NOT NULL,
        price_per_unit REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (asset_id) REFERENCES investment_assets(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── UserSettings ───────────────────────────────────────────────────────────

  Future<UserSettings?> getSettings() async {
    final db = await database;
    final rows = await db.query('user_settings', where: 'id = 1');
    if (rows.isEmpty) return null;
    return UserSettings.fromMap(rows.first);
  }

  Future<void> upsertSettings(UserSettings s) async {
    final db = await database;
    await db.insert(
      'user_settings',
      s.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final rows =
        await db.query('expenses', orderBy: 'timestamp DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: "timestamp >= ? AND timestamp < ?",
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
    await db.update('expenses', e.toMap(),
        where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Investment Assets ───────────────────────────────────────────────────────

  Future<List<InvestmentAsset>> getAllAssets() async {
    final db = await database;
    final rows = await db.query('investment_assets', orderBy: 'name ASC');
    return rows.map(InvestmentAsset.fromMap).toList();
  }

  Future<InvestmentAsset?> getAssetById(int id) async {
    final db = await database;
    final rows =
        await db.query('investment_assets', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InvestmentAsset.fromMap(rows.first);
  }

  Future<int> insertAsset(InvestmentAsset a) async {
    final db = await database;
    return db.insert('investment_assets', a.toMap());
  }

  Future<void> updateAsset(InvestmentAsset a) async {
    final db = await database;
    await db.update('investment_assets', a.toMap(),
        where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> deleteAsset(int id) async {
    final db = await database;
    await db.delete('investment_assets', where: 'id = ?', whereArgs: [id]);
    await db.delete('investment_transactions',
        where: 'asset_id = ?', whereArgs: [id]);
  }

  Future<void> updateAssetPrice(
      int assetId, double price, DateTime updatedAt) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE investment_assets SET last_known_price_per_unit = ?, last_price_update_at = ? WHERE id = ?',
      [price, updatedAt.toIso8601String(), assetId],
    );
  }

  // ─── Investment Transactions ─────────────────────────────────────────────────

  Future<List<InvestmentTransaction>> getTransactionsForAsset(
      int assetId) async {
    final db = await database;
    final rows = await db.query(
      'investment_transactions',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(InvestmentTransaction.fromMap).toList();
  }

  Future<void> insertTransactionAndRecalculate(
      InvestmentTransaction tx) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('investment_transactions', tx.toMap());
      await _recalculateAssetStats(txn, tx.assetId);
    });
  }

  Future<void> deleteTransactionAndRecalculate(int txId, int assetId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('investment_transactions',
          where: 'id = ?', whereArgs: [txId]);
      await _recalculateAssetStats(txn, assetId);
    });
  }

  Future<void> _recalculateAssetStats(
      DatabaseExecutor txn, int assetId) async {
    final rows = await txn.query(
      'investment_transactions',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      orderBy: 'timestamp ASC',
    );

    double unitsHeld = 0;
    double totalCost = 0;

    for (final row in rows) {
      final units = (row['units'] as num).toDouble();
      final price = (row['price_per_unit'] as num).toDouble();
      if (row['type'] == 'buy') {
        totalCost += units * price;
        unitsHeld += units;
      } else {
        // sell: reduce units proportionally, keep same avg cost
        final fraction = (unitsHeld > 0) ? units / unitsHeld : 0.0;
        totalCost -= totalCost * fraction;
        unitsHeld -= units;
        if (unitsHeld < 0) unitsHeld = 0;
        if (totalCost < 0) totalCost = 0;
      }
    }

    final avg = (unitsHeld > 0) ? totalCost / unitsHeld : 0.0;

    await txn.rawUpdate(
      'UPDATE investment_assets SET units_held = ?, avg_buy_price_per_unit = ?, total_invested = ? WHERE id = ?',
      [unitsHeld, avg, totalCost, assetId],
    );
  }
}
