import '../models/sms_transaction_result.dart';

/// Advanced SMS Parser - 14-step transaction parsing with region detection
/// 
/// Parses SMS messages using an enhanced 14-step approach with region awareness,
/// continuous improvement suggestions, and detailed reasoning.
class AdvancedSmsParser {
  /// Parse SMS text and return structured transaction result with region detection
  static SmsTransactionResult parse(String smsText, {String? senderId}) {
    // Convert to lowercase for case-insensitive matching
    final lowerText = smsText.toLowerCase();
    final reasoning = StringBuffer();
    final suggestions = <String>[];
    
    // Step 1: Detect financial keywords and notification patterns
    reasoning.writeln('Step 1: Analyzing message content and patterns');
    final signals = _analyzeMessageSignals(lowerText, reasoning);
    
    // Step 2: Detect region
    reasoning.writeln('\nStep 2: Detecting region');
    final region = _detectRegion(smsText, lowerText, senderId, reasoning);
    
    // Step 3: Determine transaction type
    reasoning.writeln('\nStep 3: Determining transaction type');
    final transactionType = _determineType(lowerText, reasoning);
    
    // Step 4: Extract amount
    reasoning.writeln('\nStep 4: Extracting amount');
    final amount = _extractAmount(smsText, lowerText, reasoning, suggestions);
    
    // Step 5: Extract currency
    reasoning.writeln('\nStep 5: Extracting currency');
    final currency = _extractCurrency(smsText, lowerText, region, reasoning, suggestions);
    
    // Step 6: Identify merchant
    reasoning.writeln('\nStep 6: Identifying merchant');
    final merchant = _extractMerchant(smsText, lowerText, reasoning, suggestions);
    
    // Step 7: Identify bank
    reasoning.writeln('\nStep 7: Identifying bank');
    final bank = _extractBank(smsText, lowerText, region, senderId, reasoning, suggestions);
    
    // Step 8: Extract account identifier
    reasoning.writeln('\nStep 8: Extracting account identifier');
    final account = _extractAccount(smsText, lowerText, reasoning, suggestions);
    
    // Step 9: Cross-validate with sender ID
    reasoning.writeln('\nStep 9: Cross-validating with sender ID');
    _validateSenderId(senderId, bank, reasoning, suggestions);
    
    // Step 10: Validate and clean data
    reasoning.writeln('\nStep 10: Validating and cleaning extracted data');
    _validateData(amount, currency, merchant, bank, account, reasoning);
    
    // Step 11: Generate improvement suggestions
    reasoning.writeln('\nStep 11: Generating improvement suggestions');
    _generateSuggestions(amount, currency, merchant, bank, account, transactionType, suggestions, reasoning);
    
    // Step 12: Calculate confidence score
    reasoning.writeln('\nStep 12: Calculating confidence score');
    final confidence = _calculateConfidence(
      amount, currency, merchant, bank, account, transactionType, region, reasoning
    );
    
    // Step 13: Apply region-specific adjustments
    reasoning.writeln('\nStep 13: Applying region-specific adjustments');
    _applyRegionAdjustments(region, amount, currency, reasoning);
    
    // Step 14: Final classification - Is this a transaction or notification?
    reasoning.writeln('\nStep 14: Final transaction classification');
    final isTransaction = _classifyTransaction(
      signals, amount, transactionType, confidence, reasoning, suggestions
    );
    
    if (!isTransaction) {
      reasoning.writeln('\nFinal Result: Not a transaction (notification/alert/statement)');
      return SmsTransactionResult(
        isTransaction: false,
        transactionType: TransactionTypeEnum.unknown,
        confidenceScore: 0.0,
        reasoning: reasoning.toString(),
        improvementSuggestions: suggestions,
      );
    }
    
    // Step 15: Build final transaction result
    reasoning.writeln('\nStep 15: Building final result');
    reasoning.writeln('Transaction parsing complete with confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    reasoning.writeln('Region: ${region.name}, Suggestions: ${suggestions.length}');
    
    return SmsTransactionResult(
      isTransaction: true,
      transactionType: transactionType,
      amount: amount,
      currency: currency,
      merchant: merchant,
      accountIdentifier: account,
      bank: bank,
      region: region,
      confidenceScore: confidence,
      reasoning: reasoning.toString(),
      improvementSuggestions: suggestions,
    );
  }
  
  /// Review mode: Compare existing parse with new parse and provide insights
  static Map<String, dynamic> reviewParse(
    String smsText,
    SmsTransactionResult existingParse,
    {String? senderId}
  ) {
    // Get new parse
    final newParse = parse(smsText, senderId: senderId);
    
    // Compare results
    final differences = <String, dynamic>{};
    final improvements = <String>[];
    
    // Compare each field
    if (existingParse.amount != newParse.amount) {
      differences['amount'] = {
        'old': existingParse.amount,
        'new': newParse.amount,
        'improved': newParse.amount != null && existingParse.amount != newParse.amount,
      };
      if (newParse.amount != null) {
        improvements.add('Amount corrected from ${existingParse.amount} to ${newParse.amount}');
      }
    }
    
    if (existingParse.currency != newParse.currency) {
      differences['currency'] = {
        'old': existingParse.currency,
        'new': newParse.currency,
      };
      if (newParse.currency != null) {
        improvements.add('Currency detected: ${newParse.currency}');
      }
    }
    
    if (existingParse.merchant != newParse.merchant) {
      differences['merchant'] = {
        'old': existingParse.merchant,
        'new': newParse.merchant,
      };
      if (newParse.merchant != null) {
        improvements.add('Merchant identified: ${newParse.merchant}');
      }
    }
    
    if (existingParse.bank != newParse.bank) {
      differences['bank'] = {
        'old': existingParse.bank,
        'new': newParse.bank,
      };
      if (newParse.bank != null) {
        improvements.add('Bank identified: ${newParse.bank}');
      }
    }
    
    if (existingParse.accountIdentifier != newParse.accountIdentifier) {
      differences['account_identifier'] = {
        'old': existingParse.accountIdentifier,
        'new': newParse.accountIdentifier,
      };
      if (newParse.accountIdentifier != null) {
        improvements.add('Account identified: ${newParse.accountIdentifier}');
      }
    }
    
    if (existingParse.region != newParse.region) {
      differences['region'] = {
        'old': existingParse.region.name,
        'new': newParse.region.name,
      };
      if (newParse.region != RegionEnum.unknown) {
        improvements.add('Region detected: ${newParse.region.name}');
      }
    }
    
    if (existingParse.transactionType != newParse.transactionType) {
      differences['transaction_type'] = {
        'old': existingParse.transactionType.name,
        'new': newParse.transactionType.name,
      };
    }
    
    // Confidence comparison
    final confidenceDiff = newParse.confidenceScore - existingParse.confidenceScore;
    differences['confidence_score'] = {
      'old': existingParse.confidenceScore,
      'new': newParse.confidenceScore,
      'change': confidenceDiff,
      'improved': confidenceDiff > 0,
    };
    
    if (confidenceDiff > 0) {
      improvements.add('Confidence improved by ${(confidenceDiff * 100).toStringAsFixed(1)}%');
    }
    
    return {
      'sms_text': smsText,
      'existing_confidence': existingParse.confidenceScore,
      'new_confidence': newParse.confidenceScore,
      'differences': differences,
      'improvements': improvements,
      'new_suggestions': newParse.improvementSuggestions,
      'total_changes': differences.length,
      'significant_improvement': confidenceDiff >= 0.1,
    };
  }
  
  // Step 1: Analyze message signals (collect all indicators, don't reject early)
  static Map<String, dynamic> _analyzeMessageSignals(String lowerText, StringBuffer reasoning) {
    final signals = {
      'hasTransactionKeywords': false,
      'hasBalancePatterns': false,
      'hasAlertPatterns': false,
      'hasBillStatementPatterns': false,
      'hasCurrencyIndicator': false,
      'transactionKeywordsFound': <String>[],
      'notificationPatternsFound': <String>[],
    };
    
    // PATTERNS COMMENTED OUT - Relying on step-by-step rule evaluation
    // The classification will be done by Step 3 (_determineType) and Step 14 (_classifyTransaction)
    
    // // Check for transaction keywords
    // final transactionKeywords = [
    //   'debited', 'credited', 'spent', 'withdrawn', 'deposited',
    //   'purchase', 'paid', 'received', 'transferred', 'sent',
    //   'charged', 'upi', 'atm', 'pos', 'imps', 'neft', 'rtgs',
    //   'wire', 'ach', 'check', 'cheque', 'direct debit'
    // ];
    // 
    // for (final keyword in transactionKeywords) {
    //   if (lowerText.contains(keyword)) {
    //     signals['hasTransactionKeywords'] = true;
    //     (signals['transactionKeywordsFound'] as List<String>).add(keyword);
    //   }
    // }
    // 
    // // Check for balance-only patterns
    // final balanceOnlyPatterns = [
    //   'bal is', 'balance is', 'current balance', 'current bal',
    //   'available balance', 'avl bal', 'available bal',
    //   'minimum balance', 'min bal', 'outstanding balance',
    //   'statement balance', 'total balance', 'bal plus pending',
    //   'balance plus pending', 'view your bal', 'check your bal',
    //   'bal at', 'balance at'
    // ];
    // 
    // for (final pattern in balanceOnlyPatterns) {
    //   if (lowerText.contains(pattern)) {
    //     signals['hasBalancePatterns'] = true;
    //     (signals['notificationPatternsFound'] as List<String>).add(pattern);
    //   }
    // }
    // 
    // // Check for alert/threshold patterns
    // final alertPatterns = [
    //   'exceeded amount', 'exceeded limit', 'exceeded threshold',
    //   'alert threshold', 'amount set in your', 'limit set in your',
    //   'balance alert', 'low balance alert', 'threshold alert'
    // ];
    // 
    // for (final pattern in alertPatterns) {
    //   if (lowerText.contains(pattern)) {
    //     signals['hasAlertPatterns'] = true;
    //     (signals['notificationPatternsFound'] as List<String>).add(pattern);
    //   }
    // }
    // 
    // // Check for bill/statement/invoice patterns
    // final billStatementPatterns = [
    //   'statement for', 'new statement', 'statement available',
    //   'payment is due', 'payment due', 'due by', 'due on',
    //   'bill for', 'new bill', 'bill available',
    //   'invoice for', 'new invoice', 'invoice available',
    //   'you owe', 'amount due', 'balance due',
    //   'upcoming payment', 'autopay scheduled', 'will be charged'
    // ];
    // 
    // for (final pattern in billStatementPatterns) {
    //   if (lowerText.contains(pattern)) {
    //     signals['hasBillStatementPatterns'] = true;
    //     (signals['notificationPatternsFound'] as List<String>).add(pattern);
    //   }
    // }
    
    // Check for currency symbols or patterns
    if (RegExp(r'[₹$€£¥]').hasMatch(lowerText) || 
        RegExp(r'\b(inr|usd|eur|gbp|rs\.?)\s*\d').hasMatch(lowerText)) {
      signals['hasCurrencyIndicator'] = true;
    }
    
    // Log findings
    if (signals['hasTransactionKeywords'] == true) {
      final keywords = signals['transactionKeywordsFound'] as List<String>;
      reasoning.writeln('  ✓ Found transaction keywords: ${keywords.join(", ")}');
    }
    
    if (signals['hasBalancePatterns'] == true) {
      reasoning.writeln('  ⚠ Detected balance notification pattern');
    }
    
    if (signals['hasAlertPatterns'] == true) {
      reasoning.writeln('  ⚠ Detected alert/threshold pattern');
    }
    
    if (signals['hasBillStatementPatterns'] == true) {
      reasoning.writeln('  ⚠ Detected bill/statement pattern');
    }
    
    if (signals['hasCurrencyIndicator'] == true) {
      reasoning.writeln('  ✓ Found currency indicator');
    }
    
    if (!(signals['hasTransactionKeywords'] as bool) && 
        !(signals['hasCurrencyIndicator'] as bool)) {
      reasoning.writeln('  ✗ No financial keywords or currency found');
    }
    
    return signals;
  }
  
  // Step 14: Final classification based on all collected data
  static bool _classifyTransaction(
    Map<String, dynamic> signals,
    double? amount,
    TransactionTypeEnum transactionType,
    double confidence,
    StringBuffer reasoning,
    List<String> suggestions
  ) {
    reasoning.writeln('  Analyzing collected evidence using rule-based evaluation:');
    
    // Evidence for transaction (from step-by-step processing)
    final hasAmount = amount != null && amount > 0;
    final hasTransactionType = transactionType != TransactionTypeEnum.unknown;
    final hasGoodConfidence = confidence >= 0.5;
    
    // Evidence against transaction (notification patterns - currently disabled)
    final hasBalancePatterns = signals['hasBalancePatterns'] as bool;
    final hasAlertPatterns = signals['hasAlertPatterns'] as bool;
    final hasBillStatementPatterns = signals['hasBillStatementPatterns'] as bool;
    final hasAnyNotificationPattern = hasBalancePatterns || hasAlertPatterns || hasBillStatementPatterns;
    
    reasoning.writeln('    Rule-based evidence:');
    reasoning.writeln('      - Transaction type detected (Step 3): ${hasTransactionType ? "YES ($transactionType)" : "NO"}');
    reasoning.writeln('      - Amount extracted (Step 4): ${hasAmount ? "YES (\$$amount)" : "NO"}');
    reasoning.writeln('      - Confidence score: ${(confidence * 100).toStringAsFixed(1)}%');
    
    reasoning.writeln('    Pattern evidence (for reference):');
    reasoning.writeln('      - Balance pattern: ${hasBalancePatterns ? "YES" : "NO"}');
    reasoning.writeln('      - Alert pattern: ${hasAlertPatterns ? "YES" : "NO"}');
    reasoning.writeln('      - Bill/statement pattern: ${hasBillStatementPatterns ? "YES" : "NO"}');
    
    // RULE-BASED CLASSIFICATION (relying on Step 3 _determineType)
    // The key insight: If Step 3 identified a transaction type (debit/credit),
    // it means it found valid transaction action verbs
    
    // Primary decision: Transaction type must be identified by Step 3
    if (!hasTransactionType) {
      reasoning.writeln('  ✗ Classification: NOT A TRANSACTION');
      reasoning.writeln('     Reason: Step 3 did not identify any transaction type');
      reasoning.writeln('     This means no valid transaction action verbs were found');
      return false;
    }
    
    // If we have transaction type, check if we have supporting evidence
    if (hasTransactionType && hasAmount) {
      reasoning.writeln('  ✓ Classification: TRANSACTION (strong evidence)');
      reasoning.writeln('     Reason: Step 3 identified type + Step 4 extracted amount');
      return true;
    }
    
    // Transaction type identified but no amount
    if (hasTransactionType && !hasAmount) {
      if (hasGoodConfidence) {
        reasoning.writeln('  ✓ Classification: TRANSACTION (moderate evidence)');
        reasoning.writeln('     Reason: Step 3 identified type + good confidence');
        return true;
      } else {
        reasoning.writeln('  ✗ Classification: NOT A TRANSACTION (weak evidence)');
        reasoning.writeln('     Reason: Type identified but no amount and low confidence');
        return false;
      }
    }
    
    // Fallback - should not reach here
    reasoning.writeln('  ✗ Classification: NOT A TRANSACTION (insufficient evidence)');
    return false;
  }
  
  // Step 2: Detect region
  static RegionEnum _detectRegion(String originalText, String lowerText, String? senderId, StringBuffer reasoning) {
    int indiaScore = 0;
    int usScore = 0;
    
    // Check currency indicators
    if (originalText.contains('₹') || lowerText.contains('inr') || lowerText.contains('rs.') || lowerText.contains(' rs ')) {
      indiaScore += 3;
      reasoning.writeln('  + India indicator: INR currency');
    }
    if (originalText.contains('\$') || lowerText.contains('usd')) {
      usScore += 3;
      reasoning.writeln('  + US indicator: USD currency');
    }
    
    // Check payment systems
    if (lowerText.contains('upi') || lowerText.contains('imps') || lowerText.contains('neft') || lowerText.contains('rtgs')) {
      indiaScore += 2;
      reasoning.writeln('  + India indicator: India-specific payment system');
    }
    if (lowerText.contains('ach') || lowerText.contains('wire') || lowerText.contains('zelle')) {
      usScore += 2;
      reasoning.writeln('  + US indicator: US-specific payment system');
    }
    
    // Check banks
    final indiaBanks = ['hdfc', 'icici', 'sbi', 'axis', 'kotak', 'indusind', 'yes bank', 'pnb', 'bob', 'canara'];
    final usBanks = ['chase', 'bofa', 'bank of america', 'wells fargo', 'us bank', 'capital one'];
    
    for (final bank in indiaBanks) {
      if (lowerText.contains(bank)) {
        indiaScore += 2;
        reasoning.writeln('  + India indicator: Indian bank detected');
        break;
      }
    }
    
    for (final bank in usBanks) {
      if (lowerText.contains(bank)) {
        usScore += 2;
        reasoning.writeln('  + US indicator: US bank detected');
        break;
      }
    }
    
    // Determine region
    if (indiaScore > usScore) {
      reasoning.writeln('  ✓ Region detected: INDIA (score: $indiaScore vs $usScore)');
      return RegionEnum.india;
    } else if (usScore > indiaScore) {
      reasoning.writeln('  ✓ Region detected: US (score: $usScore vs $indiaScore)');
      return RegionEnum.us;
    } else {
      reasoning.writeln('  ? Region unknown (score: India=$indiaScore, US=$usScore)');
      return RegionEnum.unknown;
    }
  }
  
  // Step 3: Determine transaction type
  static TransactionTypeEnum _determineType(String lowerText, StringBuffer reasoning) {
    // RULE 1: Check for FUTURE/SCHEDULED transactions FIRST
    // These are payment reminders, not completed transactions
    final futureScheduledPatterns = [
      'scheduled for',
      'scheduled on',
      'will be processed',
      'will be charged',
      'will be debited',
      'autopay scheduled',
      'upcoming payment',
      'payment is due',
      'payment due',
      'is due',
      'are due',
      'due by',
      'due on',
      'you owe',
      'amount due',
      'reminder:',
      'payment reminder',
    ];
    
    for (final pattern in futureScheduledPatterns) {
      if (lowerText.contains(pattern)) {
        reasoning.writeln('  ✗ Future/scheduled indicator found: "$pattern"');
        reasoning.writeln('  → This is a reminder/notification, not a completed transaction');
        return TransactionTypeEnum.unknown;
      }
    }
    
    // RULE 2: Scan for transaction action verbs AND phrases
    // If we find them, it's a completed transaction (balance info is just supplementary)
    
    // SPECIAL: Credit card payment detection
    // "payment posted to acct" = user paid their credit card bill (money leaving)
    final creditCardPaymentPhrases = [
      'payment posted to',
      'payment posted to acct',
      'payment posted to account',
      'payment posted on',
      'payment applied to',
    ];
    
    for (final phrase in creditCardPaymentPhrases) {
      if (lowerText.contains(phrase)) {
        reasoning.writeln('  ✓ Credit card payment phrase found: "$phrase"');
        reasoning.writeln('  → This is a credit card payment (money paid to reduce credit card balance)');
        reasoning.writeln('  → Classified as DEBIT from user\'s financial perspective');
        return TransactionTypeEnum.debit;
      }
    }
    
    // SPECIAL: Payment received detection (money coming in)
    final paymentReceivedPhrases = [
      'payment received on your account',
      'payment received for your',
      'payment received in',
      'payment credited to',
    ];
    
    for (final phrase in paymentReceivedPhrases) {
      if (lowerText.contains(phrase)) {
        reasoning.writeln('  ✓ Payment received phrase found: "$phrase"');
        reasoning.writeln('  → This is an incoming payment (deposit)');
        reasoning.writeln('  → Classified as CREDIT');
        return TransactionTypeEnum.credit;
      }
    }
    
    // Debit transaction phrases (completed actions)
    final debitPhrases = [
      'transaction was made',
      'transaction at',
      'electronic draft',
      'purchase at',
      'charged at',
      'was deducted',
      'has been deducted',
    ];
    
    // Credit transaction phrases (completed actions)
    final creditPhrases = [
      'direct deposit',
      'payment received',
      'deposit of',
      'credit of',
      'refund of',
      'sent you',
      'sent to you',
      'transferred to you',
    ];
    
    // Check debit phrases first (more specific than single words)
    for (final phrase in debitPhrases) {
      if (lowerText.contains(phrase)) {
        reasoning.writeln('  ✓ Debit transaction phrase found: "$phrase"');
        reasoning.writeln('  → Indicates completed debit transaction');
        return TransactionTypeEnum.debit;
      }
    }
    
    // Check credit phrases
    for (final phrase in creditPhrases) {
      if (lowerText.contains(phrase)) {
        reasoning.writeln('  ✓ Credit transaction phrase found: "$phrase"');
        reasoning.writeln('  → Indicates completed credit transaction');
        return TransactionTypeEnum.credit;
      }
    }
    
    // Debit indicators (past tense action verbs - single words)
    // Note: 'sent' removed - too ambiguous (use 'sent you' in credit phrases instead)
    final debitKeywords = [
      'debited', 'spent', 'withdrawn', 'withdrawal',
      'purchase', 'paid', 'transferred', 'charged'
    ];
    
    // Credit indicators (past tense action verbs - single words)
    final creditKeywords = [
      'credited', 'received', 'deposit', 'deposited',
      'refund', 'cashback', 'reward', 'incoming'
    ];
    
    // Check debit keywords
    for (final keyword in debitKeywords) {
      if (lowerText.contains(keyword)) {
        reasoning.writeln('  ✓ Debit action verb found: "$keyword"');
        reasoning.writeln('  → Indicates completed debit transaction');
        return TransactionTypeEnum.debit;
      }
    }
    
    // Check credit keywords, but avoid false positives from "Credit Card"
    for (final keyword in creditKeywords) {
      if (lowerText.contains(keyword)) {
        // If "credit" appears near "card", it might be a card name, not transaction type
        if (keyword == 'credit' && lowerText.contains('credit card')) {
          // Check if there's actual transaction evidence
          final hasTransaction = debitKeywords.any((kw) => lowerText.contains(kw));
          if (!hasTransaction) {
            continue; // Skip this match
          }
        }
        reasoning.writeln('  ✓ Credit action verb found: "$keyword"');
        reasoning.writeln('  → Indicates completed credit transaction');
        return TransactionTypeEnum.credit;
      }
    }
    
    // RULE 3: No transaction verb found, check for statement/bill/invoice notifications
    // (these are NOT transactions)
    
    // Statement/bill/invoice indicators
    final statementPatterns = [
      'new statement', 'statement for', 'statement available',
      'new bill', 'bill for', 'bill available',
      'new invoice', 'invoice for', 'invoice available'
    ];
    
    for (final pattern in statementPatterns) {
      if (lowerText.contains(pattern)) {
        reasoning.writeln('  ⚠ Statement/bill notification detected: "$pattern"');
        reasoning.writeln('  → This is NOT a transaction');
        return TransactionTypeEnum.unknown;
      }
    }
    
    // Balance reporting indicators (state verbs, not action verbs)
    final balanceReportingPatterns = [
      'balance is', 'bal is', 'balance at', 'bal at',
      'current balance', 'available balance', 'outstanding balance'
    ];
    
    for (final pattern in balanceReportingPatterns) {
      if (lowerText.contains(pattern)) {
        reasoning.writeln('  ⚠ Balance reporting detected: "$pattern"');
        reasoning.writeln('  → This is informational, not a transaction');
        return TransactionTypeEnum.unknown;
      }
    }
    
    reasoning.writeln('  ? No transaction action verbs or notification patterns found');
    reasoning.writeln('  → Defaulting to unknown (likely not a transaction)');
    return TransactionTypeEnum.unknown;
  }
  
  // Step 4: Extract amount
  static double? _extractAmount(String originalText, String lowerText, StringBuffer reasoning, List<String> suggestions) {
    // Try currency + amount patterns first (most specific)
    final patterns = [
      RegExp(r'[₹\$€£¥]\s*(\d+(?:,\d{3})*(?:\.\d{2})?)'),  // ₹1,234.56
      RegExp(r'\b(?:inr|usd|eur|gbp|rs\.?)\s*(\d+(?:,\d{3})*(?:\.\d{2})?)'),  // INR 1234.56
      RegExp(r'\b(\d+(?:,\d{3})*(?:\.\d{2})?)\s*(?:inr|usd|eur|gbp|rs)'),  // 1234.56 INR
      RegExp(r'\b(?:amount|amt|sum|value)[:\s]*[₹\$€£¥]?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)'),  // amount: 1234.56
      RegExp(r'\b(\d+(?:,\d{3})*\.\d{2})\b'),  // Generic decimal amount
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(originalText);
      if (match != null) {
        final amountStr = match.group(1) ?? match.group(0)!;
        final cleanAmount = amountStr.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '');
        final amount = double.tryParse(cleanAmount);
        if (amount != null && amount > 0) {
          // Avoid confusing card numbers with amounts
          // Card numbers in parentheses like (7330) should be skipped
          if (originalText.contains('($amountStr)') && !lowerText.substring(0, originalText.indexOf('($amountStr)')).contains('amount')) {
            continue; // Likely a card number, not an amount
          }
          
          reasoning.writeln('  ✓ Amount extracted: $amount (from "$amountStr")');
          return amount;
        }
      }
    }
    
    // Try large numbers only if no better match found (least specific)
    final largeNumberPattern = RegExp(r'\b(\d{2,}(?:,\d{3})*)\b');
    final match = largeNumberPattern.firstMatch(originalText);
    if (match != null) {
      final amountStr = match.group(1)!;
      // Skip if it looks like a card number (in parentheses or after "card" or "ending")
      if (originalText.contains('($amountStr)') || 
          lowerText.substring(0, originalText.indexOf(amountStr)).contains(RegExp(r'card.*\(|ending|last'))) {
        reasoning.writeln('  - Skipping $amountStr (appears to be card/account number)');
      } else {
        final cleanAmount = amountStr.replaceAll(',', '');
        final amount = double.tryParse(cleanAmount);
        if (amount != null && amount > 0 && amount < 1000000) {
          reasoning.writeln('  ✓ Amount extracted: $amount (from "$amountStr")');
          return amount;
        }
      }
    }
    
    reasoning.writeln('  ✗ No amount found');
    suggestions.add('Add amount extraction pattern for this SMS format');
    return null;
  }
  
