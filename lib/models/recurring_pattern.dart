import 'dart:convert';

/// Detected recurring transaction pattern
class RecurringPattern {

  RecurringPattern({
    required this.category, required this.type, required this.averageAmount, required this.amountVariance, required this.frequency, required this.intervalDays, required this.occurrenceCount, required this.confidenceScore, required this.firstOccurrence, required this.lastOccurrence, required this.createdAt, this.id,
    this.merchant,
    this.nextExpectedDate,
    this.transactionIds = const [],
    this.accountId,
    this.status = 'candidate',
  });

  factory RecurringPattern.fromMap(Map<String, dynamic> m) => RecurringPattern(
    id: m['id'],
    merchant: m['merchant'],
    category: m['category'],
    type: m['type'],
    averageAmount: (m['average_amount'] as num).toDouble(),
    amountVariance: (m['amount_variance'] as num).toDouble(),
    frequency: m['frequency'],
    intervalDays: m['interval_days'],
    occurrenceCount: m['occurrence_count'],
    confidenceScore: (m['confidence_score'] as num).toDouble(),
    firstOccurrence: DateTime.parse(m['first_occurrence']),
    lastOccurrence: DateTime.parse(m['last_occurrence']),
    nextExpectedDate: m['next_expected_date'] != null 
        ? DateTime.parse(m['next_expected_date']) 
        : null,
    transactionIds: m['transaction_ids'] != null
        ? List<int>.from(jsonDecode(m['transaction_ids']))
        : [],
    accountId: m['account_id'],
    status: m['status'] ?? 'candidate',
    createdAt: DateTime.parse(m['created_at']),
  );
  final int? id;
  final String? merchant;      // Identified merchant
  final String category;       // Spending category
  final String type;           // 'income' or 'expense'
  
  // Pattern Characteristics
  final double averageAmount;
  final double amountVariance;     // Standard deviation
  final String frequency;          // 'weekly', 'monthly', 'yearly', etc.
  final int intervalDays;          // Average days between occurrences
  
  // Confidence & Validation
  final int occurrenceCount;       // How many times detected
  final double confidenceScore;    // 0.0-1.0
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;
  final DateTime? nextExpectedDate; // Prediction
  
  // Linking
  final List<int> transactionIds;  // All member transactions
  final int? accountId;            // Primary account
  
  final String status;             // 'candidate', 'confirmed', 'inactive'
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'merchant': merchant,
    'category': category,
    'type': type,
    'average_amount': averageAmount,
    'amount_variance': amountVariance,
    'frequency': frequency,
    'interval_days': intervalDays,
    'occurrence_count': occurrenceCount,
    'confidence_score': confidenceScore,
    'first_occurrence': firstOccurrence.toIso8601String(),
    'last_occurrence': lastOccurrence.toIso8601String(),
    'next_expected_date': nextExpectedDate?.toIso8601String(),
    'transaction_ids': jsonEncode(transactionIds),
    'account_id': accountId,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

  bool get isCandidate => status == 'candidate';
  bool get isConfirmed => status == 'confirmed';
  bool get isInactive => status == 'inactive';

  bool get isHighConfidence => confidenceScore >= 0.8;
  bool get isMediumConfidence => confidenceScore >= 0.6 && confidenceScore < 0.8;
  bool get isLowConfidence => confidenceScore < 0.6;

  bool get isSubscriptionLike {
    // Monthly frequency with consistent amount
    if (frequency != 'monthly') return false;
    if (amountVariance / averageAmount > 0.10) return false;
    return true;
  }

  String get displayName => merchant ?? category;

  String get frequencyLabel {
    switch (frequency) {
      case 'weekly': return 'Weekly';
      case 'biweekly': return 'Bi-weekly';
      case 'monthly': return 'Monthly';
      case 'quarterly': return 'Quarterly';
      case 'semi-annual': return 'Semi-annual';
      case 'yearly': return 'Yearly';
      default: return frequency;
    }
  }

  int? get daysUntilNext {
    if (nextExpectedDate == null) return null;
    return nextExpectedDate!.difference(DateTime.now()).inDays;
  }

  bool get isOverdue {
    if (nextExpectedDate == null) return false;
    return DateTime.now().isAfter(nextExpectedDate!);
  }
}
