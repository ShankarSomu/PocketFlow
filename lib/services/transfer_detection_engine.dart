import '../db/database.dart';
import '../models/transaction.dart';
import '../models/transfer_pair.dart';

/// Transfer Detection Result
class TransferDetection {

  TransferDetection({
    required this.debitTransaction,
    required this.creditTransaction,
    required this.confidence,
    required this.matchReason,
    required this.timeDifference,
  });
  final Transaction debitTransaction;
  final Transaction creditTransaction;
  final double confidence;
  final String matchReason;
  final Duration timeDifference;

  bool get isHighConfidence => confidence >= 0.85;
  bool get isMediumConfidence => confidence >= 0.60 && confidence < 0.85;
}

/// Transfer Detection Engine (Rule-Based)
/// Detects expense-income pairs that represent transfers between accounts
/// 
/// Detection Rules:
/// - Same amount (within tolerance)
/// - Opposite types (expense + income)
/// - Within 24-48 hours
/// - Different accounts
/// 
/// Confidence Scoring:
/// - Amount match = 0.4
/// - Time match = 0.3 (better for closer times)
/// - Account pattern = 0.3 (transfer keywords, account history)
/// - Threshold > 0.7 → auto-link
class TransferDetectionEngine {
  // Time window for transfer matching (24-48 hours)
  static const Duration maxTimeDifference = Duration(hours: 48);

  // Auto-link confidence threshold
  static const double autoLinkThreshold = 0.7;

  // Amount tolerance (0.1%)
  static const double amountTolerance = 0.001;

  /// Detect all transfer pairs in recent transactions
  static Future<List<TransferDetection>> detectTransfers({
    DateTime? since,
    int? limit,
  }) async {
    final db = await AppDatabase.db();

    // Get recent transactions to analyze
    final cutoff = since ?? DateTime.now().subtract(const Duration(days: 30));

    final transactions = await db.query(
      'transactions',
      where: 'date >= ? AND deleted_at IS NULL',
      whereArgs: [cutoff.toIso8601String()],
      orderBy: 'date DESC',
      limit: limit,
    );

    final txns = transactions.map(Transaction.fromMap).toList();

    // Split by type for efficiency
    // Expense = money leaving account, Income = money entering account
    final expenseTxns = txns.where((t) => t.type == 'expense').toList();
    final incomeTxns = txns.where((t) => t.type == 'income').toList();

    final detections = <TransferDetection>[];

    // For each expense, find matching income (transfer out → transfer in)
    for (final expense in expenseTxns) {
      // Find potential income matches
      final matches = await _findIncomeMatches(expense, incomeTxns);

      if (matches.isNotEmpty) {
        // Take the best match
        detections.add(matches.first);
      }
    }

    return detections;
  }

