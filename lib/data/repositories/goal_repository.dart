import '../database/database_helper.dart';
import '../models/goal_model.dart';

class GoalRepository {
  final DatabaseHelper _db;
  GoalRepository(this._db);

  Future<List<Goal>> getAll() => _db.getAllGoals();
  Future<int> add(Goal g) => _db.insertGoal(g);
  Future<void> update(Goal g) => _db.updateGoal(g);
  Future<void> delete(int id) => _db.deleteGoal(id);

  Future<void> addToSaved(int id, double amount) async {
    final goals = await _db.getAllGoals();
    final goal = goals.firstWhere((g) => g.id == id);
    final updated = goal.copyWith(savedAmount: goal.savedAmount + amount);
    await _db.updateGoal(updated);
  }
}
