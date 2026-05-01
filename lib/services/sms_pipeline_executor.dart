import '../db/database.dart';
import '../models/pending_action.dart';
import '../models/sms_types.dart';
import '../models/transaction.dart' as model;
import '../repositories/signal_weight_repository.dart';
import 'account_resolution_engine.dart';
import 'app_logger.dart';
import 'confidence_scoring.dart';
import 'entity_extraction_service.dart';
import 'pending_action_service.dart';
import 'privacy_guard.dart';
import 'sms_classification_service.dart';
import 'sms_classifier_service.dart';
import 'sms_correction_service.dart';

class SmsProcessingResult {
  SmsProcessingResult({
    required this.success,
    required this.message,
    required this.smsType,
    this.transactionId,
    this.pendingActionId,
    this.requiresUserAction = false,
    this.confidence = 0.0,
  });

  final bool success;
  final String message;
  final int? transactionId;
  final int? pendingActionId;
  final SmsType smsType;
  final bool requiresUserAction;
  final double confidence;

  bool get isTransaction => transactionId != null;
  bool get isPending => pendingActionId != null;
}

class SmsPipelineExecutor {
  static final _signalWeightRepo = SignalWeightRepository();

  static Future<SmsProcessingResult> processSms({
    required String senderAddress,
    required String messageBody,
    required DateTime receivedAt,
  }) async {
    final startTime = DateTime.now();
    try {
      AppLogger.sms('Pipeline: Privacy check', detail: 'sender=$senderAddress');
      if (PrivacyGuard.isSensitive(messageBody)) {
        return SmsProcessingResult(
          success: true,
          message: 'Blocked sensitive SMS',
          smsType: SmsType.nonFinancial,
        );
      }

      final sanitizedBody = PrivacyGuard.sanitize(messageBody);
      if (sanitizedBody == null) {
        return SmsProcessingResult(
          success: true,
          message: 'Fully sensitive SMS',
          smsType: SmsType.nonFinancial,
        );
      }

      final rawSms = RawSmsMessage(
        id: 0,
        sender: senderAddress,
        body: sanitizedBody,
        timestamp: receivedAt,
      );

      AppLogger.sms('Pipeline: ML classification', detail: 'sender=$senderAddress');
      final mlStartTime = DateTime.now();
      final mlResult = await SmsClassifierService.classify(sanitizedBody);
      final mlDuration = DateTime.now().difference(mlStartTime);
      if (mlDuration.inMilliseconds > 200) {
        AppLogger.sms('SLOW: ML classify took ${mlDuration.inMilliseconds}ms', level: LogLevel.warning);
      }

      // Check structural negative samples using ML label for accurate pattern matching
      // If user previously marked a structurally similar SMS as "not a transaction", skip it
      final isBlocked = await SmsCorrectionService.isBlocked(
        sanitizedBody, senderAddress, mlLabel: mlResult.label);
      if (isBlocked) {
        AppLogger.sms('BLOCKED by structural similarity', detail: 'sender=$senderAddress mlLabel=${mlResult.label}');
        return SmsProcessingResult(
          success: true,
          message: 'Blocked by learned rule',
          smsType: SmsType.nonFinancial,
        );
      }
      
      AppLogger.sms('Pipeline: Rule-based classification', detail: 'mlLabel=${mlResult.label}');
      final classifyStartTime = DateTime.now();
      final classification = await SmsClassificationService.classifyWithMl(
        sms: rawSms,
        mlLabel: mlResult.label,
        mlConfidence: mlResult.confidence,
      );
      final classifyDuration = DateTime.now().difference(classifyStartTime);
      if (classifyDuration.inMilliseconds > 100) {
        AppLogger.sms('SLOW: Classification took ${classifyDuration.inMilliseconds}ms', level: LogLevel.warning);
      }

      if (classification.type == SmsType.nonFinancial) {
        return SmsProcessingResult(
          success: true,
          message: 'Non-financial SMS ignored',
          smsType: classification.type,
        );
      }

      if (classification.type == SmsType.paymentReminder) {
        return SmsProcessingResult(
          success: true,
          message: 'Reminder SMS logged',
          smsType: classification.type,
        );
      }

      if (classification.type == SmsType.accountUpdate) {
        // accountUpdate can be a real credit transaction (e.g. "Direct deposit credited")
        // Try to extract entities - if there's an amount, treat as a credit transaction
        final entities = await EntityExtractionService.extract(rawSms, classification);
        if (entities.amount != null) {
          // Reclassify as credit transaction so it gets saved
          final creditClassification = SmsClassification(
            type: SmsType.transactionCredit,
            confidence: classification.confidence,
            reason: 'Reclassified from accountUpdate (has amount)',
          );
          final resolution = await AccountResolutionEngine.resolve(entities);
          return _processTransaction(rawSms, creditClassification, entities, resolution);
        }
        // No amount - just a balance notification, skip
        return SmsProcessingResult(
          success: true,
          message: 'Balance SMS logged',
          smsType: SmsType.accountUpdate,
        );
      }

      AppLogger.sms('Pipeline: Entity extraction', detail: 'type=${classification.type.name}');
      final extractStartTime = DateTime.now();
      final entities = await EntityExtractionService.extract(rawSms, classification);
      final extractDuration = DateTime.now().difference(extractStartTime);
      if (extractDuration.inMilliseconds > 100) {
        AppLogger.sms('SLOW: Entity extraction took ${extractDuration.inMilliseconds}ms', level: LogLevel.warning);
      }

      if (entities.amount == null) {
        return _createPending(rawSms, classification.type, 'missing_amount');
      }

      AppLogger.sms('Pipeline: Account resolution', detail: 'amount=${entities.amount}');
      final resolveStartTime = DateTime.now();
      final resolution = await AccountResolutionEngine.resolve(entities);
      final resolveDuration = DateTime.now().difference(resolveStartTime);
      if (resolveDuration.inMilliseconds > 100) {
        AppLogger.sms('SLOW: Account resolution took ${resolveDuration.inMilliseconds}ms', level: LogLevel.warning);
      }

      AppLogger.sms('Pipeline: Processing type ${classification.type.name}');
      switch (classification.type) {
        case SmsType.transactionDebit:
        case SmsType.transactionCredit:
          return _processTransaction(
            rawSms,
            classification,
            entities,
            resolution,
          );
        case SmsType.transfer:
          return _processTransfer(rawSms, entities, resolution);
        case SmsType.unknownFinancial:
          return _processUnknownFinancial(
            rawSms,
            classification,
            entities,
            resolution,
          );
        default:
          return SmsProcessingResult(
            success: false,
            message: 'Unhandled type',
            smsType: classification.type,
          );
      }
    } catch (e) {
      AppLogger.sms('pipeline_error', detail: e.toString(), level: LogLevel.error);
      return SmsProcessingResult(
        success: false,
        message: 'Pipeline error: $e',
        smsType: SmsType.nonFinancial,
      );
    } finally {
      final totalDuration = DateTime.now().difference(startTime);
      if (totalDuration.inMilliseconds > 500) {
        AppLogger.sms('SLOW: Total pipeline took ${totalDuration.inMilliseconds}ms', 
          detail: 'sender=$senderAddress', level: LogLevel.warning);
      }
    }
  }

