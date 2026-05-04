import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/repositories/signal_weight_repository.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/cluster/sms_cluster_memory.dart';
import 'package:sqflite/sqflite.dart';

/// Phase 3 — Propagation.
///
/// When a cluster is promoted to `known` status by [SmsClusterMemory], its
/// learned knowledge is pushed back into the live classification infrastructure:
///
/// 1. **`sms_keywords`** — the cluster's sender is registered as a
///    `sender_pattern`, so [SmsClassificationService._isKnownSender] returns
///    `true` for that sender from that point on. This prevents previously-
///    classified senders from being dropped as "unknown" after a fresh install
///    or on a new device that shares the same DB (cloud sync).
///
/// 2. **`sms_pattern_cache`** — the template hash is written as a
///    `pattern_signature` with the resolved transaction type. Future code that
///    queries this cache (e.g. Phase 4 probability engine) can retrieve the
///    learned type without re-running the rule engine.
///
/// 3. **Signal weights** — `has_amount` and `has_transaction_verb` are
///    reinforced by a small positive delta for confirmed financial clusters.
///    This calibrates the confidence scoring in [SmsPipelineExecutor._processTransaction].
///
/// Revocation: when a `known` cluster is demoted to `disputed`, the propagated
/// entries are soft-deactivated so the sender gate reverts to "unknown" and
/// the pattern cache no longer serves fast answers. `propagated_at` is cleared
/// so re-propagation fires when confidence recovers.
class SmsClusterPropagator {
  static final _signalWeightRepo = SignalWeightRepository();

  // Guard: run propagateAll only once per app session.
  static bool _startupScanDone = false;

  // Signals reinforced for any confirmed financial transaction.
  static const Set<String> _financialSignals = {
    'has_amount',
    'has_transaction_verb',
  };

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Propagate a single cluster that has just been promoted to `known`.
  ///
  /// Idempotent: if the cluster already has a [SmsCluster.propagatedAt] value
  /// (meaning it was propagated before and then revoked + repromotd), the
  /// sender keyword and pattern cache entries are simply re-activated rather
  /// than duplicated.
  static Future<void> propagateCluster(SmsCluster cluster) async {
    if (cluster.transactionType == null) return;
    final db = await AppDatabase.db();
    final now = DateTime.now();

    AppLogger.sms(
      'Propagator: propagating cluster',
      detail: 'hash=${cluster.templateHash.substring(0, 8)}… '
          'sender=${cluster.sender} type=${cluster.transactionType} '
          'conf=${cluster.confidence.toStringAsFixed(2)}',
    );

    await _upsertSenderKeyword(db, cluster.sender, now);
    await _upsertPatternCache(db, cluster, now);

    // Reinforce signal weights for confirmed financial clusters.
    final isConfirmedFinancial = cluster.confirmedCount > 0 &&
        cluster.transactionType != 'nonFinancial';
    if (isConfirmedFinancial) {
      await _signalWeightRepo.applyFeedback(
        presentSignals: _financialSignals,
        positive: true,
      );
      // If institution name is known, bank signal is present.
      if (cluster.institution != null) {
        await _signalWeightRepo.applyFeedback(
          presentSignals: const {'has_bank'},
          positive: true,
        );
      }
    }

    // Mark propagated_at so we don't re-propagate on the next scan.
    await db.update(
      'sms_clusters',
      {'propagated_at': now.toIso8601String()},
      where: 'template_hash = ?',
      whereArgs: [cluster.templateHash],
    );

    AppLogger.sms(
      'Propagator: done',
      detail: 'hash=${cluster.templateHash.substring(0, 8)}…',
    );
  }

  /// Revoke a cluster that has been demoted from `known` to `disputed`.
  ///
  /// Soft-deactivates the sender keyword and removes the pattern cache entry.
  /// Clears [SmsCluster.propagatedAt] so re-propagation fires when confidence
  /// recovers above the threshold.
  static Future<void> revokeCluster(SmsCluster cluster) async {
    final db = await AppDatabase.db();

    AppLogger.sms(
      'Propagator: revoking cluster',
      detail: 'hash=${cluster.templateHash.substring(0, 8)}… '
          'sender=${cluster.sender}',
    );

    // Deactivate the sender keyword so the sender gate reverts to "unknown".
    // Only deactivate rows with confidence = 0.8 (propagation-inserted rows)
    // so we don't touch manually seeded keywords with higher confidence.
    await db.update(
      'sms_keywords',
      {'is_active': 0},
      where: 'keyword = ? AND type = ? AND confidence <= 0.8',
      whereArgs: [cluster.sender, 'sender_pattern'],
    );

    // Remove the pattern cache entry so stale answers are not served.
    await db.delete(
      'sms_pattern_cache',
      where: 'pattern_signature = ?',
      whereArgs: [cluster.templateHash],
    );

    // Clear propagated_at so re-propagation fires on next promotion.
    await db.update(
      'sms_clusters',
      {'propagated_at': null},
      where: 'template_hash = ?',
      whereArgs: [cluster.templateHash],
    );

    AppLogger.sms(
      'Propagator: revocation complete',
      detail: 'hash=${cluster.templateHash.substring(0, 8)}…',
    );
  }

