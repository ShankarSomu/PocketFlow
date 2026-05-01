import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/transaction.dart' as model;
import 'app_logger.dart';
import 'merchant_normalization_service.dart';

class TransactionFeedbackService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await AppDatabase.db();
    return _db!;
  }

  // ─────────────────────────────────────────────────────────────
  // WEIGHTED LEARNING CONFIG (IMPORTANT FIX)
  // ─────────────────────────────────────────────────────────────

  static const double _thumbWeight = 0.03;
  static const double _correctionWeight = 0.15;
  static const double _confirmationWeight = 0.12;

  static const double _learningRate = 0.10;
  static const double _decayFactor = 0.98;

  // ─────────────────────────────────────────────────────────────
  // QUICK FEEDBACK (FIXED WEIGHTING)
  // ─────────────────────────────────────────────────────────────

  static Future<void> recordQuickFeedback({
    required model.Transaction transaction,
    required String fieldName,
    required bool isCorrect,
  }) async {
    if (!transaction.isFromSms) return;

    final db = await database;

    await db.insert(
      'parsing_feedback',
      {
        'transaction_id': transaction.id,
        'field_name': fieldName,
        'is_correct': isCorrect ? 1 : 0,
        'feedback_date': DateTime.now().toIso8601String(),
        'sms_text': transaction.smsSource,
        'extracted_value': _getFieldValue(transaction, fieldName),
        'weight': isCorrect ? _thumbWeight : -_thumbWeight,
      },
    );

    await _applyWeightedConfidenceUpdate(
      transaction,
      isCorrect ? _thumbWeight : -_thumbWeight,
      fieldName,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CORRECTIONS (HIGH WEIGHT, CLEANED INPUT)
  // ─────────────────────────────────────────────────────────────

  static Future<void> recordCorrection({
    required model.Transaction transaction,
    required String fieldName,
    required String? originalValue,
    required String? correctedValue,
  }) async {
    if (!transaction.isFromSms) return;
    if (correctedValue == null) return;

    final db = await database;

    final cleanOriginal = _cleanText(originalValue);
    final cleanCorrected = _cleanText(correctedValue);

    if (cleanCorrected.isEmpty) return;

    await db.insert(
      'user_corrections',
      {
        'transaction_id': transaction.id,
        'field_name': fieldName,
        'original_value': cleanOriginal,
        'corrected_value': cleanCorrected,
        'correction_date': DateTime.now().toIso8601String(),
        'sms_text': transaction.smsSource,
        'feedback_type': 'edit',
        'weight': _correctionWeight,
      },
    );

    await _applyWeightedConfidenceUpdate(
      transaction,
      _correctionWeight,
      fieldName,
    );

    await _learnFromCorrection(
      transaction,
      fieldName,
      cleanOriginal,
      cleanCorrected,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACCOUNT CONFIRMATION (STRONG SIGNAL)
  // ─────────────────────────────────────────────────────────────

  static Future<void> recordAccountConfirmation({
    required model.Transaction transaction,
    required bool confirmed,
  }) async {
    if (!transaction.isFromSms) return;

    final db = await database;

    await db.insert(
      'user_account_confirmations',
      {
        'transaction_id': transaction.id,
        'institution': transaction.extractedBank,
        'merchant': transaction.merchant,
        'sender_id': _extractSenderId(transaction.smsSource),
        'confirmed': confirmed ? 1 : 0,
        'confidence_before': transaction.confidenceScore ?? 0.0,
        'confirmation_date': DateTime.now().toIso8601String(),
      },
    );

    await _applyWeightedConfidenceUpdate(
      transaction,
      confirmed ? _confirmationWeight : -_confirmationWeight,
      'account',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CORE CONFIDENCE UPDATE (FIXED STABILITY MODEL)
  // ─────────────────────────────────────────────────────────────

  static Future<void> _applyWeightedConfidenceUpdate(
    model.Transaction transaction,
    double delta,
    String field,
  ) async {
    final current = transaction.confidenceScore ?? 0.5;

    // additive update with learning rate (delta is already signed +/-)
    final updated = current + (delta * _learningRate);

    final clamped = updated.clamp(0.0, 1.0);

    await _updateTransactionConfidence(transaction.id!, clamped);

    if (clamped < 0.7) {
      await _updateNeedsReview(transaction.id!, true);
    } else if (clamped >= 0.8) {
      await _updateNeedsReview(transaction.id!, false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LEARNING FROM CORRECTIONS (CLEANED + SAFE)
  // ─────────────────────────────────────────────────────────────

  static Future<void> _learnFromCorrection(
    model.Transaction transaction,
    String fieldName,
    String? originalValue,
    String? correctedValue,
  ) async {
    if (correctedValue == null || correctedValue.trim().length < 2) return;

    final db = await database;

    if (fieldName == 'merchant') {
      final raw = _cleanText(originalValue);
      final normalized = _cleanText(correctedValue);

      if (_isInvalidToken(raw) || _isInvalidToken(normalized)) return;

      await _upsertMerchantNormalizationRule(db, raw, normalized);
    }

    if (fieldName == 'category') {
      final merchant = _cleanText(transaction.merchant ?? rawOrEmpty(originalValue));
      final category = _cleanCategory(correctedValue);

      if (merchant.isEmpty || category.isEmpty) return;

      await _upsertMerchantCategoryMap(db, merchant, category);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MERCHANT LEARNING (SAFE UPSERT)
  // ─────────────────────────────────────────────────────────────

  static Future<void> _upsertMerchantNormalizationRule(
    Database db,
    String raw,
    String normalized,
  ) async {
    final existing = await db.query(
      'merchant_normalization_rules',
      where: 'raw_pattern = ?',
      whereArgs: [raw],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final usage = (existing.first['usage_count'] as int) + 1;
      final success = (existing.first['success_count'] as int) + 1;

      await db.update(
        'merchant_normalization_rules',
        {
          'normalized_name': normalized,
          'usage_count': usage,
          'success_count': success,
          'confidence': success / usage,
          'last_used_at': DateTime.now().toIso8601String(),
        },
        where: 'raw_pattern = ?',
        whereArgs: [raw],
      );
    } else {
      await db.insert('merchant_normalization_rules', {
        'raw_pattern': raw,
        'normalized_name': normalized,
        'usage_count': 1,
        'success_count': 1,
        'confidence': 1.0,
        'last_used_at': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<void> _upsertMerchantCategoryMap(
    Database db,
    String merchant,
    String category,
  ) async {
    final existing = await db.query(
      'merchant_category_map',
      where: 'merchant = ?',
      whereArgs: [merchant],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final usage = (existing.first['usage_count'] as int) + 1;

      await db.update(
        'merchant_category_map',
        {
          'category': category,
          'usage_count': usage,
          'confidence': usage / (usage + 1),
          'last_used_at': DateTime.now().toIso8601String(),
        },
        where: 'merchant = ?',
        whereArgs: [merchant],
      );
    } else {
      await db.insert('merchant_category_map', {
        'merchant': merchant,
        'category': category,
        'usage_count': 1,
        'confidence': 1.0,
        'last_used_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS (CLEANING + SAFETY)
  // ─────────────────────────────────────────────────────────────

  static String _cleanText(String? input) {
    if (input == null) return '';
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _cleanCategory(String? input) {
    final cleaned = _cleanText(input);
    if (!RegExp(r'^[a-z ]{3,30}$').hasMatch(cleaned)) return '';
    return cleaned;
  }

  static bool _isInvalidToken(String value) {
    const invalid = {
      'account', 'card', 'bank', 'upi', 'payment', 'transaction',
      'your', 'the', 'a', 'an', ''
    };
    return invalid.contains(value.toLowerCase());
  }

  static String rawOrEmpty(String? v) => v ?? '';

  static String? _getFieldValue(model.Transaction t, String field) {
    switch (field) {
      case 'amount':
        return t.amount.toString();
      case 'merchant':
        return t.merchant;
      case 'category':
        return t.category;
      case 'account':
        return t.extractedAccountIdentifier;
      default:
        return null;
    }
  }

  static Future<void> _updateTransactionConfidence(
    int id,
    double confidence,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {'confidence_score': confidence},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> _updateNeedsReview(
    int id,
    bool needsReview,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {'needs_review': needsReview ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static String? _extractSenderId(String? sms) {
    if (sms == null) return null;
    final match = RegExp(r'\b[A-Z0-9]{4,12}\b').firstMatch(sms);
    return match?.group(0);
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC LOOKUP HELPERS (used by EntityExtractionService)
  // ─────────────────────────────────────────────────────────────

  /// Look up a learned merchant normalization for [rawMerchant].
  /// Delegates to [MerchantNormalizationService.lookupWithResult] which performs
  /// exact DB match → fuzzy DB match → static alias → raw fallback.
  /// Returns the normalized name if a learned rule was applied, otherwise null.
  static Future<String?> lookupMerchantNormalization(String rawMerchant) async {
    final result = await MerchantNormalizationService.lookupWithResult(rawMerchant);
    return result.fromLearnedRule ? result.normalizedName : null;
  }

  /// Look up a learned category for [merchant].
  /// Returns the category if a mapping with confidence ≥ 0.6 exists.
  static Future<String?> lookupMerchantCategory(String merchant) async {
    try {
      final db = await database;

      // Exact match first
      final result = await db.query(
        'merchant_category_map',
        where: 'merchant = ? AND confidence >= 0.6',
        whereArgs: [merchant],
        limit: 1,
      );
      if (result.isNotEmpty) return result.first['category'] as String;

      // Case-insensitive fallback
      final lower = merchant.toLowerCase();
      final all = await db.query(
        'merchant_category_map',
        where: 'confidence >= 0.6',
      );
      for (final row in all) {
        if ((row['merchant'] as String).toLowerCase() == lower) {
          return row['category'] as String;
        }
      }
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'lookup_merchant_category_error',
        detail: e.toString(),
      );
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // SPECIFIC FEEDBACK REASONS (routes to correct learning path)
  // ─────────────────────────────────────────────────────────────

  /// Called when user selects a specific incorrect reason from the feedback sheet.
  /// Routes to the appropriate learning method based on the reason.
  static Future<void> recordFeedbackReason({
    required model.Transaction transaction,
    required String reason,
    String? correctedValue,
  }) async {
    if (!transaction.isFromSms) return;

    switch (reason) {
      case 'Wrong Merchant':
        if (correctedValue != null) {
          await recordCorrection(
            transaction: transaction,
            fieldName: 'merchant',
            originalValue: transaction.merchant,
            correctedValue: correctedValue,
          );
        } else {
          // Record as negative signal without a correction value
          await recordQuickFeedback(
            transaction: transaction,
            fieldName: 'merchant',
            isCorrect: false,
          );
        }
        break;

      case 'Wrong Amount':
        await recordQuickFeedback(
          transaction: transaction,
          fieldName: 'amount',
          isCorrect: false,
        );
        break;

      case 'Wrong Account':
        await recordAccountConfirmation(
          transaction: transaction,
          confirmed: false,
        );
        break;

      case 'Wrong Type':
        await recordQuickFeedback(
          transaction: transaction,
          fieldName: 'type',
          isCorrect: false,
        );
        break;

      case 'Duplicate Transaction':
        // Record as a negative signal on all fields
        await recordQuickFeedback(
          transaction: transaction,
          fieldName: 'amount',
          isCorrect: false,
        );
        break;

      default:
        // Generic negative feedback
        await recordQuickFeedback(
          transaction: transaction,
          fieldName: 'amount',
          isCorrect: false,
        );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RULE DELETION (Requirement 8)
  // ─────────────────────────────────────────────────────────────

  /// Delete a merchant normalization rule by raw pattern.
  /// Silently succeeds if the rule does not exist.
  static Future<void> deleteMerchantNormalizationRule(String rawPattern) async {
    try {
      final db = await database;
      await db.delete(
        'merchant_normalization_rules',
        where: 'raw_pattern = ?',
        whereArgs: [rawPattern.toLowerCase().trim()],
      );
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'delete_merchant_norm_rule_error',
        detail: e.toString(),
      );
    }
  }

  /// Delete a merchant → category mapping.
  /// Silently succeeds if the mapping does not exist.
  static Future<void> deleteCategoryMapping(String merchant) async {
    try {
      final db = await database;
      await db.delete(
        'merchant_category_map',
        where: 'merchant = ?',
        whereArgs: [merchant.trim()],
      );
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'delete_category_mapping_error',
        detail: e.toString(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TESTING SUPPORT
  // ─────────────────────────────────────────────────────────────

  /// Clears the cached database instance.
  /// **For testing only.**
  // ignore: invalid_use_of_visible_for_testing_member
  static void resetForTesting() {
    _db = null;
  }
}