  /// Find income transactions matching an expense (transfer detection)
  static Future<List<TransferDetection>> _findIncomeMatches(
    Transaction expense,
    List<Transaction> incomeTxns,
  ) async {
    final matches = <TransferDetection>[];

    for (final income in incomeTxns) {
      // Rule 1: Different accounts (required for transfer)
      if (income.accountId == expense.accountId) continue;

      // Rule 2: Same amount (within tolerance)
      final amountMatch = _checkAmountMatch(expense.amount, income.amount);
      if (!amountMatch) continue;

      // Rule 3: Within 24-48 hours
      final timeDiff = income.date.difference(expense.date).abs();
      if (timeDiff > maxTimeDifference) continue;

      // Calculate confidence score
      final confidence = _calculateTransferConfidence(
        expense: expense,
        income: income,
        timeDiff: timeDiff,
      );

      // Only consider if confidence meets minimum threshold (0.5)
      if (confidence >= 0.50) {
        matches.add(TransferDetection(
          debitTransaction: expense,
          creditTransaction: income,
          confidence: confidence,
          matchReason: _buildMatchReason(expense, income, timeDiff),
          timeDifference: timeDiff,
        ));
      }
    }

    // Sort by confidence descending
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));

    return matches;
  }

  /// Check if amounts match within tolerance
  static bool _checkAmountMatch(double amount1, double amount2) {
    final diff = (amount1 - amount2).abs();
    final tolerance = amount1 * amountTolerance;
    return diff <= tolerance || diff <= 0.01; // Allow 1 cent difference
  }

  /// Calculate transfer detection confidence (Rule-Based)
  /// 
  /// Scoring breakdown:
  /// - Amount match = 0.4 (base score for matching amount)
  /// - Time match = 0.3 (better for closer transactions)
  /// - Account pattern = 0.3 (transfer keywords, patterns)
  /// 
  /// Threshold: > 0.7 for auto-link
  static double _calculateTransferConfidence({
    required Transaction expense,
    required Transaction income,
    required Duration timeDiff,
  }) {
    double confidence = 0.0;

    // ── Component 1: Amount Match (0.4) ──
    confidence += 0.40;

    // ── Component 2: Time Match (0.3) ──
    // Better score for closer transactions
    final hours = timeDiff.inHours;
    if (hours == 0) {
      confidence += 0.30; // Same hour (instant transfer)
    } else if (hours <= 1) {
      confidence += 0.28; // Within 1 hour
    } else if (hours <= 6) {
      confidence += 0.25; // Within 6 hours
    } else if (hours <= 24) {
      confidence += 0.20; // Within 24 hours (same day)
    } else if (hours <= 48) {
      confidence += 0.15; // Within 48 hours
    } else {
      confidence += 0.10; // Within max window
    }

    // ── Component 3: Account Pattern (0.3) ──
    final expenseIsTransfer = _isTransferType(expense);
    final incomeIsTransfer = _isTransferType(income);
    
    if (expenseIsTransfer && incomeIsTransfer) {
      // Both transactions have transfer keywords → high confidence
      confidence += 0.30;
    } else if (expenseIsTransfer || incomeIsTransfer) {
      // One transaction has transfer keywords → medium confidence
      confidence += 0.20;
    } else {
      // No transfer keywords → low account pattern confidence
      confidence += 0.10;
    }

    // Bonus: Exact same amount (perfect match)
    if ((expense.amount - income.amount).abs() < 0.01) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Check if transaction appears to be a transfer
  static bool _isTransferType(Transaction txn) {
    final category = txn.category.toLowerCase();
    final note = txn.note?.toLowerCase() ?? '';
    final merchant = txn.merchant?.toLowerCase() ?? '';
    final sms = txn.smsSource?.toLowerCase() ?? '';

    final transferKeywords = [
      'transfer',
      'upi',
      'neft',
      'imps',
      'rtgs',
      'ach',
      'wire',
      'sent to',
      'received from',
      'p2p',
      'peer',
    ];

    for (final keyword in transferKeywords) {
      if (category.contains(keyword) ||
          note.contains(keyword) ||
          merchant.contains(keyword) ||
          sms.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Build human-readable match reason
  static String _buildMatchReason(
    Transaction expense,
    Transaction income,
    Duration timeDiff,
  ) {
    final parts = <String>[];

    // Amount
    parts.add('Same amount (₹${expense.amount.toStringAsFixed(2)})');

    // Time
    final hours = timeDiff.inHours;
    if (hours == 0) {
      parts.add('same hour');
    } else if (hours < 24) {
      parts.add('$hours hr apart');
    } else {
      final days = (hours / 24).toStringAsFixed(1);
      parts.add('$days days apart');
    }

    // Type
    if (_isTransferType(expense) && _isTransferType(income)) {
      parts.add('both marked as transfer');
    }

    return parts.join(', ');
  }

  /// Create transfer pair from detection
  static Future<int> createTransferPair(TransferDetection detection) async {
    final db = await AppDatabase.db();

    final pair = TransferPair(
      debitTransactionId: detection.debitTransaction.id!,
      creditTransactionId: detection.creditTransaction.id!,
      amount: detection.debitTransaction.amount,
      timestamp: DateTime.now(),
      sourceAccountId: detection.debitTransaction.accountId ?? 0,
      destinationAccountId: detection.creditTransaction.accountId ?? 0,
      confidenceScore: detection.confidence,
      detectionMethod:
          _getDetectionMethod(detection.debitTransaction, detection.creditTransaction),
      status: detection.confidence >= autoLinkThreshold ? 'confirmed' : 'detected',
      createdAt: DateTime.now(),
    );

    final pairId = await db.insert('transfer_pairs', pair.toMap());

    // Auto-categorize if confidence meets auto-link threshold (> 0.7)
    if (detection.confidence >= autoLinkThreshold) {
      await db.update(
        'transactions',
        {
          'category': 'Transfer',
          'from_account_id': detection.debitTransaction.accountId,
          'to_account_id': detection.creditTransaction.accountId,
        },
        where: 'id = ?',
        whereArgs: [detection.debitTransaction.id],
      );

      await db.update(
        'transactions',
        {
          'category': 'Transfer',
          'from_account_id': detection.debitTransaction.accountId,
          'to_account_id': detection.creditTransaction.accountId,
        },
        where: 'id = ?',
        whereArgs: [detection.creditTransaction.id],
      );
    }

    return pairId;
  }

  /// Determine detection method
  static String _getDetectionMethod(Transaction debit, Transaction credit) {
    // Check if same merchant
    if (debit.merchant != null &&
        credit.merchant != null &&
        debit.merchant == credit.merchant) {
      return 'reference_id';
    }
    return 'amount_time';
  }

  /// Confirm a transfer pair
  static Future<void> confirmPair(int pairId) async {
    final db = await AppDatabase.db();

    await db.update(
      'transfer_pairs',
      {'status': 'confirmed'},
      where: 'id = ?',
      whereArgs: [pairId],
    );

    // Get pair to update transactions
    final pairMap = await db.query(
      'transfer_pairs',
      where: 'id = ?',
      whereArgs: [pairId],
      limit: 1,
    );

    if (pairMap.isNotEmpty) {
      final pair = TransferPair.fromMap(pairMap.first);

      // Categorize transactions as Transfer and set from/to accounts
      await db.update(
        'transactions',
        {
          'category': 'Transfer',
          'from_account_id': pair.sourceAccountId,
          'to_account_id': pair.destinationAccountId,
        },
        where: 'id = ?',
        whereArgs: [pair.debitTransactionId],
      );

      await db.update(
        'transactions',
        {
          'category': 'Transfer',
          'from_account_id': pair.sourceAccountId,
          'to_account_id': pair.destinationAccountId,
        },
        where: 'id = ?',
        whereArgs: [pair.creditTransactionId],
      );
    }
  }

  /// Reject a transfer pair
  static Future<void> rejectPair(int pairId) async {
    final db = await AppDatabase.db();

    // Mark pair as rejected
    await db.update(
      'transfer_pairs',
      {'status': 'rejected'},
      where: 'id = ?',
      whereArgs: [pairId],
    );
  }

  /// Get all transfer pairs
  static Future<List<TransferPair>> getAllPairs({String? status}) async {
    final db = await AppDatabase.db();

    final results = await db.query(
      'transfer_pairs',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'created_at DESC',
    );

    return results.map(TransferPair.fromMap).toList();
  }

  /// Get pending pairs (need user review)
  static Future<List<TransferPair>> getPendingPairs() async {
    return getAllPairs(status: 'detected');
  }

  /// Run transfer detection on recent transactions
  static Future<Map<String, dynamic>> runDetection({
    int sinceDays = 30,
  }) async {
    final since = DateTime.now().subtract(Duration(days: sinceDays));
    final detections = await detectTransfers(since: since);

    int created = 0;
    int skipped = 0;

    for (final detection in detections) {
      // Check if pair already exists
      final db = await AppDatabase.db();
      final existing = await db.query(
        'transfer_pairs',
        where: 'debit_transaction_id = ? AND credit_transaction_id = ?',
        whereArgs: [
          detection.debitTransaction.id,
          detection.creditTransaction.id,
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        await createTransferPair(detection);
        created++;
      } else {
        skipped++;
      }
    }

    return {
      'total_detected': detections.length,
      'pairs_created': created,
      'already_exists': skipped,
      'high_confidence': detections.where((d) => d.isHighConfidence).length,
      'medium_confidence': detections.where((d) => d.isMediumConfidence).length,
    };
  }

  /// Get transfer pair with transaction details
  static Future<Map<String, dynamic>?> getPairDetails(int pairId) async {
    final db = await AppDatabase.db();

    final pairMap = await db.query(
      'transfer_pairs',
      where: 'id = ?',
      whereArgs: [pairId],
      limit: 1,
    );

    if (pairMap.isEmpty) return null;

    final pair = TransferPair.fromMap(pairMap.first);

    // Get transactions
    final debitMap = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [pair.debitTransactionId],
      limit: 1,
    );

    final creditMap = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [pair.creditTransactionId],
      limit: 1,
    );

    if (debitMap.isEmpty || creditMap.isEmpty) return null;

    return {
      'pair': pair,
      'debit_transaction': Transaction.fromMap(debitMap.first),
      'credit_transaction': Transaction.fromMap(creditMap.first),
    };
  }
}
