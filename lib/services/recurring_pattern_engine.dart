import 'dart:math';

import '../db/database.dart';
import '../models/recurring_pattern.dart';
import '../models/transaction.dart';

/// Recurring Pattern Detection Result
class PatternDetection {

  PatternDetection({
    required this.merchant,
    required this.transactions,
    required this.averageAmount,
    required this.amountStdDev,
    required this.intervalDays,
    required this.confidence,
    required this.patternType,
    this.nextExpected,
  });
  final String merchant;
  final List<Transaction> transactions;
  final double averageAmount;
  final double amountStdDev;
  final int intervalDays;
  final double confidence;
  final String patternType; // 'subscription', 'emi', 'salary', 'bill'
  final DateTime? nextExpected;

  bool get isHighConfidence => confidence >= 0.80;
  bool get isMediumConfidence => confidence >= 0.60 && confidence < 0.80;
  
  double get amountMin => transactions.map((t) => t.amount).reduce(min);
  double get amountMax => transactions.map((t) => t.amount).reduce(max);
  
  int get occurrences => transactions.length;
}

/// Recurring Pattern Detection Engine
/// Detects subscription, EMI, salary, and other recurring transactions
class RecurringPatternEngine {
  // Minimum occurrences to establish pattern
  static const int minOccurrences = 3;
  
  // Maximum coefficient of variation for amount consistency
  static const double maxCoefficientOfVariation = 0.15; // 15%
  
  // Interval tolerance (±3 days)
  static const int intervalToleranceDays = 3;

  /// Detect all recurring patterns in transactions
  static Future<List<PatternDetection>> detectPatterns({
    DateTime? since,
    int minOccurrences = minOccurrences,
  }) async {
    final db = await AppDatabase.db();
    
    // Get transactions from last 12 months for pattern analysis
    final cutoff = since ?? DateTime.now().subtract(const Duration(days: 365));
    
    final transactions = await db.query(
      'transactions',
      where: 'date >= ? AND deleted_at IS NULL',
      whereArgs: [cutoff.toIso8601String()],
      orderBy: 'date ASC',
    );
    
    final txns = transactions.map(Transaction.fromMap).toList();
    
    // Group by merchant
    final merchantGroups = <String, List<Transaction>>{};
    for (final txn in txns) {
      final merchant = _normalizeMerchant(txn.merchant ?? txn.note ?? 'Unknown');
      if (merchant.isEmpty) continue;
      
      merchantGroups.putIfAbsent(merchant, () => []);
      merchantGroups[merchant]!.add(txn);
    }
    
    // Analyze each merchant group
    final patterns = <PatternDetection>[];
    
    for (final entry in merchantGroups.entries) {
      final merchant = entry.key;
      final txnList = entry.value;
      
      // Skip if too few transactions
      if (txnList.length < minOccurrences) continue;
      
      // Analyze for recurring pattern
      final pattern = _analyzeTransactionGroup(merchant, txnList);
      if (pattern != null && pattern.confidence >= 0.50) {
        patterns.add(pattern);
      }
    }
    
    // Sort by confidence descending
    patterns.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return patterns;
  }

  /// Normalize merchant name for grouping
  static String _normalizeMerchant(String merchant) {
    String normalized = merchant.toLowerCase().trim();
    
    // Remove common prefixes
    normalized = normalized.replaceAll(RegExp(r'^(sms:|📱\s*)'), '');
    
    // Remove trailing codes/numbers
    normalized = normalized.replaceAll(RegExp(r'[#*]\d+$'), '');
    
    // Remove dates
    normalized = normalized.replaceAll(RegExp(r'\d{1,2}[/-]\d{1,2}'), '');
    
    // Remove extra spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return normalized;
  }

  /// Analyze a group of transactions for recurring pattern
  static PatternDetection? _analyzeTransactionGroup(
    String merchant,
    List<Transaction> txnList,
  ) {
    // Sort by date
    final sorted = List<Transaction>.from(txnList)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Calculate amount statistics
    final amounts = sorted.map((t) => t.amount).toList();
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance = amounts.map((a) => pow(a - avgAmount, 2)).reduce((a, b) => a + b) / amounts.length;
    final stdDev = sqrt(variance);
    final coefficientOfVariation = stdDev / avgAmount;
    
    // Check amount consistency
    if (coefficientOfVariation > maxCoefficientOfVariation) {
      // Amounts vary too much - not a recurring pattern
      return null;
    }
    
    // Calculate time intervals between transactions
    final intervals = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final days = sorted[i].date.difference(sorted[i - 1].date).inDays;
      intervals.add(days);
    }
    
    // Calculate average interval
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final intervalVariance = intervals.map((i) => pow(i - avgInterval, 2)).reduce((a, b) => a + b) / intervals.length;
    final intervalStdDev = sqrt(intervalVariance);
    final intervalCV = intervalStdDev / avgInterval;
    
    // Check interval consistency
    if (intervalCV > 0.25) {
      // Intervals vary too much - not regular
      return null;
    }
    
