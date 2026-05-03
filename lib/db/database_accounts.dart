part of 'database.dart';

// ── Accounts ─────────────────────────────────────────────────────────────────

extension AppDatabaseAccounts on AppDatabase {
  static Future<int> insertAccount(Account a) async {
    final accountMap = a.toMap()..remove('id');
    if (a.isLiability && accountMap['balance'] != null && accountMap['balance'] > 0) {
      accountMap['balance'] = -(accountMap['balance'] as double);
    }
    return (await AppDatabase.db()).insert('accounts', accountMap);
  }

  static Future<List<Account>> getAccounts() async {
    final rows = await (await AppDatabase.db()).query('accounts',
        where: 'deleted_at IS NULL', orderBy: 'name ASC');
    return rows.map(Account.fromMap).toList();
  }

  static Future<Account?> findAccountByIdentity({
    String? institutionName,
    String? accountIdentifier,
  }) async {
    if (institutionName == null && accountIdentifier == null) return null;
    final d = await AppDatabase.db();
    if (institutionName != null && accountIdentifier != null) {
      final results = await d.query('accounts',
          where: 'institution_name = ? AND account_identifier = ? AND deleted_at IS NULL',
          whereArgs: [institutionName, accountIdentifier], limit: 1);
      if (results.isNotEmpty) return Account.fromMap(results.first);
    }
    if (accountIdentifier != null) {
      final results = await d.query('accounts',
          where: 'account_identifier = ? AND deleted_at IS NULL',
          whereArgs: [accountIdentifier], limit: 1);
      if (results.isNotEmpty) return Account.fromMap(results.first);
    }
    if (institutionName != null) {
      final results = await d.query('accounts',
          where: 'institution_name = ? AND deleted_at IS NULL',
          whereArgs: [institutionName], limit: 1);
      if (results.isNotEmpty) return Account.fromMap(results.first);
    }
    return null;
  }

  static Future<void> updateAccount(Account a) async {
    final accountMap = a.toMap();
    if (a.isLiability && accountMap['balance'] != null && accountMap['balance'] > 0) {
      accountMap['balance'] = -(accountMap['balance'] as double);
    }
    await (await AppDatabase.db()).update('accounts', accountMap,
        where: 'id=?', whereArgs: [a.id]);
  }

  static Future<void> deleteAccount(int id) async {
    final d = await AppDatabase.db();
    await d.update('accounts', {'deleted_at': SoftDeleteHelper.now()},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteAccount', detail: 'id=$id');
  }

  static Future<void> restoreAccount(int id) async {
    await (await AppDatabase.db()).update('accounts', {'deleted_at': null},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreAccount', detail: 'id=$id');
  }

  static Future<void> permanentlyDeleteAccount(int id) async {
    final d = await AppDatabase.db();
    final txnCount = await d.rawQuery(
        'SELECT COUNT(*) as count FROM transactions WHERE account_id = ?', [id]);
    final count = (txnCount.first['count'] as int?) ?? 0;
    if (count > 0) {
      throw Exception(
          'Cannot delete account with transactions. '
          'Account has $count transaction(s). Use soft delete instead.');
    }
    await d.delete('accounts', where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteAccount', detail: 'id=$id');
  }

  static Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final d = await AppDatabase.db();
    final now = date ?? DateTime.now();
    final memo = note ?? 'transfer';
    await d.transaction((txn) async {
      await txn.insert('transactions', {
        'type': 'expense', 'amount': amount, 'category': 'transfer',
        'note': memo, 'date': now.toIso8601String(),
        'account_id': fromId, 'from_account_id': fromId, 'to_account_id': toId,
      });
      await txn.insert('transactions', {
        'type': 'income', 'amount': amount, 'category': 'transfer',
        'note': memo, 'date': now.toIso8601String(),
        'account_id': toId, 'from_account_id': fromId, 'to_account_id': toId,
      });
    });
    final isValid = await validateTransferIntegrity();
    if (!isValid) {
      AppLogger.warn('Transfer created but integrity check failed',
          detail: 'Amount: \$${amount.toStringAsFixed(2)}, From: $fromId, To: $toId',
          category: LogCategory.database);
    }
  }

  static Future<bool> validateTransferIntegrity() async {
    final d = await AppDatabase.db();
    final transferExpenses = await d.rawQuery(
        "SELECT SUM(amount) as total FROM transactions "
        "WHERE deleted_at IS NULL AND category = 'transfer' AND type = 'expense'");
    final transferIncome = await d.rawQuery(
        "SELECT SUM(amount) as total FROM transactions "
        "WHERE deleted_at IS NULL AND category = 'transfer' AND type = 'income'");
    final expenseTotal = (transferExpenses.first['total'] as num?)?.toDouble() ?? 0;
    final incomeTotal = (transferIncome.first['total'] as num?)?.toDouble() ?? 0;
    final difference = (expenseTotal - incomeTotal).abs();
    final isValid = difference < 0.01;
    if (!isValid) {
      AppLogger.err('Transfer integrity violation',
          'Expense: \$${expenseTotal.toStringAsFixed(2)}, '
          'Income: \$${incomeTotal.toStringAsFixed(2)}, '
          'Difference: \$${difference.toStringAsFixed(2)}',
          category: LogCategory.database);
    }
    return isValid;
  }

  static Future<double> accountBalance(int accountId, Account account) async {
    final d = await AppDatabase.db();
    final income = await d.rawQuery(
        "SELECT SUM(amount) as t FROM transactions WHERE deleted_at IS NULL AND account_id=? AND type='income'",
        [accountId]);
    final expense = await d.rawQuery(
        "SELECT SUM(amount) as t FROM transactions WHERE deleted_at IS NULL AND account_id=? AND type='expense'",
        [accountId]);
    final i = (income.first['t'] as num?)?.toDouble() ?? 0;
    final e = (expense.first['t'] as num?)?.toDouble() ?? 0;
    if (account.isLiability) {
      return account.balance - e + i;
    } else {
      return account.balance + i - e;
    }
  }

  static Future<List<Account>> getDeletedAccounts() async {
    final rows = await (await AppDatabase.db()).query('accounts',
        where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');
    return rows.map(Account.fromMap).toList();
  }
}
