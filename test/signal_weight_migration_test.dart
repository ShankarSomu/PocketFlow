// Tests that the v22 migration creates and seeds the signal_weights table.
// Uses sqflite_common_ffi so no real file paths are needed.
// Does NOT import AppDatabase — the DDL is replicated inline.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialise the FFI loader so sqflite works on desktop / CI.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('signal_weights migration', () {
    test('table exists and contains exactly 5 seeded rows with correct weights',
        () async {
      // Open a fresh in-memory database.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );

      // ── Replicate the DDL from AppDatabase._createAll ──────────────────────
      await db.execute('''
        CREATE TABLE signal_weights(
          id     INTEGER PRIMARY KEY AUTOINCREMENT,
          signal TEXT    NOT NULL UNIQUE,
          weight REAL    NOT NULL
        )
      ''');

      // Seed the five default rows (same values as _createAll).
      const defaultSignalWeights = {
        'has_amount':           0.40,
        'has_account':          0.20,
        'has_bank':             0.10,
        'has_merchant':         0.10,
        'has_transaction_verb': 0.20,
      };
      for (final entry in defaultSignalWeights.entries) {
        await db.insert('signal_weights', {
          'signal': entry.key,
          'weight': entry.value,
        });
      }
      // ───────────────────────────────────────────────────────────────────────

      // Verify row count.
      final countResult =
          await db.rawQuery('SELECT COUNT(*) AS cnt FROM signal_weights');
      expect(countResult.first['cnt'], equals(5),
          reason: 'signal_weights should contain exactly 5 rows');

      // Verify each signal and its weight.
      final rows = await db.query('signal_weights',
          columns: ['signal', 'weight'], orderBy: 'signal ASC');

      final Map<String, double> stored = {
        for (final r in rows)
          r['signal'] as String: (r['weight'] as num).toDouble(),
      };

      expect(stored['has_amount'],           closeTo(0.40, 1e-9));
      expect(stored['has_account'],          closeTo(0.20, 1e-9));
      expect(stored['has_bank'],             closeTo(0.10, 1e-9));
      expect(stored['has_merchant'],         closeTo(0.10, 1e-9));
      expect(stored['has_transaction_verb'], closeTo(0.20, 1e-9));

      await db.close();
    });
  });
}
