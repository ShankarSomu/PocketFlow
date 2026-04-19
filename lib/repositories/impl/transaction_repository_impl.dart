import '../../db/database.dart';
import '../../models/transaction.dart' as model;
import '../../services/app_logger.dart';
import '../transaction_repository.dart';

/// SQLite implementation of TransactionRepository
class TransactionRepositoryImpl implements TransactionRepository {
  @override
  Future<int> insert(model.Transaction transaction) async {
    final db = await AppDatabase.db();
    final id = await db.insert('transactions', transaction.toMap()..remove('id'));
    AppLogger.db('insertTransaction', detail: '${transaction.type} \$${transaction.amount} ${transaction.category}');
    return id;
  }

  @override
  Future<void> update(model.Transaction transaction) async {
    final db = await AppDatabase.db();
    await db.update('transactions', transaction.toMap(), 
        where: 'id=?', whereArgs: [transaction.id]);
    AppLogger.db('updateTransaction', detail: 'id=${transaction.id} ${transaction.type} \$${transaction.amount}');
  }

  @override
  Future<void> delete(int id) async {
    final db = await AppDatabase.db();
    await db.delete('transactions', where: 'id=?', whereArgs: [id]);
    AppLogger.db('deleteTransaction', detail: 'id=$id');
  }

  @override
  Future<List<model.Transaction>> getAll({
    String? type,
    DateTime? from,
    DateTime? to,
    String? keyword,
    int? accountId,
  }) async {
    final db = await AppDatabase.db();
    final where = <String>[];
    final args = <dynamic>[];
    
    if (type != null) { 
      where.add('type = ?'); 
      args.add(type); 
    }
    if (from != null) { 
      where.add('date >= ?'); 
      args.add(from.toIso8601String()); 
    }
    if (to != null) { 
      where.add('date <= ?'); 
      args.add(to.toIso8601String()); 
    }
    if (keyword != null) {
      where.add('(category LIKE ? OR note LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }
    if (accountId != null) { 
      where.add('account_id = ?'); 
      args.add(accountId); 
    }
    
    final rows = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map(model.Transaction.fromMap).toList();
  }

  @override
  Future<double> getMonthlyTotal(String type, int month, int year) async {
    final db = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type=? AND date>=? AND date<? AND category != 'transfer'",
      [type, start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<Map<String, double>> getMonthlyExpenseByCategory(int month, int year) async {
    final db = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT LOWER(category) as category, SUM(amount) as total FROM transactions '
      "WHERE type='expense' AND category != 'transfer' AND date>=? AND date<? GROUP BY LOWER(category)",
      [start, end],
    );
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0
    };
  }

  @override
  Future<double> getRangeTotal(String type, DateTime from, DateTime to) async {
    final db = await AppDatabase.db();
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type=? AND date>=? AND date<=? AND category != 'transfer'",
      [type, from.toIso8601String(), to.toIso8601String()],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<Map<String, double>> getRangeExpenseByCategory(DateTime from, DateTime to) async {
    final db = await AppDatabase.db();
    final rows = await db.rawQuery(
      'SELECT LOWER(category) as category, SUM(amount) as total FROM transactions '
      "WHERE type='expense' AND category != 'transfer' AND date>=? AND date<=? GROUP BY LOWER(category)",
      [from.toIso8601String(), to.toIso8601String()],
    );
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0
    };
  }
}
