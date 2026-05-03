import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/sms_engine/models/sms_types.dart';
import 'package:pocket_flow/services/app_logger.dart';

/// SMS Classification Service
///
/// Responsibilities:
///   1. Sender gate - decide whether this SMS is from a known/learnable
///      financial sender (DB lookup -> body signal fallback).
///   2. ML hand-off - accept an ML label and confidence and convert it to an
///      [SmsClassification].
class SmsClassificationService {
  static final Map<String, bool> _senderCache = {};
  static DateTime _senderCacheBuiltAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _senderCacheTtl = Duration(minutes: 30);

  /// Clear the sender cache (call on app restart or after DB seed changes).
  static void clearSenderCache() {
    _senderCache.clear();
    _senderCacheBuiltAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Matches real amounts ($1,234.56) and masked amounts ($X.XX, $XX.XX).
  // Also matches Indian currency formats (₹500, Rs.100, INR 500).
  static final _amountPattern = RegExp(
    r'(?:\$\s*[\dX,]+(?:\.[\dX]{1,2})?|(?:Rs\.?|INR|₹)\s*[\d,]+(?:\.\d{1,2})?|[\d,]+(?:\.\d{1,2})?\s*(?:Rs\.?|INR))',
    caseSensitive: false,
  );

  /// Classify an SMS using an ML-provided label.
  ///
  /// ML is the primary signal. Sender/body heuristics are used to soften false
  /// negatives and only hard-drop when both heuristics and ML are weak.
  static Future<SmsClassification> classifyWithMl({
    required RawSmsMessage sms,
    required String mlLabel,
    required double mlConfidence,
  }) async {
    final sender = sms.sender.toLowerCase();
    final body = sms.body.toLowerCase();
    final type = _mlLabelToType(mlLabel);
    final senderKnown = await _isKnownSender(sender);
    final hasBodySignal = _hasFinancialBodySignal(body);

    AppLogger.sms(
      'classifyWithMl',
      detail:
          'sender=$sender senderKnown=$senderKnown bodySignal=$hasBodySignal mlLabel=$mlLabel mlConf=${mlConfidence.toStringAsFixed(2)}',
    );

    if (type != SmsType.nonFinancial && mlConfidence >= 0.75) {
      AppLogger.sms(
        'CLASSIFIED',
        detail:
            'sender=$sender type=${type.name} conf=${mlConfidence.toStringAsFixed(2)} reason=ml_override',
      );
      return SmsClassification(
        type: type,
        confidence: mlConfidence,
        reason:
            'ML override: $mlLabel (${(mlConfidence * 100).toStringAsFixed(0)}%)',
      );
    }

    if (type == SmsType.nonFinancial && (senderKnown || hasBodySignal)) {
      AppLogger.sms(
        'CLASSIFIED',
        detail:
            'sender=$sender type=${SmsType.unknownFinancial.name} conf=${mlConfidence.toStringAsFixed(2)} reason=heuristic_review',
      );
      return SmsClassification(
        type: SmsType.unknownFinancial,
        confidence: mlConfidence.clamp(0.35, 0.65),
        reason: 'Financial heuristics present despite non-financial ML result',
      );
    }

    if (!senderKnown && !hasBodySignal && type == SmsType.nonFinancial) {
      AppLogger.sms(
        'DROPPED',
        detail: 'sender=$sender reason=unknown_sender_weak_ml',
      );
      return SmsClassification(
        type: SmsType.nonFinancial,
        confidence: mlConfidence >= 0.80 ? mlConfidence : 0.95,
        reason: 'Unknown sender, no financial body signal, weak ML result',
      );
    }

    AppLogger.sms(
      'CLASSIFIED',
      detail:
          'sender=$sender type=${type.name} conf=${mlConfidence.toStringAsFixed(2)}',
    );
    return SmsClassification(
      type: type,
      confidence: mlConfidence,
      reason: 'ML: $mlLabel (${(mlConfidence * 100).toStringAsFixed(0)}%)',
    );
  }

  /// Fallback classify - used when no ML model is available yet.
  static Future<SmsClassification> classify(RawSmsMessage sms) async {
    final sender = sms.sender.toLowerCase();
    final body = sms.body.toLowerCase();

    final senderKnown = await _isKnownSender(sender);
    AppLogger.sms(
      'classify (fallback)',
      detail: 'sender=$sender senderKnown=$senderKnown bodyLen=${body.length}',
    );
    if (!senderKnown && !_hasFinancialBodySignal(body)) {
      AppLogger.sms(
        'DROPPED',
        detail: 'sender=$sender reason=unknown_sender_no_signal',
      );
      return SmsClassification(
        type: SmsType.nonFinancial,
        confidence: 0.95,
        reason: 'Unknown sender, no financial body signal',
      );
    }

    return SmsClassification(
      type: SmsType.unknownFinancial,
      confidence: senderKnown ? 0.60 : 0.40,
      reason: senderKnown
          ? 'Known sender - awaiting ML classification'
          : 'Body signal only - awaiting ML classification',
    );
  }

  static Future<bool> _isKnownSender(String sender) async {
    // Expire the entire cache every 30 minutes so newly-added sender patterns
    // are picked up without requiring an app restart.
    final now = DateTime.now();
    if (now.difference(_senderCacheBuiltAt) > _senderCacheTtl) {
      _senderCache.clear();
      _senderCacheBuiltAt = now;
    }

    if (_senderCache.containsKey(sender)) return _senderCache[sender]!;

    try {
      final db = await AppDatabase.db();
      final rows = await db.query(
        'sms_keywords',
        where:
            'keyword = ? AND type = ? AND (is_active IS NULL OR is_active = 1)',
        whereArgs: [sender, 'sender_pattern'],
        limit: 1,
      );
      final known = rows.isNotEmpty;
      _senderCache[sender] = known;
      return known;
    } catch (_) {
      return false;
    }
  }

  static bool _hasFinancialBodySignal(String body) {
    // Currency amount patterns (USD, INR, etc.)
    if (_amountPattern.hasMatch(body)) return true;
    // Transaction verb keywords common in Indian bank SMS
    final lower = body.toLowerCase();
    return lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('deducted') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred') ||
        lower.contains('transaction') ||
        lower.contains('payment') ||
        lower.contains('balance') ||
        lower.contains('a/c') ||
        lower.contains('acct') ||
        lower.contains('upi') ||
        lower.contains('neft') ||
        lower.contains('imps') ||
        lower.contains('rtgs');
  }

  static SmsType _mlLabelToType(String label) {
    switch (label.toLowerCase().trim()) {
      case 'debit':
        return SmsType.transactionDebit;
      case 'credit':
        return SmsType.transactionCredit;
      case 'transfer':
        return SmsType.transfer;
      case 'balance':
        return SmsType.accountUpdate;
      case 'reminder':
        return SmsType.paymentReminder;
      case 'non_financial':
      case 'nonfinancial':
        return SmsType.nonFinancial;
      default:
        return SmsType.unknownFinancial;
    }
  }

  static String getTypeLabel(SmsType type) {
    switch (type) {
      case SmsType.transactionDebit:
        return 'Debit';
      case SmsType.transactionCredit:
        return 'Credit';
      case SmsType.transfer:
        return 'Transfer';
      case SmsType.accountUpdate:
        return 'Balance';
      case SmsType.paymentReminder:
        return 'Reminder';
      case SmsType.unknownFinancial:
        return 'Unknown';
      case SmsType.nonFinancial:
        return 'Non-Financial';
    }
  }

  static String getTypeColor(SmsType type) {
    switch (type) {
      case SmsType.transactionDebit:
        return '#FF5252';
      case SmsType.transactionCredit:
        return '#4CAF50';
      case SmsType.transfer:
        return '#2196F3';
      case SmsType.accountUpdate:
        return '#9C27B0';
      case SmsType.paymentReminder:
        return '#FF9800';
      case SmsType.unknownFinancial:
        return '#FFC107';
      case SmsType.nonFinancial:
        return '#9E9E9E';
    }
  }
}
