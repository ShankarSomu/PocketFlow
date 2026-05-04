part of 'database.dart';

// ── Execution Log & Export ────────────────────────────────────────────────────

extension AppDatabaseExecutionLog on AppDatabase {
  static Future<bool> hasExecutionLog({
    required String ruleType,
    required int ruleId,
    required DateTime executionDate,
  }) async {
    final d = await AppDatabase.db();
    final dateKey = _executionDateKey(executionDate);
    final rows = await d.query(
      'execution_logs',
      columns: ['id'],
      where: 'rule_type = ? AND rule_id = ? AND execution_date = ?',
      whereArgs: [ruleType, ruleId, dateKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<void> insertExecutionLog({
    required String ruleType,
    required int ruleId,
    required DateTime executionDate,
    int? transactionId,
  }) async {
    final d = await AppDatabase.db();
    await d.insert(
      'execution_logs',
      {
        'rule_type': ruleType,
        'rule_id': ruleId,
        'execution_date': _executionDateKey(executionDate),
        'transaction_id': transactionId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static String _executionDateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static Future<DeletedItemsStats> getDeletedItemsStats() async {
    final d = await AppDatabase.db();
    final txnCount = await d.rawQuery(
        'SELECT COUNT(*) as count FROM transactions WHERE deleted_at IS NOT NULL');
    final accountCount = await d.rawQuery(
        'SELECT COUNT(*) as count FROM accounts WHERE deleted_at IS NOT NULL');
    final budgetCount = await d.rawQuery(
        'SELECT COUNT(*) as count FROM budgets WHERE deleted_at IS NOT NULL');
    final goalCount = await d.rawQuery(
        'SELECT COUNT(*) as count FROM savings_goals WHERE deleted_at IS NOT NULL');
    final recurringCount = await d.rawQuery(
        'SELECT COUNT(*) as count FROM recurring_transactions WHERE deleted_at IS NOT NULL');
    return DeletedItemsStats(
      transactions: (txnCount.first['count'] as num?)?.toInt() ?? 0,
      accounts: (accountCount.first['count'] as num?)?.toInt() ?? 0,
      budgets: (budgetCount.first['count'] as num?)?.toInt() ?? 0,
      goals: (goalCount.first['count'] as num?)?.toInt() ?? 0,
      recurring: (recurringCount.first['count'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<int> purgeOldDeletedItems({int retentionDays = 30}) async {
    final d = await AppDatabase.db();
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    int totalPurged = 0;
    totalPurged += await d.delete('transactions',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    totalPurged += await d.delete('accounts',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    totalPurged += await d.delete('budgets',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    totalPurged += await d.delete('savings_goals',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    totalPurged += await d.delete('recurring_transactions',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    AppLogger.db('purgeOldDeletedItems',
        detail: 'Purged $totalPurged items older than $retentionDays days');
    return totalPurged;
  }

  static Future<void> deleteAllData() async {
    AppLogger.userAction('deleteAllData', detail: 'All data wiped');
    final d = await AppDatabase.db();
    await d.transaction((txn) async {
      // ── Core financial data ────────────────────────────────────────────────
      await txn.delete('recurring_transactions');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('accounts');

      // ── SMS Intelligence pipeline state ────────────────────────────────────
      // These must be cleared so that re-scan treats all messages as new and
      // doesn't skip them as duplicates via content-hash dedup.
      await txn.delete('sms_events');
      await txn.delete('sms_clusters');
      await txn.delete('sms_pattern_cache');
      await txn.delete('sms_audit_log');
      await txn.delete('pending_actions');

      // ── SMS learning / negative-sample tables ─────────────────────────────
      await txn.delete('sms_negative_samples');
      await txn.delete('parsing_feedback');
      await txn.delete('user_corrections');
      await txn.delete('feedback_events');
    });
  }

  static Future<String> exportCsv() async {
    final txns = await AppDatabaseTransactions.getTransactions();
    final accounts = await AppDatabaseAccounts.getAccounts();
    final accountMap = {for (final a in accounts) a.id: a.name};
    final lines = ['type,amount,category,note,date,account'];
    for (final t in txns) {
      lines.add(
        '${t.type},${t.amount},${t.category},'
        '${t.note ?? ''},${t.date.toIso8601String()},'
        '${accountMap[t.accountId] ?? ''}',
      );
    }
    return lines.join('\n');
  }
}
