import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_signature.dart';

/// Core feedback engine. Handles all user feedback and triggers reevaluation.
/// NO keyword matching. Uses structural SMS signatures.
class SmsCorrectionService {

  /// Main entry point for all feedback.
  /// Called from TransactionDetailScreen for every feedback action.
  static Future<void> handleFeedback({
    required model.Transaction tx,
    required FeedbackType feedbackType,
    String? correctedCategory,
    String? correctedType,
  }) async {
    AppLogger.log(LogLevel.info, LogCategory.system,
        'handleFeedback: ${feedbackType.name} txId=${tx.id}');

    final db = await AppDatabase.db();
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (feedbackType) {
      case FeedbackType.correct:
        // Clear needs_review, record positive sample
        await db.update('transactions',
            {'needs_review': 0, 'user_disputed': 0},
            where: 'id = ?', whereArgs: [tx.id]);
        AppLogger.log(LogLevel.info, LogCategory.system,
            'handleFeedback: marked correct txId=${tx.id}');
        break;

      case FeedbackType.notATransaction:
        // Soft-delete this transaction
        await db.update('transactions',
            {'deleted_at': now, 'user_disputed': 1, 'needs_review': 0},
            where: 'id = ?', whereArgs: [tx.id]);

        // Store negative sample using ML-aware signature
        if (tx.smsSource != null) {
          // Use extractedBank as sender hint; the signature will also extract
          // business fingerprint from the SMS text as fallback
          final sig = SmsSignature.from(tx.smsSource!, tx.extractedBank);
          await db.insert('sms_negative_samples', {
            ...sig.toMap(),
            'original_sms': tx.smsSource,
            'created_at': now,
          });
          AppLogger.log(LogLevel.info, LogCategory.system,
              'handleFeedback: stored negative sample sender=${sig.sender} pattern=${sig.patternType}');
        }
        break;

      case FeedbackType.incorrectCategory:
        // Update category and clear review flag
        final updates = <String, dynamic>{'needs_review': 0, 'user_disputed': 0};
        if (correctedCategory != null) updates['category'] = correctedCategory;
        if (correctedType != null) updates['type'] = correctedType;
        await db.update('transactions', updates,
            where: 'id = ?', whereArgs: [tx.id]);
        AppLogger.log(LogLevel.info, LogCategory.system,
            'handleFeedback: corrected category=$correctedCategory txId=${tx.id}');
        break;
    }
  }

  /// Check if an SMS should be blocked based on stored negative samples.
  /// [mlLabel] is the ML model's output label - used for more accurate pattern matching.
  static Future<bool> isBlocked(String smsText, String? sender, {String? mlLabel}) async {
    final sig = SmsSignature.from(smsText, sender, mlLabel: mlLabel);
    final db = await AppDatabase.db();

    try {
      final samples = await db.query('sms_negative_samples');
      for (final row in samples) {
        final sample = SmsSignature.fromMap(row);
        if (sig.similarityTo(sample) >= 0.7) {
          return true;
        }
      }
    } catch (_) {
      // Table may not exist yet on older DB versions
    }
    return false;
  }

  /// Get statistics for the intelligence dashboard.
  static Future<Map<String, dynamic>> getStatistics() async {
    final db = await AppDatabase.db();

    final negativeCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sms_negative_samples');
    final confirmedCount = await db.rawQuery(
        "SELECT COUNT(*) as count FROM transactions WHERE source_type='sms' AND needs_review=0 AND deleted_at IS NULL AND user_disputed=0");
    final totalRules = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sms_classification_rules WHERE is_active=1');

    return {
      'total_rules': (totalRules.first['count'] as num?)?.toInt() ?? 0,
      'feedback_balance': {
        'negative_feedback': (negativeCount.first['count'] as num?)?.toInt() ?? 0,
        'positive_feedback': (confirmedCount.first['count'] as num?)?.toInt() ?? 0,
      },
    };
  }

  /// Get all negative samples for the intelligence dashboard detail view.
  static Future<List<Map<String, dynamic>>> getNegativeSamples({int limit = 50}) async {
    final db = await AppDatabase.db();
    return db.query('sms_negative_samples',
        orderBy: 'created_at DESC', limit: limit);
  }

  // ── Legacy compatibility methods (kept for existing call sites) ──────────

  static Future<void> markAsCorrect({
    required int transactionId,
    required String smsText,
    required String category,
    String? transactionType,
  }) async {
    final db = await AppDatabase.db();
    await db.update('transactions',
        {'needs_review': 0, 'user_disputed': 0},
        where: 'id = ?', whereArgs: [transactionId]);
  }

  static Future<void> markAsNotTransaction({
    required int transactionId,
    required String smsText,
  }) async {
    final db = await AppDatabase.db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('transactions',
        {'deleted_at': now, 'user_disputed': 1, 'needs_review': 0},
        where: 'id = ?', whereArgs: [transactionId]);
    final sig = SmsSignature.from(smsText, null);
    await db.insert('sms_negative_samples', {
      ...sig.toMap(),
      'original_sms': smsText,
      'created_at': now,
    });
  }

  static Future<void> markAsDisputed(int transactionId) async {
    final db = await AppDatabase.db();
    await db.update('transactions',
        {'user_disputed': 1},
        where: 'id = ?', whereArgs: [transactionId]);
  }

  static Future<void> undoDispute(int transactionId) async {
    final db = await AppDatabase.db();
    await db.update('transactions',
        {'user_disputed': 0},
        where: 'id = ?', whereArgs: [transactionId]);
  }

  static Future<void> recordEdit({
    required int transactionId,
    required String smsText,
    required String originalCategory,
    required String newCategory,
    String? transactionType,
  }) async {
    final db = await AppDatabase.db();
    await db.update('transactions',
        {'category': newCategory, 'needs_review': 0, 'user_disputed': 0},
        where: 'id = ?', whereArgs: [transactionId]);
  }

  static Future<List<model.Transaction>> findSimilarTransactions(String smsText) async {
    return [];
  }

  static Future<int> markAllSimilarAsNotTransaction({required String smsText}) async {
    return 0;
  }

  static Future<String?> checkFeedbackHealth() async => null;
}

enum FeedbackType {
  correct,
  notATransaction,
  incorrectCategory,
}
