import 'package:sqflite/sqflite.dart';
import 'app_logger.dart';

/// Database Migration Helper for Hybrid Transaction Mapping
/// 
/// Adds new fields to accounts and transactions tables to support:
/// - Intelligent account matching
/// - Transaction source tracking
/// - Confidence scoring
class HybridTransactionMigration {
  static const int targetVersion = 2; // Increment from current version

  /// Apply migration to add hybrid transaction mapping fields
  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    AppLogger.log(
      LogLevel.info,
      LogCategory.database,
      'hybrid_migration_start',
      detail: 'Upgrading from v$oldVersion to v$newVersion',
    );

    try {
      // Step 1: Add new columns to accounts table
      await _migrateAccountsTable(db);

      // Step 2: Add new columns to transactions table
      await _migrateTransactionsTable(db);

      AppLogger.log(
        LogLevel.info,
        LogCategory.database,
        'hybrid_migration_complete',
        detail: 'Migration successful',
      );
    } catch (e) {
      AppLogger.err('hybrid_migration_error', e);
      rethrow;
    }
  }

  /// Migrate accounts table with new mapping fields
  static Future<void> _migrateAccountsTable(Database db) async {
    // Check if columns already exist
    final columns = await _getTableColumns(db, 'accounts');

    if (!columns.contains('institution_name')) {
      await db.execute('ALTER TABLE accounts ADD COLUMN institution_name TEXT');
      AppLogger.db('Added column: accounts.institution_name');
    }

    if (!columns.contains('account_identifier')) {
      await db.execute('ALTER TABLE accounts ADD COLUMN account_identifier TEXT');
      AppLogger.db('Added column: accounts.account_identifier');
    }

    if (!columns.contains('sms_keywords')) {
      await db.execute('ALTER TABLE accounts ADD COLUMN sms_keywords TEXT');
      AppLogger.db('Added column: accounts.sms_keywords');
    }

    if (!columns.contains('account_alias')) {
      await db.execute('ALTER TABLE accounts ADD COLUMN account_alias TEXT');
      AppLogger.db('Added column: accounts.account_alias');
    }

    // Migrate existing last4 data to account_identifier format
    await db.execute('''
      UPDATE accounts 
      SET account_identifier = '****' || last4 
      WHERE last4 IS NOT NULL AND account_identifier IS NULL
    ''');

    AppLogger.db('Migrated last4 to account_identifier format');
  }

  /// Migrate transactions table with new source tracking fields
  static Future<void> _migrateTransactionsTable(Database db) async {
    final columns = await _getTableColumns(db, 'transactions');

    if (!columns.contains('source_type')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN source_type TEXT DEFAULT "manual"');
      AppLogger.db('Added column: transactions.source_type');
    }

    if (!columns.contains('merchant')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN merchant TEXT');
      AppLogger.db('Added column: transactions.merchant');
    }

    if (!columns.contains('confidence_score')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN confidence_score REAL');
      AppLogger.db('Added column: transactions.confidence_score');
    }

    if (!columns.contains('needs_review')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN needs_review INTEGER DEFAULT 0');
      AppLogger.db('Added column: transactions.needs_review');
    }

    // Set source_type for existing transactions
    await db.execute('''
      UPDATE transactions 
      SET source_type = CASE 
        WHEN sms_source IS NOT NULL THEN 'sms'
        WHEN recurring_id IS NOT NULL THEN 'recurring'
        ELSE 'manual'
      END
      WHERE source_type IS NULL OR source_type = 'manual'
    ''');

    AppLogger.db('Set source_type for existing transactions');
  }

  /// Get list of column names for a table
  static Future<List<String>> _getTableColumns(Database db, String tableName) async {
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    return result.map((row) => row['name']! as String).toList();
  }

  /// Rollback migration (drop added columns - WARNING: destructive!)
  /// 
  /// SQLite doesn't support DROP COLUMN easily, so this requires table recreation
  /// Only use for development/testing
  static Future<void> rollback(Database db) async {
    AppLogger.warn(
      'hybrid_migration_rollback',
      detail: 'DESTRUCTIVE: This will recreate tables without new columns',
    );

    // This would require recreating tables without the new columns
    // For production, migrations should not be rolled back
    throw UnimplementedError(
      'Migration rollback not implemented for production safety. '
      'Consider data backup before migration.',
    );
  }

  /// Verify migration was successful
  static Future<bool> verifyMigration(Database db) async {
    try {
      // Check accounts table
      final accountColumns = await _getTableColumns(db, 'accounts');
      final accountColumnsValid = accountColumns.contains('institution_name') &&
          accountColumns.contains('account_identifier') &&
          accountColumns.contains('sms_keywords') &&
          accountColumns.contains('account_alias');

      // Check transactions table
      final transactionColumns = await _getTableColumns(db, 'transactions');
      final transactionColumnsValid = transactionColumns.contains('source_type') &&
          transactionColumns.contains('merchant') &&
          transactionColumns.contains('confidence_score') &&
          transactionColumns.contains('needs_review');

      final isValid = accountColumnsValid && transactionColumnsValid;

      AppLogger.log(
        LogLevel.info,
        LogCategory.database,
        'hybrid_migration_verify',
        detail: isValid ? 'Migration verified' : 'Migration incomplete',
      );

      return isValid;
    } catch (e) {
      AppLogger.err('hybrid_migration_verify', e);
      return false;
    }
  }
}
