import '../../db/database.dart';
import '../../models/account.dart';
import '../account_repository.dart';

/// SQLite implementation of AccountRepository
class AccountRepositoryImpl implements AccountRepository {
  @override
  Future<int> insert(Account account) async {
    final db = await AppDatabase.db;
    return db.insert('accounts', account.toMap()..remove('id'));
  }

  @override
  Future<List<Account>> getAll() async {
    final db = await AppDatabase.db;
    final rows = await db.query('accounts', orderBy: 'name ASC');
    return rows.map(Account.fromMap).toList();
  }

  @override
  Future<void> update(Account account) async {
    final db = await AppDatabase.db;
    await db.update('accounts', account.toMap(), 
        where: 'id=?', whereArgs: [account.id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await AppDatabase.db;
    // Nullify account_id on all transactions before deleting
    await db.update('transactions', {'account_id': null},
        where: 'account_id=?', whereArgs: [id]);
    await db.delete('accounts', where: 'id=?', whereArgs: [id]);
  }

  @override
  Future<double> getBalance(int accountId, Account account) async {
    final db = await AppDatabase.db;
    final income = await db.rawQuery(
      "SELECT SUM(amount) as t FROM transactions WHERE account_id=? AND type='income'",
      [accountId],
    );
    final expense = await db.rawQuery(
      "SELECT SUM(amount) as t FROM transactions WHERE account_id=? AND type='expense'",
      [accountId],
    );
    final i = (income.first['t'] as num?)?.toDouble() ?? 0;
    final e = (expense.first['t'] as num?)?.toDouble() ?? 0;
    if (account.type == 'credit') return account.balance + e - i;
    return account.balance + i - e;
  }

  @override
  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final db = await AppDatabase.db;
    final now = date ?? DateTime.now();
    final memo = note ?? 'transfer';
    
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': 'transfer',
        'note': memo,
        'date': now.toIso8601String(),
        'account_id': fromId,
      });
      await txn.insert('transactions', {
        'type': 'income',
        'amount': amount,
        'category': 'transfer',
        'note': memo,
        'date': now.toIso8601String(),
        'account_id': toId,
      });
    });
  }
}
