import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/repositories/signal_weight_repository.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/account/sms_account_resolver.dart';
import 'package:pocket_flow/sms_engine/cluster/sms_cluster_memory.dart';
import 'package:pocket_flow/sms_engine/models/sms_types.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_entity_extractor.dart';
import 'package:sqflite/sqflite.dart';

/// The decomposed probability estimate for a single SMS event.
///
/// [score] is the final composite value in [0.0, 1.0]. All per-signal
/// components are preserved so Phase 5 (adversarial stability) and Phase 6
/// (replay / audit) can inspect exactly which signals drove the outcome.
class SmsProbabilityScore {
  const SmsProbabilityScore({
    required this.score,
    required this.senderPrior,
    required this.clusterPosterior,
    required this.signalScore,
    required this.accountScore,
    required this.patternCacheHit,
    required this.derivedFrom,
  });

  /// Final composite probability — this is what the pipeline uses as
  /// `confidenceScore` on the created [Transaction].
  final double score;

  /// P(financial | sender) — 0.90 when the sender is in `sms_keywords`,
  /// 0.30 otherwise (weak uninformed prior).
  final double senderPrior;

  /// P(transaction_type | template) — from [SmsCluster.confidence] when the
  /// cluster is `known`, from [SmsClassification.confidence] for `learning`
  /// clusters, or a mid-point blend for `disputed` ones.
  final double clusterPosterior;

  /// Weighted sum of entity-presence signals (amount, account, bank, merchant,
  /// strong classification), loaded from `signal_weights` and optionally
  /// boosted by a pattern-cache hit.
  final double signalScore;

  /// P(account resolved) — [AccountResolution.confidence] from the resolver.
  final double accountScore;

  /// Whether `sms_pattern_cache` contained an entry for this template hash.
  final bool patternCacheHit;

  /// Short human-readable string that describes which evidence dominated.
  final String derivedFrom;

  /// Score meets the auto-confirm bar — no user review required.
  bool get isHighConfidence =>
      score >= SmsProbabilityEngine.thresholdAutoConfirm;

  /// Score is below the review threshold — flag the transaction for user review.
  bool get requiresReview => score < SmsProbabilityEngine.thresholdReview;

  @override
  String toString() =>
      'score=${score.toStringAsFixed(3)} '
      'sender=${senderPrior.toStringAsFixed(2)} '
      'cluster=${clusterPosterior.toStringAsFixed(2)} '
      'signal=${signalScore.toStringAsFixed(2)} '
      'account=${accountScore.toStringAsFixed(2)} '
      'cache=$patternCacheHit '
      'from=$derivedFrom';
}

/// Phase 4 — Probability Engine.
///
/// Replaces the ad-hoc `blendedConfidence` formula in [SmsPipelineExecutor]
/// with a calibrated, multi-signal composite score that is **cluster-aware**.
///
/// ### Signal channels
///
/// | Channel            | Weight key          | Default |
/// |--------------------|---------------------|---------|
/// | Sender prior       | `p_engine_w_prior`  | 0.20    |
/// | Likelihood (cluster × signals) | `p_engine_w_likelihood` | 0.55 |
/// | Account posterior  | `p_engine_w_update` | 0.25    |
///
/// The channel weights are stored in `signal_weights` so they can be adjusted
/// by Phase 5 feedback or manual tuning without a code change.
///
/// ### Decision thresholds
///
/// | Level        | Value | Outcome                     |
/// |--------------|-------|-----------------------------|
/// | Auto-confirm | 0.85  | Save transaction, no review |
/// | Review       | 0.70  | Save transaction, needs_review=true |
/// | Pending      | <0.70 | Route to pending_actions    |
///
/// These mirror [ConfidenceScoring] thresholds so existing UI logic is
/// unaffected.
class SmsProbabilityEngine {
  // ── Public thresholds ────────────────────────────────────────────────────
  static const double thresholdAutoConfirm = 0.85;
  static const double thresholdReview      = 0.70;

  // ── Signal-weight row keys ───────────────────────────────────────────────
  static const String _kWPrior      = 'p_engine_w_prior';
  static const String _kWLikelihood = 'p_engine_w_likelihood';
  static const String _kWUpdate     = 'p_engine_w_update';

  static const double _defaultWPrior      = 0.20;
  static const double _defaultWLikelihood = 0.55;
  static const double _defaultWUpdate     = 0.25;

  // ── Sender prior values ──────────────────────────────────────────────────
  static const double _knownSenderPrior   = 0.90;
  static const double _unknownSenderPrior = 0.30;

  // ── Pattern-cache signal boost ───────────────────────────────────────────
  static const double _patternCacheBonus = 0.05;

  static final _weightRepo = SignalWeightRepository();

  // ── Public API ───────────────────────────────────────────────────────────

