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

/// Transfer Detection Engine
/// Detects debit-credit pairs that represent transfers between accounts
class TransferDetectionEngine {
  // Time window for transfer matching (±2 hours)
  static const Duration maxTimeDifference = Duration(hours: 2);

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
    final debitTxns = txns.where((t) => t.type == 'debit').toList();
    final creditTxns = txns.where((t) => t.type == 'credit').toList();

    final detections = <TransferDetection>[];

    // For each debit, find matching credit
    for (final debit in debitTxns) {
      // Find potential credit matches
      final matches = await _findCreditMatches(debit, creditTxns);

      if (matches.isNotEmpty) {
        // Take the best match
        detections.add(matches.first);
      }
    }

    return detections;
  }

  /// Find credit transactions matching a debit
  static Future<List<TransferDetection>> _findCreditMatches(
    Transaction debit,
    List<Transaction> creditTxns,
  ) async {
    final matches = <TransferDetection>[];

    for (final credit in creditTxns) {
      // Skip if same account (not a transfer)
      if (credit.accountId == debit.accountId) continue;

      // Check amount match
      final amountMatch = _checkAmountMatch(debit.amount, credit.amount);
      if (!amountMatch) continue;

      // Check time proximity
      final timeDiff = credit.date.difference(debit.date).abs();
      if (timeDiff > maxTimeDifference) continue;

      // Calculate confidence
      final confidence = _calculateTransferConfidence(
        debit: debit,
        credit: credit,
        timeDiff: timeDiff,
      );

      if (confidence >= 0.50) {
        matches.add(TransferDetection(
          debitTransaction: debit,
          creditTransaction: credit,
          confidence: confidence,
          matchReason: _buildMatchReason(debit, credit, timeDiff),
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

  /// Calculate transfer detection confidence
  static double _calculateTransferConfidence({
    required Transaction debit,
    required Transaction credit,
    required Duration timeDiff,
  }) {
    double confidence = 0.0;

    // Base confidence from amount match
    confidence += 0.40;

    // Time proximity bonus (max 0.30)
    final minutes = timeDiff.inMinutes;
    if (minutes == 0) {
      confidence += 0.30; // Same minute
    } else if (minutes <= 5) {
      confidence += 0.25; // Within 5 minutes
    } else if (minutes <= 30) {
      confidence += 0.20; // Within 30 minutes
    } else if (minutes <= 60) {
      confidence += 0.15; // Within 1 hour
    } else {
      confidence += 0.10; // Within 2 hours
    }

    // Transfer type indicator bonus
    final debitIsTransfer = _isTransferType(debit);
    final creditIsTransfer = _isTransferType(credit);
    if (debitIsTransfer && creditIsTransfer) {
      confidence += 0.10;
    }

    // Exact same amount (not just within tolerance)
    if ((debit.amount - credit.amount).abs() < 0.01) {
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
    Transaction debit,
    Transaction credit,
    Duration timeDiff,
  ) {
    final parts = <String>[];

    // Amount
    parts.add('Same amount (\$${debit.amount.toStringAsFixed(2)})');

    // Time
    final minutes = timeDiff.inMinutes;
    if (minutes == 0) {
      parts.add('same minute');
    } else if (minutes < 60) {
      parts.add('$minutes min apart');
    } else {
      final hours = (minutes / 60).toStringAsFixed(1);
      parts.add('$hours hr apart');
    }

    // Type
    if (_isTransferType(debit) && _isTransferType(credit)) {
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
      status: detection.isHighConfidence ? 'confirmed' : 'detected',
      createdAt: DateTime.now(),
    );

    final pairId = await db.insert('transfer_pairs', pair.toMap());

    // Auto-categorize if high confidence
    if (detection.isHighConfidence) {
      await db.update(
        'transactions',
        {'category': 'Transfer'},
        where: 'id = ?',
        whereArgs: [detection.debitTransaction.id],
      );

      await db.update(
        'transactions',
        {'category': 'Transfer'},
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

      // Categorize transactions as Transfer
      await db.update(
        'transactions',
        {'category': 'Transfer'},
        where: 'id = ?',
        whereArgs: [pair.debitTransactionId],
      );

      await db.update(
        'transactions',
        {'category': 'Transfer'},
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
