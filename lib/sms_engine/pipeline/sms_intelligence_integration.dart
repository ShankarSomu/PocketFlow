import 'dart:convert';

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/pipeline/sms_pipeline_executor.dart';

/// SMS Intelligence Integration Service
/// Integrates the new SMS Intelligence Pipeline with the existing SMS reader
class SmsIntelligenceIntegration {
  static const _kIntelligenceEnabled = 'sms_intelligence_enabled';
  static const _kProcessedSmsIds = 'sms_intelligence_processed_ids';
  static const _kLastIntelligenceScan = 'sms_intelligence_last_scan';

  /// Check if SMS Intelligence is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIntelligenceEnabled) ?? false;
  }

  /// Enable/disable SMS Intelligence
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIntelligenceEnabled, value);
    
    if (value) {
      AppLogger.log(
        LogLevel.info,
        LogCategory.system,
        'sms_intelligence_enabled',
        detail: 'SMS Intelligence Engine activated',
      );
    }
  }

  /// Get processed SMS IDs (to avoid reprocessing)
  static Future<Set<int>> _getProcessedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProcessedSmsIds);
    if (raw == null) return {};
    
    final List decoded = jsonDecode(raw);
    return decoded.cast<int>().toSet();
  }

  /// Save processed SMS IDs
  static Future<void> _saveProcessedIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    // Keep only latest 10000 to avoid unbounded growth
    final trimmed = ids.length > 10000 
        ? ids.skip(ids.length - 10000).toSet() 
        : ids;
    await prefs.setString(_kProcessedSmsIds, jsonEncode(trimmed.toList()));
  }

  /// Get last scan timestamp
  static Future<DateTime?> getLastScan() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kLastIntelligenceScan);
    return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
  }

  /// Set last scan timestamp
  static Future<void> _setLastScan(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastIntelligenceScan, dt.millisecondsSinceEpoch);
  }

  /// Smart scan: Process new SMS messages through intelligence pipeline
  /// 
  /// Options:
  /// - force: Reprocess all messages (ignore processed IDs)
  /// - sinceDays: Look back N days (default: 30)
  /// - limit: Max messages to process (default: 1000)
  static Future<SmsIntelligenceResult> smartScan({
    bool force = false,
    int sinceDays = 30,
    int? limit,
  }) async {
    final enabled = await isEnabled();
    if (!enabled && !force) {
      return SmsIntelligenceResult(
        error: 'SMS Intelligence is disabled. Enable it in settings.',
      );
    }

    AppLogger.log(
      LogLevel.info,
      LogCategory.system,
      'sms_intelligence_scan_start',
      detail: 'force=$force, sinceDays=$sinceDays',
    );

    final cutoff = DateTime.now().subtract(Duration(days: sinceDays));
    final processedIds = force ? <int>{} : await _getProcessedIds();

    int processed = 0;
    int transactionsCreated = 0;
    int pendingActionsCreated = 0;
    int accountCandidatesCreated = 0;
    int skipped = 0;
    int errors = 0;
    final List<String> errorMessages = [];

    try {
      // Read SMS from inbox
      final query = SmsQuery();
      final List<SmsMessage> allMessages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );

      final newIds = <int>{};

      for (final sms in allMessages) {
        try {
          final id = sms.id;
          if (id == null) continue;

          // Skip already processed (unless force)
          if (!force && processedIds.contains(id)) {
            skipped++;
            continue;
          }

          // Time range filter
          final date = sms.date ?? DateTime.now();
          if (date.isBefore(cutoff)) {
            skipped++;
            continue;
          }

          // Process through pipeline
          final result = await SmsPipelineExecutor.processSms(
            senderAddress: sms.sender ?? 'UNKNOWN',
            messageBody: sms.body ?? '',
            receivedAt: date,
          );

          processed++;
          newIds.add(id);

          // Track results
          if (result.isTransaction) {
            transactionsCreated++;
            AppLogger.log(
              LogLevel.info,
              LogCategory.system,
              'sms_intelligence_transaction',
              detail: 'id=${result.transactionId}, confidence=${result.confidence.toStringAsFixed(2)}',
            );
          } else if (result.isPending) {
            pendingActionsCreated++;
            AppLogger.log(
              LogLevel.info,
              LogCategory.system,
              'sms_intelligence_pending',
              detail: 'id=${result.pendingActionId}, type=${result.smsType}',
            );
          }

          // Check for account candidates (from resolution step)
          // Note: This is indirectly created, tracked via pending actions

          // Respect limit
          if (limit != null && processed >= limit) break;

        } catch (e) {
          errors++;
          errorMessages.add('SMS ${sms.id}: $e');
          AppLogger.err('sms_intelligence_process_sms', e);
        }
      }

      // Save processed IDs
      processedIds.addAll(newIds);
      await _saveProcessedIds(processedIds);
      await _setLastScan(DateTime.now());

      // Get statistics
      final stats = await SmsPipelineExecutor.getStatistics();
      accountCandidatesCreated = stats['account_candidates'] as int;

      AppLogger.log(
        LogLevel.info,
        LogCategory.system,
        'sms_intelligence_scan_complete',
        detail: 'processed=$processed, transactions=$transactionsCreated, pending=$pendingActionsCreated',
      );

      return SmsIntelligenceResult(
        processed: processed,
        transactionsCreated: transactionsCreated,
        pendingActionsCreated: pendingActionsCreated,
        accountCandidatesCreated: accountCandidatesCreated,
        skipped: skipped,
        errors: errors,
        errorMessages: errorMessages,
      );

    } catch (e) {
      AppLogger.err('sms_intelligence_scan', e);
      return SmsIntelligenceResult(
        error: 'Scan failed: $e',
        errors: errors,
      );
    }
  }

  /// Process a single SMS message (for testing or manual trigger)
  static Future<SmsProcessingResult> processSingleSms({
    required String sender,
    required String body,
    DateTime? receivedAt,
  }) async {
    return SmsPipelineExecutor.processSms(
      senderAddress: sender,
      messageBody: body,
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  /// Get quick statistics
  static Future<Map<String, dynamic>> getQuickStats() async {
    final stats = await SmsPipelineExecutor.getStatistics();
    final lastScan = await getLastScan();
    final enabled = await isEnabled();

    return {
      'enabled': enabled,
      'last_scan': lastScan?.toIso8601String(),
      'sms_transactions': stats['sms_transactions'],
      'pending_actions': stats['pending_actions'],
      'account_candidates': stats['account_candidates'],
    };
  }
}

/// SMS Intelligence Scan Result
class SmsIntelligenceResult {

  SmsIntelligenceResult({
    this.processed = 0,
    this.transactionsCreated = 0,
    this.pendingActionsCreated = 0,
    this.accountCandidatesCreated = 0,
    this.skipped = 0,
    this.errors = 0,
    this.errorMessages = const [],
    this.error,
  });
  final int processed;
  final int transactionsCreated;
  final int pendingActionsCreated;
  final int accountCandidatesCreated;
  final int skipped;
  final int errors;
  final List<String> errorMessages;
  final String? error;

  bool get hasError => error != null;
  bool get success => !hasError;

  @override
  String toString() {
    if (hasError) return 'Error: $error';
    
    return '''
SMS Intelligence Scan Results:
✅ Processed: $processed messages
📊 Transactions: $transactionsCreated created
⏳ Pending Actions: $pendingActionsCreated (need review)
🏦 New Accounts: $accountCandidatesCreated detected
⏭️ Skipped: $skipped
❌ Errors: $errors
''';
  }

  Map<String, dynamic> toJson() => {
    'processed': processed,
    'transactions_created': transactionsCreated,
    'pending_actions_created': pendingActionsCreated,
    'account_candidates_created': accountCandidatesCreated,
    'skipped': skipped,
    'errors': errors,
    'error_messages': errorMessages,
    'error': error,
  };
}
