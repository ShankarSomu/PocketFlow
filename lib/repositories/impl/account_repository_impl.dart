import '../../db/database.dart';
import '../../models/account.dart';
import '../account_repository.dart';

/// SQLite implementation of AccountRepository
class AccountRepositoryImpl implements AccountRepository {
  @override
  Future<int> insert(Account account) async {
    final db = await AppDatabase.db();
    final accountMap = account.toMap()..remove('id');
    // For liability accounts, negate the opening balance so it displays correctly
    if (account.isLiability && accountMap['balance'] != null && accountMap['balance'] > 0) {
      accountMap['balance'] = -(accountMap['balance'] as double);
    }
    return db.insert('accounts', accountMap);
  }

  @override
  Future<List<Account>> getAll() async {
    final db = await AppDatabase.db();
    final rows = await db.query('accounts', orderBy: 'name ASC');
    return rows.map(Account.fromMap).toList();
  }

  @override
  Future<void> update(Account account) async {
    final db = await AppDatabase.db();
    final accountMap = account.toMap();
    // For liability accounts, ensure the balance is stored as negative
    if (account.isLiability && accountMap['balance'] != null && accountMap['balance'] > 0) {
      accountMap['balance'] = -(accountMap['balance'] as double);
    }
    await db.update('accounts', accountMap, 
        where: 'id=?', whereArgs: [account.id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await AppDatabase.db();
    
    // Check if account has transactions
    final txnCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE account_id = ?',
      [id],
    );
    final count = (txnCount.first['count'] as int?) ?? 0;
    
    if (count > 0) {
      throw Exception(
        'Cannot delete account with transactions. '
        'Account has $count transaction(s). Use soft delete instead.'
      );
    }
    
    await db.delete('accounts', where: 'id=?', whereArgs: [id]);
  }

  @override
  Future<double> getBalance(int accountId, Account account) async {
    final db = await AppDatabase.db();
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
    
    // Standardized formula based on account type
    if (account.isLiability) {
      // Liabilities: stored as negative, expenses increase debt (more negative), income reduces debt (less negative)
      return account.balance - e + i;
    } else {
      return account.balance + i - e;
    }
  }

  @override
  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final db = await AppDatabase.db();
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
