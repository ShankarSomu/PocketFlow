import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_advanced_parser.dart';

void main() {
  test('Test UC Davis Health Bill Statement Processing', () {
    final smsText = 'UC Davis Health: You have a new statement for \$465.33. Your payment is due by May 5. Pay or view details: https://mchrt.io/dhT9bmXAblCSIZC-T6E Reply STOP to opt out.';
    final senderId = 'UCDavis';
    
    print('\n${'=' * 80}');
    print('TESTING UC DAVIS HEALTH BILL STATEMENT');
    print('=' * 80);
    print('SMS: $smsText');
    print('Sender: $senderId');
    print('=' * 80);
    
    final result = AdvancedSmsParser.parse(smsText, senderId: senderId);
    
    print('\n📊 PARSE RESULT:');
    print('─' * 80);
    print('Is Transaction: ${result.isTransaction}');
    print('Transaction Type: ${result.transactionType}');
    print('Amount: ${result.amount}');
    print('Currency: ${result.currency}');
    print('Merchant: ${result.merchant}');
    print('Account: ${result.accountIdentifier}');
    print('Bank: ${result.bank}');
    print('Region: ${result.region}');
    print('Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%');
    
    if (result.improvementSuggestions.isNotEmpty) {
      print('\n💡 SUGGESTIONS:');
      for (final suggestion in result.improvementSuggestions) {
        print('  → $suggestion');
      }
    }
    
    print('\n🧠 DETAILED REASONING:');
    print('─' * 80);
    print(result.reasoning);
    print('=' * 80);
    
    // Analysis
    print('\n🔍 ANALYSIS:');
    print('─' * 80);
    if (result.isTransaction) {
      print('⚠️  WARNING: This bill statement was INCORRECTLY parsed as a transaction!');
      print('   This is a FUTURE OBLIGATION, not a completed transaction.');
      if (result.amount != null) {
        print('   Amount: \$${result.amount}');
        print('   This amount is OWED, not yet debited from account.');
        if (result.transactionType.toString().contains('debit')) {
          print('   Transaction type incorrectly shows as: ${result.transactionType}');
          print('   The money has NOT been debited yet - payment is due May 5.');
        }
      }
    } else {
      print('✅ CORRECT: This bill statement was properly rejected.');
      print('   No premature transaction will be created.');
      print('   This is a future obligation (payment due May 5), not a completed transaction.');
    }
    print('=' * 80);
  });
}
