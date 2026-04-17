import '../../db/database.dart';
import '../../models/savings_goal.dart';
import '../savings_repository.dart';

/// SQLite implementation of SavingsRepository
class SavingsRepositoryImpl implements SavingsRepository {
  @override
  Future<int> insert(SavingsGoal goal) async {
    final db = await AppDatabase.db;
    return db.insert('savings_goals', goal.toMap()..remove('id'));
  }

  @override
  Future<List<SavingsGoal>> getAll() async {
    final db = await AppDatabase.db;
    final rows = await db.query('savings_goals', orderBy: 'priority ASC, name ASC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  @override
  Future<void> update(SavingsGoal goal) async {
    final db = await AppDatabase.db;
    await db.update('savings_goals', goal.toMap(), 
        where: 'id=?', whereArgs: [goal.id]);
  }

  @override
  Future<void> updateSaved(int id, double saved) async {
    final db = await AppDatabase.db;
    await db.update('savings_goals', {'saved': saved}, 
        where: 'id=?', whereArgs: [id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await AppDatabase.db;
    await db.delete('savings_goals', where: 'id=?', whereArgs: [id]);
  }
}
