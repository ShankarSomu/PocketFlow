import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/cluster/sms_cluster_memory.dart';
import 'package:pocket_flow/sms_engine/probability/sms_probability_engine.dart';

/// Classification of a detected stability threat.
///
/// Ordered from lowest to highest severity. [StabilityThreat.none] means the
/// cluster is healthy and no extra action is required.
enum StabilityThreat {
  /// Cluster is healthy.
  none,

  /// The cluster has not produced an observation in over 90 days.
  /// Its historical confidence may no longer reflect current sender behaviour.
  staleKnowledge,

  /// The cluster has accumulated many observations but still cannot converge
  /// on a single outcome — the template is structurally ambiguous.
  frequentDispute,

  /// The Phase 4 probability score diverges significantly from the cluster's
  /// stored historical confidence. This suggests the rule engine is seeing
  /// something the cluster's summary statistics do not capture — either a new
  /// variant of the template or an adversarially crafted message.
  confidenceDivergence,

  /// A high volume of SMS from this template arrived within a very short time
  /// window. Natural transaction SMS is sporadic; a burst may indicate synthetic
  /// flooding intended to rapidly push a cluster to `known` status.
  temporalBurst,
}

/// The result of a stability assessment for one SMS event.
///
/// The pipeline uses [forceReview] to decide whether to override Phase 4's
/// `requiresReview` determination — if [forceReview] is `true`, the created
/// transaction must be flagged for user review regardless of confidence score.
class StabilityAssessment {
  const StabilityAssessment({
    required this.threat,
    required this.forceReview,
    required this.reason,
  });

  /// The most severe threat detected (or [StabilityThreat.none]).
  final StabilityThreat threat;

  /// Whether this assessment overrides Phase 4's review decision.
  /// Always `false` when [threat] is [StabilityThreat.none].
  final bool forceReview;

  /// Human-readable explanation for logging and audit.
  final String reason;

  bool get isHealthy => threat == StabilityThreat.none;

  @override
  String toString() =>
      'StabilityAssessment(threat=${threat.name}, '
      'forceReview=$forceReview, reason=$reason)';
}

/// Phase 5 — Adversarial / Stability Guard.
///
/// Assesses the trustworthiness of an [SmsCluster] immediately before the
/// pipeline commits a transaction.  All analysis runs on fields already
/// present in [SmsCluster] and [SmsProbabilityScore] — no additional DB
/// queries are required.
///
/// ### Design goals
///
/// 1. **Adversarial resilience** — detect attempts to force rapid cluster
///    promotion through synthetic message flooding.
/// 2. **Statistical stability** — flag clusters that have seen many
///    contradictory outcomes and cannot converge.
/// 3. **Temporal awareness** — downgrade confidence in clusters that have gone
///    stale (not seen in > 90 days).
/// 4. **Signal coherence** — detect when Phase 4's composite score diverges
///    significantly from the cluster's long-run historical confidence, which
///    can indicate a new sub-variant of the template or a crafted anomaly.
///
/// ### Threat hierarchy
///
/// When multiple threats are present, the most severe one is reported. Severity
/// order (highest first):
/// ```
/// temporalBurst > confidenceDivergence > frequentDispute > staleKnowledge
/// ```
///
/// All threats except [StabilityThreat.none] set [StabilityAssessment.forceReview].
///
/// ### Tuning
///
/// The detection thresholds are exposed as public constants so they can be
/// adjusted in integration tests (Phase 5 test suite) without modifying logic.
class SmsStabilityGuard {
  // ── Thresholds — public for testability ────────────────────────────────────

  /// Maximum acceptable messages-per-day rate for a brand-new cluster.
  /// Exceeding this while [burstWindowDays] is also breached triggers
  /// [StabilityThreat.temporalBurst].
  static const double burstRateThreshold = 20.0; // msgs/day

  /// Minimum cluster age (in days) before burst detection is meaningful.
  /// Clusters younger than this that also exceed [burstRateThreshold] are
  /// flagged as potential floods.
  static const double burstWindowDays = 2.0;

  /// Minimum disagreement (messages seen) before [StabilityThreat.frequentDispute]
  /// is raised on a `disputed` cluster.
  static const int frequentDisputeMinSamples = 5;

  /// Maximum number of days since `last_seen` before a `known` cluster is
  /// considered stale.
  static const int staleKnowledgeDays = 90;

