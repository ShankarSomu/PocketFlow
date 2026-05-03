import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_data_masker.dart';

void main() {
  group('SMS Training Export Examples', () {
    test('Example 1: Basic transaction SMS', () {
      final original = 'Rs.500 debited from A/c XX1234 at Starbucks';
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ Example 1: Basic Transaction');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Original: $original');
      
      final masked = SmsDataMasker.maskSms(original);
      print('║ Masked:   $masked');
      
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      print('║ Summary:  ${summary.toString()}');
      print('╚════════════════════════════════════════════════════════════\n');
      
      expect(masked, 'Rs.XXX debited from A/c XXXX at Starbucks');
      expect(summary.amountsMasked, 1);
      expect(summary.accountsMasked, 1);
    });

    test('Example 2: UPI transaction with reference', () {
      final original = 'Rs.1,250.00 debited from A/c XX5678 via UPI on 19-Apr-26. UPI Ref: 123456789012. HDFC Bank';
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ Example 2: UPI Transaction with Reference');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Original: $original');
      
      final masked = SmsDataMasker.maskSms(original);
      print('║ Masked:   $masked');
      
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      print('║ Summary:  ${summary.toString()}');
      print('╚════════════════════════════════════════════════════════════\n');
      
      expect(masked, contains('Rs.X,XXX.XX'));
      expect(masked, contains('XXXX'));
      expect(masked, contains('<DATE>'));
      expect(masked, contains('<REF>'));
      expect(summary.totalMasked, 4);
    });

    test('Example 3: Balance notification (not a transaction)', () {
      final original = 'Capital One Alert: Your Quicksilver Credit Card…(7330) bal is \$0.00 as of April 19, 2026.';
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ Example 3: Balance Notification');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Original: $original');
      
      final masked = SmsDataMasker.maskSms(original);
      print('║ Masked:   $masked');
      
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      print('║ Summary:  ${summary.toString()}');
      print('╚════════════════════════════════════════════════════════════\n');
      
      expect(masked, contains('\$X.XX'));
      expect(masked, contains('XXXX'));
      expect(masked, contains('<DATE>'));
    });

    test('Example 4: Bill statement', () {
      final original = 'UC Davis Health: You have a new statement for \$465.33. Your payment is due by May 5.';
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ Example 4: Bill Statement');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Original: $original');
      
      final masked = SmsDataMasker.maskSms(original);
      print('║ Masked:   $masked');
      
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      print('║ Summary:  ${summary.toString()}');
      print('╚════════════════════════════════════════════════════════════\n');
      
      expect(masked, contains('\$XXX.XX'));
      expect(masked, isNot(contains('465.33')));
    });

    test('Example 5: Transaction with balance info', () {
      final original = 'Rs.2,500.00 debited from A/c XX7890 on 19-Apr-26. Balance: Rs.12,345.00';
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ Example 5: Transaction + Balance Info');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Original: $original');
      
      final masked = SmsDataMasker.maskSms(original);
      print('║ Masked:   $masked');
      
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      print('║ Summary:  ${summary.toString()}');
      print('╚════════════════════════════════════════════════════════════\n');
      
      // Should mask both amounts
      expect(summary.amountsMasked, 2);
      expect(masked, isNot(contains('2,500')));
      expect(masked, isNot(contains('12,345')));
    });

    test('Example 6: Multiple amounts in one message', () {
      final original = 'Rs.500 debited and Rs.50 cashback credited. Net: Rs.450 debited.';
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ Example 6: Multiple Amounts');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Original: $original');
      
      final masked = SmsDataMasker.maskSms(original);
      print('║ Masked:   $masked');
      
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      print('║ Summary:  ${summary.toString()}');
      print('╚════════════════════════════════════════════════════════════\n');
      
      expect(summary.amountsMasked, 3);
      expect(masked, isNot(contains('500')));
      expect(masked, isNot(contains('50')));
      expect(masked, isNot(contains('450')));
    });

    test('All examples summary', () {
      print('\n╔════════════════════════════════════════════════════════════');
      print('║ SMS TRAINING DATA EXPORT - MASKING SUMMARY');
      print('╠════════════════════════════════════════════════════════════');
      print('║');
      print('║ Data Masking Patterns:');
      print('║ ├─ Amounts:     Rs.1,234.56  →  Rs.X,XXX.XX');
      print('║ ├─ Accounts:    A/c XX1234   →  A/c XXXX');
      print('║ ├─ Dates:       19-Apr-26    →  <DATE>');
      print('║ └─ References:  Ref: 123456  →  <REF>');
      print('║');
      print('║ Export Formats Available:');
      print('║ ├─ JSON  (structured with metadata)');
      print('║ ├─ CSV   (tabular for analysis)');
      print('║ └─ TXT   (plain text)');
      print('║');
      print('║ Use Cases:');
      print('║ ├─ Training ML models');
      print('║ ├─ Testing & QA');
      print('║ ├─ Documentation examples');
      print('║ └─ Compliance audits');
      print('║');
      print('╚════════════════════════════════════════════════════════════\n');
    });
  });
}
