import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/services/advanced_sms_parser.dart';

void main() {
  test('Test Citi Alert Message Processing', () {
    final smsText = 'Citi Alert: Bal plus pending transactions on acct ending in 3456, \$5.00, exceeded amount set in your acct alerts. View your bal at citi.com/citimobileapp';
    final senderId = 'CITI';
    
    print('\n${'=' * 80}');
    print('TESTING CITI ALERT MESSAGE');
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
  });
}
