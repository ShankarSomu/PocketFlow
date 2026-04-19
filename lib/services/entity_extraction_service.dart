import '../models/sms_types.dart';

/// Extracted financial entities from SMS
class ExtractedEntities {    // Overall extraction confidence

  ExtractedEntities({
    required this.transactionType, required this.timestamp, this.amount,
    this.merchant,
    this.accountIdentifier,
    this.institutionName,
    this.balance,
    this.referenceNumber,
    this.confidenceScore = 0.5,
  });
  final double? amount;
  final String? merchant;
  final String? accountIdentifier; // "****1234", "UPI:user@bank"
  final String? institutionName;   // "Chase", "HDFC Bank"
  final double? balance;
  final String? referenceNumber;
  final SmsType transactionType;
  final DateTime timestamp;
  final double confidenceScore;

  bool get hasRequiredFields => amount != null;
  bool get hasAccountInfo => accountIdentifier != null || institutionName != null;
  bool get isHighConfidence => confidenceScore >= 0.8;
  bool get isMediumConfidence => confidenceScore >= 0.5 && confidenceScore < 0.8;
}

/// Entity Extraction Service
/// Extracts structured financial data from SMS messages
class EntityExtractionService {
  // ── Amount Extraction Patterns ──────────────────────────────────────────────
  
