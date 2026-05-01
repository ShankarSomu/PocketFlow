import 'package:pocket_flow/services/advanced_sms_parser.dart';

/// Test Citi balance alert with "exceeded amount" text
void main() {
  print('═' * 80);
  print('TESTING CITI BALANCE ALERT');
  print('═' * 80);
  print('');
  
  final smsText = 'Citi Alert: Bal plus pending transactions on acct ending in 3456, \$5.00, exceeded amount set in your acct alerts. View your bal at citi.com/citimobileapp';
  
  print('SMS Text:');
  print('"$smsText"');
  print('');
  print('Parsing...\n');
  
  final result = AdvancedSmsParser.parse(smsText, senderId: 'CITI');
  
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
  print('ANALYSIS');
  print('═' * 80);
  print('');
  if (!result.isTransaction) {
    print('✅ CORRECT: This is a balance alert, not a transaction');
    print('   - SMS reports balance plus pending transactions');
    print('   - No money debited or credited');
    print('   - "exceeded amount" refers to alert threshold, not transaction');
  } else {
    print('❌ ISSUE: Parser incorrectly identified this as a transaction!');
    print('   This is just a balance threshold alert.');
    print('   Keywords detected:');
    if (smsText.toLowerCase().contains('exceeded')) {
      print('   - "exceeded" might be confused with a transaction action');
    }
    print('');
    print('   Recommendation: Add "exceeded amount" to exclusion patterns');
  }
  print('═' * 80);
}
