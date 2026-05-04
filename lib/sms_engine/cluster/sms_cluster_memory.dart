import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/services/app_logger.dart';
// Propagator is imported lazily via a deferred reference to avoid a circular
// import. The import is kept at the top but the call is gated on status change.
import 'package:pocket_flow/sms_engine/cluster/sms_cluster_propagator.dart';

/// A cluster represents a group of structurally-identical SMS messages.
///
/// Two messages are "structurally identical" when their token-masked bodies
/// (via [SmsNormalizer.computeHash]) produce the same hash — i.e., the text
/// is the same template differing only in amounts, dates, or account numbers.
class SmsCluster {
  const SmsCluster({
    required this.id,
    required this.templateHash,
    required this.sender,
    required this.normalizedBody,
    this.transactionType,
    this.institution,
    required this.matchCount,
    required this.confirmedCount,
    required this.rejectedCount,
    required this.confidence,
    required this.status,
    required this.firstSeen,
    required this.lastSeen,
    this.propagatedAt,
  });

  final int id;
  final String templateHash;
  final String sender;

  /// Canonical (token-masked) body stored for human inspection.
  final String normalizedBody;

  /// The transaction type this cluster produces. Null while still learning.
  final String? transactionType;

  /// Inferred institution name (e.g. "Citi", "BofA"). Null until first outcome.
  final String? institution;

  final int matchCount;
  final int confirmedCount;
  final int rejectedCount;

  /// 0.0–1.0. Meaningful only when [matchCount] ≥ [SmsClusterMemory.minSamples].
  final double confidence;

  /// `learning` → not enough data.
  /// `known`    → high confidence, pipeline can fast-path.
  /// `disputed` → conflicting outcomes, needs human review.
  final String status;

  final DateTime firstSeen;
  final DateTime lastSeen;

  /// When this cluster's knowledge was last propagated to sms_keywords /
  /// sms_pattern_cache. Null means propagation is pending.
  final DateTime? propagatedAt;

  /// Whether this cluster has enough signal to shortcut the rule engine.
  bool get isKnown =>
      status == 'known' && confidence >= SmsClusterMemory.knownConfidenceThreshold;

  factory SmsCluster.fromMap(Map<String, dynamic> m) => SmsCluster(
        id: m['id'] as int,
        templateHash: m['template_hash'] as String,
        sender: m['sender'] as String,
        normalizedBody: m['normalized_body'] as String,
        transactionType: m['transaction_type'] as String?,
        institution: m['institution'] as String?,
        matchCount: m['match_count'] as int,
        confirmedCount: m['confirmed_count'] as int,
        rejectedCount: m['rejected_count'] as int,
        confidence: (m['confidence'] as num).toDouble(),
        status: m['status'] as String,
        firstSeen: DateTime.parse(m['first_seen'] as String),
        lastSeen: DateTime.parse(m['last_seen'] as String),
        propagatedAt: m['propagated_at'] != null
            ? DateTime.parse(m['propagated_at'] as String)
            : null,
      );
}

