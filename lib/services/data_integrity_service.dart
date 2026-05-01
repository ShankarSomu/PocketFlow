import '../db/database.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'app_logger.dart';

/// Data Integrity Service
/// 
/// Purpose: Prevent accounting corruption by enforcing critical invariants
/// 
/// Three Core Rules (MUST NEVER VIOLATE):
/// - Rule A: No transaction without accountId
/// - Rule B: Transfers must always be paired OR marked pending
/// - Rule C: Net worth must match recomputed ledger
/// 
/// This service provides:
/// 1. Pre-insert validation (preventive)
/// 2. Reconciliation checks (detective)
/// 3. Integrity reports (monitoring)
class DataIntegrityService {
  
  // ══════════════════════════════════════════════════════════════════════════
  // RULE A: No Transaction Without AccountId
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Validate transaction before insert
  /// 
  /// Rule A: Every transaction MUST have a valid accountId
  /// - accountId must not be null
  /// - accountId must reference existing account
  /// - Account must not be deleted
  /// 
  /// Throws exception if validation fails (prevents corrupt data)
  static Future<void> validateTransactionBeforeInsert(Transaction transaction) async {
    // Rule A.1: accountId must exist
    if (transaction.accountId == null) {
      throw IntegrityViolationException(
        rule: 'RULE_A',
        message: 'Transaction must have accountId',
        detail: 'type=${transaction.type}, amount=${transaction.amount}, category=${transaction.category}',
      );
    }
    
    // Rule A.2: accountId must reference valid account
    final db = await AppDatabase.db();
    final accountResult = await db.query(
      'accounts',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [transaction.accountId],
      limit: 1,
    );
    
    if (accountResult.isEmpty) {
      throw IntegrityViolationException(
        rule: 'RULE_A',
        message: 'Transaction references non-existent or deleted account',
        detail: 'accountId=${transaction.accountId}, type=${transaction.type}, amount=${transaction.amount}',
      );
    }
    
    AppLogger.log(
      LogLevel.debug, 
      LogCategory.database, 
      'Validation passed: RULE_A',
      detail: 'txn accountId=${transaction.accountId}',
    );
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // RULE B: Transfers Must Be Paired OR Pending
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Validate transfer transaction integrity
  /// 
  /// Rule B: Transfers must have matching expense + income pair OR be marked pending
  /// - Transfer with fromAccountId/toAccountId must have paired transaction
  /// - OR must be in pending_actions awaiting user confirmation
  /// - Orphaned transfer transactions corrupt net worth
  /// 
  /// Returns validation result with details
  static Future<IntegrityCheckResult> validateTransferPairing() async {
    final db = await AppDatabase.db();
    
    final violations = <String>[];
    
    // Find all transfer transactions
    final transfers = await db.query(
      'transactions',
      where: 'deleted_at IS NULL AND category = ?',
      whereArgs: ['transfer'],
    );
    
    // Group transfers by from_account_id + to_account_id + amount + date
    final transferGroups = <String, List<Map<String, dynamic>>>{};
    
    for (final transfer in transfers) {
      final fromAccountId = transfer['from_account_id'];
      final toAccountId = transfer['to_account_id'];
      final amount = transfer['amount'];
      final date = transfer['date'];
      
      // Skip if no transfer metadata (legacy transactions)
      if (fromAccountId == null || toAccountId == null) {
        continue;
      }
      
      final key = '$fromAccountId->$toAccountId:\$$amount@$date';
      transferGroups.putIfAbsent(key, () => []);
      transferGroups[key]!.add(transfer);
    }
    
    // Validate each transfer group has expense + income pair
    for (final entry in transferGroups.entries) {
      final group = entry.value;
      
      // Count expense and income transactions
      final expenses = group.where((t) => t['type'] == 'expense').length;
      final incomes = group.where((t) => t['type'] == 'income').length;
      
      // Valid: 1 expense + 1 income
      if (expenses == 1 && incomes == 1) {
        continue; // Perfect pair
      }
      
      // Invalid: Unpaired transfer
      violations.add(
        'Unpaired transfer: ${entry.key} (expenses: $expenses, incomes: $incomes)',
      );
      
      AppLogger.warn(
        'RULE_B violation',
        detail: 'Unpaired transfer: ${entry.key}',
        category: LogCategory.database,
      );
    }
    
    // Check orphaned transfer transactions (category='transfer' but no from/to)
    final orphanedTransfers = await db.query(
      'transactions',
      where: 'deleted_at IS NULL AND category = ? AND (from_account_id IS NULL OR to_account_id IS NULL)',
      whereArgs: ['transfer'],
    );
    
    for (final orphan in orphanedTransfers) {
      violations.add(
        'Orphaned transfer: id=${orphan['id']}, type=${orphan['type']}, amount=${orphan['amount']}',
      );
    }
    
    return IntegrityCheckResult(
      rule: 'RULE_B',
      passed: violations.isEmpty,
      violations: violations,
      checkedAt: DateTime.now(),
    );
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // RULE C: Net Worth Must Match Recomputed Ledger
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Validate net worth calculation
  /// 
  /// Rule C: Net worth from stored balances must match recomputed from transactions
  /// - Stored: Sum of all account balances (assets - liabilities)
  /// - Computed: Opening balances + transaction ledger (income - expense)
  /// - Difference > $0.01 indicates data corruption
  /// 
  /// Returns validation result with reconciliation details
  static Future<IntegrityCheckResult> validateNetWorth() async {
    final db = await AppDatabase.db();
    
    // ── Stored Net Worth ──
    // Sum all account balances, respecting account type
    final accounts = await db.query('accounts', where: 'deleted_at IS NULL');
    
    double storedNetWorth = 0.0;
    for (final accountMap in accounts) {
      final account = Account.fromMap(accountMap);
      final balance = await AppDatabase.accountBalance(account.id!, account);
      
      if (account.isLiability) {
        // Liabilities subtract from net worth
        storedNetWorth -= balance;
      } else {
        // Assets add to net worth
        storedNetWorth += balance;
      }
    }
    
    // ── Computed Net Worth ──
    // Recompute from transaction ledger
    double computedNetWorth = 0.0;
    
    for (final accountMap in accounts) {
      final account = Account.fromMap(accountMap);
      
      // Start with opening balance
      double accountBalance = account.balance;
      
      // Get all transactions for this account
      final txnResults = await db.query(
        'transactions',
        where: 'account_id = ? AND deleted_at IS NULL',
        whereArgs: [account.id],
      );
      
      // Apply transactions to balance
      for (final txn in txnResults) {
        final type = txn['type'] as String;
        final amount = (txn['amount'] as num).toDouble();
        
        if (account.isLiability) {
          // Liability: expenses increase debt, income reduces debt
          if (type == 'expense') {
            accountBalance += amount;
          } else {
            accountBalance -= amount;
          }
        } else {
          // Asset: income increases balance, expenses decrease balance
          if (type == 'income') {
            accountBalance += amount;
          } else {
            accountBalance -= amount;
          }
        }
      }
      
      // Add to net worth (liabilities subtract)
      if (account.isLiability) {
        computedNetWorth -= accountBalance;
      } else {
        computedNetWorth += accountBalance;
      }
    }
    
    // ── Compare ──
    final difference = (storedNetWorth - computedNetWorth).abs();
    final isValid = difference < 0.01; // Allow for floating point precision
    
    final violations = <String>[];
    if (!isValid) {
      violations.add(
        'Net worth mismatch: stored=\$${storedNetWorth.toStringAsFixed(2)}, '
        'computed=\$${computedNetWorth.toStringAsFixed(2)}, '
        'difference=\$${difference.toStringAsFixed(2)}',
      );
      
      AppLogger.err(
        'RULE_C violation',
        'Net worth mismatch: \$${difference.toStringAsFixed(2)}',
        category: LogCategory.database,
      );
    }
    
    return IntegrityCheckResult(
      rule: 'RULE_C',
      passed: isValid,
      violations: violations,
      checkedAt: DateTime.now(),
      metadata: {
        'stored_net_worth': storedNetWorth,
        'computed_net_worth': computedNetWorth,
        'difference': difference,
        'accounts_checked': accounts.length,
      },
    );
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // Reconciliation Job (Daily Check)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Run comprehensive integrity check
  /// 
  /// Checks all three rules:
  /// - Rule A: Orphaned transactions (no accountId)
  /// - Rule B: Unpaired transfers
  /// - Rule C: Net worth reconciliation
  /// 
  /// Returns comprehensive report
  static Future<IntegrityReport> runReconciliation() async {
    final startTime = DateTime.now();
    
    AppLogger.log(
      LogLevel.info, 
      LogCategory.system, 
      'Starting data integrity reconciliation',
    );
    
    // Check Rule A: Orphaned transactions
    final ruleAResult = await _checkRuleA();
    
    // Check Rule B: Transfer pairing
    final ruleBResult = await validateTransferPairing();
    
    // Check Rule C: Net worth reconciliation
    final ruleCResult = await validateNetWorth();
    
    // Check transfer integrity (sum of transfer expenses = sum of transfer income)
    final transferIntegrityResult = await _checkTransferIntegrity();
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    final report = IntegrityReport(
      ranAt: startTime,
      duration: duration,
      ruleA: ruleAResult,
      ruleB: ruleBResult,
      ruleC: ruleCResult,
      transferIntegrity: transferIntegrityResult,
    );
    
    // Log summary
    if (report.allPassed) {
      AppLogger.log(
        LogLevel.info, 
        LogCategory.system, 
        'Integrity check PASSED',
        detail: 'Duration: ${duration.inMilliseconds}ms',
      );
    } else {
      AppLogger.warn(
        'reconciliation',
        detail: 'Integrity check FAILED: ${report.totalViolations} violations found',
        category: LogCategory.system,
      );
    }
    
    return report;
  }
  
  /// Check Rule A: No orphaned transactions
  static Future<IntegrityCheckResult> _checkRuleA() async {
    final db = await AppDatabase.db();
    
    // Find transactions with null accountId (should be impossible due to NOT NULL constraint)
    final orphaned = await db.query(
      'transactions',
      where: 'account_id IS NULL AND deleted_at IS NULL',
    );
    
    // Find transactions with invalid accountId (references deleted/non-existent account)
    final invalidAccountIds = await db.rawQuery('''
      SELECT t.id, t.account_id, t.type, t.amount
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      WHERE t.deleted_at IS NULL
        AND (a.id IS NULL OR a.deleted_at IS NOT NULL)
    ''');
    
    final violations = <String>[];
    
    for (final txn in orphaned) {
      violations.add('Orphaned transaction: id=${txn['id']}, type=${txn['type']}, amount=${txn['amount']}');
    }
    
    for (final txn in invalidAccountIds) {
      violations.add('Invalid accountId: txn_id=${txn['id']}, account_id=${txn['account_id']}');
    }
    
    return IntegrityCheckResult(
      rule: 'RULE_A',
      passed: violations.isEmpty,
      violations: violations,
      checkedAt: DateTime.now(),
      metadata: {
        'orphaned_count': orphaned.length,
        'invalid_account_count': invalidAccountIds.length,
      },
    );
  }
  
  /// Check transfer integrity (expense sum = income sum)
  static Future<IntegrityCheckResult> _checkTransferIntegrity() async {
    final isValid = await AppDatabase.validateTransferIntegrity();
    
    final violations = <String>[];
    if (!isValid) {
      violations.add('Transfer expense/income sum mismatch (see logs for details)');
    }
    
    return IntegrityCheckResult(
      rule: 'TRANSFER_INTEGRITY',
      passed: isValid,
      violations: violations,
      checkedAt: DateTime.now(),
    );
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // Scheduled Reconciliation
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Store last reconciliation result in shared preferences
  static Future<void> saveLastReconciliation(IntegrityReport report) async {
    final db = await AppDatabase.db();
    
    // Store in a simple key-value table (could be added to database schema)
    // For now, just log it
    AppLogger.log(
      LogLevel.info,
      LogCategory.system,
      'Reconciliation saved',
      detail: 'passed=${report.allPassed}, violations=${report.totalViolations}',
    );
  }
  
  /// Check if reconciliation is due (daily)
  static Future<bool> isReconciliationDue() async {
    // TODO: Implement with shared preferences
    // For now, return true to allow manual triggering
    return true;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Data Models
// ══════════════════════════════════════════════════════════════════════════

/// Result of a single integrity check
class IntegrityCheckResult {
  IntegrityCheckResult({
    required this.rule,
    required this.passed,
    required this.violations,
    required this.checkedAt,
    this.metadata,
  });
  
  final String rule;
  final bool passed;
  final List<String> violations;
  final DateTime checkedAt;
  final Map<String, dynamic>? metadata;
  
  @override
  String toString() {
    if (passed) {
      return '✅ $rule: PASSED';
    } else {
      return '❌ $rule: FAILED (${violations.length} violations)';
    }
  }
}

/// Comprehensive integrity report
class IntegrityReport {
  IntegrityReport({
    required this.ranAt,
    required this.duration,
    required this.ruleA,
    required this.ruleB,
    required this.ruleC,
    required this.transferIntegrity,
  });
  
  final DateTime ranAt;
  final Duration duration;
  final IntegrityCheckResult ruleA;
  final IntegrityCheckResult ruleB;
  final IntegrityCheckResult ruleC;
  final IntegrityCheckResult transferIntegrity;
  
  bool get allPassed => 
    ruleA.passed && 
    ruleB.passed && 
    ruleC.passed && 
    transferIntegrity.passed;
  
  int get totalViolations =>
    ruleA.violations.length +
    ruleB.violations.length +
    ruleC.violations.length +
    transferIntegrity.violations.length;
  
  Map<String, dynamic> toJson() => {
    'ran_at': ranAt.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'all_passed': allPassed,
    'total_violations': totalViolations,
    'rule_a': {
      'passed': ruleA.passed,
      'violations': ruleA.violations,
      'metadata': ruleA.metadata,
    },
    'rule_b': {
      'passed': ruleB.passed,
      'violations': ruleB.violations,
    },
    'rule_c': {
      'passed': ruleC.passed,
      'violations': ruleC.violations,
      'metadata': ruleC.metadata,
    },
    'transfer_integrity': {
      'passed': transferIntegrity.passed,
      'violations': transferIntegrity.violations,
    },
  };
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('═══ Data Integrity Report ═══');
    buffer.writeln('Ran at: ${ranAt.toString()}');
    buffer.writeln('Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('Status: ${allPassed ? "✅ PASSED" : "❌ FAILED"}');
    buffer.writeln('');
    buffer.writeln(ruleA);
    buffer.writeln(ruleB);
    buffer.writeln(ruleC);
    buffer.writeln(transferIntegrity);
    
    if (!allPassed) {
      buffer.writeln('');
      buffer.writeln('Total violations: $totalViolations');
    }
    
    return buffer.toString();
  }
}

/// Exception thrown when integrity violation is detected
class IntegrityViolationException implements Exception {
  IntegrityViolationException({
    required this.rule,
    required this.message,
    this.detail,
  });
  
  final String rule;
  final String message;
  final String? detail;
  
  @override
  String toString() {
    if (detail != null) {
      return '$rule: $message ($detail)';
    }
    return '$rule: $message';
  }
}