  /// Compute the probability score for a transaction-class SMS.
  ///
  /// - [senderKnown]     — whether the sender is registered in `sms_keywords`
  /// - [cluster]         — Phase 2 cluster for this template hash
  /// - [classification]  — outcome of the rule engine (or cluster fast-path)
  /// - [entities]        — entities extracted from the SMS body
  /// - [resolution]      — account resolution result
  /// - [patternCacheHit] — whether `sms_pattern_cache` holds this template
  static Future<SmsProbabilityScore> compute({
    required bool senderKnown,
    required SmsCluster cluster,
    required SmsClassification classification,
    required ExtractedEntities entities,
    required AccountResolution resolution,
    required bool patternCacheHit,
  }) async {
    final weights = await _weightRepo.getWeights();

    // ── 1. Sender prior ────────────────────────────────────────────────────
    final senderPrior =
        senderKnown ? _knownSenderPrior : _unknownSenderPrior;

    // ── 2. Cluster posterior ───────────────────────────────────────────────
    final double clusterPosterior;
    switch (cluster.status) {
      case 'known':
        // The cluster has seen ≥3 confirmed examples — use its calibrated
        // confidence directly.
        clusterPosterior = cluster.confidence;
      case 'disputed':
        // Disagreement detected; blend toward maximum uncertainty (0.5).
        clusterPosterior = (cluster.confidence + 0.5) / 2.0;
      default: // 'learning' — not enough observations yet
        // Fall back to the rule engine's own confidence estimate.
        clusterPosterior = classification.confidence;
    }

    // ── 3. Signal score ────────────────────────────────────────────────────
    // Entity-presence weighted sum, adapted by signal_weights feedback.
    final rawSignalScore = _computeSignalScore(weights, entities, classification);
    final signalScore = patternCacheHit
        ? (rawSignalScore + _patternCacheBonus).clamp(0.0, 1.0)
        : rawSignalScore;

    // ── 4. Account posterior ───────────────────────────────────────────────
    final accountScore = resolution.confidence;

    // ── 5. Combination ─────────────────────────────────────────────────────
    // Posterior = wP × prior + wL × (cluster × signals) + wU × account
    final wPrior      = weights[_kWPrior]      ?? _defaultWPrior;
    final wLikelihood = weights[_kWLikelihood] ?? _defaultWLikelihood;
    final wUpdate     = weights[_kWUpdate]     ?? _defaultWUpdate;

    final likelihood = (clusterPosterior * 0.5 + signalScore * 0.5);
    final rawScore =
        wPrior * senderPrior + wLikelihood * likelihood + wUpdate * accountScore;
    final score = rawScore.clamp(0.0, 1.0);

    // Derive a human-readable label for the dominant signal.
    final derivedFrom = _dominantSignal(
      cluster: cluster,
      senderKnown: senderKnown,
      patternCacheHit: patternCacheHit,
    );

    final result = SmsProbabilityScore(
      score: score,
      senderPrior: senderPrior,
      clusterPosterior: clusterPosterior,
      signalScore: signalScore,
      accountScore: accountScore,
      patternCacheHit: patternCacheHit,
      derivedFrom: derivedFrom,
    );

    AppLogger.sms('ProbabilityEngine', detail: result.toString());

    return result;
  }

  /// Query `sms_pattern_cache` for a template hash and return whether it is
  /// present and active. Called by the pipeline before [compute].
  static Future<bool> checkPatternCache(String templateHash) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_pattern_cache',
      columns: ['id'],
      where: 'pattern_signature = ? AND is_active = 1',
      whereArgs: [templateHash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Query `sms_keywords` to determine whether a sender is known.
  /// Returns `true` if an active entry exists for the sender.
  ///
  /// Used by the pipeline to obtain [senderKnown] for [compute].
  static Future<bool> checkSenderKnown(String sender) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_keywords',
      columns: ['id'],
      where: 'keyword = ? AND is_active = 1',
      whereArgs: [sender],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Seed probability-engine combination weights into `signal_weights` using
  /// `INSERT OR IGNORE` so existing tuned values are not overwritten.
  ///
  /// Call once during app initialisation (after [AppDatabase] is open).
  static Future<void> ensureWeightDefaults() async {
    final db = await AppDatabase.db();
    for (final entry in {
      _kWPrior:      _defaultWPrior,
      _kWLikelihood: _defaultWLikelihood,
      _kWUpdate:     _defaultWUpdate,
    }.entries) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO signal_weights(signal, weight) VALUES(?, ?)',
        [entry.key, entry.value],
      );
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  static double _computeSignalScore(
    Map<String, double> weights,
    ExtractedEntities entities,
    SmsClassification classification,
  ) {
    double score = 0.0;
    if (entities.amount != null) {
      score += weights['has_amount'] ?? 0.40;
    }
    if (entities.accountIdentifier != null) {
      score += weights['has_account'] ?? 0.20;
    }
    if (entities.institutionName != null) {
      score += weights['has_bank'] ?? 0.10;
    }
    if (entities.merchant != null) {
      score += weights['has_merchant'] ?? 0.10;
    }
    if (classification.confidence > 0.8) {
      score += weights['has_transaction_verb'] ?? 0.20;
    }
    return score.clamp(0.0, 1.0);
  }

  static String _dominantSignal({
    required SmsCluster cluster,
    required bool senderKnown,
    required bool patternCacheHit,
  }) {
    if (cluster.isKnown) {
      return 'cluster_known(${cluster.templateHash.substring(0, 6)})';
    }
    if (patternCacheHit) return 'pattern_cache_hit';
    if (senderKnown)     return 'sender_known';
    return 'body_signals';
  }
}
