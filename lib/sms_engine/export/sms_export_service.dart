import 'dart:convert';
import 'dart:io';

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/export_models.dart';
import 'package:pocket_flow/models/transaction.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_data_masker.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_service.dart';

/// Export format for SMS training data
enum SmsExportFormat {
  json,
  csv,
  txt;
  
  String get fileExtension {
    switch (this) {
      case SmsExportFormat.json:
        return 'json';
      case SmsExportFormat.csv:
        return 'csv';
      case SmsExportFormat.txt:
        return 'txt';
    }
  }
}

/// Configuration for SMS export
class SmsExportConfig {
  const SmsExportConfig({
    this.maskSensitiveData = true,
    this.format = SmsExportFormat.json,
    this.includeMetadata = true,
    this.includeTransactionData = false,
    this.onlySuccessfullyParsed = false,
    this.startDate,
    this.endDate,
  });

  final bool maskSensitiveData;
  final SmsExportFormat format;
  final bool includeMetadata;
  final bool includeTransactionData;
  final bool onlySuccessfullyParsed;
  final DateTime? startDate;
  final DateTime? endDate;
  
  String getFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final masked = maskSensitiveData ? 'masked' : 'unmasked';
    return 'sms_training_${masked}_$timestamp.${format.fileExtension}';
  }
}

/// Result of SMS export
class SmsExportResult {
  const SmsExportResult({
    required this.success,
    required this.filePath,
    required this.messageCount,
    required this.fileSize,
    this.maskingSummary,
    this.error,
  });

  final bool success;
  final String filePath;
  final int messageCount;
  final int fileSize;
  final MaskingSummary? maskingSummary;
  final String? error;
  
  String get fileName => filePath.split('/').last.split('\\').last;
  
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Service for exporting SMS messages for training purposes
class SmsExportService {
  /// Export SMS messages directly from device (not just imported transactions)
  static Future<SmsExportResult> exportSmsMessages(SmsExportConfig config) async {
    try {
      // Check SMS permission
      if (!await SmsService.hasPermission()) {
        return const SmsExportResult(
          success: false,
          filePath: '',
          messageCount: 0,
          fileSize: 0,
          error: 'SMS permission not granted. Please enable SMS access.',
        );
      }

      // Read ALL SMS messages from device
      final query = SmsQuery();
      final List<SmsMessage> allMessages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );
      
      // Apply date filters
      var filteredMessages = allMessages;
      if (config.startDate != null) {
        filteredMessages = filteredMessages.where((m) {
          final date = m.date;
          return date != null && !date.isBefore(config.startDate!);
        }).toList();
      }
      if (config.endDate != null) {
        filteredMessages = filteredMessages.where((m) {
          final date = m.date;
          return date != null && !date.isAfter(config.endDate!);
        }).toList();
      }
      
      // Filter for financial SMS only (optional - can be made configurable)
      filteredMessages = filteredMessages.where((m) {
        final body = m.body ?? '';
        final sender = m.address ?? '';
        return _isFinancialSms(body, sender);
      }).toList();
      
      if (filteredMessages.isEmpty) {
        return const SmsExportResult(
          success: false,
          filePath: '',
          messageCount: 0,
          fileSize: 0,
          error: 'No SMS messages found matching criteria',
        );
      }
      
      // Prepare SMS data for export
      final smsData = <Map<String, dynamic>>[];
      int totalAmounts = 0, totalAccounts = 0, totalDates = 0, totalRefs = 0;
      
      for (final sms in filteredMessages) {
        final originalSms = sms.body ?? '';
        if (originalSms.isEmpty) continue;
        
        final maskedSms = config.maskSensitiveData 
            ? SmsDataMasker.maskSms(originalSms)
            : originalSms;
        
        final data = <String, dynamic>{
          'sms_text': maskedSms,
        };
        
        if (config.includeMetadata) {
          data['date'] = sms.date?.toIso8601String() ?? '';
          data['sender'] = sms.address ?? '';
          data['is_masked'] = config.maskSensitiveData;
        }
        
        if (config.maskSensitiveData) {
          final summary = SmsDataMasker.getMaskingSummary(originalSms, maskedSms);
          data['masking_summary'] = {
            'amounts_masked': summary.amountsMasked,
            'accounts_masked': summary.accountsMasked,
            'dates_masked': summary.datesMasked,
            'references_masked': summary.referencesMasked,
          };
          
          totalAmounts += summary.amountsMasked;
          totalAccounts += summary.accountsMasked;
          totalDates += summary.datesMasked;
          totalRefs += summary.referencesMasked;
        }
        
        smsData.add(data);
      }
      
      // Calculate overall masking summary
      MaskingSummary? overallSummary;
      if (config.maskSensitiveData) {
        overallSummary = MaskingSummary(
          originalLength: 0,
          maskedLength: 0,
          amountsMasked: totalAmounts,
          accountsMasked: totalAccounts,
          datesMasked: totalDates,
          referencesMasked: totalRefs,
        );
      }
      
      // Export to file
      final filePath = await _writeToFile(smsData, config);
      final fileSize = await File(filePath).length();
      
      return SmsExportResult(
        success: true,
        filePath: filePath,
        messageCount: smsData.length,
        fileSize: fileSize,
        maskingSummary: overallSummary,
      );
      
    } catch (e) {
      return SmsExportResult(
        success: false,
        filePath: '',
        messageCount: 0,
        fileSize: 0,
        error: e.toString(),
      );
    }
  }
  
