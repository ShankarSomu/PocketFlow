/// Account candidate detected from SMS but requiring user confirmation
class AccountCandidate {

  AccountCandidate({
    required this.firstSeenDate, required this.lastSeenDate, required this.createdAt, this.id,
    this.institutionName,
    this.accountIdentifier,
    this.smsKeywords = const [],
    this.suggestedType = 'checking',
    this.confidenceScore = 0.5,
    this.transactionCount = 1,
    this.status = 'pending',
    this.mergedIntoAccountId,
  });

  factory AccountCandidate.fromMap(Map<String, dynamic> m) => AccountCandidate(
    id: m['id'],
    institutionName: m['institution_name'],
    accountIdentifier: m['account_identifier'],
    smsKeywords: m['sms_keywords'] != null 
        ? (m['sms_keywords'] as String).split(',').where((s) => s.isNotEmpty).toList()
        : [],
    suggestedType: m['suggested_type'] ?? 'checking',
    confidenceScore: (m['confidence_score'] as num?)?.toDouble() ?? 0.5,
    transactionCount: m['transaction_count'] ?? 1,
    firstSeenDate: DateTime.parse(m['first_seen_date']),
    lastSeenDate: DateTime.parse(m['last_seen_date']),
    status: m['status'] ?? 'pending',
    mergedIntoAccountId: m['merged_into_account_id'],
    createdAt: DateTime.parse(m['created_at']),
  );
  final int? id;
  final String? institutionName;   // Extracted from SMS
  final String? accountIdentifier; // "****1234", "UPI: xyz@bank"
  final List<String> smsKeywords;  // All sender IDs seen
  final String suggestedType;      // Best guess: 'checking', 'credit', etc.
  final double confidenceScore;    // How sure we are (0.0-1.0)
  
  final int transactionCount;      // # of SMS linked to this candidate
  final DateTime firstSeenDate;    // First SMS date
  final DateTime lastSeenDate;     // Most recent SMS
  
  final String status;             // 'pending', 'confirmed', 'merged', 'rejected'
  final int? mergedIntoAccountId;  // If merged into existing account
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'institution_name': institutionName,
    'account_identifier': accountIdentifier,
    'sms_keywords': smsKeywords.join(','),
    'suggested_type': suggestedType,
    'confidence_score': confidenceScore,
    'transaction_count': transactionCount,
    'first_seen_date': firstSeenDate.toIso8601String(),
    'last_seen_date': lastSeenDate.toIso8601String(),
    'status': status,
    'merged_into_account_id': mergedIntoAccountId,
    'created_at': createdAt.toIso8601String(),
  };

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isMerged => status == 'merged';
  bool get isRejected => status == 'rejected';

  bool get isHighConfidence => confidenceScore >= 0.8;
  bool get isMediumConfidence => confidenceScore >= 0.5 && confidenceScore < 0.8;
  bool get isLowConfidence => confidenceScore < 0.5;

  String get displayName {
    final parts = <String>[];
    if (institutionName != null) parts.add(institutionName!);
    if (accountIdentifier != null) parts.add(accountIdentifier!);
    return parts.isNotEmpty ? parts.join(' ') : 'Unknown Account';
  }

  String get confidenceLabel {
    if (isHighConfidence) return '✅ High Confidence';
    if (isMediumConfidence) return '⚠️ Medium Confidence';
    return '❓ Low Confidence';
  }
}