  static late final List<RegExp> _amountPatterns = [
    // Currency symbol before: $1,234.56
    RegExp(r'\$\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    // Currency code before: USD 1234, INR 500, Rs.1,000
    RegExp(r'(?:USD|INR|Rs\.?|₹|RM|AED|GBP|EUR|SGD|CAD|AUD|HKD)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    // Currency code after: 1234 USD, 500 INR
    RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:USD|INR|Rs|₹)', caseSensitive: false),
    // Generic amount with keywords: amt Rs.500, amount 1234
    RegExp(r'(?:amt|amount|sum)[:\s]*(?:Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    // Generic number that looks like currency
    RegExp(r'\b([\d,]+\.\d{2})\b'),
  ];

  // ── Account Identifier Patterns ────────────────────────────────────────────
  
  static late final List<RegExp> _accountIdentifierPatterns = [
    // A/c ****1234, Account ****5678
    RegExp(r'(?:a/c|account|card).*?[xX*]{4}(\d{4})', caseSensitive: false),
    // Card ending 1234
    RegExp(r'(?:ending|last)\s+(\d{4})', caseSensitive: false),
    // XX1234 (common format)
    RegExp(r'\b[xX]{2}(\d{4})\b'),
    // UPI ID: user@okicici, VPA: user@ybl
    RegExp(r'(?:UPI|VPA)\s*(?:ID)?:\s*(\S+@\S+)', caseSensitive: false),
    // Simple 4 digits after "account"
    RegExp(r'account\s*(?:number)?.*?(\d{4})\b', caseSensitive: false),
  ];

  // ── Institution Name Mapping ────────────────────────────────────────────────
  
  static final Map<String, String> _usInstitutions = {
    'chase': 'Chase Bank',
    'jpmorgan': 'Chase Bank',
    'bofa': 'Bank of America',
    'bankofamerica': 'Bank of America',
    'wellsfargo': 'Wells Fargo',
    'wells': 'Wells Fargo',
    'citi': 'Citibank',
    'citibank': 'Citibank',
    'capitalone': 'Capital One',
    'amex': 'American Express',
    'americanexpress': 'American Express',
    'discover': 'Discover',
    'usbank': 'US Bank',
    'pnc': 'PNC Bank',
    'td': 'TD Bank',
    'bankoftexas': 'Bank of Texas',
    'regions': 'Regions Bank',
    'suntrust': 'SunTrust Bank',
    'bbt': 'BB&T',
    'fifththird': 'Fifth Third Bank',
  };
  
  static final Map<String, String> _indianInstitutions = {
    'hdfcbk': 'HDFC Bank',
    'hdfc': 'HDFC Bank',
    'icicibk': 'ICICI Bank',
    'icici': 'ICICI Bank',
    'sbiinb': 'State Bank of India',
    'sbi': 'State Bank of India',
    'axisbk': 'Axis Bank',
    'axis': 'Axis Bank',
    'kotakb': 'Kotak Mahindra Bank',
    'kotak': 'Kotak Mahindra Bank',
    'pnbsms': 'Punjab National Bank',
    'pnb': 'Punjab National Bank',
    'bobimt': 'Bank of Baroda',
    'bob': 'Bank of Baroda',
    'yesbnk': 'Yes Bank',
    'yesbank': 'Yes Bank',
    'idfcbk': 'IDFC First Bank',
    'idfc': 'IDFC First Bank',
    'aubank': 'AU Small Finance Bank',
    'federal': 'Federal Bank',
    'indusind': 'IndusInd Bank',
    'canbnk': 'Canara Bank',
    'canara': 'Canara Bank',
    'boiind': 'Bank of India',
    'unionbk': 'Union Bank',
    'union': 'Union Bank',
    'paytm': 'Paytm Payments Bank',
    'phonepe': 'PhonePe',
    'gpay': 'Google Pay',
    'googlepay': 'Google Pay',
  };

  // ── Merchant Extraction Patterns ────────────────────────────────────────────
  
  static late final List<RegExp> _merchantPatterns = [
    // "at MERCHANT", "to MERCHANT", "on MERCHANT", "for MERCHANT"
    RegExp(r'\bat\s+([A-Za-z0-9 &\-''.]{3,40})', caseSensitive: false),
    RegExp(r'\bto\s+([A-Za-z0-9 &\-''.]{3,40})', caseSensitive: false),
    RegExp(r'\bon\s+([A-Za-z0-9 &\-''.]{3,40})', caseSensitive: false),
    RegExp(r'\bfor\s+([A-Za-z0-9 &\-''.]{3,40})', caseSensitive: false),
  ];

  // ── Reference Number Patterns ───────────────────────────────────────────────
  
  static late final List<RegExp> _referencePatterns = [
    // UPI Ref: 123456789012
    RegExp(r'(?:UPI|UTR|RRN|Ref(?:erence)?)\s*(?:no|number|#)?[:=]?\s*(\w+)', caseSensitive: false),
    // Transaction ID: ABC123
    RegExp(r'(?:txn|transaction)\s*(?:id|ref)?[:=]?\s*(\w+)', caseSensitive: false),
  ];

  // ── Balance Extraction Patterns ─────────────────────────────────────────────
  
  static late final List<RegExp> _balancePatterns = [
    // Available balance: 5000.00
    RegExp(r'(?:avl|available|current|total)\s*bal(?:ance)?[:=]?\s*(?:Rs\.?|₹|INR|\$)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
    // Balance is 5000
    RegExp(r'bal(?:ance)?\s*is\s*(?:Rs\.?|₹|INR|\$)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
  ];

  // ── Main Extraction Method ──────────────────────────────────────────────────

  /// Extract all financial entities from SMS
  static ExtractedEntities extract(RawSmsMessage sms, SmsClassification classification) {
    final body = sms.body;
    final sender = sms.sender;
    
    final amount = _extractAmount(body);
    final merchant = _extractMerchant(body, classification.type);
    final accountId = _extractAccountIdentifier(body);
    final institution = _extractInstitution(sender, body);
    final balance = _extractBalance(body);
    final reference = _extractReference(body);
    
    // Calculate overall confidence
    double confidence = 0.0;
    if (amount != null) confidence += 0.40;
    if (accountId != null) confidence += 0.25;
    if (institution != null) confidence += 0.20;
    if (merchant != null) confidence += 0.10;
    if (classification.isHighConfidence) confidence += 0.05;
    
    return ExtractedEntities(
      amount: amount,
      merchant: merchant,
      accountIdentifier: accountId,
      institutionName: institution,
      balance: balance,
      referenceNumber: reference,
      transactionType: classification.type,
      timestamp: sms.timestamp,
      confidenceScore: confidence.clamp(0.0, 1.0),
    );
  }

  // ── Extraction Helper Methods ───────────────────────────────────────────────

  /// Extract amount from SMS body (multi-currency support)
  static double? _extractAmount(String body) {
    double? maxAmount;
    
    for (final pattern in _amountPatterns) {
      final matches = pattern.allMatches(body);
      for (final match in matches) {
        final raw = match.group(1)?.replaceAll(',', '');
        if (raw == null) continue;
        
        final value = double.tryParse(raw);
        if (value != null && value > 0 && value < 10000000) {
          // Keep largest plausible amount
          if (maxAmount == null || value > maxAmount) {
            maxAmount = value;
          }
        }
      }
    }
    
    return maxAmount;
  }

  /// Extract account identifier (last 4 digits, UPI ID, etc.)
  static String? _extractAccountIdentifier(String body) {
    for (final pattern in _accountIdentifierPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final extracted = match.group(1);
        if (extracted != null && extracted.isNotEmpty) {
          // Standardize format
          if (extracted.contains('@')) {
            return 'UPI:$extracted'; // UPI ID
          } else {
            return '****$extracted'; // Last 4 digits
          }
        }
      }
    }
    
    return null;
  }

  /// Extract institution name from sender ID or body
  static String? _extractInstitution(String sender, String body) {
    final allInstitutions = {..._usInstitutions, ..._indianInstitutions};
    final searchText = '${sender.toLowerCase()} ${body.toLowerCase()}';
    
    // Direct match in sender or body
    for (final entry in allInstitutions.entries) {
      if (searchText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Extract merchant name using multiple strategies
  static String? _extractMerchant(String body, SmsType type) {
    // Only extract for transaction types
    if (type != SmsType.transactionDebit && type != SmsType.transactionCredit) {
      return null;
    }
    
    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length >= 3) {
          // Clean up trailing punctuation
          return merchant
              .replaceAll(RegExp(r'[.\s]+$'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        }
      }
    }
    
    return null;
  }

  /// Extract reference number (UPI ref, transaction ID, etc.)
  static String? _extractReference(String body) {
    for (final pattern in _referencePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final ref = match.group(1);
        if (ref != null && ref.length >= 6) {
          return ref;
        }
      }
    }
    
    return null;
  }

  /// Extract balance from balance update SMS
  static double? _extractBalance(String body) {
    for (final pattern in _balancePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value >= 0) {
            return value;
          }
        }
      }
    }
    
    return null;
  }

  /// Get institution name from a list of keywords
  static String? getInstitutionFromKeywords(List<String> keywords) {
    final allInstitutions = {..._usInstitutions, ..._indianInstitutions};
    
    for (final keyword in keywords) {
      final lower = keyword.toLowerCase();
      if (allInstitutions.containsKey(lower)) {
        return allInstitutions[lower];
      }
    }
    
    return null;
  }
}
