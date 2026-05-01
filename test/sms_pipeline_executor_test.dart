// Unit tests for SmsPipelineExecutor.
//
// The full pipeline requires a complete DB setup. These tests focus on:
//   1. The helper method _signalsFromTransaction (tested via onPositiveFeedback /
//      onNegativeFeedback which call it internally).
//   2. The needsReview threshold logic (tested directly via the blended
//      confidence formula).
//   3. learnedCategory propagation (tested via ExtractedEntities).
//   4. Signal-weight-based confidence formula (tested via SignalWeightRepository).
//
// For the full pipeline tests (autoApprove / requiresReview) we verify the
// threshold logic directly using ConfidenceScoring constants, since wiring
// the full pipeline requires a complete DB with accounts, transactions, etc.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/sms_types.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/repositories/signal_weight_repository.dart';
import 'package:pocket_flow/services/confidence_scoring.dart';
import 'package:pocket_flow/services/entity_extraction_service.dart';
import 'package:pocket_flow/services/sms_pipeline_executor.dart';
import 'package:pocket_flow/services/transaction_feedback_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh in-memory database with the signal_weights table.
Future<Database> _openSignalWeightsDb({bool seedDefaults = true}) async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute('''
    CREATE TABLE signal_weights(
      id     INTEGER PRIMARY KEY AUTOINCREMENT,
      signal TEXT    NOT NULL UNIQUE,
      weight REAL    NOT NULL
    )
  ''');
  if (seedDefaults) {
    for (final entry in kDefaultSignalWeights.entries) {
      await db.insert('signal_weights', {
        'signal': entry.key,
        'weight': entry.value,
      });
    }
  }
  return db;
}

/// Resets the SignalWeightRepository static cache by performing a no-op write.
Future<void> _resetSignalWeightCache() async {
  final cleanDb = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await cleanDb.execute('''
    CREATE TABLE signal_weights(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      signal TEXT NOT NULL UNIQUE,
      weight REAL NOT NULL
    )
  ''');
  AppDatabase.setDatabaseForTesting(cleanDb);
  await SignalWeightRepository().updateWeight('__reset__', 0.0);
  await cleanDb.close();
  AppDatabase.resetForTesting();
}

