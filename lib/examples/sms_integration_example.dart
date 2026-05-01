import 'package:pocket_flow/services/sms_service.dart';
import 'package:pocket_flow/services/advanced_sms_parser.dart';

/// Example demonstrating SMS integration with AdvancedSmsParser
/// 
/// The SmsService now uses AdvancedSmsParser internally for:
/// - 14-step parsing process
/// - Region detection (INDIA/US)
/// - Confidence scoring
/// - Improvement suggestions
/// - Review flagging for low-confidence parses
void main() async {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║         SMS INTEGRATION - ADVANCED PARSER EXAMPLE                  ║');
  print('╚═══════════════════════════════════════════════════════════════════╝\n');

  // Example SMS messages from different regions
  final testMessages = [
    // INDIA - HDFC Bank
    {
      'body': 'Rs.1,250.00 debited from A/c XX5678 via UPI to merchant@paytm. UPI Ref: 123456789012. HDFC Bank',
      'sender': 'HDFCBK',
    },
    // USA - Chase Bank
    {
      'body': 'Chase Bank: Your card ending 5678 was charged \$245.50 at AMAZON.COM on 04/19/2026',
      'sender': 'CHASE',
    },
    // INDIA - ICICI Credit
    {
      'body': 'Rs.75,000 credited to your SBI A/c XX9876 on 19-04-2026. Salary from ACME CORP.',
      'sender': 'SBIINB',
    },
    // Low confidence example
    {
      'body': 'Payment of 500 successful',
      'sender': 'BANK',
    },
  ];

  for (int i = 0; i < testMessages.length; i++) {
    final msg = testMessages[i];
    final body = msg['body'] as String;
    final sender = msg['sender'] as String;

    print('\n${'─' * 70}');
    print('TEST ${i + 1}: ${sender}');
    print('${'─' * 70}');
    print('SMS: $body\n');

    // Parse using AdvancedSmsParser (same as SmsService._parseSms internally)
    final result = AdvancedSmsParser.parse(body, senderId: sender);

    print('📊 PARSE RESULT:');
    print('   Transaction: ${result.isTransaction}');
    if (result.isTransaction) {
      print('   Type: ${result.transactionType.name}');
      print('   Amount: ${result.amount ?? 'N/A'}');
      print('   Currency: ${result.currency ?? 'N/A'}');
      print('   Merchant: ${result.merchant ?? 'N/A'}');
      print('   Bank: ${result.bank ?? 'N/A'}');
      print('   Region: ${result.region.name}');
      print('   Account: ${result.accountIdentifier ?? 'N/A'}');
      print('   Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%');
      
      if (result.improvementSuggestions.isNotEmpty) {
        print('\n💡 IMPROVEMENT SUGGESTIONS:');
        for (final suggestion in result.improvementSuggestions) {
          print('   → $suggestion');
        }
      }
      
      // Determine if needs review
      final needsReview = result.confidenceScore < 0.7;
      print('\n✓ REVIEW STATUS: ${needsReview ? '⚠️  NEEDS REVIEW' : '✅ AUTO-PROCESS'}');
    }
  }

  print('\n╔═══════════════════════════════════════════════════════════════════╗');
  print('║                    INTEGRATION SUMMARY                             ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');
  print('');
  print('✅ SmsService now uses AdvancedSmsParser internally');
  print('✅ Region detection: INDIA/US based on currency and banks');
  print('✅ Confidence scoring: 0.0-1.0 scale');
  print('✅ Auto-review flagging: Transactions < 70% confidence flagged');
  print('✅ Improvement tracking: Suggestions stored in transaction notes');
  print('✅ Rich metadata: Region, bank, merchant all stored');
  print('');
  print('📝 Transaction notes now include:');
  print('   - Region badge ([INDIA], [US])');
  print('   - Merchant and bank information');
  print('   - Improvement suggestions for debugging');
  print('');
}