    // Determine pattern type based on interval and amount
    final patternType = _determinePatternType(
      avgInterval.round(),
      avgAmount,
      sorted.first.type == 'expense',
    );
    
    // Calculate confidence
    final confidence = _calculatePatternConfidence(
      occurrences: sorted.length,
      amountCV: coefficientOfVariation,
      intervalCV: intervalCV,
      intervalDays: avgInterval.round(),
    );
    
    // Predict next occurrence
    final lastDate = sorted.last.date;
    final nextExpected = lastDate.add(Duration(days: avgInterval.round()));
    
    return PatternDetection(
      merchant: merchant,
      transactions: sorted,
      averageAmount: avgAmount,
      amountStdDev: stdDev,
      intervalDays: avgInterval.round(),
      confidence: confidence,
      patternType: patternType,
      nextExpected: nextExpected,
    );
  }

  /// Determine pattern type based on characteristics
  static String _determinePatternType(int intervalDays, double amount, bool isDebit) {
    // Monthly patterns (25-35 days)
    if (intervalDays >= 25 && intervalDays <= 35) {
      if (!isDebit) {
        return 'salary'; // Monthly credit = salary
      } else if (amount < 50) {
        return 'subscription'; // Monthly small debit = subscription
      } else {
        return 'bill'; // Monthly large debit = bill
      }
    }
    
    // Weekly patterns (6-8 days)
    if (intervalDays >= 6 && intervalDays <= 8) {
      return 'subscription'; // Weekly = subscription
    }
    
    // Quarterly patterns (85-95 days)
    if (intervalDays >= 85 && intervalDays <= 95) {
      return 'bill'; // Quarterly = bill
    }
    
    // Biweekly patterns (13-15 days)
    if (intervalDays >= 13 && intervalDays <= 15) {
      if (!isDebit) {
        return 'salary'; // Biweekly credit = salary
      } else {
        return 'subscription';
      }
    }
    
    // Default
    if (isDebit) {
      return 'subscription';
    } else {
      return 'income';
    }
  }

  /// Calculate pattern detection confidence
  static double _calculatePatternConfidence({
    required int occurrences,
    required double amountCV,
    required double intervalCV,
    required int intervalDays,
  }) {
    double confidence = 0.0;
    
    // Base confidence from occurrences
    if (occurrences >= 12) {
      confidence += 0.40; // 1 year of data
    } else if (occurrences >= 6) {
      confidence += 0.30; // 6 months
    } else if (occurrences >= 3) {
      confidence += 0.20; // 3 occurrences
    }
    
    // Amount consistency bonus (max 0.30)
    if (amountCV < 0.02) {
      confidence += 0.30; // < 2% variation (very consistent)
    } else if (amountCV < 0.05) {
      confidence += 0.25; // < 5% variation
    } else if (amountCV < 0.10) {
      confidence += 0.20; // < 10% variation
    } else if (amountCV < 0.15) {
      confidence += 0.15; // < 15% variation
    }
    
    // Interval consistency bonus (max 0.30)
    if (intervalCV < 0.05) {
      confidence += 0.30; // Very regular intervals
    } else if (intervalCV < 0.10) {
      confidence += 0.25;
    } else if (intervalCV < 0.15) {
      confidence += 0.20;
    } else if (intervalCV < 0.25) {
      confidence += 0.15;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Create recurring pattern from detection
  static Future<int> createPattern(PatternDetection detection) async {
    final db = await AppDatabase.db();
    
    // Determine frequency from interval days
    String frequency;
    if (detection.intervalDays <= 7) {
      frequency = 'weekly';
    } else if (detection.intervalDays <= 15) {
      frequency = 'biweekly';
    } else if (detection.intervalDays <= 35) {
      frequency = 'monthly';
    } else if (detection.intervalDays <= 100) {
      frequency = 'quarterly';
    } else {
      frequency = 'yearly';
    }
    
    final pattern = RecurringPattern(
      merchant: detection.merchant,
      category: detection.transactions.first.category,
      type: detection.patternType,
      averageAmount: detection.averageAmount,
      amountVariance: detection.amountStdDev,
      frequency: frequency,
      intervalDays: detection.intervalDays,
      occurrenceCount: detection.occurrences,
      confidenceScore: detection.confidence,
      firstOccurrence: detection.transactions.first.date,
      lastOccurrence: detection.transactions.last.date,
      nextExpectedDate: detection.nextExpected,
      transactionIds: detection.transactions.map((t) => t.id!).toList(),
      status: detection.isHighConfidence ? 'auto_confirmed' : 'detected',
      createdAt: DateTime.now(),
    );
    
    final patternId = await db.insert('recurring_patterns', pattern.toMap());
    
    // Link transactions to pattern
    for (final txn in detection.transactions) {
      await db.update(
        'transactions',
        {
          'recurring_group_id': patternId,
          'is_recurring_candidate': 1,
        },
        where: 'id = ?',
        whereArgs: [txn.id],
      );
    }
    
    return patternId;
  }

  /// Confirm a recurring pattern
  static Future<void> confirmPattern(int patternId) async {
    final db = await AppDatabase.db();
    
    await db.update(
      'recurring_patterns',
      {
        'status': 'user_confirmed',
        'verified': 1,
      },
      where: 'id = ?',
      whereArgs: [patternId],
    );
  }

  /// Reject a recurring pattern
  static Future<void> rejectPattern(int patternId) async {
    final db = await AppDatabase.db();
    
    // Unlink transactions
    await db.update(
      'transactions',
      {
        'recurring_group_id': null,
        'is_recurring_candidate': 0,
      },
      where: 'recurring_group_id = ?',
      whereArgs: [patternId],
    );
    
    // Mark pattern as rejected
    await db.update(
      'recurring_patterns',
      {'status': 'rejected', 'verified': 0},
      where: 'id = ?',
      whereArgs: [patternId],
    );
  }

  /// Get all recurring patterns
  static Future<List<RecurringPattern>> getAllPatterns({String? status}) async {
    final db = await AppDatabase.db();
    
    final results = await db.query(
      'recurring_patterns',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'confidence DESC, occurrences DESC',
    );
    
    return results.map(RecurringPattern.fromMap).toList();
  }

  /// Get pending patterns (need user review)
  static Future<List<RecurringPattern>> getPendingPatterns() async {
    return getAllPatterns(status: 'detected');
  }

  /// Run pattern detection
  static Future<Map<String, dynamic>> runDetection({
    int sinceDays = 365,
    int minOccurrences = minOccurrences,
  }) async {
    final since = DateTime.now().subtract(Duration(days: sinceDays));
    final detections = await detectPatterns(since: since, minOccurrences: minOccurrences);
    
    int created = 0;
    int skipped = 0;
    
    for (final detection in detections) {
      // Check if pattern already exists for this merchant
      final db = await AppDatabase.db();
      final existing = await db.query(
        'recurring_patterns',
        where: 'merchant = ? AND status != ?',
        whereArgs: [detection.merchant, 'rejected'],
        limit: 1,
      );
      
      if (existing.isEmpty) {
        await createPattern(detection);
        created++;
      } else {
        skipped++;
      }
    }
    
    return {
      'total_detected': detections.length,
      'patterns_created': created,
      'already_exists': skipped,
      'by_type': _groupByType(detections),
      'high_confidence': detections.where((d) => d.isHighConfidence).length,
      'medium_confidence': detections.where((d) => d.isMediumConfidence).length,
    };
  }

  /// Group detections by pattern type
  static Map<String, int> _groupByType(List<PatternDetection> detections) {
    final groups = <String, int>{};
    
    for (final detection in detections) {
      groups[detection.patternType] = (groups[detection.patternType] ?? 0) + 1;
    }
    
    return groups;
  }

  /// Get pattern with transaction details
  static Future<Map<String, dynamic>?> getPatternDetails(int patternId) async {
    final db = await AppDatabase.db();
    
    final patternMap = await db.query(
      'recurring_patterns',
      where: 'id = ?',
      whereArgs: [patternId],
      limit: 1,
    );
    
    if (patternMap.isEmpty) return null;
    
    final pattern = RecurringPattern.fromMap(patternMap.first);
    
    // Get transactions
    final txnResults = await db.query(
      'transactions',
      where: 'recurring_group_id = ?',
      whereArgs: [patternId],
      orderBy: 'date ASC',
    );
    
    final transactions = txnResults.map(Transaction.fromMap).toList();
    
    return {
      'pattern': pattern,
      'transactions': transactions,
      'total_amount': transactions.fold<double>(0, (sum, t) => sum + t.amount),
      'monthly_cost': pattern.intervalDays > 0 
          ? (pattern.averageAmount * 30 / pattern.intervalDays)
          : 0,
    };
  }

  /// Update pattern with new transaction
  static Future<void> updatePatternWithNewTransaction(
    int patternId,
    Transaction newTransaction,
  ) async {
    final db = await AppDatabase.db();
    
    final patternMap = await db.query(
      'recurring_patterns',
      where: 'id = ?',
      whereArgs: [patternId],
      limit: 1,
    );
    
    if (patternMap.isEmpty) return;
    
    final pattern = RecurringPattern.fromMap(patternMap.first);
    
    // Update statistics
    final newOccurrences = pattern.occurrenceCount + 1;
    final newAvg = ((pattern.averageAmount * pattern.occurrenceCount) + newTransaction.amount) / newOccurrences;
    
    await db.update(
      'recurring_patterns',
      {
        'occurrence_count': newOccurrences,
        'average_amount': newAvg,
        'last_occurrence': newTransaction.date.toIso8601String(),
        'next_expected_date': newTransaction.date.add(Duration(days: pattern.intervalDays)).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patternId],
    );
    
    // Link transaction
    await db.update(
      'transactions',
      {
        'recurring_group_id': patternId,
        'is_recurring_candidate': 1,
      },
      where: 'id = ?',
      whereArgs: [newTransaction.id],
    );
  }
}
