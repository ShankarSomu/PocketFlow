import 'dart:convert';
import 'package:pocket_flow/services/advanced_sms_parser.dart';
import 'package:pocket_flow/models/sms_transaction_result.dart';

/// Comprehensive test suite for the Advanced SMS Parser
/// 
/// Demonstrates:
/// - Region-aware parsing (INDIA vs US)
/// - Improvement suggestions
/// - Review/learning mode
/// - Confidence scoring
void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║         ADVANCED SMS PARSER - COMPREHENSIVE TEST SUITE            ║');
  print('║         (Region-Aware + Learning + Improvement Tracking)          ║');
  print('╚═══════════════════════════════════════════════════════════════════╝\n');

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 1: INDIA REGION TESTS
  // ═════════════════════════════════════════════════════════════════════════

  print('═' * 70);
  print('SECTION 1: INDIA REGION TESTS');
  print('═' * 70);
  print('');

  testCase(
    'Test 1.1: HDFC Bank UPI Payment (India)',
    'Rs.1,250.00 debited from A/c XX5678 via UPI to merchant@paytm. UPI Ref: 123456789012. HDFC Bank',
    senderId: 'HDFCBK',
  );

  testCase(
    'Test 1.2: ICICI Bank Card Purchase (India)',
    'INR 3,450.50 spent on ICICI card XX1234 at Amazon on 19-Apr-26. Avl Bal: Rs.45,230.00',
    senderId: 'ICICIBK',
  );

  testCase(
    'Test 1.3: SBI Account Credit (India)',
    'Rs.75,000 credited to your SBI A/c XX9876 on 19-04-2026. Salary from ACME CORP.',
    senderId: 'SBIINB',
  );

  testCase(
    'Test 1.4: Paytm Wallet Transaction (India)',
    'Rs.150 debited from Paytm wallet for recharge. Balance: Rs.850.50',
    senderId: 'PAYTM',
  );

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 2: US REGION TESTS
  // ═════════════════════════════════════════════════════════════════════════

  print('\n${'═' * 70}');
  print('SECTION 2: US REGION TESTS');
  print('═' * 70);
  print('');

  testCase(
    'Test 2.1: Chase Card Purchase (US)',
    'Chase: Your card ending 4321 was charged \$245.99 at AMAZON.COM on 04/19/2026',
    senderId: 'Chase',
  );

  testCase(
    'Test 2.2: Bank of America Debit (US)',
    'BofA: Purchase of \$89.50 at WHOLE FOODS using card **5678. Available balance: \$2,145.30',
    senderId: 'BofA',
  );

  testCase(
    'Test 2.3: Wells Fargo Transfer (US)',
    'Wells Fargo: \$1,500.00 transferred from account ending 9012 via ACH',
    senderId: 'WellsFargo',
  );

  testCase(
    'Test 2.4: Capital One Cashback (US)',
    'Capital One: Cashback of \$15.75 credited to card ending 3456',
    senderId: 'CapitalOne',
  );

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 3: EDGE CASES & AMBIGUOUS SCENARIOS
  // ═════════════════════════════════════════════════════════════════════════

  print('\n${'═' * 70}');
  print('SECTION 3: EDGE CASES & LEARNING SCENARIOS');
  print('═' * 70);
  print('');

  testCase(
    'Test 3.1: Unknown Region (No Clear Indicators)',
    'Your account 1234 was debited 500 for payment on 19-Apr-26',
    senderId: 'UNKNOWN',
  );

  testCase(
    'Test 3.2: Multiple Numbers (Account vs Amount)',
    'Account 987654321 debited Rs.1,250 on 19042026 at Starbucks. Ref: 123456789012',
    senderId: 'ICICIBK',
  );

  testCase(
    'Test 3.3: Both Debit and Credit Keywords',
    'Rs.500 debited and Rs.50 cashback credited to A/c XX1111. Net: Rs.450 debited. HDFC',
    senderId: 'HDFCBK',
  );

  testCase(
    'Test 3.4: No Merchant Information',
    'Rs.2,500.00 debited from A/c XX7890 on 19-Apr-26. Balance: Rs.12,345.00',
    senderId: 'AXISBK',
  );

  testCase(
    'Test 3.5: Non-Transaction (OTP)',
    'Your OTP for login is 123456. Valid for 10 minutes. Do not share.',
    senderId: 'HDFCBK',
  );

  testCase(
    'Test 3.6: Unsupported Bank (Learning Opportunity)',
    '\$125.00 debited from card 5432 at TARGET. Regional Bank XYZ',
    senderId: 'REGBNK',
  );

  testCase(
    'Test 3.7: Transaction Phrase - "transaction was made"',
    'Citi Alert: A \$89.45 transaction was made at GITHUB, INC. on card ending in 1234',
    senderId: 'Citi',
  );

  testCase(
    'Test 3.8: Transaction Phrase - "electronic draft"',
    'BofA: Electronic draft of \$125.00 for NETFLIX.COM was deducted on 04/19/2026',
    senderId: 'BofA',
  );

  testCase(
    'Test 3.9: Transaction Phrase - "payment posted"',
    'Citi Alert: A \$1,250.00 payment posted to acct ending in 5678 on 04/19/2026',
    senderId: 'Citi',
  );

  testCase(
    'Test 3.10: Transaction Phrase - "direct deposit"',
    'BofA: Direct deposit of \$2,500.00 credited to account ending in 9876 on 04/19/2026',
    senderId: 'BofA',
  );

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 4: REVIEW MODE DEMONSTRATION
  // ═════════════════════════════════════════════════════════════════════════

  print('\n${'═' * 70}');
  print('SECTION 4: REVIEW MODE - Comparing Existing vs New Parse');
  print('═' * 70);
  print('');

  demonstrateReviewMode();

  // ═════════════════════════════════════════════════════════════════════════
  // SECTION 5: IMPROVEMENT SUGGESTIONS ANALYSIS
  // ═════════════════════════════════════════════════════════════════════════

  print('\n${'═' * 70}');
  print('SECTION 5: IMPROVEMENT SUGGESTIONS - Learning from Low Confidence Parses');
  print('═' * 70);
  print('');

  analyzeLearning();

  print('\n╔════════════════════════════════════════════════════════════════════╗');
  print('║                      TEST SUITE COMPLETED                          ║');
  print('║                                                                    ║');
  print('║  Advanced Features Demonstrated:                                   ║');
  print('║  ✓ Region-aware parsing (INDIA vs US)                              ║');
  print('║  ✓ Region-specific amount/account patterns                         ║');
  print('║  ✓ Improvement suggestions for parser evolution                    ║');
  print('║  ✓ Review mode for comparing parses                                ║');
  print('║  ✓ Learning from low-confidence scenarios                          ║');
  print('║  ✓ Modular, region-specific rule sets                              ║');
  print('╚════════════════════════════════════════════════════════════════════╝\n');
}

