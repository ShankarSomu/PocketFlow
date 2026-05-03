part of 'database.dart';

// ── Budgets ───────────────────────────────────────────────────────────────────

extension AppDatabaseBudgets on AppDatabase {
  static Future<void> upsertBudget(Budget b) async =>
      (await AppDatabase.db()).insert('budgets', b.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Budget>> getBudgets(int month, int year) async {
    final rows = await (await AppDatabase.db()).query('budgets',
        where: 'deleted_at IS NULL AND month=? AND year=?',
        whereArgs: [month, year]);
    return rows.map(Budget.fromMap).toList();
  }
}

// ── Savings Goals ─────────────────────────────────────────────────────────────

extension AppDatabaseGoals on AppDatabase {
  static Future<int> insertGoal(Goal g) async =>
      (await AppDatabase.db()).insert('savings_goals', g.toMap()..remove('id'));

  static Future<List<Goal>> getGoals() async {
    final rows = await (await AppDatabase.db()).query('savings_goals',
        where: 'deleted_at IS NULL', orderBy: 'priority ASC, name ASC');
    return rows.map(Goal.fromMap).toList();
  }

  static Future<void> updateGoal(Goal g) async =>
      (await AppDatabase.db()).update('savings_goals', g.toMap(),
          where: 'id=?', whereArgs: [g.id]);

  static Future<void> updateGoalSaved(int id, double saved) async =>
      (await AppDatabase.db()).update('savings_goals', {'saved': saved},
          where: 'id=?', whereArgs: [id]);

  static Future<void> deleteGoal(int id) async {
    await (await AppDatabase.db()).update('savings_goals',
        {'deleted_at': SoftDeleteHelper.now()}, where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteGoal', detail: 'id=$id');
  }

  static Future<void> restoreGoal(int id) async {
    await (await AppDatabase.db()).update('savings_goals',
        {'deleted_at': null}, where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreGoal', detail: 'id=$id');
  }

  static Future<void> permanentlyDeleteGoal(int id) async {
    await (await AppDatabase.db()).delete('savings_goals',
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteGoal', detail: 'id=$id');
  }

  static Future<List<Goal>> getDeletedGoals() async {
    final rows = await (await AppDatabase.db()).query('savings_goals',
        where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');
    return rows.map(Goal.fromMap).toList();
  }
}

// ── Recurring Transactions ────────────────────────────────────────────────────

extension AppDatabaseRecurring on AppDatabase {
  static Future<int> insertRecurring(RecurringTransaction r) async =>
      (await AppDatabase.db()).insert('recurring_transactions', r.toMap()..remove('id'));

  static Future<List<RecurringTransaction>> getRecurring() async {
    final rows = await (await AppDatabase.db()).query('recurring_transactions',
        where: 'deleted_at IS NULL', orderBy: 'next_due_date ASC');
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  static Future<void> updateRecurring(RecurringTransaction r) async =>
      (await AppDatabase.db()).update('recurring_transactions', r.toMap(),
          where: 'id=?', whereArgs: [r.id]);

  static Future<void> deleteRecurring(int id) async {
    await (await AppDatabase.db()).update('recurring_transactions',
        {'deleted_at': SoftDeleteHelper.now()}, where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteRecurring', detail: 'id=$id');
  }

  static Future<void> restoreRecurring(int id) async {
    await (await AppDatabase.db()).update('recurring_transactions',
        {'deleted_at': null}, where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreRecurring', detail: 'id=$id');
  }

  static Future<void> permanentlyDeleteRecurring(int id) async {
    await (await AppDatabase.db()).delete('recurring_transactions',
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteRecurring', detail: 'id=$id');
  }

  static Future<List<RecurringTransaction>> getDeletedRecurring() async {
    final rows = await (await AppDatabase.db()).query('recurring_transactions',
        where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');
    return rows.map(RecurringTransaction.fromMap).toList();
  }
}
