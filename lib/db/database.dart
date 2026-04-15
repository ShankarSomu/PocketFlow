import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as model;
import '../models/budget.dart';
import '../models/savings_goal.dart';
import '../models/account.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import 'package:pocket_flow/services/app_logger.dart';

// Wrap DB init to log errors


class AppDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'pocket_flow.db');
    return openDatabase(path, version: 8,
      onCreate: (db, _) => _createAll(db),
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS accounts('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, type TEXT NOT NULL, '
            'balance REAL NOT NULL DEFAULT 0, last4 TEXT)');
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
          await db.execute(
            'CREATE TABLE IF NOT EXISTS budgets('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'category TEXT NOT NULL, `limit` REAL NOT NULL, '
            'month INTEGER NOT NULL, year INTEGER NOT NULL, '
            'UNIQUE(category, month, year))');
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS recurring_transactions('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'type TEXT NOT NULL, amount REAL NOT NULL, '
            'category TEXT NOT NULL, note TEXT, '
            'account_id INTEGER REFERENCES accounts(id), '
            'frequency TEXT NOT NULL, '
            'next_due_date TEXT NOT NULL, '
            'is_active INTEGER NOT NULL DEFAULT 1)');
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE savings_goals ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
          await db.execute(
              'ALTER TABLE savings_goals ADD COLUMN priority INTEGER NOT NULL DEFAULT 999');
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS categories('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, '
            'parent_id INTEGER REFERENCES categories(id), '
            'is_default INTEGER NOT NULL DEFAULT 0, '
            'icon TEXT NOT NULL DEFAULT "📁", '
            'color TEXT NOT NULL DEFAULT "#6C63FF")');
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN recurring_id INTEGER REFERENCES recurring_transactions(id)');
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE recurring_transactions ADD COLUMN to_account_id INTEGER REFERENCES accounts(id)');
          await db.execute(
            'ALTER TABLE recurring_transactions ADD COLUMN goal_id INTEGER REFERENCES savings_goals(id)');
        }
        if (oldVersion < 8) {
          await db.execute(
              'ALTER TABLE accounts ADD COLUMN due_date_day INTEGER');
          await db.execute(
              'ALTER TABLE accounts ADD COLUMN credit_limit REAL');
        }
      },
    );
  }

  static Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        last4 TEXT,
        due_date_day INTEGER,
        credit_limit REAL
      )''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        account_id INTEGER REFERENCES accounts(id),
        recurring_id INTEGER REFERENCES recurring_transactions(id)
      )''');
    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        `limit` REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        UNIQUE(category, month, year)
      )''');
    await db.execute('''
      CREATE TABLE recurring_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        account_id INTEGER REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        goal_id INTEGER REFERENCES savings_goals(id),
        frequency TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parent_id INTEGER REFERENCES categories(id),
        is_default INTEGER NOT NULL DEFAULT 0,
        icon TEXT NOT NULL DEFAULT '📁',
        color TEXT NOT NULL DEFAULT '#6C63FF'
      )''');
    await db.execute('''
      CREATE TABLE savings_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        target REAL NOT NULL,
        saved REAL NOT NULL DEFAULT 0,
        account_id INTEGER REFERENCES accounts(id),
        priority INTEGER NOT NULL DEFAULT 999
      )''');
  }

  // ── Categories ────────────────────────────────────────────────────────────

  static Future<List<Category>> getCategories() async {
    final rows = await (await db).query('categories',
        orderBy: 'parent_id ASC, name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<List<Category>> getTopLevelCategories() async {
    final rows = await (await db).query('categories',
        where: 'parent_id IS NULL', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<List<Category>> getSubcategories(int parentId) async {
    final rows = await (await db).query('categories',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<int> insertCategory(Category c) async =>
      (await db).insert('categories', c.toMap()..remove('id'));

  static Future<void> updateCategory(Category c) async =>
      (await db).update('categories', c.toMap(),
          where: 'id = ?', whereArgs: [c.id]);

  static Future<void> deleteCategory(int id) async {
    final d = await db;
    await d.delete('categories', where: 'parent_id = ?', whereArgs: [id]);
    await d.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Accounts ────────────────────────────────────────────────────────────────

  static Future<int> insertAccount(Account a) async =>
      (await db).insert('accounts', a.toMap()..remove('id'));

  static Future<List<Account>> getAccounts() async {
    final rows = await (await db).query('accounts', orderBy: 'name ASC');
    return rows.map(Account.fromMap).toList();
  }

  static Future<void> updateAccount(Account a) async =>
      (await db).update('accounts', a.toMap(), where: 'id=?', whereArgs: [a.id]);

  /// Nullifies account_id on all transactions before deleting the account
  /// so balance calculations don't break.
  static Future<void> deleteAccount(int id) async {
    final d = await db;
    await d.update('transactions', {'account_id': null},
        where: 'account_id=?', whereArgs: [id]);
    await d.delete('accounts', where: 'id=?', whereArgs: [id]);
  }

  /// Transfer money from one account to another.
  /// Records an expense on [fromId] and income on [toId].
  static Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final d = await db;
    final now = date ?? DateTime.now();
    final memo = note ?? 'transfer';
    await d.transaction((txn) async {
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

  /// Running balance = opening balance + income − expenses for that account.
  /// Credit cards: opening balance is amount already owed; expenses add to it.
  static Future<double> accountBalance(int accountId, Account account) async {
    final d = await db;
    final income = await d.rawQuery(
      "SELECT SUM(amount) as t FROM transactions WHERE account_id=? AND type='income'",
      [accountId],
    );
    final expense = await d.rawQuery(
      "SELECT SUM(amount) as t FROM transactions WHERE account_id=? AND type='expense'",
      [accountId],
    );
    final i = (income.first['t'] as num?)?.toDouble() ?? 0;
    final e = (expense.first['t'] as num?)?.toDouble() ?? 0;
    if (account.type == 'credit') return account.balance + e - i;
    return account.balance + i - e;
  }

  // ── Transactions ─────────────────────────────────────────────────────────────

  static Future<int> insertTransaction(model.Transaction t) async {
    final d = await db;
    final id = await d.insert('transactions', t.toMap()..remove('id'));
    AppLogger.db('insertTransaction', detail: '${t.type} \$${t.amount} ${t.category}');
    return id;
  }

  static Future<void> updateTransaction(model.Transaction t) async {
    await (await db).update('transactions', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    AppLogger.db('updateTransaction', detail: 'id=${t.id} ${t.type} \$${t.amount}');
  }

  static Future<void> deleteTransaction(int id) async {
    await (await db).delete('transactions', where: 'id=?', whereArgs: [id]);
    AppLogger.db('deleteTransaction', detail: 'id=$id');
  }

  static Future<List<model.Transaction>> getTransactions({
    String? type,
    DateTime? from,
    DateTime? to,
    String? keyword,
    int? accountId,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <dynamic>[];
    if (type != null) { where.add('type = ?'); args.add(type); }
    if (from != null) { where.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null) { where.add('date <= ?'); args.add(to.toIso8601String()); }
    if (keyword != null) {
      where.add('(category LIKE ? OR note LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }
    if (accountId != null) { where.add('account_id = ?'); args.add(accountId); }
    final rows = await d.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map(model.Transaction.fromMap).toList();
  }

  static Future<double> monthlyTotal(String type, int month, int year) async {
    final d = await db;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await d.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type=? AND date>=? AND date<? AND category != 'transfer'",
      [type, start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  static Future<Map<String, double>> monthlyExpenseByCategory(int month, int year) async {
    final d = await db;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await d.rawQuery(
      "SELECT LOWER(category) as category, SUM(amount) as total FROM transactions "
      "WHERE type='expense' AND category != 'transfer' AND date>=? AND date<? GROUP BY LOWER(category)",
      [start, end],
    );
    return {for (final r in rows) r['category'] as String: (r['total'] as num).toDouble()};
  }

  // ── Budgets ──────────────────────────────────────────────────────────────────

  static Future<void> upsertBudget(Budget b) async =>
      (await db).insert('budgets', b.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Budget>> getBudgets(int month, int year) async {
    final rows = await (await db).query('budgets',
        where: 'month=? AND year=?', whereArgs: [month, year]);
    return rows.map(Budget.fromMap).toList();
  }

  // ── Savings ──────────────────────────────────────────────────────────────────

  static Future<int> insertGoal(SavingsGoal g) async =>
      (await db).insert('savings_goals', g.toMap()..remove('id'));

  static Future<List<SavingsGoal>> getGoals() async {
    final rows = await (await db).query('savings_goals', orderBy: 'priority ASC, name ASC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  static Future<void> updateGoal(SavingsGoal g) async =>
      (await db).update('savings_goals', g.toMap(), where: 'id=?', whereArgs: [g.id]);

  static Future<void> updateGoalSaved(int id, double saved) async =>
      (await db).update('savings_goals', {'saved': saved}, where: 'id=?', whereArgs: [id]);

  static Future<void> deleteGoal(int id) async =>
      (await db).delete('savings_goals', where: 'id=?', whereArgs: [id]);

  // ── Recurring Transactions ───────────────────────────────────────────────────

  static Future<int> insertRecurring(RecurringTransaction r) async =>
      (await db).insert('recurring_transactions', r.toMap()..remove('id'));

  static Future<List<RecurringTransaction>> getRecurring() async {
    final rows = await (await db).query('recurring_transactions', orderBy: 'next_due_date ASC');
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  static Future<void> updateRecurring(RecurringTransaction r) async =>
      (await db).update('recurring_transactions', r.toMap(),
          where: 'id=?', whereArgs: [r.id]);

  static Future<void> deleteRecurring(int id) async =>
      (await db).delete('recurring_transactions', where: 'id=?', whereArgs: [id]);

  // ── Export ───────────────────────────────────────────────────────────────────

  static Future<void> deleteAllData() async {
    AppLogger.userAction('deleteAllData', detail: 'All data wiped');
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('recurring_transactions');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('accounts');
    });
  }

  static Future<String> exportCsv() async {
    final txns = await getTransactions();
    final accounts = await getAccounts();
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
