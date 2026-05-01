import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/services/advanced_sms_parser.dart';

/// Verification test for rule-based evaluation (no hardcoded patterns)
/// Ensures Step 3 linguistic analysis drives all classification decisions
void main() {
  group('Rule-Based Classification (No Patterns)', () {
    test('Transaction with balance info - should detect transaction verb first', () {
      final result = AdvancedSmsParser.parse(
        'Rs.500 debited from A/c XX1234. Available balance: Rs.12,500',
        senderId: 'HDFCBK',
      );
      
      expect(result.isTransaction, true, 
        reason: 'Should identify as transaction - "debited" verb found before balance pattern');
      expect(result.transactionType?.name, 'debit');
      expect(result.amount, 500.0);
      expect(result.confidenceScore, greaterThan(0.9));
    });

    test('Balance notification only - no transaction verb', () {
      final result = AdvancedSmsParser.parse(
        'Your balance is Rs.25,430.50. Thank you for banking with us.',
        senderId: 'HDFCBK',
      );
      
      expect(result.isTransaction, false,
        reason: 'Should reject - no transaction verb found');
      expect(result.transactionType?.name, 'unknown');
    });

    test('Bill statement with "is due" - should reject', () {
      final result = AdvancedSmsParser.parse(
        'You have a new statement for \$465.33. Your payment is due on May 1st, 2026.',
        senderId: 'UCDAVIS',
      );
      
      expect(result.isTransaction, false,
        reason: 'Should reject - "is due" indicates future obligation, no transaction verb');
      expect(result.transactionType?.name, 'unknown');
    });

    test('OTP message - should reject', () {
      final result = AdvancedSmsParser.parse(
        'Your OTP for login is 123456. Valid for 10 minutes.',
        senderId: 'HDFCBK',
      );
      
      expect(result.isTransaction, false,
        reason: 'Should reject - no transaction verb found');
      expect(result.transactionType?.name, 'unknown');
    });

    test('Real transaction - debited verb', () {
      final result = AdvancedSmsParser.parse(
        'Rs.1,250 debited from A/c XX5678 at Amazon on 19-Apr-26',
        senderId: 'HDFCBK',
      );
      
      expect(result.isTransaction, true,
        reason: 'Should accept - "debited" verb found');
      expect(result.transactionType?.name, 'debit');
      expect(result.amount, 1250.0);
    });

    test('Real transaction - credited verb', () {
      final result = AdvancedSmsParser.parse(
        'Rs.5,000 credited to your account XX9876 on 19-04-2026',
        senderId: 'SBIINB',
      );
      
      expect(result.isTransaction, true,
        reason: 'Should accept - "credited" verb found');
      expect(result.transactionType?.name, 'credit');
      expect(result.amount, 5000.0);
    });

    test('Alert with threshold - no transaction verb', () {
      final result = AdvancedSmsParser.parse(
        'Your bal plus pending transactions at card 7330 has exceeded 75% of your credit limit',
        senderId: 'CITI',
      );
      
      expect(result.isTransaction, false,
        reason: 'Should reject - no transaction verb, only alert info');
      expect(result.transactionType?.name, 'unknown');
    });

    test('Statement balance - no transaction verb', () {
      final result = AdvancedSmsParser.parse(
        'Your statement balance is \$2,345.67. Due date: May 15, 2026',
        senderId: 'CHASE',
      );
      
      expect(result.isTransaction, false,
        reason: 'Should reject - no transaction verb, only balance reporting');
      expect(result.transactionType?.name, 'unknown');
    });
  });

  group('Priority-Based Rules Verification', () {
    test('Step 3 checks transaction verbs FIRST (priority)', () {
      // This message has both "debited" (transaction verb) and "available balance" (reporting)
      // The transaction verb should be checked first and should win
      final result = AdvancedSmsParser.parse(
        'Rs.2,500.00 debited from A/c XX7890 on 19-Apr-26. Balance: Rs.12,345.00',
        senderId: 'AXISBK',
      );
      
      expect(result.isTransaction, true,
        reason: 'Transaction verb (debited) should override balance reporting');
      expect(result.transactionType?.name, 'debit');
      expect(result.amount, 2500.0);
      expect(result.confidenceScore, greaterThan(0.9));
    });

    test('No transaction verb - negative context wins', () {
      // This message has "payment is due" (future obligation) and no transaction verb
      // Negative context should cause rejection
      final result = AdvancedSmsParser.parse(
        'Your credit card payment is due on May 5th. Amount: \$1,234.56',
        senderId: 'CHASE',
      );
      
      expect(result.isTransaction, false,
        reason: 'No transaction verb + "is due" pattern = not a transaction');
      expect(result.transactionType?.name, 'unknown');
    });
  });

  group('No Pattern Matching in Step 1', () {
    test('Step 1 should not use hardcoded patterns for classification', () {
      // This would have matched patterns in old system, but now should rely on Step 3
      final result = AdvancedSmsParser.parse(
        'Rs.1,000 debited from account ending 1234 at Starbucks',
        senderId: 'HDFCBK',
      );
      
      // Verify it's classified as transaction via Step 3's verb detection, not Step 1 patterns
      expect(result.isTransaction, true);
      expect(result.transactionType?.name, 'debit');
      expect(result.amount, 1000.0);
    });
  });
}
