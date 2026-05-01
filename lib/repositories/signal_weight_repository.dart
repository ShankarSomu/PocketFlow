import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Default signal weights used when the table is empty or on error.
const Map<String, double> kDefaultSignalWeights = {
  'has_amount':           0.40,
  'has_account':          0.20,
  'has_bank':             0.10,
  'has_merchant':         0.10,
  'has_transaction_verb': 0.20,
};

/// Owns all reads and writes to the [signal_weights] table.
///
/// Maintains an in-memory cache that is invalidated on every write, giving
/// O(1) reads for the common case (no feedback between parses) while
/// guaranteeing freshness after any write.
class SignalWeightRepository {
  // Static cache shared across all instances (singleton-style).
  static Map<String, double>? _cache;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns the current signal weights.
  ///
  /// On the first call the weights are read from the database and stored in
  /// [_cache].  Subsequent calls return the cached map directly.
  /// Falls back to [kDefaultSignalWeights] if the table is empty or on error.
  Future<Map<String, double>> getWeights() async {
    if (_cache != null) return _cache!;

    try {
      final db = await AppDatabase.db();
      final rows = await db.query(
        'signal_weights',
        columns: ['signal', 'weight'],
      );

      if (rows.isEmpty) {
        return kDefaultSignalWeights;
      }

      _cache = {
        for (final r in rows)
          r['signal']! as String: (r['weight']! as num).toDouble(),
      };
      return _cache!;
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'signal_weight_read_error',
        detail: e.toString(),
      );
      return kDefaultSignalWeights;
    }
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Updates a single signal weight in the database and invalidates the cache.
  Future<void> updateWeight(String signal, double newWeight) async {
    try {
      final db = await AppDatabase.db();
      await db.update(
        'signal_weights',
        {'weight': newWeight},
        where: 'signal = ?',
        whereArgs: [signal],
      );
      _invalidateCache();
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'signal_weight_update_error',
        detail: e.toString(),
      );
    }
  }

  /// Applies a ±0.01 delta to each signal in [presentSignals], clamped to
  /// [0.0, 1.0].
  ///
  /// [positive] = `true` for thumbs-up / confirmation,
  /// [positive] = `false` for thumbs-down / dispute.
  ///
  /// Invalidates the cache after all updates are applied.
  Future<void> applyFeedback({
    required Set<String> presentSignals,
    required bool positive,
  }) async {
    if (presentSignals.isEmpty) return;

    try {
      final db = await AppDatabase.db();
      final delta = positive ? 0.01 : -0.01;

      for (final signal in presentSignals) {
        // Read the current weight for this signal.
        final rows = await db.query(
          'signal_weights',
          columns: ['weight'],
          where: 'signal = ?',
          whereArgs: [signal],
        );
        if (rows.isEmpty) continue;

        final current = (rows.first['weight']! as num).toDouble();
        final updated = (current + delta).clamp(0.0, 1.0);

        await db.update(
          'signal_weights',
          {'weight': updated},
          where: 'signal = ?',
          whereArgs: [signal],
        );
      }

      _invalidateCache();
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'signal_weight_feedback_error',
        detail: e.toString(),
      );
    }
  }

  /// Seeds default weights using [ConflictAlgorithm.ignore].
  ///
  /// Safe to call multiple times — existing rows are left unchanged.
  Future<void> ensureDefaults() async {
    try {
      final db = await AppDatabase.db();
      for (final entry in kDefaultSignalWeights.entries) {
        await db.insert(
          'signal_weights',
          {'signal': entry.key, 'weight': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    } catch (e) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.database,
        'signal_weight_ensure_defaults_error',
        detail: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cache management
  // ---------------------------------------------------------------------------

  /// Invalidates the in-memory cache.  Called after every write.
  void _invalidateCache() {
    _cache = null;
  }
}
