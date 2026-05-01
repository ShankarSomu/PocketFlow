// Unit tests for SignalWeightRepository.
//
// Uses sqflite_common_ffi to open a fresh in-memory database for each test
// group, injected into AppDatabase via setDatabaseForTesting().

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/repositories/signal_weight_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh in-memory database with the signal_weights table.
Future<Database> _openDb({bool createTable = true}) async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  if (createTable) {
    await db.execute('''
      CREATE TABLE signal_weights(
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        signal TEXT    NOT NULL UNIQUE,
        weight REAL    NOT NULL
      )
    ''');
  }
  return db;
}

/// Seeds the five default rows into [db].
Future<void> _seedDefaults(Database db) async {
  for (final entry in kDefaultSignalWeights.entries) {
    await db.insert('signal_weights', {
      'signal': entry.key,
      'weight': entry.value,
    });
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Reset the AppDatabase cache and the repository cache before every test.
  setUp(() {
    AppDatabase.resetForTesting();
  });

  tearDown(() async {
    // Close the injected database and clear both the AppDatabase cache and
    // the SignalWeightRepository static cache.
    try {
      final db = await AppDatabase.db();
      await db.close();
    } catch (_) {}
    AppDatabase.resetForTesting();

    // Clear the SignalWeightRepository._cache by performing a no-op write
    // against a fresh in-memory DB (the write fails silently but
    // _invalidateCache() is still called before the try/catch exits).
    // We open a minimal DB, inject it, call updateWeight, then close.
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
  });

  // ── 1. Empty table returns kDefaultSignalWeights ──────────────────────────
  test('signalWeightRepo_defaultsSeeded', () async {
    final db = await _openDb(); // table exists but is empty
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();
    final weights = await repo.getWeights();

    expect(weights, equals(kDefaultSignalWeights));
  });

  // ── 2. Missing table → no exception, returns defaults ────────────────────
  test('signalWeightRepo_fallbackOnEmpty', () async {
    final db = await _openDb(createTable: false); // no signal_weights table
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();
    // Should not throw; should return defaults.
    final weights = await repo.getWeights();

    expect(weights, equals(kDefaultSignalWeights));
  });

  // ── 3. updateWeight invalidates cache; next getWeights hits DB ────────────
  test('signalWeightRepo_updateWeight_invalidatesCache', () async {
    final db = await _openDb();
    await _seedDefaults(db);
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();

    // Prime the cache.
    final before = await repo.getWeights();
    expect(before['has_amount'], closeTo(0.40, 1e-9));

    // Update the weight.
    await repo.updateWeight('has_amount', 0.55);

    // Next call must reflect the new value (cache was invalidated).
    final after = await repo.getWeights();
    expect(after['has_amount'], closeTo(0.55, 1e-9));
  });

  // ── 4. Positive feedback increases weight by 0.01 ────────────────────────
  test('signalWeightRepo_applyFeedback_positive', () async {
    final db = await _openDb();
    await _seedDefaults(db);
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();

    await repo.applyFeedback(
      presentSignals: {'has_amount'},
      positive: true,
    );

    final weights = await repo.getWeights();
    // 0.40 + 0.01 = 0.41
    expect(weights['has_amount'], closeTo(0.41, 1e-9));
  });

  // ── 5. Negative feedback decreases weight by 0.01 ────────────────────────
  test('signalWeightRepo_applyFeedback_negative', () async {
    final db = await _openDb();
    await _seedDefaults(db);
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();

    await repo.applyFeedback(
      presentSignals: {'has_amount'},
      positive: false,
    );

    final weights = await repo.getWeights();
    // 0.40 - 0.01 = 0.39
    expect(weights['has_amount'], closeTo(0.39, 1e-9));
  });

  // ── 6. Weight at 1.0 stays at 1.0 after positive feedback (clamp max) ────
  test('signalWeightRepo_applyFeedback_clampMax', () async {
    final db = await _openDb();
    // Seed with weight = 1.0
    await db.insert('signal_weights', {'signal': 'has_amount', 'weight': 1.0});
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();

    await repo.applyFeedback(
      presentSignals: {'has_amount'},
      positive: true,
    );

    final weights = await repo.getWeights();
    expect(weights['has_amount'], closeTo(1.0, 1e-9));
  });

  // ── 7. Weight at 0.0 stays at 0.0 after negative feedback (clamp min) ────
  test('signalWeightRepo_applyFeedback_clampMin', () async {
    final db = await _openDb();
    // Seed with weight = 0.0
    await db.insert('signal_weights', {'signal': 'has_amount', 'weight': 0.0});
    AppDatabase.setDatabaseForTesting(db);

    final repo = SignalWeightRepository();

    await repo.applyFeedback(
      presentSignals: {'has_amount'},
      positive: false,
    );

    final weights = await repo.getWeights();
    expect(weights['has_amount'], closeTo(0.0, 1e-9));
  });
}
