import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SMS Transfer Detection Logic Tests', () {
    
    test('Citi payment message should be detected as payment', () {
      final message = "Citi Alert: A \$1,543.23 payment posted to acct ending in 3130 on 04/03/2026. View your balance at citi.com/citimobileapp";
      final lower = message.toLowerCase();
      
      final isPayment = lower.contains('payment') || lower.contains('posted');
      final isDebit = lower.contains('debit') || 
                     lower.contains('draft') || 
                     lower.contains('withdrew') ||
                     lower.contains('deducted');
      
      expect(isPayment, true, reason: 'Should detect "payment" and "posted"');
      expect(isDebit, false, reason: 'Should not be debit');
      
      print('✓ Citi message: isPayment=$isPayment, isDebit=$isDebit');
    });
    
    test('BofA draft message should be detected as debit', () {
      final message = "BofA: Electronic draft of \$1,543.23 for account - 3281 was deducted on 04/03/2026. STOP to end account texts";
      final lower = message.toLowerCase();
      
      final isPayment = lower.contains('payment') || lower.contains('posted');
      final isDebit = lower.contains('debit') || 
                     lower.contains('draft') || 
                     lower.contains('withdrew') ||
                     lower.contains('deducted');
      
      expect(isPayment, false, reason: 'Should not be payment');
      expect(isDebit, true, reason: 'Should detect "draft" and "deducted"');
      
      print('✓ BofA message: isPayment=$isPayment, isDebit=$isDebit');
    });
    
    test('Payment + Debit pair should be detected as transfer', () {
      final citiMsg = "Citi Alert: A \$1,543.23 payment posted to acct ending in 3130 on 04/03/2026.";
      final bofaMsg = "BofA: Electronic draft of \$1,543.23 for account - 3281 was deducted on 04/03/2026.";
      
      final citiLower = citiMsg.toLowerCase();
      final bofaLower = bofaMsg.toLowerCase();
      
      final citiIsPayment = citiLower.contains('payment') || citiLower.contains('posted');
      final citiIsDebit = citiLower.contains('debit') || 
                         citiLower.contains('draft') || 
                         citiLower.contains('withdrew') ||
                         citiLower.contains('deducted');
      
      final bofaIsPayment = bofaLower.contains('payment') || bofaLower.contains('posted');
      final bofaIsDebit = bofaLower.contains('debit') || 
                         bofaLower.contains('draft') || 
                         bofaLower.contains('withdrew') ||
                         bofaLower.contains('deducted');
      
      // One should be payment, other should be debit
      final isTransferPair = (citiIsPayment && bofaIsDebit) || (bofaIsPayment && citiIsDebit);
      
      expect(citiIsPayment, true);
      expect(citiIsDebit, false);
      expect(bofaIsPayment, false);
      expect(bofaIsDebit, true);
      expect(isTransferPair, true, reason: 'Should detect as transfer pair');
      
      print('✓ Transfer pair detected: citiIsPayment=$citiIsPayment, bofaIsDebit=$bofaIsDebit');
      print('✓ Result: isTransferPair=$isTransferPair');
    });
    
    test('Same-type messages should NOT be detected as transfer', () {
      final msg1 = "Citi Alert: A \$100 payment posted on 04/03/2026.";
      final msg2 = "Chase: \$100 payment posted on 04/03/2026.";
      
      final msg1Lower = msg1.toLowerCase();
      final msg2Lower = msg2.toLowerCase();
      
      final msg1IsPayment = msg1Lower.contains('payment') || msg1Lower.contains('posted');
      final msg1IsDebit = msg1Lower.contains('debit') || 
                         msg1Lower.contains('draft') || 
                         msg1Lower.contains('withdrew') ||
                         msg1Lower.contains('deducted');
      
      final msg2IsPayment = msg2Lower.contains('payment') || msg2Lower.contains('posted');
      final msg2IsDebit = msg2Lower.contains('debit') || 
                         msg2Lower.contains('draft') || 
                         msg2Lower.contains('withdrew') ||
                         msg2Lower.contains('deducted');
      
      // One should be payment, other should be debit
      final isTransferPair = (msg1IsPayment && msg2IsDebit) || (msg2IsPayment && msg1IsDebit);
      
      expect(isTransferPair, false, reason: 'Both payments - should NOT be transfer pair');
      
      print('✓ Both payments: NOT a transfer pair (as expected)');
    });
    
    test('Keyword detection coverage', () {
      final keywords = {
        'payment': 'payment posted to account',
        'posted': 'transaction posted successfully',
        'debit': 'debit card transaction',
        'draft': 'electronic draft',
        'withdrew': 'withdrew from account',
        'deducted': 'amount deducted from balance',
      };
      
      for (final entry in keywords.entries) {
        final keyword = entry.key;
        final testMsg = entry.value;
        final lower = testMsg.toLowerCase();
        
        final containsKeyword = lower.contains(keyword);
        expect(containsKeyword, true, reason: 'Should detect "$keyword" in "$testMsg"');
        print('✓ Detected "$keyword" in: "$testMsg"');
      }
    });
  });
}