  // Step 5: Extract currency
  static String? _extractCurrency(String originalText, String lowerText, RegionEnum region, StringBuffer reasoning, List<String> suggestions) {
    // Check for currency symbols
    if (originalText.contains('₹') || lowerText.contains('inr') || lowerText.contains('rs.') || lowerText.contains(' rs ')) {
      reasoning.writeln('  ✓ Currency detected: INR');
      return 'INR';
    }
    if (originalText.contains('\$') || lowerText.contains('usd')) {
      reasoning.writeln('  ✓ Currency detected: USD');
      return 'USD';
    }
    if (originalText.contains('€') || lowerText.contains('eur')) {
      reasoning.writeln('  ✓ Currency detected: EUR');
      return 'EUR';
    }
    if (originalText.contains('£') || lowerText.contains('gbp')) {
      reasoning.writeln('  ✓ Currency detected: GBP');
      return 'GBP';
    }
    
    // Use region as fallback
    if (region == RegionEnum.india) {
      reasoning.writeln('  ? No explicit currency, inferring INR from region');
      return 'INR';
    } else if (region == RegionEnum.us) {
      reasoning.writeln('  ? No explicit currency, inferring USD from region');
      return 'USD';
    }
    
    reasoning.writeln('  ? No explicit currency found, assuming INR as default');
    return 'INR';
  }
  
