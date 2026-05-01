import 'dart:io';
import 'package:pocket_flow/services/advanced_sms_parser.dart';
import 'package:pocket_flow/models/sms_transaction_result.dart';

/// Comprehensive SMS Parser Accuracy Test
/// Tests all SMS messages from sms-text-raw.txt
void main() {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║           SMS PARSER ACCURACY TEST - REAL DATA                    ║');
  print('╚═══════════════════════════════════════════════════════════════════╝\n');

  // Read SMS messages from file
  final file = File('test/sms-text-raw.txt');
  if (!file.existsSync()) {
    print('❌ Error: test/sms-text-raw.txt not found');
    return;
  }

  final lines = file.readAsLinesSync();
  final smsMessages = <String>[];
  
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty && !trimmed.startsWith('//')) {
      smsMessages.add(trimmed);
    }
  }

  print('📊 Total SMS messages: ${smsMessages.length}\n');
  print('═' * 70);
  print('ANALYZING MESSAGES...');
  print('═' * 70);
  print('');

  // Statistics
  int totalMessages = 0;
  int detectedTransactions = 0;
  int balanceAlerts = 0;
  int thresholdAlerts = 0;
  int paymentReminders = 0;
  int nonFinancial = 0;
  int highConfidence = 0; // >= 90%
  int mediumConfidence = 0; // 70-89%
  int lowConfidence = 0; // < 70%

  // Categories
  final transactions = <Map<String, dynamic>>[];
  final balanceOnly = <Map<String, dynamic>>[];
  final alerts = <Map<String, dynamic>>[];
  final reminders = <Map<String, dynamic>>[];
  final other = <Map<String, dynamic>>[];

  // Process each SMS
  for (int i = 0; i < smsMessages.length; i++) {
    final sms = smsMessages[i];
    totalMessages++;

    // Detect sender from SMS content
    String? sender;
    if (sms.startsWith('Citi')) sender = 'Citi';
    else if (sms.startsWith('BofA')) sender = 'BofA';
    else if (sms.startsWith('Capital One')) sender = 'CapitalOne';
    else if (sms.startsWith('PG&E')) sender = 'PGE';
    else if (sms.startsWith('Allstate')) sender = 'Allstate';
    else if (sms.startsWith('UC Davis')) sender = 'UCDavis';
    else if (sms.contains('Xfinity')) sender = 'Xfinity';
    else if (sms.contains('Flex:')) sender = 'Flex';

    final result = AdvancedSmsParser.parse(sms, senderId: sender);

    final info = {
      'index': i + 1,
      'sms': sms.length > 100 ? sms.substring(0, 97) + '...' : sms,
      'fullSms': sms,
      'sender': sender ?? 'Unknown',
      'isTransaction': result.isTransaction,
      'type': result.transactionType.name,
      'amount': result.amount,
      'merchant': result.merchant,
      'bank': result.bank,
      'account': result.accountIdentifier,
      'confidence': result.confidenceScore,
      'region': result.region?.name ?? 'unknown',
      'suggestions': result.improvementSuggestions.length,
    };

    // Categorize
    if (result.isTransaction) {
      detectedTransactions++;
      transactions.add(info);
      
      if (result.confidenceScore >= 0.9) highConfidence++;
      else if (result.confidenceScore >= 0.7) mediumConfidence++;
      else lowConfidence++;
    } else {
      // Analyze why it's not a transaction
      final lowerSms = sms.toLowerCase();
      
      if (lowerSms.contains('available balance') || 
          lowerSms.contains('bal is') ||
          lowerSms.contains('balance of')) {
        balanceAlerts++;
        balanceOnly.add(info);
      } else if (lowerSms.contains('exceeded amount') || 
                 lowerSms.contains('exceeded the amount') ||
                 lowerSms.contains('exceeded limit')) {
        thresholdAlerts++;
        alerts.add(info);
      } else if (lowerSms.contains('payment is due') || 
                 lowerSms.contains('due by') ||
                 lowerSms.contains('scheduled for') ||
                 lowerSms.contains('will be processed')) {
        paymentReminders++;
        reminders.add(info);
      } else {
        nonFinancial++;
        other.add(info);
      }
    }
  }

  // Print Summary
  print('');
  print('═' * 70);
  print('SUMMARY STATISTICS');
  print('═' * 70);
  print('');
  print('📈 Total Messages Analyzed: $totalMessages');
  print('');
  print('✅ DETECTED TRANSACTIONS: $detectedTransactions (${(detectedTransactions / totalMessages * 100).toStringAsFixed(1)}%)');
  print('   ├─ High Confidence (≥90%): $highConfidence');
  print('   ├─ Medium Confidence (70-89%): $mediumConfidence');
  print('   └─ Low Confidence (<70%): $lowConfidence');
  print('');
  print('❌ NON-TRANSACTIONS: ${totalMessages - detectedTransactions} (${((totalMessages - detectedTransactions) / totalMessages * 100).toStringAsFixed(1)}%)');
  print('   ├─ Balance Alerts: $balanceAlerts');
  print('   ├─ Threshold Alerts: $thresholdAlerts');
  print('   ├─ Payment Reminders: $paymentReminders');
  print('   └─ Other/Non-Financial: $nonFinancial');
  print('');

  // Show detailed breakdown
  print('═' * 70);
  print('DETECTED TRANSACTIONS (${transactions.length})');
  print('═' * 70);
  print('');
  
  for (final tx in transactions) {
    final confidence = (tx['confidence'] as double) * 100;
    final confidenceIcon = confidence >= 90 ? '🟢' : confidence >= 70 ? '🟡' : '🔴';
    
    print('${confidenceIcon} #${tx['index']} [$confidence%] ${tx['type']}');
    print('   Amount: \$${tx['amount']?.toStringAsFixed(2) ?? 'N/A'}');
    print('   Merchant: ${tx['merchant'] ?? 'N/A'}');
    print('   Bank: ${tx['bank'] ?? 'N/A'} | Account: ${tx['account'] ?? 'N/A'}');
    print('   SMS: ${tx['sms']}');
    if (tx['suggestions'] > 0) {
      print('   💡 Suggestions: ${tx['suggestions']}');
    }
    print('');
  }

  if (balanceOnly.isNotEmpty) {
    print('═' * 70);
    print('BALANCE ALERTS (${balanceOnly.length}) - Correctly Ignored');
    print('═' * 70);
    print('');
    for (final msg in balanceOnly.take(5)) {
      print('⚪ #${msg['index']}: ${msg['sms']}');
    }
    if (balanceOnly.length > 5) {
      print('   ... and ${balanceOnly.length - 5} more balance alerts');
    }
    print('');
  }

  if (alerts.isNotEmpty) {
    print('═' * 70);
    print('THRESHOLD ALERTS (${alerts.length}) - Correctly Ignored');
    print('═' * 70);
    print('');
    for (final msg in alerts.take(5)) {
      print('⚪ #${msg['index']}: ${msg['sms']}');
    }
    if (alerts.length > 5) {
      print('   ... and ${alerts.length - 5} more threshold alerts');
    }
    print('');
  }

  if (reminders.isNotEmpty) {
    print('═' * 70);
    print('PAYMENT REMINDERS (${reminders.length}) - Correctly Ignored');
    print('═' * 70);
    print('');
    for (final msg in reminders.take(5)) {
      print('⚪ #${msg['index']}: ${msg['sms']}');
    }
    if (reminders.length > 5) {
      print('   ... and ${reminders.length - 5} more reminders');
    }
    print('');
  }

  if (other.isNotEmpty) {
    print('═' * 70);
    print('OTHER NON-FINANCIAL (${other.length})');
    print('═' * 70);
    print('');
    for (final msg in other) {
      print('⚪ #${msg['index']}: ${msg['sms']}');
    }
    print('');
  }

  // Accuracy Assessment
  print('═' * 70);
  print('ACCURACY ASSESSMENT');
  print('═' * 70);
  print('');
  
  // Expected transactions (manual review)
  final expectedTransactionKeywords = [
    'transaction was made',
    'payment posted',
    'direct deposit',
    'electronic draft',
    'money transfer',
    'charge made',
    'credit from',
    'sent you',
  ];

  int expectedTransactions = 0;
  for (final sms in smsMessages) {
    final lowerSms = sms.toLowerCase();
    for (final keyword in expectedTransactionKeywords) {
      if (lowerSms.contains(keyword)) {
        expectedTransactions++;
        break;
      }
    }
  }

  final accuracy = detectedTransactions / expectedTransactions * 100;
  print('📊 Expected Transactions (by keywords): $expectedTransactions');
  print('📊 Detected Transactions: $detectedTransactions');
  print('📊 Detection Rate: ${accuracy.toStringAsFixed(1)}%');
  print('');
  
  if (accuracy >= 95) {
    print('✅ EXCELLENT - Parser is highly accurate!');
  } else if (accuracy >= 85) {
    print('🟢 GOOD - Parser is performing well');
  } else if (accuracy >= 75) {
    print('🟡 FAIR - Some improvements needed');
  } else {
    print('🔴 NEEDS IMPROVEMENT - Review parser logic');
  }
  print('');

  // Transaction types breakdown
  print('═' * 70);
  print('TRANSACTION TYPE BREAKDOWN');
  print('═' * 70);
  print('');
  
  final typeCount = <String, int>{};
  for (final tx in transactions) {
    final type = tx['type'] as String;
    typeCount[type] = (typeCount[type] ?? 0) + 1;
  }
  
  typeCount.forEach((type, count) {
    print('   $type: $count');
  });
  print('');

  print('✨ Analysis complete!\n');
}
