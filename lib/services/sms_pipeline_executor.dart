import '../db/database.dart';
import '../models/pending_action.dart';
import '../models/sms_types.dart';
import '../models/transaction.dart';
import 'account_resolution_engine.dart';
import 'entity_extraction_service.dart';
import 'privacy_guard.dart';
import 'sms_classification_service.dart';
import 'transfer_detection_engine.dart';

/// SMS Processing Result
class SmsProcessingResult {

  SmsProcessingResult({
    required this.success,
    required this.message,
    required this.smsType, this.transactionId,
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

/// SMS Intelligence Pipeline Executor
/// Orchestrates the complete SMS processing pipeline
class SmsPipelineExecutor {
  /// Process a single SMS message through the complete pipeline
  static Future<SmsProcessingResult> processSms({
    required String senderAddress,
    required String messageBody,
    required DateTime receivedAt,
  }) async {
    try {
      // === LAYER 1: PRIVACY FILTER ===
      // Block sensitive SMS from being stored
      if (PrivacyGuard.isSensitive(messageBody)) {
        return SmsProcessingResult(
          success: true,
          message: 'SMS blocked: contains sensitive data (OTP/password)',
          smsType: SmsType.nonFinancial,
        );
      }
      
      // Sanitize content
      final sanitizedBody = PrivacyGuard.sanitize(messageBody);
      if (sanitizedBody == null) {
        return SmsProcessingResult(
          success: true,
          message: 'SMS blocked: entirely sensitive',
          smsType: SmsType.nonFinancial,
        );
      }
      
      // === LAYER 2: CLASSIFICATION ===
      final rawSms = RawSmsMessage(
        id: 0, // Temporary ID
        sender: senderAddress,
        body: sanitizedBody,
        timestamp: receivedAt,
      );
      final classificationResult = SmsClassificationService.classify(rawSms);
      
      // Skip non-financial SMS
      if (classificationResult.type == SmsType.nonFinancial) {
        return SmsProcessingResult(
          success: true,
          message: 'SMS ignored: not financial',
          smsType: classificationResult.type,
        );
      }
      
      // Handle account update SMS
      if (classificationResult.type == SmsType.accountUpdate) {
        return await _processBalanceInquiry(
          rawSms,
          classificationResult,
        );
      }
      
      // Handle payment reminder SMS (non-transactional)
      if (classificationResult.type == SmsType.paymentReminder) {
        return await _processPaymentSms(
          rawSms,
          classificationResult,
        );
      }
      
      // === LAYER 3: ENTITY EXTRACTION ===
      final extractedEntities = EntityExtractionService.extract(rawSms, classificationResult);
      
      // Validate required data
      if (extractedEntities.amount == null) {
        return await _createPendingAction(
          rawSms.body,
          classificationResult.type,
          'missing_amount',
          {},
        );
      }
      
      // === LAYER 4: ACCOUNT RESOLUTION ===
      final accountResolution = await AccountResolutionEngine.resolve(extractedEntities);
      
      // === LAYER 5: TRANSACTION CREATION ===
      if (classificationResult.type == SmsType.transactionDebit || 
          classificationResult.type == SmsType.transactionCredit) {
        return await _processTransaction(
          rawSms,
          classificationResult,
          extractedEntities,
          accountResolution,
        );
      }
      
      // Transfer SMS
      if (classificationResult.type == SmsType.transfer) {
        return await _processTransfer(
          rawSms,
          classificationResult,
          extractedEntities,
          accountResolution,
        );
      }
      
      // Fallback
      return SmsProcessingResult(
        success: false,
        message: 'Unhandled SMS type: ${classificationResult.type}',
        smsType: classificationResult.type,
      );
      
    } catch (e) {
      // Log error and create pending action
      print('ERROR in SMS pipeline: $e');
      return SmsProcessingResult(
        success: false,
        message: 'Pipeline error: $e',
        smsType: SmsType.nonFinancial,
      );
    }
  }
  
  /// Process balance inquiry SMS
  static Future<SmsProcessingResult> _processBalanceInquiry(
    RawSmsMessage rawSms,
    SmsClassification classification,
  ) async {
    // Extract balance and update account if possible
    final entities = EntityExtractionService.extract(rawSms, classification);
    
    if (entities.institutionName != null && entities.amount != null) {
      final resolution = await AccountResolutionEngine.resolve(entities);
      
      if (resolution.hasMatch && resolution.isHighConfidence) {
        // Update account balance
        final db = await AppDatabase.db();
        await db.update(
          'accounts',
          {
            'balance': entities.amount,
            'last_synced': rawSms.timestamp.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [resolution.accountId],
        );
        
        return SmsProcessingResult(
          success: true,
          message: 'Balance updated for account',
          smsType: SmsType.accountUpdate,
          confidence: resolution.confidence,
        );
      }
    }
    
    // Create pending action if no account match
    return _createPendingAction(
      rawSms.body,
      SmsType.accountUpdate,
      'no_account_match',
      {},
    );
  }
  
  /// Process payment confirmation SMS
  static Future<SmsProcessingResult> _processPaymentSms(
    RawSmsMessage rawSms,
    SmsClassification classification,
  ) async {
    // Payment confirmations often don't need transactions
    // Just log for now
    return SmsProcessingResult(
      success: true,
      message: 'Payment SMS logged',
      smsType: SmsType.paymentReminder,
    );
  }
  
  /// Process transaction SMS
  static Future<SmsProcessingResult> _processTransaction(
    RawSmsMessage rawSms,
    SmsClassification classification,
    ExtractedEntities entities,
    AccountResolution resolution,
  ) async {
    final db = await AppDatabase.db();
    
    // Determine transaction type based on classification
    final transactionType = classification.type == SmsType.transactionDebit ? 'expense' : 'income';
    
    // High confidence account match - create transaction directly
    if (resolution.hasMatch && resolution.isHighConfidence) {
      final transaction = Transaction(
        accountId: resolution.accountId,
        amount: entities.amount!,
        date: entities.timestamp,
        note: entities.merchant ?? 'SMS Transaction',
        merchant: entities.merchant,
        category: _getDefaultCategory(classification.type, entities.merchant),
        type: transactionType,
        smsSource: rawSms.body,
        sourceType: 'sms',
        confidenceScore: resolution.confidence,
        needsReview: false,
      );
      
      final transactionId = await AppDatabase.insertTransaction(transaction);
      
      return SmsProcessingResult(
        success: true,
        message: 'Transaction created',
        transactionId: transactionId,
        smsType: classification.type,
        confidence: resolution.confidence,
      );
    }
    
    // Medium confidence - create transaction but mark for review
    if (resolution.hasMatch && resolution.confidence >= 0.60) {
      final transaction = Transaction(
        accountId: resolution.accountId,
        amount: entities.amount!,
        date: entities.timestamp,
        note: entities.merchant ?? 'SMS Transaction (Review)',
        merchant: entities.merchant,
        category: _getDefaultCategory(classification.type, entities.merchant),
        type: transactionType,
        smsSource: rawSms.body,
        sourceType: 'sms',
        confidenceScore: resolution.confidence,
        needsReview: true,
      );
      
      final transactionId = await AppDatabase.insertTransaction(transaction);
      
      return SmsProcessingResult(
        success: true,
        message: 'Transaction created (needs review)',
        transactionId: transactionId,
        smsType: classification.type,
        requiresUserAction: true,
        confidence: resolution.confidence,
      );
    }
    
    // Low confidence or new candidate - create pending action
    return _createPendingAction(
      rawSms.body,
      classification.type,
      'account_unresolved',
      {},
    );
  }
  
  /// Process transfer SMS
  static Future<SmsProcessingResult> _processTransfer(
    RawSmsMessage rawSms,
    SmsClassification classification,
    ExtractedEntities entities,
    AccountResolution resolution,
  ) async {
    // Similar to transaction but mark as transfer
    if (resolution.hasMatch && resolution.isHighConfidence) {
      final transaction = Transaction(
        accountId: resolution.accountId,
        amount: entities.amount!,
        date: entities.timestamp,
        note: entities.merchant ?? 'Transfer',
        merchant: entities.merchant,
        category: 'Transfer',
        type: 'expense', // Transfers are typically outgoing by default
        smsSource: rawSms.body,
        sourceType: 'sms',
        confidenceScore: resolution.confidence,
        needsReview: false,
      );
      
      final transactionId = await AppDatabase.insertTransaction(transaction);
      
      // Queue for transfer pair detection (run async in background)
      TransferDetectionEngine.runDetection(sinceDays: 7).catchError((e) {
        print('Transfer detection failed: $e');
      });
      
      return SmsProcessingResult(
        success: true,
        message: 'Transfer transaction created',
        transactionId: transactionId,
        smsType: SmsType.transfer,
        confidence: resolution.confidence,
      );
    }
    
    // Create pending action
    return _createPendingAction(
      rawSms.body,
      SmsType.transfer,
      'account_unresolved',
      {},
    );
  }
  
  /// Create pending action for user review
  static Future<SmsProcessingResult> _createPendingAction(
    String smsBody,
    SmsType smsType,
    String actionType,
    Map<String, dynamic> extractedData,
  ) async {
    final db = await AppDatabase.db();
    
    // Generate title and description based on action type
    final title = _generateTitle(actionType, smsType);
    final description = _generateDescription(actionType, smsType);
    final priority = _getPriority(smsType);
    
    final pendingAction = PendingAction(
      title: title,
      description: description,
      priority: priority,
      smsSource: smsBody,
      metadata: extractedData,
      actionType: actionType,
      createdAt: DateTime.now(),
    );
    
    final pendingId = await db.insert('pending_actions', pendingAction.toMap());
    
    return SmsProcessingResult(
      success: true,
      message: 'Created pending action for user review',
      pendingActionId: pendingId,
      smsType: smsType,
      requiresUserAction: true,
      confidence: 0.5,
    );
  }
  
  /// Generate title for pending action
  static String _generateTitle(String actionType, SmsType smsType) {
    switch (actionType) {
      case 'missing_amount':
        return 'Review SMS Transaction';
      case 'no_account_match':
        return 'Confirm Account';
      case 'account_unresolved':
        return 'Link Transaction to Account';
      default:
        return 'Review ${smsType.toString().split('.').last}';
    }
  }
  
  /// Generate description for pending action
  static String _generateDescription(String actionType, SmsType smsType) {
    switch (actionType) {
      case 'missing_amount':
        return 'Could not extract transaction amount from SMS';
      case 'no_account_match':
        return 'Unable to match SMS to an existing account';
      case 'account_unresolved':
        return 'Please confirm which account this transaction belongs to';
      default:
        return 'Please review and confirm this ${smsType.toString().split('.').last} SMS';
    }
  }
  
  /// Get priority for pending action
  static String _getPriority(SmsType smsType) {
    switch (smsType) {
      case SmsType.transactionDebit:
      case SmsType.transactionCredit:
        return 'high';
      case SmsType.transfer:
        return 'medium';
      default:
        return 'low';
    }
  }
  
  /// Get default category based on SMS classification and merchant
  static String _getDefaultCategory(SmsType smsType, String? merchant) {
    // Use merchant-based categorization if available
    if (merchant != null) {
      final merchantLower = merchant.toLowerCase();
      if (merchantLower.contains('restaurant') || merchantLower.contains('food')) {
        return 'Food & Dining';
      }
      if (merchantLower.contains('fuel') || merchantLower.contains('petrol')) {
        return 'Transportation';
      }
      if (merchantLower.contains('supermarket') || merchantLower.contains('grocery')) {
        return 'Groceries';
      }
    }
    
    // Default based on transaction type
    return smsType == SmsType.transactionDebit ? 'Other Expense' : 'Other Income';
  }
  
  /// Batch process multiple SMS messages
  static Future<List<SmsProcessingResult>> processBatch(
    List<Map<String, dynamic>> smsList,
  ) async {
    final results = <SmsProcessingResult>[];
    
    for (final sms in smsList) {
      final result = await processSms(
        senderAddress: sms['sender'] as String,
        messageBody: sms['body'] as String,
        receivedAt: sms['date'] as DateTime,
      );
      results.add(result);
      
      // Add small delay to avoid overwhelming DB
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    return results;
  }
  
  /// Get processing statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final db = await AppDatabase.db();
    
    final transactionCount = await db.rawQuery('SELECT COUNT(*) as count FROM transactions WHERE sms_source IS NOT NULL');
    final pendingCount = await db.rawQuery('SELECT COUNT(*) as count FROM pending_actions WHERE status = ?', ['pending']);
    final candidateCount = await db.rawQuery('SELECT COUNT(*) as count FROM account_candidates WHERE status = ?', ['pending']);
    
    return {
      'sms_transactions': transactionCount.first['count'],
      'pending_actions': pendingCount.first['count'],
      'account_candidates': candidateCount.first['count'],
    };
  }
}
