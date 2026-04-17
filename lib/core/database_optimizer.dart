import 'package:sqflite/sqflite.dart';

/// Database optimization utilities
class DatabaseOptimizer {
  /// Create indexes for better query performance
  static Future<void> createIndexes(Database db) async {
    // Drop old indexes with incorrect column names (if they exist)
    try {
      await db.execute('DROP INDEX IF EXISTS idx_transactions_account');
      await db.execute('DROP INDEX IF EXISTS idx_recurring_next_date');
      await db.execute('DROP INDEX IF EXISTS idx_savings_goals_target_date');
    } catch (e) {
      // Ignore errors if indexes don't exist
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_date 
      ON transactions(date DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_account 
      ON transactions(account_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_category 
      ON transactions(category)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_type 
      ON transactions(type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_date_type 
      ON transactions(date DESC, type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_budgets_month 
      ON budgets(month, year)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recurring_next_due_date 
      ON recurring_transactions(next_due_date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_savings_goals_priority 
      ON savings_goals(priority)
    ''');
  }

  /// Analyze database to update query planner statistics
  static Future<void> analyze(Database db) async {
    await db.execute('ANALYZE');
  }

  /// Vacuum database to reclaim unused space
  static Future<void> vacuum(Database db) async {
    await db.execute('VACUUM');
  }

  /// Get database size in bytes
  static Future<int> getDatabaseSize(String path) async {
    final db = await openDatabase(path, readOnly: true);
    try {
      final result = await db.rawQuery('SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
      return result.first['size'] as int;
    } finally {
      await db.close();
    }
  }

  /// Optimize query with EXPLAIN QUERY PLAN
  static Future<void> explainQuery(Database db, String query) async {
    final results = await db.rawQuery('EXPLAIN QUERY PLAN $query');
    for (final row in results) {
      print('Query Plan: $row');
    }
  }
}

/// Query builder with parameterization to prevent SQL injection
class SafeQueryBuilder {
  final StringBuffer _buffer = StringBuffer();
  final List<dynamic> _args = [];

  /// SELECT clause
  SafeQueryBuilder select(String columns) {
    _buffer.write('SELECT $columns ');
    return this;
  }

  /// FROM clause
  SafeQueryBuilder from(String table) {
    _buffer.write('FROM $table ');
    return this;
  }

  /// WHERE clause with parameterization
  SafeQueryBuilder where(String condition, [List<dynamic>? args]) {
    _buffer.write('WHERE $condition ');
    if (args != null) _args.addAll(args);
    return this;
  }

  /// AND condition
  SafeQueryBuilder and(String condition, [List<dynamic>? args]) {
    _buffer.write('AND $condition ');
    if (args != null) _args.addAll(args);
    return this;
  }

  /// OR condition
  SafeQueryBuilder or(String condition, [List<dynamic>? args]) {
    _buffer.write('OR $condition ');
    if (args != null) _args.addAll(args);
    return this;
  }

  /// ORDER BY clause
  SafeQueryBuilder orderBy(String column, {bool desc = false}) {
    _buffer.write('ORDER BY $column ${desc ? 'DESC' : 'ASC'} ');
    return this;
  }

  /// LIMIT clause
  SafeQueryBuilder limit(int count) {
    _buffer.write('LIMIT $count ');
    return this;
  }

  /// OFFSET clause
  SafeQueryBuilder offset(int count) {
    _buffer.write('OFFSET $count ');
    return this;
  }

  /// Build query string
  String get sql => _buffer.toString().trim();

  /// Get arguments
  List<dynamic> get arguments => _args;

  /// Execute query
  Future<List<Map<String, dynamic>>> execute(Database db) async {
    return await db.rawQuery(sql, arguments);
  }

  /// Execute single result query
  Future<Map<String, dynamic>?> executeSingle(Database db) async {
    final results = await execute(db);
    return results.isEmpty ? null : results.first;
  }

  @override
  String toString() => sql;
}

/// Batch operation helper for better performance
class BatchOperationHelper {
  /// Insert multiple rows in a single transaction
  static Future<void> batchInsert(
    Database db,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(table, row);
    }
    await batch.commit(noResult: true);
  }

  /// Update multiple rows in a single transaction
  static Future<void> batchUpdate(
    Database db,
    String table,
    List<Map<String, dynamic>> rows,
    String idColumn,
  ) async {
    final batch = db.batch();
    for (final row in rows) {
      final id = row[idColumn];
      batch.update(
        table,
        row,
        where: '$idColumn = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Delete multiple rows in a single transaction
  static Future<void> batchDelete(
    Database db,
    String table,
    String idColumn,
    List<dynamic> ids,
  ) async {
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(
        table,
        where: '$idColumn = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }
}

/// Connection pool simulation for SQLite (single connection with proper reuse)
class DatabaseConnectionPool {
  static Database? _connection;
  static int _referenceCount = 0;

  /// Get database connection
  static Future<Database> getConnection(String path) async {
    if (_connection == null || !_connection!.isOpen) {
      _connection = await openDatabase(path);
    }
    _referenceCount++;
    return _connection!;
  }

  /// Release connection
  static void releaseConnection() {
    _referenceCount--;
  }

  /// Close connection when no longer needed
  static Future<void> closeIfUnused() async {
    if (_referenceCount <= 0 && _connection != null) {
      await _connection!.close();
      _connection = null;
      _referenceCount = 0;
    }
  }

  /// Force close connection
  static Future<void> forceClose() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _referenceCount = 0;
    }
  }
}

/// Query result cache
class QueryCache {
  final Map<String, ({List<Map<String, dynamic>> results, DateTime timestamp})> _cache = {};
  final Duration maxAge;

  QueryCache({this.maxAge = const Duration(minutes: 5)});

  /// Get cached result
  List<Map<String, dynamic>>? get(String query, List<dynamic>? args) {
    final key = _buildKey(query, args);
    final cached = _cache[key];
    
    if (cached != null) {
      if (DateTime.now().difference(cached.timestamp) < maxAge) {
        return cached.results;
      }
      _cache.remove(key);
    }
    return null;
  }

  /// Cache result
  void put(String query, List<dynamic>? args, List<Map<String, dynamic>> results) {
    final key = _buildKey(query, args);
    _cache[key] = (results: results, timestamp: DateTime.now());
  }

  /// Clear cache
  void clear() {
    _cache.clear();
  }

  /// Clear expired entries
  void clearExpired() {
    final now = DateTime.now();
    _cache.removeWhere((key, value) {
      return now.difference(value.timestamp) >= maxAge;
    });
  }

  String _buildKey(String query, List<dynamic>? args) {
    return '$query:${args?.join(',')}';
  }
}
