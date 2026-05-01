import 'package:pocket_flow/services/advanced_sms_parser.dart';

/// Test UC Davis Health bill statement notification
void main() {
  print('═' * 80);
  print('TESTING UC DAVIS HEALTH BILL STATEMENT');
  print('═' * 80);
  print('');
  
  final smsText = 'UC Davis Health: You have a new statement for \$465.33. Your payment is due by May 5. Pay or view details: https://mchrt.io/dhT9bmXAblCSIZC-T6E Reply STOP to opt out.';
  
  print('SMS Text:');
  print('"$smsText"');
  print('');
  print('Parsing...\n');
  
  final result = AdvancedSmsParser.parse(smsText, senderId: 'UCDavis');
  
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
    print('✅ CORRECT: This is a bill statement notification, not a transaction');
    print('   - SMS notifies about a new statement/bill');
    print('   - Amount is what is OWED, not debited');
    print('   - Payment is DUE in the future');
    print('   - No money has moved yet');
  } else {
    print('❌ ISSUE: Parser incorrectly identified this as a transaction!');
    print('   This is just a bill statement notification.');
    print('   The amount (\$465.33) is what is owed, not debited.');
    print('   No actual payment has occurred yet.');
    print('');
    print('   Recommendation: Add "statement", "payment is due" patterns');
  }
  print('═' * 80);
}