  static Future<SmsProcessingResult> _processTransaction(
    RawSmsMessage sms,
    SmsClassification classification,
    ExtractedEntities entities,
    AccountResolution resolution,
  ) async {
    final weights = await _signalWeightRepo.getWeights();

    final signalScore =
        (entities.amount != null ? weights['has_amount'] ?? 0.4 : 0) +
        (entities.accountIdentifier != null ? weights['has_account'] ?? 0.2 : 0) +
        (entities.institutionName != null ? weights['has_bank'] ?? 0.1 : 0) +
        (entities.merchant != null ? weights['has_merchant'] ?? 0.1 : 0) +
        (classification.confidence > 0.8
            ? weights['strong_classification'] ?? 0.2
            : 0);

    final blendedConfidence =
        (signalScore * 0.6 + resolution.confidence * 0.4).clamp(0.0, 1.0);

    final needsReview =
        blendedConfidence < ConfidenceScoring.thresholdMedium ||
        resolution.accountId == null; // Needs review only if no account resolved

    // IMPROVED: Create transaction even without account (use placeholder)
    // User can review and assign account later in Transactions screen
    int accountId = resolution.accountId ?? await _getOrCreatePlaceholderAccount();

    final tx = model.Transaction(
      accountId: accountId,
      amount: entities.amount!,
      date: entities.timestamp,
      merchant: entities.merchant,
      note: entities.merchant ?? 'SMS Transaction',
      category:
          entities.learnedCategory ?? _defaultCategory(classification.type, entities.merchant),
      type: classification.type == SmsType.transactionDebit ? 'expense' : 'income',
      smsSource: sms.body,
      sourceType: 'sms',
      confidenceScore: blendedConfidence,
      needsReview: needsReview,
      extractedBank: entities.institutionName,
      extractedAccountIdentifier: entities.accountIdentifier,
    );

    final id = await AppDatabase.insertTransaction(tx);

    return SmsProcessingResult(
      success: true,
      message: needsReview ? 'Transaction created (review needed)' : 'Transaction created',
      transactionId: id,
      smsType: classification.type,
      requiresUserAction: needsReview,
      confidence: blendedConfidence,
    );
  }

