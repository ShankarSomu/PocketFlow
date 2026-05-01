// Unit tests for EntityExtractionService.
//
// Uses sqflite_common_ffi to open a fresh in-memory database for each test,
// injected into AppDatabase via setDatabaseForTesting().
//
// These are integration-style tests that exercise the full extract() path
// including the DB-backed category lookup.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/sms_types.dart';
import 'package:pocket_flow/services/entity_extraction_service.dart';
import 'package:pocket_flow/services/transaction_feedback_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh in-memory database with the tables required by
/// [EntityExtractionService] and [TransactionFeedbackService].
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

  return db;
}

/// Builds a [SmsClassification] for a debit transaction with medium confidence.
SmsClassification _debitClassification() => SmsClassification(
      type: SmsType.transactionDebit,
      confidence: 0.75,
      reason: 'test',
    );

/// Builds a [RawSmsMessage] using a US-style body that the regex fallback
/// can parse (transaction_sms_parser will fail on it and fall through).
RawSmsMessage _usSms(String body) => RawSmsMessage(
      id: 0,
      sender: 'CHASE',
      body: body,
      timestamp: DateTime(2024, 1, 15, 10, 30),
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

  // ── 1. learnedCategory is populated when a mapping exists ─────────────────
  test('extract_appliesLearnedCategory', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    // Pre-seed a category mapping for "Starbucks"
    await db.insert('merchant_category_map', {
      'merchant': 'Starbucks',
      'category': 'Food & Drink',
      'usage_count': 1,
      'confidence': 1.0,
      'last_used_at': DateTime.now().toIso8601String(),
    });

    // US-style SMS — transaction_sms_parser will fail, regex fallback runs.
    // The regex "at MERCHANT" pattern will extract "Starbucks".
    final sms = _usSms('Your card was charged \$50.00 at Starbucks');
    final classification = _debitClassification();

    final result = await EntityExtractionService.extract(sms, classification);

    expect(result.learnedCategory, equals('Food & Drink'));
  });

  // ── 2. learnedCategory is null when no mapping exists ─────────────────────
  test('extract_noLearnedCategory_returnsNull', () async {
    final db = await _openDb();
    AppDatabase.setDatabaseForTesting(db);

    // Empty merchant_category_map — no mapping for any merchant.
    final sms = _usSms('Your card was charged \$50.00 at Starbucks');
    final classification = _debitClassification();

    final result = await EntityExtractionService.extract(sms, classification);

    expect(result.learnedCategory, isNull);
  });
}
