import 'dart:convert';
import 'package:crypto/crypto.dart' show md5;
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/sms_engine/models/sms_types.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/services/chat_parser.dart';
import 'package:pocket_flow/services/recurring_pattern_engine.dart';
import 'package:pocket_flow/sms_engine/pipeline/sms_pipeline_executor.dart';
import 'package:pocket_flow/sms_engine/_ml_deprecated/sms_classifier_service.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_classification_service.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_entity_extractor.dart';
import 'package:pocket_flow/sms_engine/account/sms_account_resolver.dart';
import 'package:pocket_flow/services/privacy_guard.dart';

// ── Internal Classes ──────────────────────────────────────────────────────────

/// Holds parsed SMS data for batch processing
class _ParsedSmsData {
  final model.Transaction transaction;
  final String smsBody;
  final DateTime smsDate;
  final int smsId;

  _ParsedSmsData({
    required this.transaction,
    required this.smsBody,
    required this.smsDate,
    required this.smsId,
  });
}

// ── SMS Scan Settings Keys ────────────────────────────────────────────────────
const _kSmsEnabled = 'sms_enabled';
const _kSmsScanRange = 'sms_scan_range';       // 'all' | '6m' | '3m' | '1m' | '1w' | 'custom'
const _kSmsLastScan = 'sms_last_scan';
const _kSmsProcessed = 'sms_processed_ids';    // JSON set of processed SMS IDs
const _kSmsCustomStartDate = 'sms_custom_start_date';
const _kSmsCustomEndDate = 'sms_custom_end_date';
const _kSmsLastScanResult = 'sms_last_scan_result'; // JSON of last scan result

/// How far back to look when scanning SMS.
enum SmsScanRange {
  allTime('all', 'All messages'),
  sixMonths('6m', 'Last 6 months'),
  threeMonths('3m', 'Last 3 months'),
  oneMonth('1m', 'Last 1 month'),
  oneWeek('1w', 'Last 1 week'),
  customRange('custom', 'Custom range');

  final String key;
  final String label;
  const SmsScanRange(this.key, this.label);

  static SmsScanRange fromKey(String k) =>
      SmsScanRange.values.firstWhere((e) => e.key == k, orElse: () => SmsScanRange.oneMonth);

  DateTime? get cutoff {
    final now = DateTime.now();
    switch (this) {
      case SmsScanRange.allTime:
        return null;
      case SmsScanRange.sixMonths:
        return now.subtract(const Duration(days: 183));
      case SmsScanRange.threeMonths:
        return now.subtract(const Duration(days: 91));
      case SmsScanRange.oneMonth:
        return now.subtract(const Duration(days: 30));
      case SmsScanRange.oneWeek:
        return now.subtract(const Duration(days: 7));
      case SmsScanRange.customRange:
        // Custom range cutoff will be handled separately
        return null;
    }
  }
}

// ── Financial SMS patterns ────────────────────────────────────────────────────

/// Regex for extracting amount with currency symbol (highest priority)
/// Matches: $75.50, $1,200, $1,234.56, ₹500, Rs.100
final _amountWithCurrencyRe = RegExp(
  r'(?:USD|INR|Rs\.?|₹|RM|AED|GBP|EUR|SGD|CAD|AUD|HKD|\$)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)',
  caseSensitive: false,
);

/// Regex for amount near transaction keywords (medium priority)
/// Matches: "amount of 500", "deposit 1,234.56", "credited 75.50"
final _amountNearKeywordRe = RegExp(
  r'(?:amount|amt|deposit|credited|debited|paid|received|payment|withdrawn|transfer|spent)\s*(?:of\s+)?(?:rs\.?|inr|usd|₹|\$)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
  caseSensitive: false,
);

/// Generic amount pattern (lowest priority, fallback only) - ONLY with decimals
/// Matches: 1234.56, 500.00, 75.50
final _amountGenericRe = RegExp(
  r'\b(\d{1,7}\.\d{2})\b',  // Only match amounts with exactly 2 decimals
  caseSensitive: false,
);

// ── SmsService ────────────────────────────────────────────────────────────────

class SmsService {
  // ── SMS Fingerprinting ──────────────────────────────────────────────────────
  
