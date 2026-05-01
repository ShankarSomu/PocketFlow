import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/services/advanced_sms_parser.dart';

void main() {
  test('Test Capital One Alert Message Processing', () {
    final smsText = 'Capital One Alert: Your Quicksilver Credit Card…(7330) bal is \$0.00 as of April 19, 2026. Msg & data rates may apply.';
    final senderId = 'CapOne';
    
    print('\n${'=' * 80}');
    print('TESTING CAPITAL ONE BALANCE ALERT');
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
      print('⚠️  WARNING: This balance notification was INCORRECTLY parsed as a transaction!');
      if (result.amount != null) {
        print('   Ghost transaction amount: \$${result.amount}');
        print('   This is likely the card number (7330) misidentified as amount.');
      }
    } else {
      print('✅ CORRECT: This balance notification was properly rejected.');
      print('   No ghost transaction will be created.');
    }
    print('=' * 80);
  });
}