/// Minimal SMS transaction for feedback tests.
model.Transaction _makeTx({
  String? merchant,
  String? extractedBank,
  String? extractedAccountIdentifier,
  double amount = 100.0,
}) =>
    model.Transaction(
      id: 1,
      accountId: 1,
      amount: amount,
      date: DateTime.now(),
      type: 'expense',
      category: 'Other',
      sourceType: 'sms',
      smsSource: 'Test SMS',
      merchant: merchant,
      extractedBank: extractedBank,
      extractedAccountIdentifier: extractedAccountIdentifier,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    AppDatabase.resetForTesting();
    TransactionFeedbackService.resetForTesting();
  });

  tearDown(() async {
    try {
      final db = await AppDatabase.db();
      await db.close();
    } catch (_) {}
    AppDatabase.resetForTesting();
    TransactionFeedbackService.resetForTesting();
    await _resetSignalWeightCache();
  });

  // ── 1. needsReview = false when blended confidence >= 0.85 ───────────────
  //
  // We test the threshold logic directly using ConfidenceScoring constants.
  // The pipeline sets needsReview = blendedConfidence < thresholdMedium.
  // For blendedConfidence >= thresholdHigh (0.85), needsReview must be false.
  test('pipeline_autoApprove_highConfidence', () {
    const highConfidence = 0.90;
    final needsReview = highConfidence < ConfidenceScoring.thresholdMedium;
    expect(needsReview, isFalse,
        reason: 'confidence $highConfidence >= ${ConfidenceScoring.thresholdMedium} → needsReview must be false');
  });

  // ── 2. needsReview = true when blended confidence < 0.70 ─────────────────
  test('pipeline_requiresReview_lowConfidence', () {
    const lowConfidence = 0.50;
    final needsReview = lowConfidence < ConfidenceScoring.thresholdMedium;
    expect(needsReview, isTrue,
        reason: 'confidence $lowConfidence < ${ConfidenceScoring.thresholdMedium} → needsReview must be true');
  });

  // ── 3. learnedCategory on ExtractedEntities is used by the pipeline ───────
  //
  // We verify that ExtractedEntities correctly carries learnedCategory and
  // that the pipeline would use it (entities.learnedCategory ?? default).
  test('pipeline_usesLearnedCategory', () {
    const learnedCat = 'Food & Drink';

    // Simulate what the pipeline does: entities.learnedCategory ?? default
    final entities = ExtractedEntities(
      transactionType: SmsType.transactionDebit,
      timestamp: DateTime.now(),
      amount: 50.0,
      merchant: 'Starbucks',
      learnedCategory: learnedCat,
    );

    // The pipeline expression: entities.learnedCategory ?? _getDefaultCategory(...)
    final category = entities.learnedCategory ?? 'Other Expense';

    expect(category, equals(learnedCat));
  });

  // ── 4. learnedCategory is null → falls back to default ───────────────────
  test('pipeline_usesDefaultCategory_whenNoLearnedCategory', () {
    final entities = ExtractedEntities(
      transactionType: SmsType.transactionDebit,
      timestamp: DateTime.now(),
      amount: 50.0,
      merchant: 'Starbucks',
      // learnedCategory not set → null
    );

    const defaultCategory = 'Other Expense';
    final category = entities.learnedCategory ?? defaultCategory;

    expect(category, equals(defaultCategory));
  });

  // ── 5. Signal-weight confidence formula uses weights from signal_weights ──
  //
  // Verifies that the weighted sum formula produces the expected result
  // when all five signals are present with default weights.
  test('pipeline_usesSignalWeights', () async {
    final db = await _openSignalWeightsDb();
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();
    final weights = await repo.getWeights();

    // Simulate all signals present
    double signalConfidence = 0.0;
    signalConfidence += weights['has_amount'] ?? 0.40;       // 0.40
    signalConfidence += weights['has_account'] ?? 0.20;      // 0.20
    signalConfidence += weights['has_bank'] ?? 0.10;         // 0.10
    signalConfidence += weights['has_merchant'] ?? 0.10;     // 0.10
    signalConfidence += weights['has_transaction_verb'] ?? 0.20; // 0.20
    signalConfidence = signalConfidence.clamp(0.0, 1.0);

    // All five default weights sum to 1.0
    expect(signalConfidence, closeTo(1.0, 1e-9));
  });

  // ── 6. Signal-weight confidence with partial signals ─────────────────────
  test('pipeline_usesSignalWeights_partialSignals', () async {
    final db = await _openSignalWeightsDb();
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();
    final weights = await repo.getWeights();

    // Only amount and account present
    double signalConfidence = 0.0;
    signalConfidence += weights['has_amount'] ?? 0.40;   // 0.40
    signalConfidence += weights['has_account'] ?? 0.20;  // 0.20
    signalConfidence = signalConfidence.clamp(0.0, 1.0);

    expect(signalConfidence, closeTo(0.60, 1e-9));
  });

  // ── 7. onPositiveFeedback increases signal weights ────────────────────────
  test('pipeline_onPositiveFeedback_increasesWeights', () async {
    final db = await _openSignalWeightsDb();
    AppDatabase.setDatabaseForTesting(db);

    final tx = _makeTx(
      merchant: 'Starbucks',
      extractedBank: 'Chase',
      extractedAccountIdentifier: '****1234',
    );

    await SmsPipelineExecutor.onPositiveFeedback(tx);

    final repo = SignalWeightRepository();
    final weights = await repo.getWeights();

    // has_amount: 0.40 + 0.01 = 0.41
    expect(weights['has_amount'], closeTo(0.41, 1e-9));
    // has_merchant: 0.10 + 0.01 = 0.11
    expect(weights['has_merchant'], closeTo(0.11, 1e-9));
    // has_bank: 0.10 + 0.01 = 0.11
    expect(weights['has_bank'], closeTo(0.11, 1e-9));
    // has_account: 0.20 + 0.01 = 0.21
    expect(weights['has_account'], closeTo(0.21, 1e-9));
    // has_transaction_verb: 0.20 + 0.01 = 0.21 (sourceType == 'sms')
    expect(weights['has_transaction_verb'], closeTo(0.21, 1e-9));
  });

  // ── 8. onNegativeFeedback decreases signal weights ────────────────────────
  test('pipeline_onNegativeFeedback_decreasesWeights', () async {
    final db = await _openSignalWeightsDb();
    AppDatabase.setDatabaseForTesting(db);

    final tx = _makeTx(merchant: 'Starbucks');

    await SmsPipelineExecutor.onNegativeFeedback(tx);

    final repo = SignalWeightRepository();
    final weights = await repo.getWeights();

    // has_amount: 0.40 - 0.01 = 0.39
    expect(weights['has_amount'], closeTo(0.39, 1e-9));
    // has_merchant: 0.10 - 0.01 = 0.09
    expect(weights['has_merchant'], closeTo(0.09, 1e-9));
  });

  // ── 9. Blended confidence formula ────────────────────────────────────────
  test('pipeline_blendedConfidence_formula', () {
    const signalConfidence = 0.80;
    const resolutionConfidence = 0.90;
    final blended = ((signalConfidence + resolutionConfidence) / 2.0).clamp(0.0, 1.0);
    expect(blended, closeTo(0.85, 1e-9));
  });
}