  /// Scan all `known` clusters whose `propagated_at IS NULL` and propagate
  /// them. Safe to call on every app start — clusters that are already
  /// propagated are skipped because their `propagated_at` is set.
  ///
  /// Only runs once per Dart isolate session (guarded by [_startupScanDone]).
  static Future<void> propagateAll() async {
    if (_startupScanDone) return;
    _startupScanDone = true;

    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_clusters',
      where: "status = 'known' AND propagated_at IS NULL",
    );

    if (rows.isEmpty) {
      AppLogger.sms('Propagator: nothing to propagate on startup');
      return;
    }

    AppLogger.sms(
      'Propagator: startup scan',
      detail: '${rows.length} unpropagated known clusters',
    );

    for (final row in rows) {
      final cluster = SmsCluster.fromMap(row);
      await propagateCluster(cluster);
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Upsert the sender into `sms_keywords` as a `sender_pattern` with
  /// `source = 'cluster_propagation'`.
  ///
  /// - If a matching row already exists (any source) and is active: no-op.
  /// - If a row exists but is inactive (revoked): re-activate it.
  /// - Otherwise: insert a new row.
  static Future<void> _upsertSenderKeyword(Database db, String sender, DateTime now) async {
    // Check for an existing row (any source) that covers this sender.
    final existing = await db.query(
      'sms_keywords',
      where: 'keyword = ? AND type = ?',
      whereArgs: [sender, 'sender_pattern'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      if ((row['is_active'] as int?) == 0) {
        // Re-activate a previously revoked row.
        await db.update(
          'sms_keywords',
          {'is_active': 1},
          where: 'keyword = ? AND type = ?',
          whereArgs: [sender, 'sender_pattern'],
        );
        AppLogger.sms('Propagator: re-activated sender keyword', detail: 'sender=$sender');
      }
      // Already active — nothing to do.
      return;
    }

    // Insert a new propagation-originated keyword.
    await db.insert(
      'sms_keywords',
      {
        'keyword': sender,
        'type': 'sender_pattern',
        'region': null,
        'confidence': 0.8,
        'priority': 1,
        'is_active': 1,
        'usage_count': 0,
        'created_at': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    AppLogger.sms('Propagator: inserted sender keyword', detail: 'sender=$sender');
  }

  /// Upsert the template hash into `sms_pattern_cache`.
  ///
  /// Stores the canonical masked body and resolved transaction type so future
  /// cache lookups can skip the classification step entirely.
  static Future<void> _upsertPatternCache(Database db, SmsCluster cluster, DateTime now) async {
    final nowMs = now.millisecondsSinceEpoch;
    final existing = await db.query(
      'sms_pattern_cache',
      where: 'pattern_signature = ?',
      whereArgs: [cluster.templateHash],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update the transaction type (in case it was refined) and bump hit count.
      await db.update(
        'sms_pattern_cache',
        {
          'transaction_type': cluster.transactionType,
          'hit_count': (existing.first['hit_count'] as int? ?? 0) + 1,
          'last_hit_at': nowMs,
        },
        where: 'pattern_signature = ?',
        whereArgs: [cluster.templateHash],
      );
    } else {
      await db.insert(
        'sms_pattern_cache',
        {
          'pattern_signature': cluster.templateHash,
          'category': null,
          'transaction_type': cluster.transactionType,
          'matched_rule_ids': null,
          'hit_count': cluster.matchCount,
          'last_hit_at': nowMs,
          'created_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    AppLogger.sms(
      'Propagator: pattern_cache upserted',
      detail: 'sig=${cluster.templateHash.substring(0, 8)}… type=${cluster.transactionType}',
    );
  }
}
