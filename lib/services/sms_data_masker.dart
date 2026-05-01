/// Service for masking sensitive data in SMS messages for training/export
class SmsDataMasker {
  /// Mask all sensitive data in an SMS message
  static String maskSms(String smsText, {bool preserveStructure = true}) {
    String masked = smsText;
    
    // Step 1: Mask amounts (currency + numbers)
    masked = _maskAmounts(masked);
    
    // Step 2: Mask reference IDs (BEFORE account numbers to catch longer IDs first)
    masked = _maskReferenceIds(masked);
    
    // Step 3: Mask account numbers
    masked = _maskAccountNumbers(masked);
    
    // Step 4: Mask dates
    masked = _maskDates(masked);
    
    return masked;
  }
  
  /// Mask amounts and currency values
  static String _maskAmounts(String text) {
    // Pattern 1: Currency symbols with amounts (₹1,234.56, $100.00)
    text = text.replaceAllMapped(
      RegExp(r'([₹\$€£¥])(\s*)(\d+(?:,\d{3})*(?:\.\d{2})?)'),
      (match) {
        final currencySymbol = match.group(1)!;
        final space = match.group(2)!; // Preserve the space if it exists
        final amount = match.group(3)!;
        return '$currencySymbol$space${_maskNumber(amount)}';
      },
    );
    
    // Pattern 2: Amounts with currency codes (INR 1234.56, Rs. 500, 100 USD)
    text = text.replaceAllMapped(
      RegExp(r'\b(INR|USD|EUR|GBP|Rs\.?)(\s*)(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      (match) {
        final currency = match.group(1)!;
        final space = match.group(2)!; // Preserve original spacing
        final amount = match.group(3)!;
        return '$currency$space${_maskNumber(amount)}';
      },
    );
    
    text = text.replaceAllMapped(
      RegExp(r'\b(\d+(?:,\d{3})*(?:\.\d{2})?)(\s*)(INR|USD|EUR|GBP|Rs)', caseSensitive: false),
      (match) {
        final amount = match.group(1)!;
        final space = match.group(2)!; // Preserve original spacing
        final currency = match.group(3)!;
        return '${_maskNumber(amount)}$space$currency';
      },
    );
    
    // Pattern 3: Amount labels (amount: 1234.56, amt: 500, balance: 500)
    text = text.replaceAllMapped(
      RegExp(r'\b(?:amount|amt|sum|value|balance|bal)[:\s]*([₹\$€£¥]?\s*\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      (match) {
        final fullMatch = match.group(0)!;
        final amountPart = match.group(1)!;
        final label = fullMatch.substring(0, fullMatch.indexOf(amountPart));
        
        // Check if there's a currency symbol
        final currencyMatch = RegExp(r'[₹\$€£¥]').firstMatch(amountPart);
        if (currencyMatch != null) {
          final currency = currencyMatch.group(0)!;
          final number = amountPart.replaceFirst(RegExp(r'[₹\$€£¥]\s*'), '');
          return '$label$currency${_maskNumber(number)}';
        }
        return '$label${_maskNumber(amountPart.trim())}';
      },
    );
    
    // Pattern 4: Standalone decimal amounts (1234.56)
    text = text.replaceAllMapped(
      RegExp(r'\b(\d+(?:,\d{3})*\.\d{2})\b'),
      (match) => _maskNumber(match.group(1)!),
    );
    
    return text;
  }
  
  /// Mask a number with X's preserving structure (commas, decimals)
  static String _maskNumber(String number) {
    // Replace all digits with X, keep commas and dots
    return number.replaceAll(RegExp(r'\d'), 'X');
  }
  
