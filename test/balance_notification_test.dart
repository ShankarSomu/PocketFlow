import 'package:pocket_flow/sms_engine/parsing/sms_advanced_parser.dart';

/// Test to demonstrate how balance notification SMS is handled
void main() {
  print('═' * 80);
  print('TESTING BALANCE NOTIFICATION SMS');
  print('═' * 80);
  print('');
  
  final smsText = 'Capital One Alert: Your Quicksilver Credit Card…(7330) bal is \$0.00 as of April 19, 2026. Msg & data rates may apply.';
  
  print('SMS Text:');
  print('"$smsText"');
  print('');
  print('Parsing...\n');
  
  final result = AdvancedSmsParser.parse(smsText, senderId: 'CapOne');
  
  print('═' * 80);
  print('PARSE RESULT');
  print('═' * 80);
  print('');
  print('Is Transaction: ${result.isTransaction}');
  print('Transaction Type: ${result.transactionType}');
  print('Amount: ${result.amount}');
  print('Currency: ${result.currency}');
  print('Merchant: ${result.merchant ?? 'null'}');
  print('Bank: ${result.bank ?? 'null'}');
  print('Account: ${result.accountIdentifier ?? 'null'}');
  print('Region: ${result.region}');
  print('Confidence Score: ${(result.confidenceScore * 100).toStringAsFixed(1)}%');
  print('');
  print('═' * 80);
  print('DETAILED REASONING');
  print('═' * 80);
  print('');
  print(result.reasoning);
  
  if (result.improvementSuggestions.isNotEmpty) {
    print('═' * 80);
    print('IMPROVEMENT SUGGESTIONS');
    print('═' * 80);
    print('');
    for (var i = 0; i < result.improvementSuggestions.length; i++) {
      print('${i + 1}. ${result.improvementSuggestions[i]}');
    }
    print('');
  }
  
  print('═' * 80);
  print('ISSUE IDENTIFIED');
  print('═' * 80);
  print('');
  print('⚠️  This is a BALANCE NOTIFICATION, not a transaction!');
  print('    However, the parser classified it as a transaction.');
  print('');
  print('Problem:');
  print('  - SMS only reports current balance (\$0.00)');
  print('  - No money was debited or credited');
  print('  - Should be filtered out to avoid creating ghost transactions');
  print('');
  print('Recommendation:');
  print('  - Add balance-only notification detection in Step 1');
  print('  - Reject SMS with ONLY balance info and no transaction keywords');
  print('  - Keywords to exclude: "bal is", "balance is", "current balance"');
  print('═' * 80);
}