  /// Get or create a placeholder account for unresolved SMS transactions
  static Future<int> _getOrCreatePlaceholderAccount() async {
    final db = await AppDatabase.db();
    
    // Check if placeholder account exists
    final existing = await db.query(
      'accounts',
      where: 'name = ? AND deleted_at IS NULL',
      whereArgs: ['SMS - Needs Review'],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }
    
    // Create placeholder account
    final accountId = await db.insert('accounts', {
      'name': 'SMS - Needs Review',
      'type': 'unidentified',
      'balance': 0.0,
    });
    
    AppLogger.log(
      LogLevel.info,
      LogCategory.system,
      'Created placeholder account for SMS transactions',
      detail: 'accountId=$accountId',
    );
    
    return accountId;
  }

  static Future<SmsProcessingResult> _processTransfer(
    RawSmsMessage sms,
    ExtractedEntities entities,
    AccountResolution resolution,
  ) async {
    final pendingId = await PendingActionService.createAction(
      actionType: 'confirm_transfer',
      priority: 'medium',
      title: 'Transfer detected',
      description:
          'Transfer of ${entities.amount?.toStringAsFixed(2) ?? "unknown"} detected. Confirm accounts.',
      smsSource: sms.body,
      metadata: {
        'amount': entities.amount,
        'merchant': entities.merchant,
        'sms': sms.body,
      },
      accountCandidateId: resolution.accountCandidateId,
      confidence: resolution.confidence,
    );

    return SmsProcessingResult(
      success: true,
      message: 'Transfer queued for confirmation',
      pendingActionId: pendingId,
      smsType: SmsType.transfer,
      requiresUserAction: true,
      confidence: resolution.confidence,
    );
  }

