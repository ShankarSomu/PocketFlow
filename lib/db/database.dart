import 'package:path/path.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database_optimizer.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/deletable_entity.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart' as model;
import '../services/data_integrity_service.dart';
import '../services/notification_service.dart';
import 'seeds/account_extraction_seed.dart';
import 'seeds/sms_keywords_seed.dart';

part 'database_schema.dart';
part 'database_migrations.dart';
part 'database_categories.dart';
part 'database_accounts.dart';
part 'database_transactions.dart';
part 'database_budgets.dart';
part 'database_execution_log.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> db() async {
    _db ??= await _init();
    return _db!;
  }

  // ignore: invalid_use_of_visible_for_testing_member
  static void setDatabaseForTesting(Database database) {
    _db = database;
  }

  // ignore: invalid_use_of_visible_for_testing_member
  static void resetForTesting() {
    _db = null;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'pocket_flow.db');
    return openDatabase(
      path,
      version: 27,
      onCreate: (db, _) => _AppDatabaseSchema._createAll(db),
      onUpgrade: (db, oldVersion, _) =>
          _AppDatabaseMigrations._migrate(db, oldVersion),
      onOpen: (db) async {
        _runAsyncMaintenance(db);
      },
    );
  }

  static Future<void> _runAsyncMaintenance(Database db) async {
    try {
      final count =
          await db.rawQuery('SELECT COUNT(*) as count FROM categories');
      final subCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM categories WHERE parent_id IS NOT NULL');
      if (count.isNotEmpty && subCount.isNotEmpty) {
        final categoryCount = (count.first['count'] as num?)?.toInt() ?? 0;
        final subcategoryCount = (subCount.first['count'] as num?)?.toInt() ?? 0;
        if (categoryCount == 0 || (categoryCount > 0 && subcategoryCount == 0)) {
          await db.delete('categories');
          await _AppDatabaseSchema._seedDefaultCategories(db);
        }
      }
      await DatabaseOptimizer.createIndexes(db);
    } catch (e) {
      AppLogger.log(LogLevel.error, LogCategory.database, 'Maintenance Error',
          detail: e.toString());
    }
  }

  // ── Categories ─────────────────────────────────────────────────────────────
  static Future<List<Category>> getCategories() =>
      AppDatabaseCategories.getCategories();
  static Future<List<Category>> getTopLevelCategories() =>
      AppDatabaseCategories.getTopLevelCategories();
  static Future<List<Category>> getSubcategories(int parentId) =>
      AppDatabaseCategories.getSubcategories(parentId);
  static Future<int> insertCategory(Category c) =>
      AppDatabaseCategories.insertCategory(c);
  static Future<void> updateCategory(Category c) =>
      AppDatabaseCategories.updateCategory(c);
  static Future<void> deleteCategory(int id) =>
      AppDatabaseCategories.deleteCategory(id);

  // ── Accounts ───────────────────────────────────────────────────────────────
  static Future<int> insertAccount(Account a) =>
      AppDatabaseAccounts.insertAccount(a);
  static Future<List<Account>> getAccounts() =>
      AppDatabaseAccounts.getAccounts();
  static Future<Account?> findAccountByIdentity({
    String? institutionName,
    String? accountIdentifier,
  }) =>
      AppDatabaseAccounts.findAccountByIdentity(
          institutionName: institutionName,
          accountIdentifier: accountIdentifier);
  static Future<void> updateAccount(Account a) =>
      AppDatabaseAccounts.updateAccount(a);
  static Future<void> deleteAccount(int id) =>
      AppDatabaseAccounts.deleteAccount(id);
  static Future<void> restoreAccount(int id) =>
      AppDatabaseAccounts.restoreAccount(id);
  static Future<void> permanentlyDeleteAccount(int id) =>
      AppDatabaseAccounts.permanentlyDeleteAccount(id);
  static Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  }) =>
      AppDatabaseAccounts.transfer(
          fromId: fromId, toId: toId, amount: amount, note: note, date: date);
  static Future<bool> validateTransferIntegrity() =>
      AppDatabaseAccounts.validateTransferIntegrity();
  static Future<double> accountBalance(int accountId, Account account) =>
      AppDatabaseAccounts.accountBalance(accountId, account);
  static Future<List<Account>> getDeletedAccounts() =>
      AppDatabaseAccounts.getDeletedAccounts();

  // ── Transactions ───────────────────────────────────────────────────────────
  static Future<int> insertTransaction(model.Transaction t) =>
      AppDatabaseTransactions.insertTransaction(t);
  static Future<void> updateTransaction(model.Transaction t) =>
      AppDatabaseTransactions.updateTransaction(t);
  static Future<void> deleteTransaction(int id) =>
      AppDatabaseTransactions.deleteTransaction(id);
  static Future<void> restoreTransaction(int id) =>
      AppDatabaseTransactions.restoreTransaction(id);
  static Future<void> permanentlyDeleteTransaction(int id) =>
      AppDatabaseTransactions.permanentlyDeleteTransaction(id);
  static Future<List<model.Transaction>> getTransactions({
    String? type,
    DateTime? from,
    DateTime? to,
    String? keyword,
    int? accountId,
  }) =>
      AppDatabaseTransactions.getTransactions(
          type: type, from: from, to: to, keyword: keyword, accountId: accountId);
  static Future<double> monthlyTotal(String type, int month, int year) =>
      AppDatabaseTransactions.monthlyTotal(type, month, year);
  static Future<Map<String, double>> monthlyExpenseByCategory(
          int month, int year) =>
      AppDatabaseTransactions.monthlyExpenseByCategory(month, year);
  static Future<double> rangeTotal(String type, DateTime from, DateTime to) =>
      AppDatabaseTransactions.rangeTotal(type, from, to);
  static Future<Map<String, double>> rangeExpenseByCategory(
          DateTime from, DateTime to) =>
      AppDatabaseTransactions.rangeExpenseByCategory(from, to);
  static Future<List<model.Transaction>> getDeletedTransactions() =>
      AppDatabaseTransactions.getDeletedTransactions();

  // ── Budgets ────────────────────────────────────────────────────────────────
  static Future<void> upsertBudget(Budget b) =>
      AppDatabaseBudgets.upsertBudget(b);
  static Future<List<Budget>> getBudgets(int month, int year) =>
      AppDatabaseBudgets.getBudgets(month, year);

  // ── Savings Goals ──────────────────────────────────────────────────────────
  static Future<int> insertGoal(Goal g) => AppDatabaseGoals.insertGoal(g);
  static Future<List<Goal>> getGoals() => AppDatabaseGoals.getGoals();
  static Future<void> updateGoal(Goal g) => AppDatabaseGoals.updateGoal(g);
  static Future<void> updateGoalSaved(int id, double saved) =>
      AppDatabaseGoals.updateGoalSaved(id, saved);
  static Future<void> deleteGoal(int id) => AppDatabaseGoals.deleteGoal(id);
  static Future<void> restoreGoal(int id) => AppDatabaseGoals.restoreGoal(id);
  static Future<void> permanentlyDeleteGoal(int id) =>
      AppDatabaseGoals.permanentlyDeleteGoal(id);
  static Future<List<Goal>> getDeletedGoals() =>
      AppDatabaseGoals.getDeletedGoals();

  // ── Recurring ──────────────────────────────────────────────────────────────
  static Future<int> insertRecurring(RecurringTransaction r) =>
      AppDatabaseRecurring.insertRecurring(r);
  static Future<List<RecurringTransaction>> getRecurring() =>
      AppDatabaseRecurring.getRecurring();
  static Future<void> updateRecurring(RecurringTransaction r) =>
      AppDatabaseRecurring.updateRecurring(r);
  static Future<void> deleteRecurring(int id) =>
      AppDatabaseRecurring.deleteRecurring(id);
  static Future<void> restoreRecurring(int id) =>
      AppDatabaseRecurring.restoreRecurring(id);
  static Future<void> permanentlyDeleteRecurring(int id) =>
      AppDatabaseRecurring.permanentlyDeleteRecurring(id);
  static Future<List<RecurringTransaction>> getDeletedRecurring() =>
      AppDatabaseRecurring.getDeletedRecurring();

  // ── Execution Log & Export ─────────────────────────────────────────────────
  static Future<bool> hasExecutionLog({
    required String ruleType,
    required int ruleId,
    required DateTime executionDate,
  }) =>
      AppDatabaseExecutionLog.hasExecutionLog(
          ruleType: ruleType, ruleId: ruleId, executionDate: executionDate);
  static Future<void> insertExecutionLog({
    required String ruleType,
    required int ruleId,
    required DateTime executionDate,
    int? transactionId,
  }) =>
      AppDatabaseExecutionLog.insertExecutionLog(
          ruleType: ruleType,
          ruleId: ruleId,
          executionDate: executionDate,
          transactionId: transactionId);
  static Future<DeletedItemsStats> getDeletedItemsStats() =>
      AppDatabaseExecutionLog.getDeletedItemsStats();
  static Future<int> purgeOldDeletedItems({int retentionDays = 30}) =>
      AppDatabaseExecutionLog.purgeOldDeletedItems(
          retentionDays: retentionDays);
  static Future<void> deleteAllData() =>
      AppDatabaseExecutionLog.deleteAllData();
  static Future<String> exportCsv() => AppDatabaseExecutionLog.exportCsv();
}
