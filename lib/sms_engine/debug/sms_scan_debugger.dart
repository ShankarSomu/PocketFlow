import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/main.dart' show hybridSmsParser;
import 'package:pocket_flow/sms_engine/parsing/sms_account_extractor.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_keyword_service.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_service.dart';

/// SMS Scan Debugger
/// 
/// Helps diagnose why SMS messages are not being imported as transactions.
/// 
/// Usage:
/// ```dart
/// await SmsScanDebugger.diagnoseJsonFile('test/SMS Training Data.json');
/// ```
class SmsScanDebugger {
  
  /// Diagnose why SMS from JSON file are not being imported
  static Future<void> diagnoseJsonFile(String filePath) async {
    print('\n════════════════════════════════════════════════════════════════');
    print('SMS SCAN DIAGNOSTICS');
    print('════════════════════════════════════════════════════════════════\n');
    
    // Step 1: Check if file exists
    final file = File(filePath);
    if (!await file.exists()) {
      print('❌ ERROR: File not found: $filePath');
      return;
    }
    print('✓ File found: $filePath\n');
    
    // Step 2: Read and parse JSON
    String jsonContent;
    List<dynamic> smsData;
    try {
      jsonContent = await file.readAsString();
      smsData = jsonDecode(jsonContent) as List<dynamic>;
      print('✓ JSON parsed successfully');
      print('  Total messages in file: ${smsData.length}\n');
    } catch (e) {
      print('❌ ERROR: Failed to parse JSON: $e');
      return;
    }
    
    // Step 3: Check database connection
    try {
      await AppDatabase.db();
      print('✓ Database connection established\n');
    } catch (e) {
      print('❌ ERROR: Database connection failed: $e');
      return;
    }
    
    // Step 4: Check SMS keywords loaded
    final keywordsCount = SmsKeywordService.getCacheStats().values.fold(0, (a, b) => a + b);
    print('✓ SMS keywords loaded: $keywordsCount keywords\n');
    
    if (keywordsCount == 0) {
      print('⚠ WARNING: No SMS keywords in database!');
      print('  Run database seed to add keywords.\n');
    }
    
    // Step 5: Analyze first 10 SMS messages
    print('═══════════════════════════════════════════════════════════════');
    print('ANALYZING SAMPLE MESSAGES (first 10)');
    print('═══════════════════════════════════════════════════════════════\n');
    
    int analyzed = 0;
    int passedFinancialCheck = 0;
    int passedParseCheck = 0;
    
    for (final sms in smsData.take(10)) {
      analyzed++;
      final sender = sms['sender'] ?? sms['address'] ?? 'Unknown';
      final body = sms['body'] ?? '';
      
      print('─────────────────────────────────────────────────────────────');
      print('Message $analyzed');
      print('─────────────────────────────────────────────────────────────');
      print('Sender: $sender');
      print('Body: ${body.length > 100 ? body.substring(0, 100) + '...' : body}');
      print('');
      
      // Check 1: Is it considered financial?
      final isFinancial = await _checkIsFinancial(body, sender);
      if (isFinancial) {
        passedFinancialCheck++;
        print('✓ Passed financial SMS check');
        
        // Check 2: Can it be parsed?
        try {
          final parseResult = await hybridSmsParser.parse(body, senderId: sender);
          print('  Parser result:');
          print('    - Is transaction: ${parseResult.isTransaction}');
          print('    - Type: ${parseResult.transactionType.name}');
          print('    - Amount: \$${parseResult.amount?.toStringAsFixed(2) ?? 'null'}');
          print('    - Confidence: ${(parseResult.confidenceScore * 100).toStringAsFixed(1)}%');
          print('    - Region: ${parseResult.region.name}');
          
          if (parseResult.isTransaction && parseResult.amount != null) {
            passedParseCheck++;
            print('✓ Passed parse check - would be imported');
            
            // Check account extraction
            final accountIdentity = await AccountExtractionService.extractIdentity(
              smsText: body,
              region: parseResult.region,
              senderId: sender,
            );
            print('  Account extraction:');
            print('    - Bank: ${accountIdentity.bank ?? 'Unknown'} (${(accountIdentity.bankConfidence * 100).toStringAsFixed(0)}%)');
            print('    - Identifier: ${accountIdentity.accountIdentifier ?? 'Unknown'} (${(accountIdentity.identifierConfidence * 100).toStringAsFixed(0)}%)');
          } else {
            print('❌ Failed parse check - would be skipped');
            if (!parseResult.isTransaction) {
              print('   Reason: Not classified as transaction');
            }
            if (parseResult.amount == null) {
              print('   Reason: Amount not extracted');
            }
          }
        } catch (e) {
          print('❌ Parse error: $e');
        }
      } else {
        print('❌ Failed financial SMS check - would be skipped immediately');
        await _explainWhyNotFinancial(body, sender);
      }
      print('');
    }
    
    // Step 6: Summary
    print('═══════════════════════════════════════════════════════════════');
    print('DIAGNOSTIC SUMMARY');
    print('═══════════════════════════════════════════════════════════════');
    print('Total analyzed: $analyzed');
    print('Passed financial check: $passedFinancialCheck (${ (passedFinancialCheck / analyzed * 100).toStringAsFixed(1)}%)');
    print('Passed parse check: $passedParseCheck (${(passedParseCheck / analyzed * 100).toStringAsFixed(1)}%)');
    print('');
    
    if (passedParseCheck == 0) {
      print('⚠ PROBLEM DETECTED: No messages would be imported!');
      print('');
      print('Common causes:');
      print('1. SMS keywords not seeded in database');
      print('2. Sender IDs not recognized (numeric vs text format)');
      print('3. Amount patterns not matching (masked amounts)');
      print('4. ML parser not loading properly');
      print('5. Account extraction failing');
      print('');
      print('Suggested fixes:');
      print('1. Run: await SmsKeywordSeed.seed(db) to populate keywords');
      print('2. Check sender ID format (should match database entries)');
      print('3. Verify ML model files exist (assets/ml/*.tflite)');
      print('4. Check app logs for detailed error messages');
    } else if (passedParseCheck < analyzed) {
      print('⚠ PARTIAL SUCCESS: Only $passedParseCheck/$analyzed would be imported');
      print('');
      print('Some SMS are being filtered out. Check logs above for reasons.');
    } else {
      print('✓ ALL CLEAR: All analyzed messages would be imported successfully!');
    }
    print('═══════════════════════════════════════════════════════════════\n');
  }
  