  /// Mask account numbers (last 4 digits, account patterns)
  static String _maskAccountNumbers(String text) {
    // Pattern 1: Account with XX/asterisks (A/c XX1234, Card ****1234)
    text = text.replaceAllMapped(
      RegExp(r'\b((?:A/c|Account|Card|a/c)\s*)(XX|xx|\*{4})(\d{4})\b', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        return '${prefix}XXXX';
      },
    );
    
    // Pattern 2: "ending in" or "ending" with 4 digits (card ending in 1234)
    text = text.replaceAllMapped(
      RegExp(r'\b((?:ending|last)\s*(?:in)?\s*)(\d{4})\b', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        return '${prefix}XXXX';
      },
    );
    
    // Pattern 3: "card" or "account" followed by 4 digits (card 7330, account 1234)
    text = text.replaceAllMapped(
      RegExp(r'\b((?:card|account|acct|a/c)\s+)(\d{4})\b', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        return '${prefix}XXXX';
      },
    );
    
    // Pattern 4: Account numbers in parentheses (7330), but only if near card/account context
    text = text.replaceAllMapped(
      RegExp(r'((?:card|account|a/c)\s*(?:[^\d\(]{0,30}))\((\d{4})\)', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        return '$prefix(XXXX)';
      },
    );
    
    // Pattern 5: Long account numbers (9-16 digits, but NOT reference IDs which were masked earlier)
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{9,16})\b'),
      (match) {
        final number = match.group(1)!;
        return 'X' * number.length;
      },
    );
    
    return text;
  }
  
  /// Mask dates (various formats)
  static String _maskDates(String text) {
    // Pattern 1: DD-MMM-YY/YYYY (19-Apr-26, 19-April-2026)
    text = text.replaceAllMapped(
      RegExp(r'\b\d{1,2}-(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*-\d{2,4}\b', caseSensitive: false),
      (match) => '<DATE>',
    );
    
    // Pattern 2: DD/MM/YY or DD/MM/YYYY or DD-MM-YY
    text = text.replaceAllMapped(
      RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'),
      (match) => '<DATE>',
    );
    
    // Pattern 3: YYYYMMDD or DDMMYYYY (20260419, 19042026)
    text = text.replaceAllMapped(
      RegExp(r'\b(?:\d{8})\b'),
      (match) => '<DATE>',
    );
    
    // Pattern 4: Month DD, YYYY (April 19, 2026)
    text = text.replaceAllMapped(
      RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4}\b', caseSensitive: false),
      (match) => '<DATE>',
    );
    
    // Pattern 5: "on DATE" or "as of DATE" patterns
    text = text.replaceAllMapped(
      RegExp(r'\b(?:on|as of|dated)\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b', caseSensitive: false),
      (match) {
        final prefix = match.group(0)!.split(RegExp(r'\d'))[0];
        return '${prefix}<DATE>';
      },
    );
    
    return text;
  }
  
  /// Mask reference IDs, transaction IDs, UPI references
  static String _maskReferenceIds(String text) {
    // Pattern 1: Ref/Reference labels (Ref: 123456789012, UPI Ref: XXX)
    text = text.replaceAllMapped(
      RegExp(r'\b(?:Ref|Reference|UPI\s+Ref|Transaction\s+ID|Txn\s+ID|Order\s+ID)[:\s]+[A-Z0-9]{6,}', caseSensitive: false),
      (match) {
        final label = match.group(0)!.split(RegExp(r'[\s:]+\w'))[0];
        return '${label}: <REF>';
      },
    );
    
    // Pattern 2: Long alphanumeric IDs (12+ characters)
    text = text.replaceAllMapped(
      RegExp(r'\b[A-Z0-9]{12,}\b'),
      (match) => '<REF>',
    );
    
    return text;
  }
  
  /// Get a summary of what was masked
  static MaskingSummary getMaskingSummary(String original, String masked) {
    int amountCount = 0;
    int accountCount = 0;
    int dateCount = 0;
    int refCount = 0;
    
    // Count amounts by detecting currency symbols followed by X's or currency codes with X's
    final currencySymbolMatches = RegExp(r'[₹\$€£¥]X+').allMatches(masked);
    final currencyCodeMatches = RegExp(r'\b(?:INR|USD|EUR|GBP|Rs\.?)\s*X+', caseSensitive: false).allMatches(masked);
    final balanceMatches = RegExp(r'\b(?:amount|amt|sum|value|balance|bal)[:\s]*X+', caseSensitive: false).allMatches(masked);
    amountCount = currencySymbolMatches.length + currencyCodeMatches.length + balanceMatches.length;
    
    // Count accounts by detecting XXXX patterns (4 X's) in account contexts
    // Look for XXXX that appears after account-related words or XX/asterisks
    final accountPatterns = RegExp(r'\b(?:A/c|Account|Card|a/c|ending|last|card)\s*(?:XX|xx|\*{4})?\s*X{4}\b', caseSensitive: false).allMatches(masked);
    final parenAccountMatches = RegExp(r'\(X{4}\)').allMatches(masked);
    accountCount = accountPatterns.length + parenAccountMatches.length;
    
    // Count dates
    final dateMatches = RegExp(r'<DATE>').allMatches(masked);
    dateCount = dateMatches.length;
    
    // Count references
    final refMatches = RegExp(r'<REF>').allMatches(masked);
    refCount = refMatches.length;
    
    return MaskingSummary(
      originalLength: original.length,
      maskedLength: masked.length,
      amountsMasked: amountCount,
      accountsMasked: accountCount,
      datesMasked: dateCount,
      referencesMasked: refCount,
    );
  }
}

/// Summary of masking operations
class MaskingSummary {
  const MaskingSummary({
    required this.originalLength,
    required this.maskedLength,
    required this.amountsMasked,
    required this.accountsMasked,
    required this.datesMasked,
    required this.referencesMasked,
  });

  final int originalLength;
  final int maskedLength;
  final int amountsMasked;
  final int accountsMasked;
  final int datesMasked;
  final int referencesMasked;
  
  int get totalMasked => amountsMasked + accountsMasked + datesMasked + referencesMasked;
  
  bool get hasMaskedData => totalMasked > 0;
  
  @override
  String toString() {
    return 'Masked: $amountsMasked amounts, $accountsMasked accounts, $datesMasked dates, $referencesMasked refs';
  }
}
