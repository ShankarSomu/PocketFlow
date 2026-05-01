import 'package:pocket_flow/services/advanced_sms_parser.dart';

/// Comprehensive test for balance notification handling
/// Ensures we don't create ghost transactions from non-transaction SMS
void main() {
  print('═' * 80);
  print('COMPREHENSIVE BALANCE NOTIFICATION TEST');
  print('Testing various balance-only SMS formats to ensure NO ghost transactions');
  print('═' * 80);
  print('');
  
  final testCases = [
    {
      'name': 'Test 1: Capital One Balance Alert (from user)',
      'sms': 'Capital One Alert: Your Quicksilver Credit Card…(7330) bal is \$0.00 as of April 19, 2026. Msg & data rates may apply.',
      'senderId': 'CapOne',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 2: Available Balance Notification',
      'sms': 'Your available balance is Rs.25,430.50 as of 19-Apr-26. HDFC Bank',
      'senderId': 'HDFCBK',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 3: Current Balance Update',
      'sms': 'Account XX1234 current balance: \$1,245.30. Chase Bank',
      'senderId': 'Chase',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 4: Minimum Balance Alert',
      'sms': 'Alert: Your account min bal is Rs.5,000. Please maintain minimum balance. SBI',
      'senderId': 'SBIINB',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 5: Statement Balance',
      'sms': 'Your statement balance is \$2,345.67 as of March 31. BofA',
      'senderId': 'BofA',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 6: Balance WITH Transaction (should parse)',
      'sms': 'Rs.500 debited from A/c XX1234. Available balance: Rs.12,500. HDFC',
      'senderId': 'HDFCBK',
      'expectedTransaction': true,
    },
    {
      'name': 'Test 7: Outstanding Balance',
      'sms': 'Outstanding balance on your card is \$875.50. Pay by due date. Capital One',
      'senderId': 'CapOne',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 8: Total Balance',
      'sms': 'Your total balance across all accounts is Rs.1,25,000. Axis Bank',
      'senderId': 'AXISBK',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 9: Citi Balance Alert with Exceeded Threshold',
      'sms': 'Citi Alert: Bal plus pending transactions on acct ending in 3456, \$5.00, exceeded amount set in your acct alerts. View your bal at citi.com/citimobileapp',
      'senderId': 'CITI',
      'expectedTransaction': false,
    },
    {
      'name': 'Test 10: UC Davis Health Bill Statement',
      'sms': 'UC Davis Health: You have a new statement for \$465.33. Your payment is due by May 5. Pay or view details: https://mchrt.io/dhT9bmXAblCSIZC-T6E',
      'senderId': 'UCDavis',
      'expectedTransaction': false,
    },
  ];
  
  int passed = 0;
  int failed = 0;
  
  for (final testCase in testCases) {
    final name = testCase['name'] as String;
    final sms = testCase['sms'] as String;
    final senderId = testCase['senderId'] as String;
    final expectedTransaction = testCase['expectedTransaction'] as bool;
    
    print('─' * 80);
    print('$name');
    print('─' * 80);
    print('SMS: "$sms"');
    print('Sender: $senderId');
    print('');
    
    final result = AdvancedSmsParser.parse(sms, senderId: senderId);
    
    final success = result.isTransaction == expectedTransaction;
    
    if (success) {
      passed++;
      print('✓ PASS: Correctly identified as ${expectedTransaction ? "TRANSACTION" : "NON-TRANSACTION"}');
      print('  - Is Transaction: ${result.isTransaction}');
      print('  - Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%');
      if (result.isTransaction) {
        print('  - Amount: ${result.amount}');
        print('  - Type: ${result.transactionType}');
      }
    } else {
      failed++;
      print('✗ FAIL: Expected ${expectedTransaction ? "TRANSACTION" : "NON-TRANSACTION"}, got ${result.isTransaction ? "TRANSACTION" : "NON-TRANSACTION"}');
      print('  - Is Transaction: ${result.isTransaction}');
      print('  - Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%');
      print('  - Amount: ${result.amount}');
      print('  - Type: ${result.transactionType}');
      print('');
      print('  REASONING:');
      print(result.reasoning.split('\\n').take(5).join('\\n'));
    }
    print('');
  }
  
  print('═' * 80);
  print('TEST SUMMARY');
  print('═' * 80);
  print('Total Tests: ${testCases.length}');
  print('Passed: $passed ✓');
  print('Failed: $failed ✗');
  print('Success Rate: ${((passed / testCases.length) * 100).toStringAsFixed(1)}%');
  print('═' * 80);
  
  if (failed == 0) {
    print('');
    print('🎉 ALL TESTS PASSED!');
    print('✓ Balance notifications correctly filtered out');
    print('✓ No ghost transactions will be created');
    print('✓ Actual transactions still parsed correctly');
  } else {
    print('');
    print('⚠️  Some tests failed. Review the parser logic.');
  }
  print('');
}