  /// Check if an SMS is financial (bank/wallet transaction)
  static bool _isFinancialSms(String body, String sender) {
    final b = body.toLowerCase();
    final s = sender.toLowerCase();
    
    // Common financial keywords
    const keywords = [
      'debited', 'credited', 'transaction', 'balance', 'payment',
      'withdrawn', 'deposit', 'transfer', 'upi', 'neft', 'imps',
      'atm', 'pos', 'merchant', 'bank', 'card', 'account',
      'rs.', 'inr', 'amount', 'rupees',
    ];
    
    // Common financial senders
    const senders = [
      'bank', 'hdfc', 'icici', 'sbi', 'axis', 'kotak', 'paytm',
      'phonepe', 'gpay', 'amazonpay', 'mobikwik', 'freecharge',
      'bhim', 'cred', 'jupiter', 'fi', 'niyo',
    ];
    
    // Check body for keywords
    for (final keyword in keywords) {
      if (b.contains(keyword)) return true;
    }
    
    // Check sender
    for (final senderPattern in senders) {
      if (s.contains(senderPattern)) return true;
    }
    
    return false;
  }
  
  /// Get count of available financial SMS messages for export
  static Future<int> getAvailableMessageCount({DateTime? startDate, DateTime? endDate}) async {
    try {
      if (!await SmsService.hasPermission()) {
        return 0;
      }

      final query = SmsQuery();
      final List<SmsMessage> allMessages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );
      
      var filteredMessages = allMessages;
      
      // Apply date filters
      if (startDate != null) {
        filteredMessages = filteredMessages.where((m) {
          final date = m.date;
          return date != null && !date.isBefore(startDate);
        }).toList();
      }
      if (endDate != null) {
        filteredMessages = filteredMessages.where((m) {
          final date = m.date;
          return date != null && !date.isAfter(endDate);
        }).toList();
      }
      
      // Filter for financial SMS
      filteredMessages = filteredMessages.where((m) {
        final body = m.body ?? '';
        final sender = m.address ?? '';
        return _isFinancialSms(body, sender);
      }).toList();
      
      return filteredMessages.length;
    } catch (e) {
      return 0;
    }
  }
  
  /// Prepare SMS data for export (kept for backward compatibility with transaction export)
  static Map<String, dynamic> _prepareSmsData(Transaction transaction, SmsExportConfig config) {
    final originalSms = transaction.smsSource!;
    final maskedSms = config.maskSensitiveData 
        ? SmsDataMasker.maskSms(originalSms)
        : originalSms;
    
    final data = <String, dynamic>{
      'sms_text': maskedSms,
    };
    
    if (config.includeMetadata) {
      data['date'] = transaction.date.toIso8601String();
      data['source_type'] = transaction.sourceType;
      data['is_masked'] = config.maskSensitiveData;
    }
    
    if (config.includeTransactionData) {
      data['transaction'] = {
        'type': transaction.type,
        'amount': transaction.amount,
        'category': transaction.category,
        'merchant': transaction.merchant,
        'confidence_score': transaction.confidenceScore,
        'needs_review': transaction.needsReview,
      };
    }
    
    if (config.maskSensitiveData) {
      final summary = SmsDataMasker.getMaskingSummary(originalSms, maskedSms);
      data['masking_summary'] = {
        'amounts_masked': summary.amountsMasked,
        'accounts_masked': summary.accountsMasked,
        'dates_masked': summary.datesMasked,
        'references_masked': summary.referencesMasked,
      };
    }
    
    return data;
  }
  
  /// Write data to file based on format
  static Future<String> _writeToFile(List<Map<String, dynamic>> smsData, SmsExportConfig config) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = config.getFileName();
    final filePath = '${directory.path}/$fileName';
    
    switch (config.format) {
      case SmsExportFormat.json:
        await _writeJsonFile(smsData, filePath, config);
        break;
      case SmsExportFormat.csv:
        await _writeCsvFile(smsData, filePath, config);
        break;
      case SmsExportFormat.txt:
        await _writeTxtFile(smsData, filePath, config);
        break;
    }
    
    return filePath;
  }
  
  /// Write JSON format
  static Future<void> _writeJsonFile(List<Map<String, dynamic>> smsData, String filePath, SmsExportConfig config) async {
    final output = {
      'export_info': {
        'export_date': DateTime.now().toIso8601String(),
        'format': 'json',
        'masked': config.maskSensitiveData,
        'message_count': smsData.length,
      },
      'messages': smsData,
    };
    
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(output);
    await File(filePath).writeAsString(jsonString);
  }
  
  /// Write CSV format
  static Future<void> _writeCsvFile(List<Map<String, dynamic>> smsData, String filePath, SmsExportConfig config) async {
    final buffer = StringBuffer();
    
    // Header
    if (config.includeTransactionData) {
      buffer.writeln('sms_text,date,type,amount,category,merchant,confidence,needs_review');
    } else {
      buffer.writeln('sms_text,date');
    }
    
    // Rows
    for (final data in smsData) {
      final sms = _escapeCsv(data['sms_text'] as String);
      final date = config.includeMetadata ? (data['date'] as String?) ?? '' : '';
      
      if (config.includeTransactionData && data['transaction'] != null) {
        final txn = data['transaction'] as Map<String, dynamic>;
        buffer.writeln(
          '$sms,$date,${txn['type']},${txn['amount']},${txn['category']},${txn['merchant']},${txn['confidence_score']},${txn['needs_review']}'
        );
      } else {
        buffer.writeln('$sms,$date');
      }
    }
    
    await File(filePath).writeAsString(buffer.toString());
  }
  
  /// Write plain text format (one SMS per line)
  static Future<void> _writeTxtFile(List<Map<String, dynamic>> smsData, String filePath, SmsExportConfig config) async {
    final buffer = StringBuffer();
    
    if (config.includeMetadata) {
      buffer.writeln('# SMS Training Data Export');
      buffer.writeln('# Exported: ${DateTime.now()}');
      buffer.writeln('# Messages: ${smsData.length}');
      buffer.writeln('# Masked: ${config.maskSensitiveData}');
      buffer.writeln('#');
      buffer.writeln();
    }
    
    for (var i = 0; i < smsData.length; i++) {
      final data = smsData[i];
      if (config.includeMetadata) {
        buffer.writeln('# Message ${i + 1}');
        if (data['date'] != null) {
          buffer.writeln('# Date: ${data['date']}');
        }
      }
      buffer.writeln(data['sms_text']);
      buffer.writeln();
    }
    
    await File(filePath).writeAsString(buffer.toString());
  }
  
  /// Escape CSV field
  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
