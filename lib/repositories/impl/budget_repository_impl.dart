import 'package:sqflite/sqflite.dart';
import '../../db/database.dart';
import '../../models/budget.dart';
import '../budget_repository.dart';

/// SQLite implementation of BudgetRepository
class BudgetRepositoryImpl implements BudgetRepository {
  @override
  Future<void> upsert(Budget budget) async {
    final db = await AppDatabase.db;
    await db.insert('budgets', budget.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Budget>> getForMonth(int month, int year) async {
    final db = await AppDatabase.db;
    final rows = await db.query('budgets',
        where: 'month=? AND year=?', whereArgs: [month, year]);
    return rows.map(Budget.fromMap).toList();
  }
}
