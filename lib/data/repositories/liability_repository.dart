import '../database/database_helper.dart';
import '../models/liability_model.dart';

class LiabilityRepository {
  final DatabaseHelper _db;
  LiabilityRepository(this._db);

  Future<List<Liability>> getAll() => _db.getAllLiabilities();
  Future<int> add(Liability l) => _db.insertLiability(l);
  Future<void> update(Liability l) => _db.updateLiability(l);
  Future<void> delete(int id) => _db.deleteLiability(id);

  Future<void> makePayment(int id, double payment) async {
    final all = await _db.getAllLiabilities();
    final liability = all.firstWhere((l) => l.id == id);
    final newBalance =
        (liability.outstandingBalance - payment).clamp(0.0, double.infinity);
    final updated = liability.copyWith(outstandingBalance: newBalance);
    await _db.updateLiability(updated);
  }
}
