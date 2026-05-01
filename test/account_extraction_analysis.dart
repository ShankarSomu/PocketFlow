import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/db/database.dart';
import '../lib/services/account_extraction_service.dart';
import '../lib/models/sms_transaction_result.dart';

/// Test script to analyze SMS training data and show account extraction results
void main() {
  setUpAll(() async {
    // Initialize database
    await AppDatabase.db();
  });

  test('Analyze SMS Training Data - Account Extraction', () async {
    // Load SMS training data
    final file = File('test/SMS Training Data.json');
    if (!file.existsSync()) {
      print('❌ SMS Training Data.json not found');
      return;
    }

    final jsonContent = await file.readAsString();
    final data = json.decode(jsonContent) as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>;
    
    print('\n📊 SMS Training Data Analysis');
    print('=' * 80);
    print('Total messages: ${messages.length}');
    print('Analyzing account extraction...\n');

    // Statistics
    final bankCounts = <String, int>{};
    final identifierPatterns = <String, int>{};
    final regionCounts = <String, int>{};
    int extractedBoth = 0;
    int extractedBankOnly = 0;
    int extractedIdentifierOnly = 0;
    int extractedNeither = 0;

    // Analyze first 100 messages for detailed output
    final sampleSize = 100;
    print('📋 Sample Analysis (first $sampleSize messages):');
    print('-' * 80);
    
    for (int i = 0; i < messages.length && i < sampleSize; i++) {
      final msg = messages[i] as Map<String, dynamic>;
      final smsText = msg['sms_text'] as String;
      final sender = msg['sender'] as String;
      
      // Detect region (simplified - based on sender and keywords)
      RegionEnum region = RegionEnum.unknown;
      if (sender.contains('CITI') || sender.contains('BOFA') || 
          sender.contains('CHASE') || smsText.contains(r'$')) {
        region = RegionEnum.us;
      } else if (sender.contains('HDFC') || sender.contains('ICICI') || 
                 sender.contains('SBI') || smsText.contains('Rs')) {
        region = RegionEnum.india;
      }
      
      // Extract identity
      final identity = await AccountExtractionService.extractIdentity(
        smsText: smsText,
        region: region,
        senderId: sender,
      );
      
      // Count statistics
      if (identity.bank != null) {
        bankCounts[identity.bank!] = (bankCounts[identity.bank!] ?? 0) + 1;
      }
      
      if (identity.accountIdentifier != null) {
        // Categorize pattern type
        final id = identity.accountIdentifier!;
        String patternType;
        if (id.startsWith('****')) {
          patternType = '****XXXX format';
        } else if (id.startsWith('XX') || id.startsWith('xx')) {
          patternType = 'XXNNNN format';
        } else if (id.length == 4 && int.tryParse(id) != null) {
          patternType = 'Last 4 digits';
        } else {
          patternType = 'Other format';
        }
        identifierPatterns[patternType] = (identifierPatterns[patternType] ?? 0) + 1;
      }
      
      regionCounts[region.name] = (regionCounts[region.name] ?? 0) + 1;
      
      if (identity.bank != null && identity.accountIdentifier != null) {
        extractedBoth++;
      } else if (identity.bank != null) {
        extractedBankOnly++;
      } else if (identity.accountIdentifier != null) {
        extractedIdentifierOnly++;
      } else {
        extractedNeither++;
      }
      
      // Print detailed output for sample
      if (i < 20) {  // Show first 20 in detail
        print('\n${i + 1}. SMS: "${smsText.substring(0, smsText.length.clamp(0, 70))}..."');
        print('   Sender: $sender | Region: ${region.name}');
        if (identity.bank != null) {
          print('   ✅ Bank: ${identity.bank} (confidence: ${(identity.bankConfidence * 100).toStringAsFixed(0)}%)');
        } else {
          print('   ❌ Bank: Not detected');
        }
        if (identity.accountIdentifier != null) {
          print('   ✅ Account#: ${identity.accountIdentifier} (confidence: ${(identity.identifierConfidence * 100).toStringAsFixed(0)}%)');
        } else {
          print('   ❌ Account#: Not detected');
        }
      }
    }
    
    // Process remaining messages for statistics only
    if (messages.length > sampleSize) {
      print('\n\n⏳ Processing remaining ${messages.length - sampleSize} messages...');
      
      for (int i = sampleSize; i < messages.length; i++) {
        if (i % 1000 == 0) {
          print('   Processed $i / ${messages.length}...');
        }
        
        final msg = messages[i] as Map<String, dynamic>;
        final smsText = msg['sms_text'] as String;
        final sender = msg['sender'] as String;
        
        RegionEnum region = RegionEnum.unknown;
        if (sender.contains('CITI') || sender.contains('BOFA') || 
            sender.contains('CHASE') || smsText.contains(r'$')) {
          region = RegionEnum.us;
        } else if (sender.contains('HDFC') || sender.contains('ICICI') || 
                   sender.contains('SBI') || smsText.contains('Rs')) {
          region = RegionEnum.india;
        }
        
        final identity = await AccountExtractionService.extractIdentity(
          smsText: smsText,
          region: region,
          senderId: sender,
        );
        
        if (identity.bank != null) {
          bankCounts[identity.bank!] = (bankCounts[identity.bank!] ?? 0) + 1;
        }
        
        if (identity.accountIdentifier != null) {
          final id = identity.accountIdentifier!;
          String patternType;
          if (id.startsWith('****')) {
            patternType = '****XXXX format';
          } else if (id.startsWith('XX') || id.startsWith('xx')) {
            patternType = 'XXNNNN format';
          } else if (id.length == 4 && int.tryParse(id) != null) {
            patternType = 'Last 4 digits';
          } else {
            patternType = 'Other format';
          }
          identifierPatterns[patternType] = (identifierPatterns[patternType] ?? 0) + 1;
        }
        
        regionCounts[region.name] = (regionCounts[region.name] ?? 0) + 1;
        
        if (identity.bank != null && identity.accountIdentifier != null) {
          extractedBoth++;
        } else if (identity.bank != null) {
          extractedBankOnly++;
        } else if (identity.accountIdentifier != null) {
          extractedIdentifierOnly++;
        } else {
          extractedNeither++;
        }
      }
    }
    
    // Print summary
    print('\n\n' + '=' * 80);
    print('📊 EXTRACTION SUMMARY');
    print('=' * 80);
    
    print('\n🎯 Extraction Success Rate:');
    final total = messages.length;
    print('   Both bank & account#: $extractedBoth (${(extractedBoth / total * 100).toStringAsFixed(1)}%)');
    print('   Bank only:            $extractedBankOnly (${(extractedBankOnly / total * 100).toStringAsFixed(1)}%)');
    print('   Account# only:        $extractedIdentifierOnly (${(extractedIdentifierOnly / total * 100).toStringAsFixed(1)}%)');
    print('   Neither extracted:    $extractedNeither (${(extractedNeither / total * 100).toStringAsFixed(1)}%)');
    
    print('\n🏦 Banks Detected:');
    final sortedBanks = bankCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedBanks) {
      print('   ${entry.key}: ${entry.value} (${(entry.value / total * 100).toStringAsFixed(1)}%)');
    }
    
    print('\n🔢 Account Identifier Patterns:');
    final sortedPatterns = identifierPatterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedPatterns) {
      print('   ${entry.key}: ${entry.value}');
    }
    
    print('\n🌍 Region Distribution:');
    for (final entry in regionCounts.entries) {
      print('   ${entry.key}: ${entry.value} (${(entry.value / total * 100).toStringAsFixed(1)}%)');
    }
    
    print('\n' + '=' * 80);
    print('✅ Analysis complete!');
    print('=' * 80 + '\n');
  });
}