void testCase(String title, String smsText, {String? senderId}) {
  print('─' * 70);
  print('📱 $title');
  print('─' * 70);
  print('SMS: $smsText');
  if (senderId != null) print('Sender ID: $senderId');
  print('');

  final result = AdvancedSmsParser.parse(smsText, senderId: senderId);

  // Print JSON output
  print('📊 RESULT:');
  print(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  
  print('\n🧠 REASONING:');
  final reasoningSteps = result.reasoning.split(';');
  for (final step in reasoningSteps) {
    print('   • ${step.trim()}');
  }
  
  // Print improvement suggestions
  if (result.improvementSuggestions.isNotEmpty) {
    print('\n💡 IMPROVEMENT SUGGESTIONS:');
    for (final suggestion in result.improvementSuggestions) {
      print('   → $suggestion');
    }
  }
  
  // Print confidence assessment
  print('\n✓ CONFIDENCE ASSESSMENT:');
  final confidencePercent = (result.confidenceScore * 100).toStringAsFixed(0);
  String emoji;
  String assessment;
  
  if (result.confidenceScore >= 0.8) {
    emoji = '🟢';
    assessment = 'HIGH - Auto-process recommended';
  } else if (result.confidenceScore >= 0.5) {
    emoji = '🟡';
    assessment = 'MEDIUM - Consider review';
  } else {
    emoji = '🔴';
    assessment = 'LOW - Manual verification required';
  }
  
  print('   $emoji $confidencePercent% - $assessment');
  print('\n');
}

void demonstrateReviewMode() {
  final smsText = 'Rs.1,500 debited from A/c XX1234 at Amazon. HDFC Bank';
  
  // Simulate existing parse (potentially incorrect)
  final existingParse = SmsTransactionResult(
    isTransaction: true,
    transactionType: TransactionTypeEnum.debit,
    amount: 1234.0, // Wrong amount!
    currency: 'INR',
    merchant: 'Amazon',
    accountIdentifier: '****1234',
    bank: 'HDFC Bank',
    region: RegionEnum.unknown, // Wrong region!
    confidenceScore: 0.65,
    reasoning: 'Old parsing logic',
    improvementSuggestions: [],
  );

  print('🔍 REVIEW MODE EXAMPLE');
  print('─' * 70);
  print('SMS: $smsText\n');

  final review = AdvancedSmsParser.reviewParse(
    smsText,
    existingParse,
    senderId: 'HDFCBK',
  );

  print('📋 REVIEW RESULTS:');
  print(const JsonEncoder.withIndent('  ').convert(review));
  print('');
}

void analyzeLearning() {
  final lowConfidenceSms = [
    'Your account was debited 500 for payment',
    '\$100 charged to card',
    'Payment of 1500 successful',
  ];

  print('📚 LEARNING ANALYSIS\n');
  
  for (int i = 0; i < lowConfidenceSms.length; i++) {
    final sms = lowConfidenceSms[i];
    final result = AdvancedSmsParser.parse(sms);
    
    print('SMS ${i + 1}: "$sms"');
    print('Confidence: ${(result.confidenceScore * 100).toStringAsFixed(0)}%');
    print('Suggestions for improvement:');
    for (final suggestion in result.improvementSuggestions) {
      print('  → $suggestion');
    }
    print('');
  }

  print('💭 LEARNING INSIGHTS:');
  print('   • Track repeated parsing failures');
  print('   • Identify common pattern gaps');
  print('   • Recommend rule updates instead of hardcoding');
  print('   • Prefer modular improvements over monolithic fixes');
  print('');
}