  /// Generate unique fingerprint for SMS to prevent duplicates
  static String generateSmsFingerprint({
    required String? merchant,
    required double amount,
    required DateTime date,
    required String? accountIdentifier,
  }) {
    // Normalize inputs
    final normalizedMerchant = (merchant ?? 'unknown').toLowerCase().trim();
    final normalizedAmount = amount.toStringAsFixed(2);
    final normalizedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final normalizedLast4 = (accountIdentifier ?? 'none').toLowerCase().replaceAll(RegExp(r'[^0-9]'), '');
    
    // Create fingerprint string
    final fingerprintInput = '$normalizedMerchant|$normalizedAmount|$normalizedDate|$normalizedLast4';
    
    // Generate MD5 hash
    final bytes = utf8.encode(fingerprintInput);
    final hash = md5.convert(bytes);
    
    return hash.toString();
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSmsEnabled) ?? false;
  }

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmsEnabled, v);
  }

  static Future<SmsScanRange> getScanRange() async {
    final p = await SharedPreferences.getInstance();
    return SmsScanRange.fromKey(p.getString(_kSmsScanRange) ?? '1m');
  }

  static Future<void> setScanRange(SmsScanRange r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSmsScanRange, r.key);
  }

  static Future<DateTime?> getCustomStartDate() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kSmsCustomStartDate);
    return s != null ? DateTime.tryParse(s) : null;
  }

  static Future<DateTime?> getCustomEndDate() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kSmsCustomEndDate);
    return s != null ? DateTime.tryParse(s) : null;
  }

  static Future<void> setCustomDateRange(DateTime start, DateTime end) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSmsCustomStartDate, start.toIso8601String());
    await p.setString(_kSmsCustomEndDate, end.toIso8601String());
  }

  static Future<DateTime?> getLastScan() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kSmsLastScan);
    return s != null ? DateTime.tryParse(s) : null;
  }

  static Future<void> _setLastScan(DateTime dt) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSmsLastScan, dt.toIso8601String());
  }

  static Future<SmsImportResult?> getLastScanResult() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSmsLastScanResult);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SmsImportResult(
        imported: map['imported'] ?? 0,
        skipped: map['skipped'] ?? 0,
        failed: map['failed'] ?? 0,
        filteredByDate: map['filteredByDate'] ?? 0,
        alreadyProcessed: map['alreadyProcessed'] ?? 0,
        nonFinancial: map['nonFinancial'] ?? 0,
        parseFailed: map['parseFailed'] ?? 0,
        duplicates: map['duplicates'] ?? 0,
        blockedByRule: map['blockedByRule'] ?? 0,
        scanDate: map['scanDate'] != null ? DateTime.tryParse(map['scanDate']) : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveLastScanResult(SmsImportResult result) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSmsLastScanResult, jsonEncode({
      'imported': result.imported,
      'skipped': result.skipped,
      'failed': result.failed,
      'filteredByDate': result.filteredByDate,
      'alreadyProcessed': result.alreadyProcessed,
      'nonFinancial': result.nonFinancial,
      'parseFailed': result.parseFailed,
      'duplicates': result.duplicates,
      'blockedByRule': result.blockedByRule,
      'scanDate': DateTime.now().toIso8601String(),
    }));
  }

  static Future<Set<int>> _getProcessedIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSmsProcessed);
    if (raw == null) return {};
    final List decoded = jsonDecode(raw);
    return decoded.cast<int>().toSet();
  }

  static Future<void> _saveProcessedIds(Set<int> ids) async {
    final p = await SharedPreferences.getInstance();
    // Keep only latest 5000 to avoid unbounded growth
    final Set<int> trimmed;
    if (ids.length > 5000) {
      AppLogger.sms(
        'Processed IDs trimmed: ${ids.length} → 5000. Oldest IDs dropped; re-scan may re-import some messages.',
        level: LogLevel.warning,
      );
      trimmed = ids.skip(ids.length - 5000).toSet();
    } else {
      trimmed = ids;
    }
    await p.setString(_kSmsProcessed, jsonEncode(trimmed.toList()));
  }

  /// Clear all SMS scan state (processed IDs, last scan date, last scan result).
  /// Call this when the user deletes all app data so the next scan reimports everything.
  static Future<void> clearSmsState() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSmsProcessed);
    await p.remove(_kSmsLastScan);
    await p.remove(_kSmsLastScanResult);
  }

  // ── Permission ───────────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<bool> hasPermission() async {
    return Permission.sms.isGranted;
  }

  // ── Main scan ────────────────────────────────────────────────────────────────

  /// Reads SMS inbox, parses financial messages, inserts new transactions.
  /// Optimized for responsiveness to prevent ANR.
  static Future<SmsImportResult> scanAndImport({
    bool force = false,
    void Function(int current)? onProgress,
  }) async {
    final scanStartTime = DateTime.now();
    AppLogger.sms('=== SMS SCAN STARTED ===', level: LogLevel.info);
    
    if (!await hasPermission()) {
      AppLogger.sms('SMS scan aborted - no permission', level: LogLevel.error);
      return const SmsImportResult(error: 'SMS permission not granted');
    }

    final range = await getScanRange();
    DateTime? cutoff = range.cutoff;
    DateTime? endDate;

    if (range == SmsScanRange.customRange) {
      cutoff = await getCustomStartDate();
      endDate = await getCustomEndDate();
    }

    AppLogger.sms('Phase 0: Querying SMS inbox', level: LogLevel.info);
    final query = SmsQuery();
    List<SmsMessage> allMessages = [];
    try {
      allMessages = await query.querySms(kinds: [SmsQueryKind.inbox]);
      
      // Sort messages by date descending (newest first) to allow early exit
      // Using a slightly more defensive sort
      allMessages.sort((a, b) {
        final da = a.date ?? DateTime(0);
        final db = b.date ?? DateTime(0);
        return db.compareTo(da);
      });
      
    } catch (e) {
      AppLogger.err('sms_query_failed', e);
      return SmsImportResult(error: 'Failed to query SMS: $e');
    }

    final processedIds = await _getProcessedIds();
    
    int imported = 0;
    int skipped = 0;
    int failed = 0;
    int pending = 0;
    final newIds = <int>{};

    int totalInRange = 0;
    int filteredByDate = 0;
    int alreadyProcessed = 0;
    int nonFinancial = 0;
    int parseFailed = 0;
    int duplicatesFound = 0;
    int blockedByRule = 0;
    int messagesChecked = 0;

    AppLogger.sms('Phase 2: Initializing ML classifier', level: LogLevel.info);
    await SmsClassifierService.initialize();

    final processingStartTime = DateTime.now();
    
    for (final sms in allMessages) {
      messagesChecked++;
      
      // CRITICAL: Yield to the UI thread every single message.
      // SMS processing (ML inference + DB writes) is heavy. 
      // This prevents the "App Not Responding" (ANR) dialog.
      await Future.delayed(Duration.zero);

      // Update progress every 10 messages to avoid flooding the UI with rebuilds
      if (messagesChecked % 10 == 0 || messagesChecked == allMessages.length) {
        if (onProgress != null) onProgress(messagesChecked);
        
        final elapsed = DateTime.now().difference(processingStartTime);
        final avg = elapsed.inMilliseconds / messagesChecked;
        AppLogger.sms(
          'Progress: $messagesChecked/${allMessages.length}',
          detail: 'Avg ${avg.toStringAsFixed(1)}ms/msg, Imported=$imported',
          level: LogLevel.info,
        );
      }

      final id = sms.id;
      final date = sms.date;
      final body = sms.body ?? '';
      final sender = sms.sender ?? '';

      if (id == null) continue;

      if (date != null) {
        // Since we sorted newest-to-oldest, we can stop entirely once we hit the cutoff
        if (cutoff != null && date.isBefore(cutoff)) {
          filteredByDate++;
          AppLogger.sms('scan_stop_cutoff_reached', detail: 'Reached date ${date.toIso8601String()}');
          break; 
        }
        
        if (endDate != null && date.isAfter(endDate)) {
          filteredByDate++;
          continue;
        }
      }

      totalInRange++;

      if (!force && processedIds.contains(id)) {
        skipped++;
        alreadyProcessed++;
        continue;
      }

      try {
        final result = await SmsPipelineExecutor.processSms(
          senderAddress: sender,
          messageBody: body,
          receivedAt: date ?? DateTime.now(),
        );

        if (!result.success) {
          failed++;
          parseFailed++;
          continue;
        }

        newIds.add(id);

        if (result.isTransaction) {
          imported++;
        } else if (result.isPending) {
          pending++;
          skipped++;
        } else {
          skipped++;
          if (result.smsType == SmsType.nonFinancial) {
            nonFinancial++;
            if (result.message == 'Blocked by learned rule') {
              blockedByRule++;
            }
          } else {
            parseFailed++;
          }
        }
      } catch (e) {
        failed++;
        parseFailed++;
        AppLogger.err('sms_msg_process_err', e);
      }
    }

    // Phase 3: Save state
    processedIds.addAll(newIds);
    await _saveProcessedIds(processedIds);
    await _setLastScan(DateTime.now());

    // Phase 4: Transfer Detection (Post-processing)
    if (imported > 0) {
      // Yield before heavy post-processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      try {
        AppLogger.sms('Phase 4: Running transfer detection', level: LogLevel.info);
        final fixedCount = await cleanupDuplicateTransfers();
        duplicatesFound = fixedCount;
      } catch (e) {
        AppLogger.err('sms_transfer_detection', e);
      }
    }

    // Phase 5: Recurring Pattern Detection
    // Guard: Only run automatic detection if a small/moderate number of transactions were imported.
    // Huge imports should run pattern detection manually from the Intelligence screen.
    if (imported > 0 && imported <= 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        AppLogger.sms('Phase 5: Running recurring pattern detection', level: LogLevel.info);
        final results = await RecurringPatternEngine.runDetection();
        final created = results['patterns_created'] ?? 0;
        if (created > 0) {
          AppLogger.sms('Auto-created $created recurring patterns', level: LogLevel.info);
        }
      } catch (e) {
        AppLogger.err('sms_recurring_detection', e);
      }
    }

    final totalDuration = DateTime.now().difference(scanStartTime);
    AppLogger.sms('=== SMS SCAN COMPLETE ===', 
      detail: 'Processed ${allMessages.length} messages in ${totalDuration.inSeconds}s, Imported $imported',
      level: LogLevel.info);

    final result = SmsImportResult(
      imported: imported,
      skipped: skipped,
      failed: failed,
      filteredByDate: filteredByDate,
      alreadyProcessed: alreadyProcessed,
      nonFinancial: nonFinancial,
      parseFailed: parseFailed,
      duplicates: duplicatesFound,
      blockedByRule: blockedByRule,
    );
    await _saveLastScanResult(result);
    return result;
  }

  /// Scan existing transactions for duplicates and convert them to transfers.
  /// Optimized with bucketing and yielding to prevent UI freezes.
  static Future<int> cleanupDuplicateTransfers() async {
    try {
      final db = await AppDatabase.db();
      int fixedCount = 0;
      
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 183));
      final transactions = await db.query(
        'transactions',
        where: "source_type = 'sms' AND date >= ? AND type IN ('expense', 'income')",
        whereArgs: [sixMonthsAgo.toIso8601String()],
      );
      
      if (transactions.isEmpty) return 0;
      
      final txnList = transactions.map((m) => model.Transaction.fromMap(m)).toList();
      
      // Group by Date and Amount to avoid O(N^2) global search
      final buckets = <String, List<model.Transaction>>{};
      for (final txn in txnList) {
        final dateKey = "${txn.date.year}-${txn.date.month}-${txn.date.day}";
        final amountKey = txn.amount.toStringAsFixed(2);
        final key = "$dateKey|$amountKey";
        buckets.putIfAbsent(key, () => []).add(txn);
      }
      
      final processed = <int>{};
      final batch = db.batch();
      
      int bucketCount = 0;
      for (final bucket in buckets.values) {
        if (bucket.length < 2) continue;
        
        // Yield every 50 buckets to keep UI responsive
        if (bucketCount++ % 50 == 0) await Future.delayed(Duration.zero);
        
        for (var i = 0; i < bucket.length; i++) {
          if (processed.contains(bucket[i].id)) continue;
          final txn1 = bucket[i];
          final body1 = txn1.smsSource?.toLowerCase() ?? '';
          
          final is1Payment = body1.contains('payment') || body1.contains('posted');
          final is1Debit = body1.contains('debit') || body1.contains('draft') || 
                           body1.contains('withdrew') || body1.contains('deducted');

          for (var j = i + 1; j < bucket.length; j++) {
            if (processed.contains(bucket[j].id)) continue;
            final txn2 = bucket[j];
            final body2 = txn2.smsSource?.toLowerCase() ?? '';
            
            final is2Payment = body2.contains('payment') || body2.contains('posted');
            final is2Debit = body2.contains('debit') || body2.contains('draft') || 
                             body2.contains('withdrew') || body2.contains('deducted');
            
            if ((is1Payment && is2Debit) || (is2Payment && is1Debit)) {
              batch.update(
                'transactions',
                {
                  'type': 'transfer',
                  'category': 'Transfer',
                  'note': '${txn1.note ?? ''} [Auto-detected transfer]',
                },
                where: 'id = ?',
                whereArgs: [txn1.id],
              );
              
              batch.update(
                'transactions',
                {
                  'type': 'transfer',
                  'category': 'Transfer',
                  'note': '${txn2.note ?? ''} [Auto-detected transfer]',
                },
                where: 'id = ?',
                whereArgs: [txn2.id],
              );
              
              processed.add(txn1.id!);
              processed.add(txn2.id!);
              fixedCount += 2;
              break; 
            }
          }
        }
      }
      
      if (fixedCount > 0) {
        await batch.commit(noResult: true);
      }
      
      return fixedCount;
    } catch (e) {
      AppLogger.err('cleanup_duplicates', e);
      return 0;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _previewSmsBody(String body, {int maxLength = 80}) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '<empty>';
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  static Future<void> createAccountsFromTransactions() async {
    final db = await AppDatabase.db();
    final txnResults = await db.query(
      'transactions',
      where: "source_type = 'sms' AND (extracted_institution IS NOT NULL OR extracted_identifier IS NOT NULL)",
    );
    
    if (txnResults.isEmpty) return;
    
    final accountGroups = <String, List<Map<String, dynamic>>>{};
    for (final txn in txnResults) {
      final bank = txn['extracted_institution'] as String?;
      final identifier = txn['extracted_identifier'] as String?;
      if (identifier == null || identifier.isEmpty) continue;
      
      final key = '${bank ?? "Unknown"}|$identifier';
      accountGroups.putIfAbsent(key, () => []).add(txn);
    }
    
    for (final entry in accountGroups.entries) {
      final parts = entry.key.split('|');
      final bank = parts[0] == 'Unknown' ? null : parts[0];
      final identifier = parts[1];
      
      final existing = await AppDatabase.findAccountByIdentity(
        institutionName: bank,
        accountIdentifier: identifier,
      );
      
      int accountId;
      if (existing != null) {
        accountId = existing.id!;
      } else {
        final accountName = (bank != null) ? '$bank $identifier' : 'Account $identifier';
        final newAccount = Account(
          name: accountName,
          type: 'unidentified',
          balance: 0,
          institutionName: bank,
          accountIdentifier: identifier,
        );
        accountId = await AppDatabase.insertAccount(newAccount);
      }
      
      for (final txn in entry.value) {
        await db.update('transactions', {'account_id': accountId}, 
          where: 'id = ?', whereArgs: [txn['id']]);
      }
    }
  }
}

