import '../database/database_helper.dart';
import '../models/expense_model.dart';

enum ExpenseFilter { all, today, thisWeek, thisMonth }

class ExpenseRepository {
  final DatabaseHelper _db;
  ExpenseRepository(this._db);

  Future<List<Expense>> getExpenses(ExpenseFilter filter) async {
    final now = DateTime.now();
    switch (filter) {
      case ExpenseFilter.all:
        return _db.getAllExpenses();
      case ExpenseFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return _db.getExpensesBetween(start, end);
      case ExpenseFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
      case ExpenseFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    }
  }

  Future<List<Expense>> getRecentExpenses(int limit) async {
    final all = await _db.getAllExpenses();
    return all.take(limit).toList();
  }

  Future<double> getTotalForToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final list = await _db.getExpensesBetween(start, end);
    return list.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<double> getTotalForWeek() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final list = await _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    return list.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<double> getTotalForMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final list = await _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    return list.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  /// Inserts the expense and adjusts cash. Returns the new id.
  Future<int> addExpense(Expense e) async {
    final id = await _db.insertExpense(e);
    await _db.adjustCash(-e.amount);
    return id;
  }

  /// Updates expense; adjusts cash by the amount difference.
  Future<void> updateExpense(Expense updated, double oldAmount) async {
    await _db.updateExpense(updated);
    final diff = updated.amount - oldAmount;
    if (diff != 0) await _db.adjustCash(-diff);
  }

  /// Deletes expense and refunds amount to cash.
  Future<void> deleteExpense(Expense e) async {
    await _db.deleteExpense(e.id!);
    await _db.adjustCash(e.amount);
  }
}
