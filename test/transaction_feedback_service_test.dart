// Unit tests for TransactionFeedbackService.
//
// Uses sqflite_common_ffi to open a fresh in-memory database for each test,
// injected into AppDatabase via setDatabaseForTesting().

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/sms_engine/feedback/sms_feedback_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh in-memory database with the tables required by
/// [TransactionFeedbackService].
Future<Database> _openDb() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );

  await db.execute('''
    CREATE TABLE merchant_normalization_rules(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      raw_pattern TEXT NOT NULL UNIQUE,
      normalized_name TEXT NOT NULL,
      usage_count INTEGER NOT NULL DEFAULT 1,
      success_count INTEGER NOT NULL DEFAULT 1,
      confidence REAL NOT NULL DEFAULT 1.0,
      last_used_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE merchant_category_map(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      merchant TEXT NOT NULL UNIQUE,
      category TEXT NOT NULL,
      usage_count INTEGER NOT NULL DEFAULT 1,
      confidence REAL NOT NULL DEFAULT 1.0,
      last_used_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE user_corrections(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      field_name TEXT NOT NULL,
      original_value TEXT,
      corrected_value TEXT,
      correction_date TEXT NOT NULL,
      sms_text TEXT,
      feedback_type TEXT NOT NULL
    )
  ''');

  return db;
}

/// Minimal SMS transaction used across tests.
model.Transaction _makeTx({String? merchant}) => model.Transaction(
      id: 1,
      accountId: 1,
      amount: 100.0,
      date: DateTime.now(),
      type: 'expense',
      category: 'Other',
      sourceType: 'sms',
      smsSource: 'Test SMS',
      merchant: merchant ?? 'TestMerchant',
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
  });

  // ── 1. Merchant correction writes a row to merchant_normalization_rules ───
  test('learnFromCorrection_merchant_writesRow', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    final tx = _makeTx(merchant: 'AMZN MKTPLACE');

    await TransactionFeedbackService.recordCorrection(
      transaction: tx,
      fieldName: 'merchant',
      originalValue: 'AMZN MKTPLACE',
      correctedValue: 'Amazon',
    );

    final rows = await db.query(
      'merchant_normalization_rules',
      where: 'raw_pattern = ?',
      whereArgs: ['amzn mktplace'],
    );

    expect(rows, hasLength(1));
    expect(rows.first['normalized_name'], equals('Amazon'));
  });

  // ── 2. Short correctedValue (length ≤ 2) writes no row ───────────────────
  test('learnFromCorrection_shortValue_noWrite', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    final tx = _makeTx();

    await TransactionFeedbackService.recordCorrection(
      transaction: tx,
      fieldName: 'merchant',
      originalValue: 'SomeMerchant',
      correctedValue: 'ab', // length 2 — should be rejected
    );

    final normRows = await db.query('merchant_normalization_rules');
    final catRows = await db.query('merchant_category_map');

    expect(normRows, isEmpty);
    expect(catRows, isEmpty);
  });

  // ── 3. Invalid token as correctedValue writes no row ─────────────────────
  test('learnFromCorrection_invalidToken_noWrite', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    final tx = _makeTx();

    // 'account' is in _invalidLearningTokens
    await TransactionFeedbackService.recordCorrection(
      transaction: tx,
      fieldName: 'merchant',
      originalValue: 'SomeMerchant',
      correctedValue: 'account',
    );

    final rows = await db.query('merchant_normalization_rules');
    expect(rows, isEmpty);
  });

  // ── 4. lookupMerchantCategory returns the learned category ───────────────
  test('lookupMerchantCategory_returnsLearnedCategory', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    // Pre-insert a mapping
    await db.insert('merchant_category_map', {
      'merchant': 'Starbucks',
      'category': 'Food & Drink',
      'usage_count': 1,
      'confidence': 1.0,
      'last_used_at': DateTime.now().toIso8601String(),
    });

    final category =
        await TransactionFeedbackService.lookupMerchantCategory('Starbucks');

    expect(category, equals('Food & Drink'));
  });

  // ── 5. deleteMerchantNormalizationRule removes the row ───────────────────
  test('deleteMerchantNormRule_removesRow', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    // Insert a rule
    await db.insert('merchant_normalization_rules', {
      'raw_pattern': 'swgy',
      'normalized_name': 'Swiggy',
      'usage_count': 1,
      'success_count': 1,
      'confidence': 1.0,
      'last_used_at': DateTime.now().toIso8601String(),
    });

    // Verify it exists
    final before = await db.query(
      'merchant_normalization_rules',
      where: 'raw_pattern = ?',
      whereArgs: ['swgy'],
    );
    expect(before, hasLength(1));

    // Delete it
    await TransactionFeedbackService.deleteMerchantNormalizationRule('swgy');

    // Verify it's gone
    final after = await db.query(
      'merchant_normalization_rules',
      where: 'raw_pattern = ?',
      whereArgs: ['swgy'],
    );
    expect(after, isEmpty);
  });

  // ── 6. deleteCategoryMapping removes the row ─────────────────────────────
  test('deleteCategoryMapping_removesRow', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    // Insert a mapping
    await db.insert('merchant_category_map', {
      'merchant': 'Netflix',
      'category': 'Entertainment',
      'usage_count': 1,
      'confidence': 1.0,
      'last_used_at': DateTime.now().toIso8601String(),
    });

    // Verify it exists
    final before = await db.query(
      'merchant_category_map',
      where: 'merchant = ?',
      whereArgs: ['Netflix'],
    );
    expect(before, hasLength(1));

    // Delete it
    await TransactionFeedbackService.deleteCategoryMapping('Netflix');

    // Verify it's gone
    final after = await db.query(
      'merchant_category_map',
      where: 'merchant = ?',
      whereArgs: ['Netflix'],
    );
    expect(after, isEmpty);
  });
}
