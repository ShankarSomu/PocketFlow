import 'package:pocket_flow/sms_engine/models/sms_types.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/services/merchant_normalization_service.dart';
import 'package:pocket_flow/sms_engine/feedback/sms_feedback_service.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_classification_service.dart';

/// Extracted financial entities from an SMS message.
class ExtractedEntities {
  const ExtractedEntities({
    required this.transactionType,
    required this.timestamp,
    this.amount,
    this.merchant,
    this.accountIdentifier,
    this.institutionName,
    this.balance,
    this.referenceNumber,
    this.confidenceScore = 0.5,
    this.learnedCategory,
  });

  final double? amount;
  final String? merchant;
  final String? accountIdentifier; // e.g. "****1234"
  final String? institutionName;   // e.g. "Citibank"
  final double? balance;
  final String? referenceNumber;
  final SmsType transactionType;
  final DateTime timestamp;
  final double confidenceScore;
  final String? learnedCategory;

  bool get hasRequiredFields => amount != null;
  bool get hasAccountInfo =>
      accountIdentifier != null || institutionName != null;
  bool get isHighConfidence => confidenceScore >= 0.8;
}

/// Entity Extraction Service - US banks only, no hardcoded keywords.
///
/// Extracts structured fields (amount, merchant, account, institution) from
/// raw SMS text using regex patterns tuned for US bank message formats.
/// All merchant normalization and category lookup is delegated to the
/// learning system (DB-backed rules), not hardcoded maps.
class EntityExtractionService {
  // Amount patterns (US: $ prefix, USD suffix, plain decimal)
  static final List<RegExp> _amountPatterns = [
    // $1,234.56  or  $ 50.00
    RegExp(r'\$\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    // USD 1234  or  1234 USD
    RegExp(r'USD\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*USD', caseSensitive: false),
    // INR/Rs patterns (Indian banks)
    RegExp(r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?)', caseSensitive: false),
    // amount 1234  /  amt: 50.00
    RegExp(
      r'(?:amount|amt)[:\s]+\$?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    // debited/credited with amount
    RegExp(
      r'(?:debited|credited|paid|received)\s+(?:with\s+)?(?:Rs\.?|INR|₹|\$)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    // "of Rs 1234" or "of $50"
    RegExp(
      r'of\s+(?:Rs\.?|INR|₹|\$)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    // Plain decimal that looks like money (last resort, must have 2 decimals)
    RegExp(r'\b([\d,]+\.\d{2})\b'),
    // NOTE: No plain integer fallback - too many false positives (card numbers, dates, etc.)
  ];

  // Account identifier patterns
  static final List<RegExp> _accountPatterns = [
    // "card ending in 1234" / "card ending 1234"
    RegExp(r'card\s+ending\s+(?:in\s+)?(\d{4})', caseSensitive: false),
    // "account - 3281" (BofA style) - hyphen or dash
    RegExp(r'account\s*[-]\s*(\d{4})', caseSensitive: false),
    // "acct ending in XXXX" / "acct ending XXXX"
    RegExp(r'acct\s+ending\s+(?:in\s+)?(\w{4})', caseSensitive: false),
    // "(XXXX)" (Capital One style)
    RegExp(r'\((\w{4})\)', caseSensitive: false),
    // "****1234" or "XXXX1234"
    RegExp(r'[*xX]{2,4}(\d{4})\b'),
  ];

  // US institution name map (sender/body keyword -> display name)
  // Kept minimal - only what's needed to match the sender or body text.
  static final Map<String, String> _institutions = {
    'citi':            'Citibank',
    'citibank':        'Citibank',
    'bofa':            'Bank of America',
    'bankofamerica':   'Bank of America',
    'bank of america': 'Bank of America',
    'chase':           'Chase Bank',
    'jpmorgan':        'Chase Bank',
    'wellsfargo':      'Wells Fargo',
    'wells fargo':     'Wells Fargo',
    'capitalone':      'Capital One',
    'capital one':     'Capital One',
    'amex':            'American Express',
    'americanexpress': 'American Express',
    'american express':'American Express',
    'discover':        'Discover',
    'usbank':          'US Bank',
    'us bank':         'US Bank',
    'pnc':             'PNC Bank',
    'tdbank':          'TD Bank',
    'td bank':         'TD Bank',
    'ally':            'Ally Bank',
    'usaa':            'USAA',
    'schwab':          'Charles Schwab',
    'fidelity':        'Fidelity',
    'truist':          'Truist Bank',
    'regions':         'Regions Bank',
    'keybank':         'KeyBank',
    'suntrust':        'SunTrust Bank',
    'fifththird':      'Fifth Third Bank',
    'fifth third':     'Fifth Third Bank',
    'navy federal':    'Navy Federal',
    'navyfederal':     'Navy Federal',
  };

  // Merchant extraction patterns
  // Matches "at MERCHANT", "from MERCHANT" in US bank SMS formats.
  static final List<RegExp> _merchantPatterns = [
    // "transaction was made at MERCHANT"
    RegExp(r"[Aa]t\s+([A-Z][A-Za-z0-9 &\-'.#]{2,40})", caseSensitive: false),
    // "purchase at MERCHANT" / "charge at MERCHANT"
    RegExp(
      r"(?:purchase|charge|payment)\s+(?:at|to|from)\s+([A-Za-z0-9 &\-'.#]{3,40})",
      caseSensitive: false,
    ),
    // "posted to MERCHANT"
    RegExp(r"posted\s+to\s+([A-Za-z0-9 &\-'.#]{3,40})", caseSensitive: false),
  ];

  // Noise words that are never valid merchant names
  static const _invalidMerchants = {
    'account', 'card', 'balance', 'transaction', 'payment',
    'your', 'the', 'a', 'an', 'us', 'you', 'bank', 'end', 'stop',
  };

  // Balance patterns
  static final List<RegExp> _balancePatterns = [
    RegExp(
      r'(?:available|current|total)\s+bal(?:ance)?\s+(?:is\s+)?\$?\s*([\d,]+(?:\.\d{2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'bal(?:ance)?\s+(?:is\s+)?\$?\s*([\d,]+(?:\.\d{2})?)',
      caseSensitive: false,
    ),
  ];

  // -------------------------------------------------------------------------
  // MAIN EXTRACTION METHOD
  // -------------------------------------------------------------------------

  /// Extract all financial entities from [sms].
  ///
  /// Uses US-focused regex only. Merchant normalization and category lookup
  /// are delegated to the DB-backed learning system.
  static Future<ExtractedEntities> extract(
    RawSmsMessage sms,
    SmsClassification classification,
  ) async {
    final body = sms.body;
    final sender = sms.sender;

    // Amount
    final amount = _extractAmount(body);

    // Merchant (raw -> normalized via learning system)
    final rawMerchant = _extractMerchant(body, classification.type);
    NormalizationResult? normResult;
    String? merchant;
    if (rawMerchant != null) {
      try {
        normResult =
            await MerchantNormalizationService.lookupWithResult(rawMerchant);
        merchant = normResult.normalizedName;
      } catch (e) {
        merchant = rawMerchant;
        AppLogger.log(
          LogLevel.debug,
          LogCategory.system,
          'merchant_normalization_failed',
          detail: e.toString(),
        );
      }
    }

    // Account identifier
    final accountId = _extractAccountIdentifier(body);

    // Institution
    final institution = _extractInstitution(sender, body);

    // Balance
    final balance = _extractBalance(body);

    // Learned category
    String? learnedCategory;
    if (merchant != null) {
      try {
        learnedCategory =
            await TransactionFeedbackService.lookupMerchantCategory(merchant);
      } catch (_) {}
    }

    // Confidence
    double confidence = 0.0;
    if (amount != null)      confidence += 0.40;
    if (accountId != null)   confidence += 0.25;
    if (institution != null) confidence += 0.20;
    if (merchant != null)    confidence += 0.10;
    if (classification.isHighConfidence) confidence += 0.05;

    if (normResult != null &&
        normResult.fromLearnedRule &&
        normResult.ruleConfidence != null) {
      confidence =
          (confidence + 0.2 * normResult.ruleConfidence!).clamp(0.0, 1.0);
    }

    return ExtractedEntities(
      amount: amount,
      merchant: merchant,
      accountIdentifier: accountId,
      institutionName: institution,
      balance: balance,
      transactionType: classification.type,
      timestamp: sms.timestamp,
      confidenceScore: confidence.clamp(0.0, 1.0),
      learnedCategory: learnedCategory,
    );
  }

  // -------------------------------------------------------------------------
  // EXTRACTION HELPERS
  // -------------------------------------------------------------------------

  static double? _extractAmount(String body) {
    AppLogger.log(
      LogLevel.debug,
      LogCategory.system,
      'amount_extraction_start',
      detail: 'Attempting to extract amount from: ${body.substring(0, body.length > 100 ? 100 : body.length)}...',
    );
    
    int patternIndex = 0;
    
    // Try patterns in priority order - return the FIRST valid match from the
    // highest-priority pattern. Do NOT pick the largest value across all patterns,
    // as that causes card numbers / account digits to win over real amounts.
    for (final pattern in _amountPatterns) {
      patternIndex++;
      final matches = pattern.allMatches(body);
      
      if (matches.isNotEmpty) {
        AppLogger.log(
          LogLevel.debug,
          LogCategory.system,
          'amount_pattern_matched',
          detail: 'Pattern $patternIndex matched ${matches.length} time(s)',
        );
      }
      
      for (final match in matches) {
        final raw = match.group(1)?.replaceAll(',', '');
        if (raw == null) continue;
        
        final value = double.tryParse(raw);
        if (value != null && value > 0 && value < 10000000) {
          AppLogger.log(
            LogLevel.info,
            LogCategory.system,
            'amount_extraction_success',
            detail: 'Pattern $patternIndex extracted: $value (raw: $raw)',
          );
          return value; // Return immediately - first match from highest-priority pattern wins
        }
      }
    }
    
    AppLogger.log(
      LogLevel.warning,
      LogCategory.system,
      'amount_extraction_failed',
      detail: 'No amount found in SMS',
    );
    
    return null;
  }

  static String? _extractAccountIdentifier(String body) {
    for (final pattern in _accountPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final extracted = match.group(1);
        if (extracted != null && extracted.isNotEmpty) {
          final digits = extracted.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length == 4) return '****$digits';
          return '****$extracted';
        }
      }
    }
    return null;
  }

  static String? _extractInstitution(String sender, String body) {
    final search = '${sender.toLowerCase()} ${body.toLowerCase()}';
    for (final entry in _institutions.entries) {
      if (search.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? _extractMerchant(String body, SmsType type) {
    if (type != SmsType.transactionDebit &&
        type != SmsType.transactionCredit &&
        type != SmsType.unknownFinancial) {
      return null;
    }

    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final raw = match.group(1)?.trim();
      if (raw == null || raw.length < 3) continue;

      final cleaned = raw
          .replaceAll(RegExp(r'[.]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (_invalidMerchants.contains(cleaned.toLowerCase())) continue;
      return cleaned;
    }
    return null;
  }

  static double? _extractBalance(String body) {
    for (final pattern in _balancePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value >= 0) return value;
        }
      }
    }
    return null;
  }

  /// Public helper - resolve institution name from a list of keywords.
  static String? getInstitutionFromKeywords(List<String> keywords) {
    for (final keyword in keywords) {
      final lower = keyword.toLowerCase();
      if (_institutions.containsKey(lower)) return _institutions[lower];
    }
    return null;
  }
}
