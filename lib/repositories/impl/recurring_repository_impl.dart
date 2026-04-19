import '../../db/database.dart';
import '../../models/recurring_transaction.dart';
import '../recurring_repository.dart';

/// SQLite implementation of RecurringRepository
class RecurringRepositoryImpl implements RecurringRepository {
  @override
  Future<int> insert(RecurringTransaction transaction) async {
    final db = await AppDatabase.db();
    return db.insert('recurring_transactions', transaction.toMap()..remove('id'));
  }

  @override
  Future<List<RecurringTransaction>> getAll() async {
    final db = await AppDatabase.db();
    final rows = await db.query('recurring_transactions', orderBy: 'next_due_date ASC');
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  @override
  Future<void> update(RecurringTransaction transaction) async {
    final db = await AppDatabase.db();
    await db.update('recurring_transactions', transaction.toMap(),
        where: 'id=?', whereArgs: [transaction.id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await AppDatabase.db();
    await db.delete('recurring_transactions', where: 'id=?', whereArgs: [id]);
  }
}