  /// Check if SMS would pass the financial check
  static Future<bool> _checkIsFinancial(String body, String sender) async {
    final lower = body.toLowerCase();
    
    // 1. Check if sender is a known bank
    if (SmsKeywordService.isBankSender(sender)) return true;
    
    // 2. Check numeric short code pattern (5-6 digits)
    if (RegExp(r'^\d{5,6}$').hasMatch(sender)) {
      if (_hasFinancialKeywords(lower)) return true;
    }
    
    // 3. Check for financial keywords from database
    if (SmsKeywordService.containsKeyword(text: lower, type: 'debit')) return true;
    if (SmsKeywordService.containsKeyword(text: lower, type: 'credit')) return true;
    if (SmsKeywordService.containsKeyword(text: lower, type: 'financial')) return true;
    
    // 4. Check for bank names in message body
    if (_hasBankNameInBody(lower)) return true;
    
    // 5. Check for amount patterns
    final amountWithCurrencyRe = RegExp(
      r'(?:USD|INR|Rs\.?|₹|RM|AED|GBP|EUR|SGD|CAD|AUD|HKD|\$)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)',
      caseSensitive: false,
    );
    final amountNearKeywordRe = RegExp(
      r'(?:amount|amt|deposit|credited|debited|paid|received|payment|withdrawn|transfer|spent)\s*(?:of\s+)?(?:rs\.?|inr|usd|₹|\$)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final amountGenericRe = RegExp(r'\b(\d{1,7}\.\d{2})\b', caseSensitive: false);
    final maskedAmountRe = RegExp(r'\$[X,]+\.[X]{2}');
    
    if (!amountWithCurrencyRe.hasMatch(body) && 
        !amountNearKeywordRe.hasMatch(lower) && 
        !amountGenericRe.hasMatch(body) &&
        !maskedAmountRe.hasMatch(body)) {
      return false;
    }
    
    return true;
  }
  
  /// Explain why SMS failed financial check
  static Future<void> _explainWhyNotFinancial(String body, String sender) async {
    print('  Detailed check:');
    
    // Check 1: Sender
    final isKnownBank = SmsKeywordService.isBankSender(sender);
    print('    1. Known bank sender: ${isKnownBank ? '✓' : '❌'} ($sender)');
    
    // Check 2: Numeric sender
    final isNumericShortCode = RegExp(r'^\d{5,6}$').hasMatch(sender);
    print('    2. Numeric short code (5-6 digits): ${isNumericShortCode ? '✓' : '❌'}');
    
    // Check 3: Financial keywords
    final lower = body.toLowerCase();
    final hasDebitKeyword = SmsKeywordService.containsKeyword(text: lower, type: 'debit');
    final hasCreditKeyword = SmsKeywordService.containsKeyword(text: lower, type: 'credit');
    final hasFinancialKeyword = SmsKeywordService.containsKeyword(text: lower, type: 'financial');
    print('    3. Financial keywords: ${hasDebitKeyword || hasCreditKeyword || hasFinancialKeyword ? '✓' : '❌'}');
    print('       - Debit: $hasDebitKeyword');
    print('       - Credit: $hasCreditKeyword');
    print('       - Financial: $hasFinancialKeyword');
    
    // Check 4: Bank name in body
    final hasBankName = _hasBankNameInBody(lower);
    print('    4. Bank name in body: ${hasBankName ? '✓' : '❌'}');
    
    // Check 5: Amount pattern
    final amountWithCurrencyRe = RegExp(
      r'(?:USD|INR|Rs\.?|₹|RM|AED|GBP|EUR|SGD|CAD|AUD|HKD|\$)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)',
      caseSensitive: false,
    );
    final amountNearKeywordRe = RegExp(
      r'(?:amount|amt|deposit|credited|debited|paid|received|payment|withdrawn|transfer|spent)\s*(?:of\s+)?(?:rs\.?|inr|usd|₹|\$)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final amountGenericRe = RegExp(r'\b(\d{1,7}\.\d{2})\b', caseSensitive: false);
    final maskedAmountRe = RegExp(r'\$[X,]+\.[X]{2}');
    
    final hasAmount = amountWithCurrencyRe.hasMatch(body) ||
                     amountNearKeywordRe.hasMatch(lower) ||
                     amountGenericRe.hasMatch(body) ||
                     maskedAmountRe.hasMatch(body);
    print('    5. Amount pattern: ${hasAmount ? '✓' : '❌'}');
  }
  
  static bool _hasBankNameInBody(String lower) {
    final bankNames = [
      'citi', 'citibank', 'chase', 'bank of america', 'bofa',
      'wells fargo', 'capital one', 'capitalone', 'discover',
      'amex', 'american express', 'usaa', 'pnc', 'td bank',
      'hdfc', 'icici', 'sbi', 'axis', 'kotak', 'paytm',
    ];
    
    for (final bank in bankNames) {
      if (lower.contains(bank)) return true;
    }
    
    return false;
  }
  
  static bool _hasFinancialKeywords(String lower) {
    final keywords = [
      'transaction', 'payment', 'debit', 'credit', 'balance',
      'account', 'acct', 'alert', 'purchased', 'charged',
      'card', 'ending', 'deposit', 'withdraw', 'transfer',
    ];
    
    for (final keyword in keywords) {
      if (lower.contains(keyword)) return true;
    }
    
    return false;
  }
}
