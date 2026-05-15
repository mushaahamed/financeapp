import '../database/database_helper.dart';
import '../models/expense_model.dart';

enum ExpenseFilter { all, today, thisWeek, thisMonth, thisYear }

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
        return _db.getExpensesBetween(start, start.add(const Duration(days: 1)));
      case ExpenseFilter.thisWeek:
        final mon = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(mon.year, mon.month, mon.day);
        return _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
      case ExpenseFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
      case ExpenseFilter.thisYear:
        final start = DateTime(now.year, 1, 1);
        return _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    }
  }

  Future<List<Expense>> getRecentExpenses(int limit) async {
    final all = await _db.getAllExpenses();
    return all.take(limit).toList();
  }

  /// Returns one entry per distinct title (most recent per title) for quick-repeat chips.
  Future<List<Expense>> getRecentDistinct(int limit) async {
    final all = await _db.getAllExpenses();
    final seen = <String>{};
    final result = <Expense>[];
    for (final e in all) {
      final key = e.title.toLowerCase().trim();
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(e);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  /// All expenses on a specific calendar date.
  Future<List<Expense>> getExpensesForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _db.getExpensesBetween(start, end);
  }

  /// Set of dates (midnight-normalised) that have at least one expense in a month.
  Future<Set<DateTime>> getDatesWithExpensesInMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final expenses = await _db.getExpensesBetween(start, end);
    return expenses
        .map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
        .toSet();
  }

  Future<double> getTotalForToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final list =
        await _db.getExpensesBetween(start, start.add(const Duration(days: 1)));
    return list.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<double> getTotalForWeek() async {
    final now = DateTime.now();
    final mon = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(mon.year, mon.month, mon.day);
    final list =
        await _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    return list.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<double> getTotalForMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final list =
        await _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    return list.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<int> addExpense(Expense e) async {
    final id = await _db.insertExpense(e);
    // Income adds to cash, expense deducts
    await _db.adjustCash(e.isIncome ? e.amount : -e.amount);
    return id;
  }

  Future<void> updateExpense(Expense updated, double oldAmount, bool wasIncome) async {
    await _db.updateExpense(updated);
    // Reverse old effect
    await _db.adjustCash(wasIncome ? -oldAmount : oldAmount);
    // Apply new effect
    await _db.adjustCash(updated.isIncome ? updated.amount : -updated.amount);
  }

  Future<void> deleteExpense(Expense e) async {
    await _db.deleteExpense(e.id!);
    // Reverse the effect
    await _db.adjustCash(e.isIncome ? -e.amount : e.amount);
  }

  Future<double> getMonthIncome() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final list = await _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    return list.where((e) => e.isIncome).fold<double>(0.0, (s, e) => s + e.amount);
  }

  Future<double> getMonthExpenses() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final list = await _db.getExpensesBetween(start, now.add(const Duration(days: 1)));
    return list.where((e) => !e.isIncome).fold<double>(0.0, (s, e) => s + e.amount);
  }
}
