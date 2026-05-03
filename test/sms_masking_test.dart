import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_data_masker.dart';

void main() {
  group('SMS Data Masker', () {
    test('Should mask amounts with currency symbols', () {
      final original = 'Rs.500 debited from A/c XX1234';
      final masked = SmsDataMasker.maskSms(original);
      
      expect(masked, contains('Rs.XXX'));
      expect(masked, isNot(contains('500')));
      expect(masked, isNot(contains('Rs.500')));
    });

    test('Should mask account numbers', () {
      final original = 'Rs.500 debited from A/c XX1234';
      final masked = SmsDataMasker.maskSms(original);
      
      expect(masked, contains('XXXX'));
      expect(masked, isNot(contains('1234')));
    });

    test('Should mask dates in DD-MMM-YY format', () {
      final original = 'Transaction on 19-Apr-26 at Starbucks';
      final masked = SmsDataMasker.maskSms(original);
      
      expect(masked, contains('<DATE>'));
      expect(masked, isNot(contains('19-Apr-26')));
    });

    test('Should mask reference IDs', () {
      final original = 'UPI Ref: 123456789012';
      final masked = SmsDataMasker.maskSms(original);
      
      expect(masked, contains('<REF>'));
      expect(masked, isNot(contains('123456789012')));
    });

    test('Should mask complete real-world SMS', () {
      final original = 'Rs.1,250.00 debited from A/c XX5678 via UPI to merchant@paytm on 19-Apr-26. UPI Ref: 123456789012. HDFC Bank';
      final masked = SmsDataMasker.maskSms(original);
      
      print('Original: $original');
      print('Masked:   $masked');
      
      expect(masked, contains('Rs.X,XXX.XX'));
      expect(masked, contains('XXXX'));
      expect(masked, contains('<DATE>'));
      expect(masked, contains('<REF>'));
      
      // Should not contain original sensitive data
      expect(masked, isNot(contains('1,250')));
      expect(masked, isNot(contains('5678')));
      expect(masked, isNot(contains('19-Apr-26')));
      expect(masked, isNot(contains('123456789012')));
    });

    test('Should mask Capital One balance alert', () {
      final original = 'Capital One Alert: Your Quicksilver Credit Card…(7330) bal is \$0.00 as of April 19, 2026.';
      final masked = SmsDataMasker.maskSms(original);
      
      print('Original: $original');
      print('Masked:   $masked');
      
      expect(masked, contains('\$X.XX'));
      expect(masked, contains('XXXX'));
      expect(masked, contains('<DATE>'));
    });

    test('Should mask UC Davis bill statement', () {
      final original = 'UC Davis Health: You have a new statement for \$465.33. Your payment is due by May 5.';
      final masked = SmsDataMasker.maskSms(original);
      
      print('Original: $original');
      print('Masked:   $masked');
      
      expect(masked, contains('\$XXX.XX'));
      expect(masked, isNot(contains('465.33')));
    });

    test('Should mask Citi balance alert with card number', () {
      final original = 'Citi Alert: Bal plus pending transactions at card 7330 has exceeded 75% of your credit limit';
      final masked = SmsDataMasker.maskSms(original);
      
      print('Original: $original');
      print('Masked:   $masked');
      
      expect(masked, contains('XXXX'));
      expect(masked, isNot(contains('7330')));
    });

    test('Should mask transaction with balance info', () {
      final original = 'Rs.2,500.00 debited from A/c XX7890 on 19-Apr-26. Balance: Rs.12,345.00';
      final masked = SmsDataMasker.maskSms(original);
      
      print('Original: $original');
      print('Masked:   $masked');
      
      expect(masked, contains('Rs.X,XXX.XX'));
      expect(masked, contains('XXXX'));
      expect(masked, contains('<DATE>'));
      
      // Should mask both the transaction amount and balance
      expect(masked, isNot(contains('2,500')));
      expect(masked, isNot(contains('12,345')));
    });

    test('Should get masking summary', () {
      final original = 'Rs.500 debited from A/c XX1234 on 19-Apr-26. UPI Ref: 123456789012';
      final masked = SmsDataMasker.maskSms(original);
      final summary = SmsDataMasker.getMaskingSummary(original, masked);
      
      print('Summary: $summary');
      
      expect(summary.amountsMasked, greaterThan(0));
      expect(summary.accountsMasked, greaterThan(0));
      expect(summary.datesMasked, greaterThan(0));
      expect(summary.referencesMasked, greaterThan(0));
      expect(summary.hasMaskedData, isTrue);
      expect(summary.totalMasked, greaterThan(0));
    });

    test('Should mask multiple amounts in same message', () {
      final original = 'Rs.500 debited and Rs.50 cashback credited. Net: Rs.450 debited.';
      final masked = SmsDataMasker.maskSms(original);
      
      print('Original: $original');
      print('Masked:   $masked');
      
      // Should mask all three amounts with X's
      expect(masked, contains('Rs.XXX'));
      expect(masked, contains('Rs.XX'));
      expect(masked, contains('Rs.XXX'));
      expect(masked, isNot(contains('500')));
      expect(masked, isNot(contains('50')));
      expect(masked, isNot(contains('450')));
    });

    test('Should mask various account number formats', () {
      final testCases = [
        'A/c XX1234',
        'Account xx5678',
        'Card ****9012',
        'card ending in 3456',
        'ending 7890',
      ];
      
      for (final testCase in testCases) {
        final masked = SmsDataMasker.maskSms(testCase);
        print('$testCase → $masked');
        expect(masked, contains('XXXX'));
      }
    });

    test('Should mask various date formats', () {
      final testCases = [
        '19-Apr-26',
        '19/04/2026',
        '19-04-26',
        'April 19, 2026',
        'on 19-04-2026',
        'as of April 19, 2026',
      ];
      
      for (final testCase in testCases) {
        final masked = SmsDataMasker.maskSms(testCase);
        print('$testCase → $masked');
        expect(masked, contains('<DATE>'));
      }
    });
  });
}
