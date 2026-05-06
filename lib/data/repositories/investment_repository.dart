import '../database/database_helper.dart';
import '../models/investment_asset_model.dart';
import '../models/investment_transaction_model.dart';

class InvestmentRepository {
  final DatabaseHelper _db;
  InvestmentRepository(this._db);

  Future<List<InvestmentAsset>> getAllAssets() => _db.getAllAssets();

  Future<InvestmentAsset?> getAsset(int id) => _db.getAssetById(id);

  Future<int> addAsset(InvestmentAsset a) => _db.insertAsset(a);

  Future<void> updateAsset(InvestmentAsset a) => _db.updateAsset(a);

  Future<void> deleteAsset(int id) => _db.deleteAsset(id);

  Future<List<InvestmentTransaction>> getTransactions(int assetId) =>
      _db.getTransactionsForAsset(assetId);

  /// Adds a buy/sell transaction, recalculates asset stats,
  /// and adjusts cash (buy → deduct, sell → add).
  Future<void> addTransaction(InvestmentTransaction tx) async {
    await _db.insertTransactionAndRecalculate(tx);
    final cashDelta = tx.type == 'buy'
        ? -(tx.units * tx.pricePerUnit)
        : tx.units * tx.pricePerUnit;
    await _db.adjustCash(cashDelta);
  }

  /// Deletes a transaction, recalculates, and reverses cash impact.
  Future<void> deleteTransaction(InvestmentTransaction tx) async {
    await _db.deleteTransactionAndRecalculate(tx.id!, tx.assetId);
    // reverse the original cash impact
    final cashDelta = tx.type == 'buy'
        ? tx.units * tx.pricePerUnit
        : -(tx.units * tx.pricePerUnit);
    await _db.adjustCash(cashDelta);
  }

  Future<void> updateAssetPrice(
      int assetId, double price, DateTime updatedAt) =>
      _db.updateAssetPrice(assetId, price, updatedAt);

  Future<void> updateLastPortfolioUpdate(DateTime dt) =>
      _db.updateLastPortfolioUpdate(dt);
}
