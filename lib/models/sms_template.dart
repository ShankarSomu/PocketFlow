import 'dart:convert';

/// SMS template for pattern matching and learning
class SmsTemplate {

  SmsTemplate({
    required this.institutionName, required this.messagePattern, required this.transactionType, required this.createdAt, this.id,
    this.senderPatterns = const [],
    this.amountPattern,
    this.merchantPattern,
    this.accountIdPattern,
    this.balancePattern,
    this.matchCount = 0,
    this.userConfirmations = 0,
    this.userRejections = 0,
    this.accuracy = 0.5,
    this.isUserCreated = false,
    this.lastUsed,
  });

  factory SmsTemplate.fromMap(Map<String, dynamic> m) => SmsTemplate(
    id: m['id'],
    institutionName: m['institution_name'],
    senderPatterns: m['sender_patterns'] != null
        ? List<String>.from(jsonDecode(m['sender_patterns']))
        : [],
    messagePattern: m['message_pattern'],
    amountPattern: m['amount_pattern'],
    merchantPattern: m['merchant_pattern'],
    accountIdPattern: m['account_id_pattern'],
    balancePattern: m['balance_pattern'],
    transactionType: m['transaction_type'],
    matchCount: m['match_count'] ?? 0,
    userConfirmations: m['user_confirmations'] ?? 0,
    userRejections: m['user_rejections'] ?? 0,
    accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0.5,
    isUserCreated: (m['is_user_created'] ?? 0) == 1,
    createdAt: DateTime.parse(m['created_at']),
    lastUsed: m['last_used'] != null ? DateTime.parse(m['last_used']) : null,
  );
  final int? id;
  final String institutionName;     // "Chase", "HDFC Bank"
  final List<String> senderPatterns; // Regex patterns for sender IDs
  final String messagePattern;      // Regex for message body
  
  // Extraction Rules
  final String? amountPattern;      // Amount extraction regex
  final String? merchantPattern;    // Merchant extraction regex
  final String? accountIdPattern;   // Account identifier pattern
  final String? balancePattern;     // Balance extraction
  
  // Classification
  final String transactionType;     // 'debit', 'credit', 'balance', 'transfer'
  
  // Learning Metadata
  final int matchCount;             // Times this template matched
  final int userConfirmations;      // User validated matches
  final int userRejections;         // User rejected matches
  final double accuracy;            // confirmations / (confirmations + rejections)
  
  final bool isUserCreated;         // User-defined template
  final DateTime createdAt;
  final DateTime? lastUsed;

  Map<String, dynamic> toMap() => {
    'id': id,
    'institution_name': institutionName,
    'sender_patterns': jsonEncode(senderPatterns),
    'message_pattern': messagePattern,
    'amount_pattern': amountPattern,
    'merchant_pattern': merchantPattern,
    'account_id_pattern': accountIdPattern,
    'balance_pattern': balancePattern,
    'transaction_type': transactionType,
    'match_count': matchCount,
    'user_confirmations': userConfirmations,
    'user_rejections': userRejections,
    'accuracy': accuracy,
    'is_user_created': isUserCreated ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'last_used': lastUsed?.toIso8601String(),
  };

  bool get isHighAccuracy => accuracy >= 0.80;
  bool get isMediumAccuracy => accuracy >= 0.60 && accuracy < 0.80;
  bool get isLowAccuracy => accuracy < 0.60;

  int get totalFeedback => userConfirmations + userRejections;
  bool get hasEnoughFeedback => totalFeedback >= 5;

  String get accuracyLabel {
    if (!hasEnoughFeedback) return '📊 Learning';
    if (isHighAccuracy) return '✅ ${(accuracy * 100).toStringAsFixed(0)}%';
    if (isMediumAccuracy) return '⚠️ ${(accuracy * 100).toStringAsFixed(0)}%';
    return '❌ ${(accuracy * 100).toStringAsFixed(0)}%';
  }
}
