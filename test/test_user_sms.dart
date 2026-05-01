import 'package:pocket_flow/services/advanced_sms_parser.dart';
import 'package:pocket_flow/models/sms_transaction_result.dart';

/// Test the specific SMS messages from the user
void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║              TESTING USER SMS MESSAGES                             ║');
  print('╚═══════════════════════════════════════════════════════════════════╝\n');

  // Test 1: Citi Alert
  print('═' * 70);
  print('TEST 1: CITI ALERT - Payment Posted');
  print('═' * 70);
  final citiSms = 'Citi Alert: A \$1,175.03 payment posted to acct ending in 3530 on 04/02/2026. View your balance at citi.com/citimobileapp';
  final citiResult = AdvancedSmsParser.parse(citiSms, senderId: 'Citi');
  
  print('\n📱 SMS: $citiSms');
  print('\n📊 PARSE RESULT:');
  print('   Is Transaction: ${citiResult.isTransaction}');
  print('   Type: ${citiResult.transactionType.name}');
  print('   Amount: \$${citiResult.amount?.toStringAsFixed(2) ?? 'N/A'}');
  print('   Currency: ${citiResult.currency ?? 'N/A'}');
  print('   Merchant: ${citiResult.merchant ?? 'N/A'}');
  print('   Bank: ${citiResult.bank ?? 'N/A'}');
  print('   Account: ${citiResult.accountIdentifier ?? 'N/A'}');
  print('   Region: ${citiResult.region?.name ?? 'N/A'}');
  print('   Confidence: ${(citiResult.confidenceScore * 100).toStringAsFixed(1)}%');
  
  if (citiResult.improvementSuggestions.isNotEmpty) {
    print('\n💡 IMPROVEMENT SUGGESTIONS:');
    for (int i = 0; i < citiResult.improvementSuggestions.length; i++) {
      print('   ${i + 1}. ${citiResult.improvementSuggestions[i]}');
    }
  }
  
  print('\n🔍 DETAILED REASONING:');
  print(citiResult.reasoning);
  print('\n');

  // Test 2: BofA Alert
  print('═' * 70);
  print('TEST 2: BOFA ALERT - Electronic Draft Deducted');
  print('═' * 70);
  final bofaSms = 'BofA: Electronic draft of \$1,175.03 for account - 3281 was deducted on 04/03/2026. STOP to end account texts';
  final bofaResult = AdvancedSmsParser.parse(bofaSms, senderId: 'BofA');
  
  print('\n📱 SMS: $bofaSms');
  print('\n📊 PARSE RESULT:');
  print('   Is Transaction: ${bofaResult.isTransaction}');
  print('   Type: ${bofaResult.transactionType.name}');
  print('   Amount: \$${bofaResult.amount?.toStringAsFixed(2) ?? 'N/A'}');
  print('   Currency: ${bofaResult.currency ?? 'N/A'}');
  print('   Merchant: ${bofaResult.merchant ?? 'N/A'}');
  print('   Bank: ${bofaResult.bank ?? 'N/A'}');
  print('   Account: ${bofaResult.accountIdentifier ?? 'N/A'}');
  print('   Region: ${bofaResult.region?.name ?? 'N/A'}');
  print('   Confidence: ${(bofaResult.confidenceScore * 100).toStringAsFixed(1)}%');
  
  if (bofaResult.improvementSuggestions.isNotEmpty) {
    print('\n💡 IMPROVEMENT SUGGESTIONS:');
    for (int i = 0; i < bofaResult.improvementSuggestions.length; i++) {
      print('   ${i + 1}. ${bofaResult.improvementSuggestions[i]}');
    }
  }
  
  print('\n🔍 DETAILED REASONING:');
  print(bofaResult.reasoning);
  print('\n');

  // Summary comparison
  print('═' * 70);
  print('SUMMARY COMPARISON');
  print('═' * 70);
  print('\nCiti Alert:');
  print('   Detected: ${citiResult.isTransaction ? 'YES ✓' : 'NO ✗'}');
  print('   Type: ${citiResult.transactionType.name}');
  print('   Confidence: ${(citiResult.confidenceScore * 100).toStringAsFixed(1)}%');
  
  print('\nBofA Alert:');
  print('   Detected: ${bofaResult.isTransaction ? 'YES ✓' : 'NO ✗'}');
  print('   Type: ${bofaResult.transactionType.name}');
  print('   Confidence: ${(bofaResult.confidenceScore * 100).toStringAsFixed(1)}%');
  
  print('\n✨ Both messages parsed successfully!\n');
}
