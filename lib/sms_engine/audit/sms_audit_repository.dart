import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/probability/sms_probability_engine.dart';
import 'package:pocket_flow/sms_engine/stability/sms_stability_guard.dart';

/// An immutable snapshot of all signals that drove one pipeline decision.
///
/// Every field mirrors a column in `sms_audit_log`. The model is intentionally
/// flat (no nested objects) so it is cheap to serialise and replay.
class SmsAuditRecord {
  const SmsAuditRecord({
    required this.id,
    required this.eventId,
    this.clusterId,
    this.transactionId,
    required this.senderKnown,
    required this.patternCacheHit,
    required this.senderPrior,
    required this.clusterPosterior,
    required this.signalScore,
    required this.accountScore,
    required this.probScore,
    this.derivedFrom,
    required this.stabilityThreat,
    required this.needsReview,
    required this.pipelineVersion,
    required this.createdAt,
  });

  final int id;
  final int eventId;
  final int? clusterId;
  final int? transactionId;

  /// Whether the sender was registered in `sms_keywords` at processing time.
  final bool senderKnown;

  /// Whether `sms_pattern_cache` held an entry for this template hash.
  final bool patternCacheHit;

  // ── Phase 4 signal components ─────────────────────────────────────────────
  final double senderPrior;
  final double clusterPosterior;
  final double signalScore;
  final double accountScore;

  /// Final composite probability from [SmsProbabilityEngine].
  final double probScore;

  /// Human-readable label of the dominant signal (from [SmsProbabilityScore.derivedFrom]).
  final String? derivedFrom;

  // ── Phase 5 stability assessment ──────────────────────────────────────────
  /// Name of the [StabilityThreat] enum value (`'none'`, `'temporalBurst'`, …).
  final String stabilityThreat;

  /// Whether the transaction was flagged for user review.
  final bool needsReview;

  /// Semver-style label of the pipeline version that produced this record.
  /// Used to filter replay results when the logic changes.
  final String pipelineVersion;

  final DateTime createdAt;

  factory SmsAuditRecord.fromMap(Map<String, dynamic> m) => SmsAuditRecord(
        id: m['id'] as int,
        eventId: m['event_id'] as int,
        clusterId: m['cluster_id'] as int?,
        transactionId: m['transaction_id'] as int?,
        senderKnown: (m['sender_known'] as int) == 1,
        patternCacheHit: (m['pattern_cache_hit'] as int) == 1,
        senderPrior: (m['sender_prior'] as num).toDouble(),
        clusterPosterior: (m['cluster_posterior'] as num).toDouble(),
        signalScore: (m['signal_score'] as num).toDouble(),
        accountScore: (m['account_score'] as num).toDouble(),
        probScore: (m['prob_score'] as num).toDouble(),
        derivedFrom: m['derived_from'] as String?,
        stabilityThreat: m['stability_threat'] as String,
        needsReview: (m['needs_review'] as int) == 1,
        pipelineVersion: m['pipeline_version'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Phase 6 — Replay / Audit.
///
/// Writes an [SmsAuditRecord] to `sms_audit_log` after every pipeline run that
/// reaches the Phase 4/5 decision point. The log is append-only — records are
/// never updated or deleted.
///
/// ### Replay
/// The log enables offline replay: query all audit records for a given date
/// range and re-run them through a newer pipeline version to compare decisions.
/// See [queryByDateRange] and [queryByEventId].
///
/// ### Retention
/// Audit records are lightweight (~200 bytes each) and grow at one row per
/// processed SMS. No automatic pruning is implemented — add a periodic job at
/// the app layer if storage becomes a concern.
class SmsAuditRepository {
  /// Semver label embedded in every audit record. Bump this when the Phase 4/5
  /// logic changes so replay queries can isolate records from old behaviour.
  static const String pipelineVersion = '6.0.0';

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Insert an audit record for one pipeline run.
  ///
  /// - [eventId]      — `sms_events.id` for this raw message.
  /// - [clusterId]    — `sms_clusters.id` (null for brand-new clusters).
  /// - [transactionId]— `transactions.id` if a transaction was created.
  /// - [probScore]    — Phase 4 [SmsProbabilityScore].
  /// - [stability]    — Phase 5 [StabilityAssessment].
  /// - [needsReview]  — final pipeline decision.
  static Future<int> insert({
    required int eventId,
    int? clusterId,
    int? transactionId,
    required bool senderKnown,
    required bool patternCacheHit,
    required SmsProbabilityScore probScore,
    required StabilityAssessment stability,
    required bool needsReview,
  }) async {
    final db = await AppDatabase.db();
    final id = await db.insert('sms_audit_log', {
      'event_id':          eventId,
      'cluster_id':        clusterId,
      'transaction_id':    transactionId,
      'sender_known':      senderKnown ? 1 : 0,
      'pattern_cache_hit': patternCacheHit ? 1 : 0,
      'sender_prior':      probScore.senderPrior,
      'cluster_posterior': probScore.clusterPosterior,
      'signal_score':      probScore.signalScore,
      'account_score':     probScore.accountScore,
      'prob_score':        probScore.score,
      'derived_from':      probScore.derivedFrom,
      'stability_threat':  stability.threat.name,
      'needs_review':      needsReview ? 1 : 0,
      'pipeline_version':  pipelineVersion,
      'created_at':        DateTime.now().toIso8601String(),
    });

    AppLogger.sms(
      'AuditLog: record written',
      detail: 'auditId=$id eventId=$eventId txId=$transactionId '
          'prob=${probScore.score.toStringAsFixed(3)} '
          'threat=${stability.threat.name} review=$needsReview',
    );

    return id;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetch the single audit record for [eventId], if one exists.
  static Future<SmsAuditRecord?> queryByEventId(int eventId) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_audit_log',
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SmsAuditRecord.fromMap(rows.first);
  }

  /// Fetch all audit records for a given [transactionId].
  ///
  /// A transaction may have multiple records if it was re-processed (e.g. after
  /// a replay run). Records are ordered newest-first.
  static Future<List<SmsAuditRecord>> queryByTransactionId(int transactionId) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_audit_log',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SmsAuditRecord.fromMap).toList();
  }

  /// Fetch all audit records in a date window (inclusive), ordered
  /// oldest-first. Useful for batch replay and regression analysis.
  ///
  /// [from] and [to] are compared against the `created_at` column.
  static Future<List<SmsAuditRecord>> queryByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_audit_log',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return rows.map(SmsAuditRecord.fromMap).toList();
  }

  /// Count audit records that matched a specific [stabilityThreat] within
  /// the given date window. Used for dashboards and health checks.
  static Future<int> countByThreat(
    String stabilityThreat, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase.db();
    final whereArgs = <dynamic>[stabilityThreat];
    var where = 'stability_threat = ?';
    if (from != null) {
      where += ' AND created_at >= ?';
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      where += ' AND created_at <= ?';
      whereArgs.add(to.toIso8601String());
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM sms_audit_log WHERE $where',
      whereArgs,
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Count how many records were flagged `needs_review = 1` within the window.
  static Future<int> countNeedsReview({DateTime? from, DateTime? to}) async {
    final db = await AppDatabase.db();
    final whereArgs = <dynamic>[1];
    var where = 'needs_review = ?';
    if (from != null) {
      where += ' AND created_at >= ?';
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      where += ' AND created_at <= ?';
      whereArgs.add(to.toIso8601String());
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM sms_audit_log WHERE $where',
      whereArgs,
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