// ── Result ────────────────────────────────────────────────────────────────────

class SmsImportResult {
  const SmsImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.failed = 0,
    this.filteredByDate = 0,
    this.alreadyProcessed = 0,
    this.nonFinancial = 0,
    this.parseFailed = 0,
    this.duplicates = 0,
    this.blockedByRule = 0,
    this.scanDate,
    this.error,
  });
  final int imported;
  final int skipped;
  final int failed;
  final int filteredByDate;
  final int alreadyProcessed;
  final int nonFinancial;
  final int parseFailed;
  final int duplicates;
  final int blockedByRule;
  final DateTime? scanDate;
  final String? error;

  bool get hasError => error != null;

  @override
  String toString() {
    if (error != null) return error!;
    final parts = <String>[];
    if (imported > 0) parts.add('Imported: $imported');
    if (skipped > 0) parts.add('Skipped: $skipped');
    if (failed > 0) parts.add('Failed: $failed');
    if (filteredByDate > 0) parts.add('Out of range: $filteredByDate');
    if (alreadyProcessed > 0) parts.add('Already processed: $alreadyProcessed');
    if (nonFinancial > 0) parts.add('Non-financial: $nonFinancial');
    if (blockedByRule > 0) parts.add('Blocked by rules: $blockedByRule');
    if (parseFailed > 0) parts.add('Parse failed: $parseFailed');
    if (duplicates > 0) parts.add('Duplicates: $duplicates');
    return parts.isEmpty ? 'No messages processed' : parts.join('  •  ');
  }
}
