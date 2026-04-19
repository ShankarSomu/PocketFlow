class Transaction {

  Transaction({
    required this.type, required this.amount, required this.category, required this.date, this.id,
    this.note,
    this.accountId,
    this.recurringId,
    this.smsSource,
    this.sourceType = 'manual',
    this.merchant,
    this.confidenceScore,
    this.needsReview = false,
    this.deletedAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'],
        type: m['type'],
        amount: m['amount'],
        category: m['category'],
        note: m['note'],
        date: DateTime.parse(m['date']),
        accountId: m['account_id'],
        recurringId: m['recurring_id'],
        smsSource: m['sms_source'],
        sourceType: m['source_type'] ?? 'manual',
        merchant: m['merchant'],
        confidenceScore: m['confidence_score'],
        needsReview: (m['needs_review'] ?? 0) == 1,
        deletedAt: m['deleted_at'],
      );
  final int? id;
  final String type;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final int? accountId;
  final int? recurringId;
  
  // ── Enhanced Hybrid Transaction Mapping Fields ──
  final String? smsSource;         // Original SMS text (if from SMS)
  final String sourceType;         // 'sms' | 'manual' | 'recurring' | 'import'
  final String? merchant;          // Standardized merchant name
  final double? confidenceScore;   // 0.0-1.0 for SMS matching confidence
  final bool needsReview;          // Flag for low-confidence SMS matches
  
  final int? deletedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'account_id': accountId,
        'recurring_id': recurringId,
        'sms_source': smsSource,
        'source_type': sourceType,
        'merchant': merchant,
        'confidence_score': confidenceScore,
        'needs_review': needsReview ? 1 : 0,
        'deleted_at': deletedAt,
      };
  
  /// Check if this transaction is from SMS
  bool get isFromSms => sourceType == 'sms';
  
  /// Check if this transaction requires user review
  bool get requiresReview => needsReview || (confidenceScore != null && confidenceScore! < 0.7);
  
  /// Get source badge text for UI
  String get sourceBadge {
    switch (sourceType) {
      case 'sms':
        return needsReview ? 'SMS (Needs Review)' : 'SMS';
      case 'manual':
        return 'Manual';
      case 'recurring':
        return 'Recurring';
      case 'import':
        return 'Imported';
      default:
        return sourceType;
    }
  }
}