  static Future<SmsProcessingResult> _processUnknownFinancial(
    RawSmsMessage sms,
    SmsClassification classification,
    ExtractedEntities entities,
    AccountResolution resolution,
  ) async {
    // If we have an amount, create a transaction with needs_review=true
    // rather than a pending action. The user can review it in the Transactions screen.
    if (entities.amount != null) {
      final accountId = resolution.accountId ?? await _getOrCreatePlaceholderAccount();

      final tx = model.Transaction(
        accountId: accountId,
        amount: entities.amount!,
        date: entities.timestamp,
        merchant: entities.merchant,
        note: entities.merchant ?? 'SMS Transaction (unclassified)',
        category: 'uncategorized',
        type: 'expense', // Default to expense; user can correct during review
        smsSource: sms.body,
        sourceType: 'sms',
        confidenceScore: classification.confidence,
        needsReview: true, // Always needs review for unknown financial
        extractedBank: entities.institutionName,
        extractedAccountIdentifier: entities.accountIdentifier,
      );

      final id = await AppDatabase.insertTransaction(tx);

      return SmsProcessingResult(
        success: true,
        message: 'Transaction created (review needed - unclassified)',
        transactionId: id,
        smsType: classification.type,
        requiresUserAction: true,
        confidence: classification.confidence,
      );
    }

    // No amount found - fall back to pending action
    return _createPending(sms, classification.type, 'ambiguous_transaction');
  }

  static Future<SmsProcessingResult> _processBalance(
    RawSmsMessage sms,
    SmsClassification classification,
  ) async {
    final entities = await EntityExtractionService.extract(sms, classification);

    if (entities.amount == null) {
      return _createPending(sms, classification.type, 'missing_balance');
    }

    return SmsProcessingResult(
      success: true,
      message: 'Balance SMS logged',
      smsType: SmsType.accountUpdate,
    );
  }

  static Future<SmsProcessingResult> _createPending(
    RawSmsMessage sms,
    SmsType type,
    String reason,
  ) async {
    final id = await PendingActionService.createAction(
      actionType: 'review_sms',
      priority: 'medium',
      title: 'Review required',
      description: reason,
      smsSource: sms.body,
      metadata: {
        'sms_type': type.name,
        'reason': reason,
      },
      confidence: 0.5,
    );

    return SmsProcessingResult(
      success: true,
      message: 'Pending action created',
      pendingActionId: id,
      smsType: type,
      requiresUserAction: true,
      confidence: 0.5,
    );
  }

  static String _defaultCategory(SmsType type, String? merchant) {
    final m = merchant?.toLowerCase() ?? '';

    if (m.contains('uber') || m.contains('ola')) return 'Transport';
    if (m.contains('zomato') || m.contains('swiggy')) return 'Food';
    if (m.contains('amazon')) return 'Shopping';

    return type == SmsType.transactionDebit ? 'Expense' : 'Income';
  }

  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await AppDatabase.db();

      final txnResult = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM transactions WHERE source_type = 'sms'",
      );
      final pendingResult = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM pending_actions WHERE status = 'pending'",
      );
      final candidateResult = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM accounts WHERE type = 'unidentified'",
      );

      return {
        'sms_transactions': (txnResult.first['cnt'] as int?) ?? 0,
        'pending_actions': (pendingResult.first['cnt'] as int?) ?? 0,
        'account_candidates': (candidateResult.first['cnt'] as int?) ?? 0,
      };
    } catch (_) {
      return {
        'sms_transactions': 0,
        'pending_actions': 0,
        'account_candidates': 0,
      };
    }
  }

  static Future<void> onPositiveFeedback(model.Transaction tx) async {
    await _signalWeightRepo.applyFeedback(
      presentSignals: _signalsFromTransaction(tx).toSet(),
      positive: true,
    );
  }

  static Future<void> onNegativeFeedback(model.Transaction tx) async {
    await _signalWeightRepo.applyFeedback(
      presentSignals: _signalsFromTransaction(tx).toSet(),
      positive: false,
    );
  }

  static List<String> _signalsFromTransaction(model.Transaction tx) {
    final signals = <String>['has_amount'];
    if (tx.merchant != null) signals.add('has_merchant');
    if (tx.extractedBank != null) signals.add('has_bank');
    if (tx.extractedAccountIdentifier != null) signals.add('has_account');
    if (tx.sourceType == 'sms') signals.add('has_transaction_verb');
    return signals;
  }
}