/// Phase 2 — Cluster Memory.
///
/// Builds a per-template memory by grouping structurally-identical SMS messages
/// and tracking how often each template leads to a confirmed transaction.
///
/// ### Lifecycle
/// 1. **lookupOrCreate** — called on every new SMS. Returns the existing cluster
///    or creates a new `learning` one.
/// 2. **recordHit** — increments [SmsCluster.matchCount] and updates
///    `last_seen`. Called for every SMS that matches an existing cluster,
///    including duplicates surfaced to the user.
/// 3. **recordOutcome** — called after the pipeline resolves. Updates
///    confirmed/rejected counts and recomputes confidence. Promotes the cluster
///    to `known` when confidence is high enough, or marks it `disputed` when
///    outcomes conflict.
///
/// ### Confidence and promotion
/// ```
/// confidence = confirmed / (confirmed + rejected)
/// status = 'known' when confidence ≥ 0.8 AND confirmed ≥ minSamples
/// status = 'disputed' when 0.2 < confidence < 0.8 AND total ≥ minSamples
/// ```
class SmsClusterMemory {
  static const int minSamples = 3;
  static const double knownConfidenceThreshold = 0.8;
  static const double _disputedUpperBound = 0.8;
  static const double _disputedLowerBound = 0.2;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns an existing cluster for [templateHash], or creates a new
  /// `learning` entry and returns it.
  static Future<SmsCluster> lookupOrCreate({
    required String templateHash,
    required String sender,
    required String normalizedBody,
  }) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_clusters',
      where: 'template_hash = ?',
      whereArgs: [templateHash],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return SmsCluster.fromMap(rows.first);
    }

    // New cluster — status starts as 'learning'.
    final now = DateTime.now().toIso8601String();
    await db.insert('sms_clusters', {
      'template_hash': templateHash,
      'sender': sender,
      'normalized_body': normalizedBody,
      'transaction_type': null,
      'institution': null,
      'match_count': 1,
      'confirmed_count': 0,
      'rejected_count': 0,
      'confidence': 0.0,
      'status': 'learning',
      'first_seen': now,
      'last_seen': now,
    });

    AppLogger.sms(
      'ClusterMemory: new cluster',
      detail: 'hash=${templateHash.substring(0, 8)}… sender=$sender',
    );

    final created = await db.query(
      'sms_clusters',
      where: 'template_hash = ?',
      whereArgs: [templateHash],
      limit: 1,
    );
    return SmsCluster.fromMap(created.first);
  }

  /// Increment the hit counter and update `last_seen` for an existing cluster.
  ///
  /// Call this for every SMS that matches a known template hash (including
  /// messages routed to the duplicate-confirmation flow).
  static Future<void> recordHit(String templateHash) async {
    final db = await AppDatabase.db();
    await db.rawUpdate(
      '''UPDATE sms_clusters
         SET match_count = match_count + 1,
             last_seen   = ?
         WHERE template_hash = ?''',
      [DateTime.now().toIso8601String(), templateHash],
    );
  }

  /// Record the outcome of a pipeline run for the given [templateHash].
  ///
  /// - [transactionType] — the resolved type string (e.g. `"transactionDebit"`)
  /// - [institution]     — optional institution name extracted from sender
  /// - [confirmed]       — `true` when a transaction row was created/confirmed;
  ///                       `false` when the pipeline decided non-financial or
  ///                       the user rejected the pending action.
  ///
  /// After updating counts this method recomputes [SmsCluster.confidence] and
  /// promotes the cluster to `known` or `disputed` as appropriate.
  static Future<void> recordOutcome({
    required String templateHash,
    required String transactionType,
    String? institution,
    required bool confirmed,
  }) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_clusters',
      where: 'template_hash = ?',
      whereArgs: [templateHash],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final current = SmsCluster.fromMap(rows.first);

    final newConfirmed =
        current.confirmedCount + (confirmed ? 1 : 0);
    final newRejected =
        current.rejectedCount + (confirmed ? 0 : 1);
    final total = newConfirmed + newRejected;

    final newConfidence =
        total == 0 ? 0.0 : newConfirmed / total;

    final newStatus = _computeStatus(
      confirmed: newConfirmed,
      total: total,
      confidence: newConfidence,
    );

    // Preserve the most-recently-seen transaction_type and institution.
    final newTxType = confirmed ? transactionType : (current.transactionType ?? transactionType);
    final newInstitution = institution ?? current.institution;

    await db.update(
      'sms_clusters',
      {
        'transaction_type': newTxType,
        'institution': newInstitution,
        'confirmed_count': newConfirmed,
        'rejected_count': newRejected,
        'confidence': newConfidence,
        'status': newStatus,
        'last_seen': DateTime.now().toIso8601String(),
      },
      where: 'template_hash = ?',
      whereArgs: [templateHash],
    );

    AppLogger.sms(
      'ClusterMemory: outcome recorded',
      detail: 'hash=${templateHash.substring(0, 8)}… status=$newStatus '
          'conf=${newConfidence.toStringAsFixed(2)} '
          'c=$newConfirmed r=$newRejected',
    );

    // ── Phase 3: Propagation ──────────────────────────────────────────────────
    final previousStatus = current.status;
    if (newStatus == 'known' && previousStatus != 'known') {
      // Cluster just became known — propagate to sms_keywords + pattern_cache.
      final updatedRows = await db.query(
        'sms_clusters',
        where: 'template_hash = ?',
        whereArgs: [templateHash],
        limit: 1,
      );
      if (updatedRows.isNotEmpty) {
        await SmsClusterPropagator.propagateCluster(
          SmsCluster.fromMap(updatedRows.first),
        );
      }
    } else if (newStatus == 'disputed' && previousStatus == 'known') {
      // Cluster was demoted — revoke propagated entries.
      final updatedRows = await db.query(
        'sms_clusters',
        where: 'template_hash = ?',
        whereArgs: [templateHash],
        limit: 1,
      );
      if (updatedRows.isNotEmpty) {
        await SmsClusterPropagator.revokeCluster(
          SmsCluster.fromMap(updatedRows.first),
        );
      }
    }
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  static String _computeStatus({
    required int confirmed,
    required int total,
    required double confidence,
  }) {
    if (total < minSamples) return 'learning';
    if (confidence >= _disputedUpperBound && confirmed >= minSamples) {
      return 'known';
    }
    if (confidence < _disputedLowerBound) {
      // Almost always rejected — treat as known non-financial.
      return 'known';
    }
    return 'disputed';
  }
}