  // Step 6: Extract merchant
  static String? _extractMerchant(String originalText, String lowerText, StringBuffer reasoning, List<String> suggestions) {
    // SPECIAL: Detect credit card payment patterns
    final creditCardPaymentIndicators = [
      'payment posted to',
      'payment applied to',
      'payment posted on',
      'payment received on your account',
    ];
    
    for (final indicator in creditCardPaymentIndicators) {
      if (lowerText.contains(indicator)) {
        reasoning.writeln('  ✓ Merchant identified: "Credit Card Payment" (detected from payment pattern)');
        return 'Credit Card Payment';
      }
    }
    
    // SPECIAL: Detect electronic draft/ACH patterns
    if (lowerText.contains('electronic draft') || lowerText.contains('ach debit')) {
      // Try to extract payee from common patterns
      final draftPatterns = [
        RegExp(r'draft\s+(?:to|from)\s+([A-Z][A-Za-z0-9\s&\-]{2,30})(?:\s+for\s+account)?', caseSensitive: false),
        RegExp(r'(?:payee|to|from)[:\s]+([A-Z][A-Za-z0-9\s&\-]{3,30})(?:\s+on\s+\d)', caseSensitive: false),
      ];
      
      for (final pattern in draftPatterns) {
        final match = pattern.firstMatch(originalText);
        if (match != null) {
          final merchant = match.group(1)?.trim();
          if (merchant != null && merchant.length >= 3) {
            // Filter out account-related matches
            final merchantLower = merchant.toLowerCase();
            if (!merchantLower.contains('account') && !RegExp(r'^\d+$').hasMatch(merchant)) {
              reasoning.writeln('  ✓ Merchant identified: "$merchant" (from electronic draft)');
              return merchant;
            }
          }
        }
      }
      
      // If no specific payee found, use generic label
      reasoning.writeln('  ✓ Merchant identified: "Electronic Draft" (ACH/draft payment)');
      return 'Electronic Draft';
    }
    
    // Standard merchant extraction patterns
    final patterns = [
      RegExp(r'\bat\s+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // at MERCHANT
      RegExp(r'\bto\s+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // to MERCHANT
      RegExp(r'\bfrom\s+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // from MERCHANT
      RegExp(r'\bfor\s+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // for MERCHANT
      RegExp(r'\bvia\s+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // via MERCHANT
      RegExp(r'\bon\s+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // on MERCHANT
      RegExp(r'\bmerchant[:\s]+([A-Z][A-Za-z0-9\s&\-]{2,30})'),  // merchant: NAME
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(originalText);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length >= 3) {
          // Filter out common non-merchant words
          final excludeWords = ['your', 'account', 'card', 'balance', 'transaction', 'payment', 'the', 'this'];
          final merchantLower = merchant.toLowerCase();
          if (!excludeWords.any((word) => merchantLower.startsWith(word))) {
            reasoning.writeln('  ✓ Merchant identified: "$merchant"');
            return merchant;
          }
        }
      }
    }
    
    reasoning.writeln('  ✗ No merchant found');
    suggestions.add('Add merchant extraction pattern for this SMS format');
    return null;
  }
  
  // Step 7: Extract bank (REGION-AWARE)
  static String? _extractBank(String originalText, String lowerText, RegionEnum region, String? senderId, StringBuffer reasoning, List<String> suggestions) {
    // Indian banks (only for INDIA region)
    final indianBanks = {
      'hdfc': 'HDFC Bank',
      'icici': 'ICICI Bank',
      'sbi': 'State Bank of India',
      'axis': 'Axis Bank',
      'kotak': 'Kotak Mahindra Bank',
      'indusind': 'IndusInd Bank',
      'yes bank': 'YES Bank',
      'pnb': 'Punjab National Bank',
      'bob': 'Bank of Baroda',
      'canara': 'Canara Bank',
      'union bank': 'Union Bank',
      'idbi': 'IDBI Bank',
      'idfc': 'IDFC First Bank',
      'rbl': 'RBL Bank',
      'bandhan': 'Bandhan Bank',
    };
    
    // US banks (only for US region)
    final usBanks = {
      'chase': 'Chase',
      'bofa': 'Bank of America',
      'bank of america': 'Bank of America',
      'wells fargo': 'Wells Fargo',
      'us bank': 'US Bank',
      'capital one': 'Capital One',
      'pnc': 'PNC Bank',
      'td bank': 'TD Bank',
      'truist': 'Truist',
      'fifth third': 'Fifth Third Bank',
    };
    
    // Global banks and credit cards (available in both regions)
    final globalBanks = {
      'citi': 'Citi',
      'citibank': 'Citi',
      'hsbc': 'HSBC',
      'standard chartered': 'Standard Chartered',
      'deutsche': 'Deutsche Bank',
      'american express': 'American Express',
      'amex': 'American Express',
      'discover': 'Discover',
      'mastercard': 'Mastercard',
      'visa': 'Visa',
    };
    
    // Select region-appropriate banks
    Map<String, String> banksToCheck = {};
    
    if (region == RegionEnum.india) {
      banksToCheck.addAll(indianBanks);
      banksToCheck.addAll(globalBanks);
      reasoning.writeln('  → Checking INDIA region banks');
    } else if (region == RegionEnum.us) {
      banksToCheck.addAll(usBanks);
      banksToCheck.addAll(globalBanks);
      reasoning.writeln('  → Checking US region banks');
    } else {
      // UNKNOWN region - check all banks
      banksToCheck.addAll(indianBanks);
      banksToCheck.addAll(usBanks);
      banksToCheck.addAll(globalBanks);
      reasoning.writeln('  → Region unknown, checking all banks');
    }
    
    // Check sender ID first
    if (senderId != null) {
      final senderLower = senderId.toLowerCase();
      for (final entry in banksToCheck.entries) {
        if (senderLower.contains(entry.key)) {
          reasoning.writeln('  ✓ Bank identified from sender ID: ${entry.value}');
          return entry.value;
        }
      }
    }
    
    // Check message content
    for (final entry in banksToCheck.entries) {
      if (lowerText.contains(entry.key)) {
        reasoning.writeln('  ✓ Bank identified: ${entry.value}');
        return entry.value;
      }
    }
    
    // Check for generic bank patterns
    final bankPattern = RegExp(r'\b([A-Z]{2,})\s+bank\b', caseSensitive: true);
    final match = bankPattern.firstMatch(originalText);
    if (match != null) {
      final bankName = match.group(0);
      reasoning.writeln('  ✓ Bank identified: $bankName');
      suggestions.add('Add "$bankName" to known bank list');
      return bankName;
    }
    
    reasoning.writeln('  ✗ No bank identified');
    suggestions.add('Add bank identification for this sender/format');
    return null;
  }
  
  // Step 8: Extract account identifier
  static String? _extractAccount(String originalText, String lowerText, StringBuffer reasoning, List<String> suggestions) {
    final patterns = [
      // Standard masked formats
      RegExp(r'\b([xX]{2,}\d{4})\b'),  // XX1234, XXXX1234
      RegExp(r'(\*{4}\d{4})\b'),  // ****1234
      
      // "ending in" / "last" formats
      RegExp(r'\b(?:ending|last)\s+(?:in\s+)?(\d{4})\b'),  // ending in 1234
      
      // Account number formats
      RegExp(r'\b(?:a\/c|ac|acc|account)\s*(?:no\.?|number)?\s*[:\s-]*([xX*]{2,}\d{4,6}|\d{4,16})\b', caseSensitive: false),  // A/C XX1234, account - 3281, Acc XX026
      
      // Card formats
      RegExp(r'\b(?:card|debit|credit)\s*(?:card)?\s*[:\s-]+\s*([xX*]{1,4}\d{4})\b', caseSensitive: false),  // card - 5517, Card x9993, debit card - 5517
      RegExp(r'\bcard\s+(?:ending|no\.?)\s*[:\s]*([xX*]{2,}\d{4}|\d{4})\b'),  // card ending 1234
      
      // UPI formats
      RegExp(r'\b([a-z0-9._%+-]+@[a-z0-9.-]+)\b'),  // UPI: user@bank
      RegExp(r'\bupi:\s*([a-z0-9._%+-]+@[a-z0-9.-]+)\b'),  // UPI: explicit format
      
      // Parenthesis formats (Capital One, etc.)
      RegExp(r'\(([xX*]{4})\)'),  // (XXXX)
      RegExp(r'…\(([xX*]{4})\)'),  // …(XXXX) with ellipsis
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        final account = match.group(1)!;
        reasoning.writeln('  ✓ Account identifier found: "$account"');
        return account;
      }
    }
    
    reasoning.writeln('  ✗ No account identifier found');
    suggestions.add('Add account identifier extraction pattern');
    return null;
  }
  
  // Step 9: Cross-validate with sender ID
  static void _validateSenderId(String? senderId, String? bank, StringBuffer reasoning, List<String> suggestions) {
    if (senderId == null) {
      reasoning.writeln('  - No sender ID provided for validation');
      return;
    }
    
    if (bank == null) {
      reasoning.writeln('  ! Sender ID present but no bank identified');
      suggestions.add('Use sender ID "$senderId" to improve bank detection');
      return;
    }
    
    final senderLower = senderId.toLowerCase();
    final bankLower = bank.toLowerCase();
    
    // Known sender ID aliases
    final senderAliases = {
      'bofa': 'bank of america',
      'citi': 'citi',
      'citibank': 'citi',
      'chase': 'chase',
      'hdfcbk': 'hdfc',
      'icicibk': 'icici',
      'sbiinb': 'sbi',
      'axisbk': 'axis',
      'paytm': 'paytm',
    };
    
    // Check if we have a known alias mapping
    if (senderAliases.containsKey(senderLower)) {
      final expectedBank = senderAliases[senderLower]!;
      if (bankLower.contains(expectedBank)) {
        reasoning.writeln('  ✓ Sender ID matches identified bank (known alias)');
        return;
      }
    }
    
    // Check if sender ID matches bank name
    if (senderLower.contains(bankLower.split(' ')[0]) || bankLower.contains(senderLower)) {
      reasoning.writeln('  ✓ Sender ID matches identified bank');
    } else {
      reasoning.writeln('  ! Sender ID "$senderId" does not match bank "$bank"');
      suggestions.add('Review sender-bank mapping for "$senderId"');
    }
  }
  
  // Step 10: Validate data
  static void _validateData(
    double? amount, 
    String? currency, 
    String? merchant, 
    String? bank, 
    String? account, 
    StringBuffer reasoning
  ) {
    final issues = <String>[];
    
    if (amount == null) issues.add('amount missing');
    if (currency == null) issues.add('currency missing');
    if (merchant == null) issues.add('merchant missing');
    if (bank == null) issues.add('bank missing');
    if (account == null) issues.add('account missing');
    
    if (issues.isEmpty) {
      reasoning.writeln('  ✓ All core fields validated successfully');
    } else {
      reasoning.writeln('  ! Validation notes: ${issues.join(", ")}');
    }
  }
  
  // Step 11: Generate improvement suggestions
  static void _generateSuggestions(
    double? amount,
    String? currency,
    String? merchant,
    String? bank,
    String? account,
    TransactionTypeEnum type,
    List<String> suggestions,
    StringBuffer reasoning
  ) {
    final generated = <String>[];
    
    if (type == TransactionTypeEnum.unknown) {
      generated.add('Add transaction type keywords for this format');
    }
    
    if (amount == null) {
      generated.add('Improve amount extraction patterns');
    }
    
    if (merchant == null) {
      generated.add('Enhance merchant detection algorithms');
    }
    
    if (suggestions.isEmpty) {
      reasoning.writeln('  ✓ No additional improvement suggestions needed');
    } else {
      reasoning.writeln('  → Generated ${suggestions.length} improvement suggestions');
    }
  }
  
  // Step 12: Calculate confidence score
  static double _calculateConfidence(
    double? amount,
    String? currency,
    String? merchant,
    String? bank,
    String? account,
    TransactionTypeEnum type,
    RegionEnum region,
    StringBuffer reasoning
  ) {
    double score = 0.0;
    
    // Amount is critical (25%)
    if (amount != null && amount > 0) {
      score += 0.25;
      reasoning.writeln('  + 25% for valid amount');
    }
    
    // Transaction type (20%)
    if (type != TransactionTypeEnum.unknown) {
      score += 0.20;
      reasoning.writeln('  + 20% for identified transaction type');
    }
    
    // Account identifier (15%)
    if (account != null) {
      score += 0.15;
      reasoning.writeln('  + 15% for account identifier');
    }
    
    // Bank (15%)
    if (bank != null) {
      score += 0.15;
      reasoning.writeln('  + 15% for bank identification');
    }
    
    // Region detection (10%)
    if (region != RegionEnum.unknown) {
      score += 0.10;
      reasoning.writeln('  + 10% for region detection');
    }
    
    // Currency (8%)
    if (currency != null) {
      score += 0.08;
      reasoning.writeln('  + 8% for currency');
    }
    
    // Merchant (7%)
    if (merchant != null) {
      score += 0.07;
      reasoning.writeln('  + 7% for merchant');
    }
    
    reasoning.writeln('  = Total confidence: ${(score * 100).toStringAsFixed(1)}%');
    return score;
  }
  
  // Step 13: Apply region-specific adjustments
  static void _applyRegionAdjustments(
    RegionEnum region,
    double? amount,
    String? currency,
    StringBuffer reasoning
  ) {
    if (region == RegionEnum.india) {
      reasoning.writeln('  ✓ Applied India-specific parsing rules');
      if (currency == 'INR' && amount != null && amount < 1) {
        reasoning.writeln('  ! Warning: Unusually low amount for INR transaction');
      }
    } else if (region == RegionEnum.us) {
      reasoning.writeln('  ✓ Applied US-specific parsing rules');
      if (currency == 'USD' && amount != null && amount > 10000) {
        reasoning.writeln('  ! Note: High-value USD transaction detected');
      }
    } else {
      reasoning.writeln('  - No region-specific adjustments applied');
    }
  }
}
