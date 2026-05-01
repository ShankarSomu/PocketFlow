class Transaction {

  Transaction({
    required this.type, required this.amount, required this.date, required this.accountId, this.id,
    this.category = 'uncategorized',
    this.note,
    this.recurringId,
    this.smsSource,
    this.sourceType = 'manual',
    this.merchant,
    this.confidenceScore,
    this.needsReview = false,
    this.userDisputed = false,
    this.extractedBank,
    this.extractedAccountIdentifier,
    this.fromAccountId,
    this.toAccountId,
    this.deletedAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'],
        type: m['type'],
        amount: m['amount'],
        category: m['category'] ?? 'uncategorized',  // Default if null
        note: m['note'],
        date: DateTime.parse(m['date']),
        accountId: m['account_id'] as int,  // Required - will throw if null
        recurringId: m['recurring_id'],
        smsSource: m['sms_source'],
        sourceType: m['source_type'] ?? 'manual',
        merchant: m['merchant'],
        confidenceScore: m['confidence_score'],
        needsReview: (m['needs_review'] ?? 0) == 1,
        userDisputed: (m['user_disputed'] ?? 0) == 1,
        extractedBank: m['extracted_institution'],
        extractedAccountIdentifier: m['extracted_identifier'],
        fromAccountId: m['from_account_id'],
        toAccountId: m['to_account_id'],
        deletedAt: m['deleted_at'],
      );
  final int? id;
  final String type;
  final double amount;
  final String category;  // Optional, defaults to 'uncategorized'
  final String? note;
  final DateTime date;
  final int accountId;  // REQUIRED - every transaction must have an account
  final int? recurringId;
  
  // ── Enhanced Hybrid Transaction Mapping Fields ──
  final String? smsSource;         // Original SMS text (if from SMS)
  final String sourceType;         // 'sms' | 'manual' | 'recurring' | 'import'
  final String? merchant;          // Standardized merchant name
  final double? confidenceScore;   // 0.0-1.0 for SMS matching confidence
  final bool needsReview;          // Flag for low-confidence SMS matches
  final bool userDisputed;         // User clicked 👎 (soft disagreement marker)
  final String? extractedBank;     // Bank name extracted from SMS
  final String? extractedAccountIdentifier; // Account identifier extracted from SMS
  
  // ── Transfer Fields ──
  final int? fromAccountId;        // Source account for transfers
  final int? toAccountId;          // Destination account for transfers
  
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
        'user_disputed': userDisputed ? 1 : 0,
        'extracted_institution': extractedBank,
        'extracted_identifier': extractedAccountIdentifier,
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'deleted_at': deletedAt,
      };
  
  /// Check if this transaction is from SMS
  bool get isFromSms => sourceType == 'sms';
  
  /// Check if this transaction requires user review
  bool get requiresReview => needsReview;
  
  /// Check if this is a transfer transaction
  bool get isTransfer => fromAccountId != null && toAccountId != null;
  
  /// Get transfer direction (outgoing/incoming/internal)
  String? get transferDirection {
    if (!isTransfer) return null;
    if (accountId == fromAccountId && accountId == toAccountId) return 'internal';
    if (accountId == fromAccountId) return 'outgoing';
    if (accountId == toAccountId) return 'incoming';
    return 'unknown';
  }
  
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
