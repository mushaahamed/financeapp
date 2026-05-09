import '../database/database_helper.dart';
import '../models/investment_asset_model.dart';

class InvestmentRepository {
  final DatabaseHelper _db;
  InvestmentRepository(this._db);

  Future<List<InvestmentAsset>> getAll() => _db.getAllInvestments();

  Future<InvestmentAsset?> getById(int id) => _db.getInvestmentById(id);

  /// Creates a new investment and deducts from cash.
  Future<int> add(InvestmentAsset a) async {
    final id = await _db.insertInvestment(a);
    await _db.adjustCash(-a.amountInvested);
    return id;
  }

  /// Adds more money to an existing investment and deducts from cash.
  Future<void> addMore(int id, double amount) async {
    await _db.addToInvestment(id, amount);
    await _db.adjustCash(-amount);
  }

  Future<void> update(InvestmentAsset a) => _db.updateInvestment(a);

  /// Deletes investment and refunds invested amount to cash.
  Future<void> delete(int id, double amountInvested) async {
    await _db.deleteInvestment(id);
    await _db.adjustCash(amountInvested);
  }

  Future<void> updateValue(int id, double value, DateTime at) =>
      _db.updateInvestmentValue(id, value, at);

  Future<void> updateLastPortfolioUpdate(DateTime dt) =>
      _db.updateLastPortfolioUpdate(dt);
}
