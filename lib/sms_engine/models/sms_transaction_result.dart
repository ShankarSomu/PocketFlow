/// SMS Transaction Parsing Result Model
/// 
/// Represents the structured output of the advanced step-by-step SMS parsing engine
/// with region awareness and continuous improvement capabilities.
class SmsTransactionResult {
  SmsTransactionResult({
    required this.isTransaction,
    required this.transactionType,
    required this.confidenceScore,
    required this.reasoning,
    this.amount,
    this.currency,
    this.merchant,
    this.accountIdentifier,
    this.bank,
    this.region = RegionEnum.unknown,
    this.improvementSuggestions = const [],
  });

  /// Whether this SMS is a financial transaction
  final bool isTransaction;
  
  /// Type of transaction: debit, credit, or unknown
  final TransactionTypeEnum transactionType;
  
  /// Extracted amount (null if not found)
  final double? amount;
  
  /// Currency code or symbol (₹, $, USD, INR, etc.)
  final String? currency;
  
  /// Merchant or counterparty name
  final String? merchant;
  
  /// Account identifier (e.g., ****1234, UPI:user@bank)
  final String? accountIdentifier;
  
  /// Bank or financial institution name
  final String? bank;
  
  /// Detected region (INDIA, US, or UNKNOWN)
  final RegionEnum region;
  
  /// Confidence score from 0.0 to 1.0
  final double confidenceScore;
  
  /// Detailed reasoning explaining parsing decisions
  final String reasoning;
  
  /// Improvement suggestions for evolving the parser
  final List<String> improvementSuggestions;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'is_transaction': isTransaction,
      'transaction_type': transactionType.name,
      'amount': amount,
      'currency': currency,
      'merchant': merchant,
      'account_identifier': accountIdentifier,
      'bank': bank,
      'region': region.name,
      'confidence_score': confidenceScore,
      'improvement_suggestions': improvementSuggestions,
      'reasoning': reasoning,
    };
  }

  /// Create from JSON
  factory SmsTransactionResult.fromJson(Map<String, dynamic> json) {
    return SmsTransactionResult(
      isTransaction: json['is_transaction'] as bool,
      transactionType: TransactionTypeEnum.fromString(json['transaction_type'] as String? ?? 'unknown'),
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      merchant: json['merchant'] as String?,
      accountIdentifier: json['account_identifier'] as String?,
      bank: json['bank'] as String?,
      region: RegionEnum.fromString(json['region'] as String? ?? 'UNKNOWN'),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      improvementSuggestions: (json['improvement_suggestions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      reasoning: json['reasoning'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'SmsTransactionResult(isTransaction: $isTransaction, type: ${transactionType.name}, '
           'amount: $amount, currency: $currency, merchant: $merchant, '
           'account: $accountIdentifier, bank: $bank, region: ${region.name}, '
           'confidence: $confidenceScore, suggestions: ${improvementSuggestions.length})';
  }
}

/// Transaction type enumeration
enum TransactionTypeEnum {
  debit,
  credit,
  unknown;

  String get name {
    switch (this) {
      case TransactionTypeEnum.debit:
        return 'debit';
      case TransactionTypeEnum.credit:
        return 'credit';
      case TransactionTypeEnum.unknown:
        return 'unknown';
    }
  }

  static TransactionTypeEnum fromString(String value) {
    switch (value.toLowerCase()) {
      case 'debit':
        return TransactionTypeEnum.debit;
      case 'credit':
        return TransactionTypeEnum.credit;
      default:
        return TransactionTypeEnum.unknown;
    }
  }
}

/// Region enumeration for region-aware parsing
enum RegionEnum {
  india,
  us,
  unknown;

  String get name {
    switch (this) {
      case RegionEnum.india:
        return 'INDIA';
      case RegionEnum.us:
        return 'US';
      case RegionEnum.unknown:
        return 'UNKNOWN';
    }
  }

  static RegionEnum fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INDIA':
        return RegionEnum.india;
      case 'US':
        return RegionEnum.us;
      default:
        return RegionEnum.unknown;
    }
  }
}
