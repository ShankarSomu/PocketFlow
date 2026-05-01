import '../lib/services/advanced_sms_parser.dart';

void main() {
  // Test the BofA SMS that's not extracting account number
  final sms = 'Bank of America: Direct deposit of \$300.00 credited 09/03/2025 for account 4567. Go online for recent activity.';
  final senderId = 'BofA';
  
  print('Testing SMS:');
  print(sms);
  print('\nSender ID: $senderId');
  print('\n' + '='*80);
  
  final result = AdvancedSmsParser.parse(sms, senderId: senderId);
  
  print('\n📊 PARSE RESULTS:');
  print('='*80);
  print('Is Valid Transaction: ${result.isTransaction}');
  print('Type: ${result.transactionType}');
  print('Amount: \$${result.amount}');
  print('Currency: ${result.currency}');
  print('Bank: ${result.bank}');
  print('Account: ${result.accountIdentifier}');  // <-- This should be "4567"
  print('Merchant: ${result.merchant}');
  print('Region: ${result.region}');
  print('Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%');
  print('\n📝 REASONING:');
  print(result.reasoning);
  
  if (result.improvementSuggestions.isNotEmpty) {
    print('\n💡 SUGGESTIONS:');
    for (final suggestion in result.improvementSuggestions) {
      print('  • $suggestion');
    }
  }
  
  print('\n' + '='*80);
  
  // Check specifically for account extraction issue
  if (result.accountIdentifier == null) {
    print('\n❌ ISSUE CONFIRMED: Account identifier NOT extracted');
    print('   Expected: "4567"');
    print('   Got: null');
    
    // Test the regex pattern directly
    print('\n🔍 DEBUG: Testing regex patterns directly on lowercase text:');
    final lowerText = sms.toLowerCase();
    
    final patterns = [
      RegExp(r'\b(?:a\/c|ac|acc|account)\s*(?:no\.?|number)?\s*[:\s-]*([xX*]{2,}\d{4,6}|\d{4,16})\b', caseSensitive: false),
      RegExp(r'\baccount\s+(\d{4})\b'),
      RegExp(r'\baccount\s+(\d{4,8})\b'),
    ];
    
    for (int i = 0; i < patterns.length; i++) {
      final match = patterns[i].firstMatch(lowerText);
      print('  Pattern ${i+1}: ${match != null ? "MATCH -> ${match.group(1)}" : "NO MATCH"}');
      if (match != null) {
        print('    Full match: "${match.group(0)}"');
        print('    Pattern: ${patterns[i].pattern}');
      }
    }
    
    // Also test just the text around "account 4567"
    print('\n🔍 Text around "account 4567":');
    final accountIdx = lowerText.indexOf('account 4567');
    if (accountIdx >= 0) {
      final snippet = lowerText.substring(
        accountIdx > 20 ? accountIdx - 20 : 0,
        accountIdx + 30 < lowerText.length ? accountIdx + 30 : lowerText.length
      );
      print('  "$snippet"');
    }
  } else {
    print('\n✅ Account identifier extracted: ${result.accountIdentifier}');
  }
}
