import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/sms_engine/models/sms_types.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/repositories/signal_weight_repository.dart';
import 'package:pocket_flow/sms_engine/account/sms_account_resolver.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_entity_extractor.dart';
import 'package:pocket_flow/services/pending_action_service.dart';
import 'package:pocket_flow/services/privacy_guard.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_classification_service.dart';
import 'package:pocket_flow/sms_engine/rules/sms_correction_service.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_normalizer.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_event_repository.dart';
import 'package:pocket_flow/sms_engine/cluster/sms_cluster_memory.dart';
import 'package:pocket_flow/sms_engine/cluster/sms_cluster_propagator.dart';
import 'package:pocket_flow/sms_engine/probability/sms_probability_engine.dart';
import 'package:pocket_flow/sms_engine/stability/sms_stability_guard.dart';
import 'package:pocket_flow/sms_engine/audit/sms_audit_repository.dart';

/// Internal carrier for Phase 4+5 signal data — written to `sms_audit_log`
/// after the pipeline completes. Stored on [SmsProcessingResult] so the
/// outer [SmsPipelineExecutor.processSms] can write the audit record once it
/// has the [eventId].
class _SmsAuditContext {
  const _SmsAuditContext({
    required this.clusterId,
    required this.senderKnown,
    required this.patternCacheHit,
    required this.probScore,
    required this.stability,
    required this.needsReview,
  });

  final int? clusterId;
  final bool senderKnown;
  final bool patternCacheHit;
  final SmsProbabilityScore probScore;
  final StabilityAssessment stability;
  final bool needsReview;
}

class SmsProcessingResult {
  SmsProcessingResult({
    required this.success,
    required this.message,
    required this.smsType,
    this.transactionId,
    this.pendingActionId,
    this.requiresUserAction = false,
    this.confidence = 0.0,
    this.auditContext,
  });

  final bool success;
  final String message;
  final int? transactionId;
  final int? pendingActionId;
  final SmsType smsType;
  final bool requiresUserAction;
  final double confidence;

  /// Phase 6: present only for financial pipeline paths (transaction/unknown).
  /// Written to `sms_audit_log` by [SmsPipelineExecutor.processSms].
  final _SmsAuditContext? auditContext;

  bool get isTransaction => transactionId != null;
  bool get isPending => pendingActionId != null;
}

class SmsPipelineExecutor {
  static final _signalWeightRepo = SignalWeightRepository();
  static final _eventRepo = SmsEventRepository();

  static Future<int?> _findExistingSmsTransactionIdBySource(
    String smsSource,
  ) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'transactions',
      columns: ['id'],
      where:
          'source_type = ? AND sms_source = ? AND (deleted_at IS NULL OR user_disputed = 1)',
      whereArgs: ['sms', smsSource],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  static Future<SmsProcessingResult> processSms({
    required String senderAddress,
    required String messageBody,
    required DateTime receivedAt,
  }) async {
    // ── Privacy gate ──────────────────────────────────────────────────────────
    AppLogger.sms('Pipeline: Privacy check', detail: 'sender=$senderAddress');
    // ── Phase 3: startup propagation scan (once per session) ─────────────────
    SmsClusterPropagator.propagateAll();
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

    // ── Normalize + content-hash dedup ────────────────────────────────────────
    // Use the raw sanitized body (not token-masked) so only truly identical
    // messages hash the same. Two transactions of different amounts at the same
    // merchant will have different hashes and will NOT be treated as duplicates.
    final contentHash = SmsNormalizer.computeDedupeHash(sanitizedBody, senderAddress);
    final existingEventId = await _eventRepo.findIdByHash(contentHash);
    if (existingEventId != null) {
      AppLogger.sms(
        'Pipeline: Duplicate SMS skipped by event hash',
        detail: 'hash=$contentHash eventId=$existingEventId',
      );
      return SmsProcessingResult(
        success: true,
        message: 'Duplicate SMS skipped',
        smsType: SmsType.nonFinancial,
      );
    }

    // Fallback dedupe for restored backups where sms_events may be empty:
    // if an identical SMS source already exists in transactions, skip import.
    final existingTxId = await _findExistingSmsTransactionIdBySource(messageBody);
    if (existingTxId != null) {
      AppLogger.sms(
        'Pipeline: Duplicate SMS skipped by transaction source',
        detail: 'txId=$existingTxId',
      );
      return SmsProcessingResult(
        success: true,
        message: 'Duplicate SMS skipped',
        smsType: SmsType.nonFinancial,
      );
    }

    // ── Cluster memory lookup (Phase 2) ─────────────────────────────────────
    // Template hash uses token-masked body so structurally identical messages
    // (same template, different amounts/dates) map to the same cluster.
    final normalizedBody = SmsNormalizer.normalize(sanitizedBody);
    final templateHash = SmsNormalizer.computeHash(normalizedBody, senderAddress);
    final cluster = await SmsClusterMemory.lookupOrCreate(
      templateHash: templateHash,
      sender: senderAddress,
      normalizedBody: normalizedBody,
    );

    // ── Log raw event (pending status until pipeline completes) ───────────────
    final eventId = await _eventRepo.insert(
      rawBody: messageBody,
      sender: senderAddress,
      receivedAt: receivedAt,
      contentHash: contentHash,
    );

    // ── Run structural pipeline ───────────────────────────────────────────────
    final result = await _runPipeline(
      senderAddress: senderAddress,
      sanitizedBody: sanitizedBody,
      receivedAt: receivedAt,
      cluster: cluster,
    );

    // ── Record cluster outcome (Phase 2) ──────────────────────────────────────
    final isFinancialOutcome = result.transactionId != null ||
        (result.smsType != SmsType.nonFinancial && result.success);
    if (isFinancialOutcome || cluster.matchCount > 1) {
      // Record even non-financial outcomes once we have prior hits — helps the
      // cluster learn that a template is consistently non-financial.
      final outcomeTxType = result.smsType.name;
      await SmsClusterMemory.recordOutcome(
        templateHash: templateHash,
        transactionType: outcomeTxType,
        confirmed: result.transactionId != null,
      );
    }

    // ── Update event status ───────────────────────────────────────────────────
    final status = result.transactionId != null
        ? SmsEventStatus.processed
        : (result.success ? SmsEventStatus.skipped : SmsEventStatus.skipped);
    await _eventRepo.updateStatus(eventId, status,
        transactionId: result.transactionId);

    // ── Phase 6: Audit log ──────────────────────────────────────────────────
    final audit = result.auditContext;
    if (audit != null) {
      await SmsAuditRepository.insert(
        eventId: eventId,
        clusterId: audit.clusterId,
        transactionId: result.transactionId,
        senderKnown: audit.senderKnown,
        patternCacheHit: audit.patternCacheHit,
        probScore: audit.probScore,
        stability: audit.stability,
        needsReview: audit.needsReview,
      );
    }

    return result;
  }