  /// The minimum absolute difference between [SmsProbabilityScore.score] and
  /// [SmsCluster.confidence] that triggers [StabilityThreat.confidenceDivergence].
  /// Only evaluated for `known` clusters with ≥ [SmsClusterMemory.minSamples]
  /// confirmed outcomes, so the historical confidence is meaningful.
  static const double divergenceThreshold = 0.35;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Assess the stability of [cluster] given the Phase 4 [probScore].
  ///
  /// Returns [StabilityAssessment.isHealthy] == true when no threat is found.
  /// Returns the most severe threat otherwise, always with [forceReview] = true.
  static StabilityAssessment assess(
    SmsCluster cluster,
    SmsProbabilityScore probScore,
  ) {
    final now = DateTime.now();

    // ── 1. Temporal burst ────────────────────────────────────────────────────
    // Risk: adversary floods the system with synthetic messages to rapidly
    // build a `known` cluster, then exploits the fast-path.
    final ageDays = now.difference(cluster.firstSeen).inHours / 24.0;
    if (ageDays < burstWindowDays && ageDays > 0) {
      final rate = cluster.matchCount / ageDays;
      if (rate > burstRateThreshold) {
        final assessment = StabilityAssessment(
          threat: StabilityThreat.temporalBurst,
          forceReview: true,
          reason: 'temporalBurst: ${rate.toStringAsFixed(1)} msgs/day '
              'over ${ageDays.toStringAsFixed(1)} days '
              '(threshold: $burstRateThreshold)',
        );
        _log(cluster, assessment);
        return assessment;
      }
    }

    // ── 2. Confidence divergence ─────────────────────────────────────────────
    // Risk: a new sub-variant of a known template is being misclassified with
    // inflated confidence because the cluster's summary matches the template hash.
    if (cluster.isKnown && cluster.confirmedCount >= SmsClusterMemory.minSamples) {
      final delta = (probScore.score - cluster.confidence).abs();
      if (delta > divergenceThreshold) {
        final assessment = StabilityAssessment(
          threat: StabilityThreat.confidenceDivergence,
          forceReview: true,
          reason: 'confidenceDivergence: probScore=${probScore.score.toStringAsFixed(3)} '
              'clusterConf=${cluster.confidence.toStringAsFixed(3)} '
              'delta=${delta.toStringAsFixed(3)} '
              '(threshold: $divergenceThreshold)',
        );
        _log(cluster, assessment);
        return assessment;
      }
    }

    // ── 3. Frequent dispute ──────────────────────────────────────────────────
    // Risk: an inherently ambiguous template that will never converge, causing
    // repeated false confirmations or missed transactions.
    if (cluster.status == 'disputed' &&
        cluster.matchCount >= frequentDisputeMinSamples) {
      final assessment = StabilityAssessment(
        threat: StabilityThreat.frequentDispute,
        forceReview: true,
        reason: 'frequentDispute: status=disputed matchCount=${cluster.matchCount} '
            '(min: $frequentDisputeMinSamples) '
            'conf=${cluster.confidence.toStringAsFixed(2)}',
      );
      _log(cluster, assessment);
      return assessment;
    }

    // ── 4. Stale knowledge ───────────────────────────────────────────────────
    // Risk: a `known` cluster that has not been exercised in months may have
    // drifted — the sender may have changed their template format.
    if (cluster.isKnown) {
      final daysSinceSeen = now.difference(cluster.lastSeen).inDays;
      if (daysSinceSeen > staleKnowledgeDays) {
        final assessment = StabilityAssessment(
          threat: StabilityThreat.staleKnowledge,
          forceReview: true,
          reason: 'staleKnowledge: lastSeen=$daysSinceSeen days ago '
              '(threshold: $staleKnowledgeDays)',
        );
        _log(cluster, assessment);
        return assessment;
      }
    }

    return const StabilityAssessment(
      threat: StabilityThreat.none,
      forceReview: false,
      reason: 'healthy',
    );
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  static void _log(SmsCluster cluster, StabilityAssessment assessment) {
    AppLogger.sms(
      'StabilityGuard: threat=${assessment.threat.name}',
      detail: 'hash=${cluster.templateHash.substring(0, 6)} '
          'sender=${cluster.sender} ${assessment.reason}',
      level: LogLevel.warning,
    );
  }
}
