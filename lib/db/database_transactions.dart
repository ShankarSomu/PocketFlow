part of 'database.dart';

// ── Transactions ──────────────────────────────────────────────────────────────

extension AppDatabaseTransactions on AppDatabase {
  static Future<int> insertTransaction(model.Transaction t) async {
    await DataIntegrityService.validateTransactionBeforeInsert(t);
    final d = await AppDatabase.db();
    final id = await d.insert('transactions', t.toMap()..remove('id'));
    AppLogger.db('insertTransaction', detail: '${t.type} \$${t.amount} ${t.category}');
    final transactionWithId = model.Transaction(
      id: id, type: t.type, amount: t.amount, category: t.category,
      note: t.note, date: t.date, accountId: t.accountId,
      recurringId: t.recurringId, smsSource: t.smsSource,
    );
    NotificationService.notifyTransaction(transactionWithId);
    if (t.type == 'expense') {
      NotificationService.checkBudgetWarnings(t.category, t.date);
    }
    return id;
  }

  static Future<void> updateTransaction(model.Transaction t) async {
    if (t.id == null) throw ArgumentError('Transaction ID is required for updates');
    await (await AppDatabase.db()).update('transactions', t.toMap(),
        where: 'id=?', whereArgs: [t.id]);
    AppLogger.db('updateTransaction', detail: 'id=${t.id} ${t.type} \$${t.amount}');
  }

  static Future<void> deleteTransaction(int id) async {
    await (await AppDatabase.db()).update('transactions',
        {'deleted_at': SoftDeleteHelper.now()}, where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteTransaction', detail: 'id=$id');
  }

  static Future<void> restoreTransaction(int id) async {
    await (await AppDatabase.db()).update('transactions',
        {'deleted_at': null}, where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreTransaction', detail: 'id=$id');
  }

  static Future<void> permanentlyDeleteTransaction(int id) async {
    await (await AppDatabase.db()).delete('transactions',
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteTransaction', detail: 'id=$id');
  }

  static Future<List<model.Transaction>> getTransactions({
    String? type,
    DateTime? from,
    DateTime? to,
    String? keyword,
    int? accountId,
  }) async {
    final d = await AppDatabase.db();
    final where = <String>['deleted_at IS NULL'];
    final args = <dynamic>[];
    if (type != null) { where.add('type = ?'); args.add(type); }
    if (from != null) { where.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null) { where.add('date <= ?'); args.add(to.toIso8601String()); }
    if (keyword != null) {
      where.add('(category LIKE ? OR note LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }
    if (accountId != null) { where.add('account_id = ?'); args.add(accountId); }
    final rows = await d.query('transactions',
        where: where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'date DESC');
    return rows.map(model.Transaction.fromMap).toList();
  }

  static Future<double> monthlyTotal(String type, int month, int year) async {
    final d = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final result = await d.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE deleted_at IS NULL AND type=? AND date>=? AND date<? AND category != 'transfer'",
        [type, start, end]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  static Future<Map<String, double>> monthlyExpenseByCategory(int month, int year) async {
    final d = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final rows = await d.rawQuery(
        'SELECT LOWER(category) as category, SUM(amount) as total FROM transactions '
        "WHERE deleted_at IS NULL AND type='expense' AND category != 'transfer' AND date>=? AND date<? GROUP BY LOWER(category)",
        [start, end]);
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0,
    };
  }

  static Future<double> rangeTotal(String type, DateTime from, DateTime to) async {
    final d = await AppDatabase.db();
    final result = await d.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE deleted_at IS NULL AND type=? AND date>=? AND date<=? AND category != 'transfer'",
        [type, from.toIso8601String(), to.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  static Future<Map<String, double>> rangeExpenseByCategory(DateTime from, DateTime to) async {
    final d = await AppDatabase.db();
    final rows = await d.rawQuery(
        'SELECT LOWER(category) as category, SUM(amount) as total FROM transactions '
        "WHERE deleted_at IS NULL AND type='expense' AND category != 'transfer' AND date>=? AND date<=? GROUP BY LOWER(category)",
        [from.toIso8601String(), to.toIso8601String()]);
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0,
    };
  }

  static Future<List<model.Transaction>> getDeletedTransactions() async {
    final rows = await (await AppDatabase.db()).query('transactions',
        where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');
    return rows.map(model.Transaction.fromMap).toList();
  }
}