  /// Core structural pipeline — runs after privacy gate, dedup, and event
  /// logging. No ML calls; relies on sender/body heuristics and rule engine.
  static Future<SmsProcessingResult> _runPipeline({
    required String senderAddress,
    required String sanitizedBody,
    required DateTime receivedAt,
    required SmsCluster cluster,
  }) async {
    final startTime = DateTime.now();
    try {
      final rawSms = RawSmsMessage(
        id: 0,
        sender: senderAddress,
        body: sanitizedBody,
        timestamp: receivedAt,
      );

      // Check structural negative samples
      final isBlocked =
          await SmsCorrectionService.isBlocked(sanitizedBody, senderAddress);
      if (isBlocked) {
        AppLogger.sms('BLOCKED by structural similarity',
            detail: 'sender=$senderAddress');
        return SmsProcessingResult(
          success: true,
          message: 'Blocked by learned rule',
          smsType: SmsType.nonFinancial,
        );
      }

      // ── Cluster fast-path (Phase 2) ───────────────────────────────────────
      // If this template has been seen enough times with consistent outcomes,
      // skip the rule engine and use the cluster's known type directly.
      late final SmsClassification classification;
      if (cluster.isKnown && cluster.transactionType != null) {
        final knownSmsType = _smsTypeFromName(cluster.transactionType!);
        if (knownSmsType != null) {
          AppLogger.sms(
            'ClusterMemory: fast-path classification',
            detail: 'type=${cluster.transactionType} conf=${cluster.confidence.toStringAsFixed(2)} '
                'matches=${cluster.matchCount}',
          );
          classification = SmsClassification(
            type: knownSmsType,
            confidence: cluster.confidence,
            reason: 'cluster_memory:${cluster.templateHash.substring(0, 8)}',
          );
        } else {
          classification = await _classifyWithTiming(rawSms, senderAddress);
        }
      } else {
        // Record a hit on existing learning clusters so the count grows.
        if (cluster.matchCount > 1) {
          await SmsClusterMemory.recordHit(cluster.templateHash);
        }
        classification = await _classifyWithTiming(rawSms, senderAddress);
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
          final sSenderKnown = await SmsProbabilityEngine.checkSenderKnown(senderAddress);
          final sPatternHit = await SmsProbabilityEngine.checkPatternCache(cluster.templateHash);
          return _processTransaction(
            rawSms, creditClassification, entities, resolution,
            cluster: cluster, senderKnown: sSenderKnown, patternCacheHit: sPatternHit,
          );
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

      // ── Phase 4: pre-compute probability inputs ──────────────────────────
      final senderKnown = await SmsProbabilityEngine.checkSenderKnown(senderAddress);
      final patternCacheHit = await SmsProbabilityEngine.checkPatternCache(cluster.templateHash);

      AppLogger.sms('Pipeline: Processing type ${classification.type.name}');
      switch (classification.type) {
        case SmsType.transactionDebit:
        case SmsType.transactionCredit:
          return _processTransaction(
            rawSms,
            classification,
            entities,
            resolution,
            cluster: cluster,
            senderKnown: senderKnown,
            patternCacheHit: patternCacheHit,
          );
        case SmsType.transfer:
          return _processTransfer(rawSms, entities, resolution);
        case SmsType.unknownFinancial:
          return _processUnknownFinancial(
            rawSms,
            classification,
            entities,
            resolution,
            cluster: cluster,
            senderKnown: senderKnown,
            patternCacheHit: patternCacheHit,
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
    AccountResolution resolution, {
    required SmsCluster cluster,
    required bool senderKnown,
    required bool patternCacheHit,
  }) async {
    // ── Phase 4: Probability Engine ───────────────────────────────────────────
    final probScore = await SmsProbabilityEngine.compute(
      senderKnown: senderKnown,
      cluster: cluster,
      classification: classification,
      entities: entities,
      resolution: resolution,
      patternCacheHit: patternCacheHit,
    );

    // ── Phase 5: Stability Guard ────────────────────────────────────────────
    final stability = SmsStabilityGuard.assess(cluster, probScore);

    final blendedConfidence = probScore.score;
    final needsReview =
        probScore.requiresReview || resolution.accountId == null || stability.forceReview;

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
      message: stability.forceReview
          ? 'Transaction created (review needed: ${stability.threat.name})'
          : (needsReview ? 'Transaction created (review needed)' : 'Transaction created'),
      transactionId: id,
      smsType: classification.type,
      requiresUserAction: needsReview,
      confidence: blendedConfidence,
      auditContext: _SmsAuditContext(
        clusterId: cluster.id,
        senderKnown: senderKnown,
        patternCacheHit: patternCacheHit,
        probScore: probScore,
        stability: stability,
        needsReview: needsReview,
      ),
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
    AccountResolution resolution, {
    required SmsCluster cluster,
    required bool senderKnown,
    required bool patternCacheHit,
  }) async {
    // If we have an amount, create a transaction with needs_review=true
    // rather than a pending action. The user can review it in the Transactions screen.
    if (entities.amount != null) {
      // ── Phase 4: Probability Engine ─────────────────────────────────────────
      final probScore = await SmsProbabilityEngine.compute(
        senderKnown: senderKnown,
        cluster: cluster,
        classification: classification,
        entities: entities,
        resolution: resolution,
        patternCacheHit: patternCacheHit,
      );

      // ── Phase 5: Stability Guard ──────────────────────────────────────────
      final stability = SmsStabilityGuard.assess(cluster, probScore);

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
        confidenceScore: probScore.score,
        needsReview: true, // unknownFinancial always needs review
        extractedBank: entities.institutionName,
        extractedAccountIdentifier: entities.accountIdentifier,
      );

      final id = await AppDatabase.insertTransaction(tx);

      return SmsProcessingResult(
        success: true,
        message: stability.forceReview
            ? 'Transaction created (review needed - ${stability.threat.name})'
            : 'Transaction created (review needed - unclassified)',
        transactionId: id,
        smsType: classification.type,
        requiresUserAction: true,
        confidence: probScore.score,
        auditContext: _SmsAuditContext(
          clusterId: cluster.id,
          senderKnown: senderKnown,
          patternCacheHit: patternCacheHit,
          probScore: probScore,
          stability: stability,
          needsReview: true,
        ),
      );
    }

    // No amount found - fall back to pending action
    return _createPending(sms, classification.type, 'ambiguous_transaction');
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

  // ── Cluster memory helpers ────────────────────────────────────────────────

  /// Run [SmsClassificationService.classify] with timing instrumentation.
  static Future<SmsClassification> _classifyWithTiming(
    RawSmsMessage rawSms,
    String senderAddress,
  ) async {
    AppLogger.sms('Pipeline: Rule-based classification',
        detail: 'sender=$senderAddress');
    final start = DateTime.now();
    final result = await SmsClassificationService.classify(rawSms);
    final elapsed = DateTime.now().difference(start);
    if (elapsed.inMilliseconds > 100) {
      AppLogger.sms('SLOW: Classification took ${elapsed.inMilliseconds}ms',
          level: LogLevel.warning);
    }
    return result;
  }

  /// Convert a stored [SmsType.name] string back to an [SmsType], or return
  /// `null` if the name is unrecognised (guards against stale cluster data).
  static SmsType? _smsTypeFromName(String name) {
    try {
      return SmsType.values.byName(name);
    } catch (_) {
      return null;
    }
  }
}
