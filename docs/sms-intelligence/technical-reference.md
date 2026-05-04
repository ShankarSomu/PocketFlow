# SMS Intelligence Layer — Technical Reference

> **Version**: 6.0.0  
> **Last updated**: Phase 6 (Replay / Audit)  
> **DB version**: 30

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Database Schema](#database-schema)
4. [Phase 1 — SMS Ledger](#phase-1--sms-ledger)
5. [Phase 2 — Cluster Memory](#phase-2--cluster-memory)
6. [Phase 3 — Propagation](#phase-3--propagation)
7. [Phase 4 — Probability Engine](#phase-4--probability-engine)
8. [Phase 5 — Stability Guard](#phase-5--stability-guard)
9. [Phase 6 — Replay / Audit](#phase-6--replay--audit)
10. [Pipeline Execution Flow](#pipeline-execution-flow)
11. [Configuration & Thresholds](#configuration--thresholds)

---

## Architecture Overview

```
Raw SMS
  │
  ▼
Privacy Gate ──────────► discard personal (non-financial)
  │
  ▼
SmsNormalizer  (normalize + dedup hash + template hash)
  │
  ▼
SmsClusterMemory  (lookup / create cluster)
  │
  ▼
SmsEventRepository  (insert immutable raw event)
  │
  ▼
_runPipeline
  ├── SmsClassificationService  (rule-based type detection)
  ├── SmsEntityExtractor         (amount / account / merchant)
  ├── SmsAccountResolver         (match to known account)
  ├── SmsProbabilityEngine       (Phase 4 composite score)
  └── SmsStabilityGuard          (Phase 5 threat assessment)
        │
        ▼
  decision: create transaction / pending / skip
        │
        ▼
  SmsClusterMemory.recordOutcome (Phase 2 feedback loop)
  SmsEventRepository.updateStatus
  SmsAuditRepository.insert       (Phase 6 write)
        │
        ▼
  SmsClusterPropagator            (Phase 3 — on status transition)
```

Classification is **rule-based only** — no ML inference at runtime. The TFLite model files in `assets/ml/` are not loaded by the active pipeline.

---

## File Structure

```
lib/sms_engine/
├── ingestion/
│   ├── sms_normalizer.dart          # Phase 1 — normalize + hash
│   └── sms_event_repository.dart   # Phase 1 — raw event ledger
├── cluster/
│   ├── sms_cluster_memory.dart     # Phase 2 — cluster lifecycle
│   └── sms_cluster_propagator.dart # Phase 3 — push to live infra
├── probability/
│   └── sms_probability_engine.dart # Phase 4 — composite score
├── stability/
│   └── sms_stability_guard.dart    # Phase 5 — adversarial guard
├── audit/
│   └── sms_audit_repository.dart   # Phase 6 — replay log
├── pipeline/
│   └── sms_pipeline_executor.dart  # Main orchestrator
├── account/
│   └── sms_account_resolver.dart
├── parsing/
│   └── ...
├── rules/
│   └── ...
└── models/
    └── ...
```

---

## Database Schema

### `sms_events` (Phase 1)

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | autoincrement |
| `raw_body` | TEXT | original SMS text |
| `sender` | TEXT | originating address |
| `received_at` | TEXT | ISO-8601 |
| `content_hash` | TEXT | SHA-256 of raw body + sender (dedup) |
| `status` | TEXT | `pending` / `processed` / `skipped` / `duplicate` |
| `transaction_id` | INTEGER | FK → transactions(id), set on success |
| `created_at` | TEXT | row insert time |

Index: `idx_sms_events_hash` on `(content_hash)`.

### `sms_clusters` (Phase 2)

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | autoincrement |
| `template_hash` | TEXT UNIQUE | SHA-256 of token-masked body + sender |
| `sender` | TEXT | |
| `normalized_body` | TEXT | token-masked body |
| `status` | TEXT | `learning` / `known` / `disputed` |
| `confidence` | REAL | current cluster confidence 0–1 |
| `match_count` | INTEGER | total messages matched |
| `confirmed_count` | INTEGER | outcomes recorded as confirmed transactions |
| `disputed_count` | INTEGER | disputed outcomes |
| `last_seen_at` | TEXT | ISO-8601 |
| `propagated_at` | TEXT | timestamp of last propagation push |
| `created_at` | TEXT | |

Indexes: `idx_sms_clusters_template`, `idx_sms_clusters_status`, `idx_sms_clusters_propagated`.

**Status transitions:**

```
total < 3                    → learning
conf ≥ 0.8 AND confirmed ≥ 3 → known
conf < 0.2                   → known  (reliably non-financial)
0.2 ≤ conf < 0.8, total ≥ 3  → disputed
```

### `sms_audit_log` (Phase 6)

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | autoincrement |
| `event_id` | INTEGER | FK → sms_events(id), NOT NULL |
| `cluster_id` | INTEGER | FK → sms_clusters(id) |
| `transaction_id` | INTEGER | FK → transactions(id) |
| `sender_known` | INTEGER | 0/1 |
| `pattern_cache_hit` | INTEGER | 0/1 |
| `sender_prior` | REAL | Phase 4 sender component |
| `cluster_posterior` | REAL | Phase 4 cluster component |
| `signal_score` | REAL | Phase 4 signal component |
| `account_score` | REAL | Phase 4 account component |
| `prob_score` | REAL | final composite probability |
| `derived_from` | TEXT | dominant signal label |
| `stability_threat` | TEXT | Phase 5 threat name |
| `needs_review` | INTEGER | 0/1 |
| `pipeline_version` | TEXT | semver, e.g. `6.0.0` |
| `created_at` | TEXT | ISO-8601 |

Indexes: `idx_sms_audit_event`, `idx_sms_audit_transaction`, `idx_sms_audit_created`.

Records are **append-only** — never updated or deleted.

---

## Phase 1 — SMS Ledger

**Files:** `sms_normalizer.dart`, `sms_event_repository.dart`

### SmsNormalizer

```dart
// Sanitize body (strip PII, control chars, excess whitespace)
final sanitized = SmsNormalizer.normalize(rawBody);

// Dedup hash — SHA-256(rawBody + sender). Identical if same message arrives twice.
final dedupeHash = SmsNormalizer.computeDedupeHash(sanitized, sender);

// Template hash — SHA-256(tokenMasked + sender). Identical for same template
// regardless of amount/date/account differences.
final templateHash = SmsNormalizer.computeHash(normalized, sender);
```

Token masking replaces numbers, amounts, dates, and account tokens with
placeholder strings, so `"Rs.1500 debited"` and `"Rs.2000 debited"` produce
the same template hash.

### SmsEventRepository

```dart
final eventId = await _eventRepo.insert(
  rawBody: body, sender: sender, receivedAt: receivedAt, contentHash: dedupeHash,
);
// Status transitions: pending → processed | skipped | duplicate
await _eventRepo.updateStatus(eventId, SmsEventStatus.processed, transactionId: id);
```

Dedup check: if `findIdByHash(dedupeHash)` returns a row the message is
`confirm_duplicate` and the pipeline aborts.

---

## Phase 2 — Cluster Memory

**File:** `sms_cluster_memory.dart`

```dart
final cluster = await SmsClusterMemory.lookupOrCreate(
  templateHash: templateHash,
  sender: sender,
  normalizedBody: normalizedBody,
);

// After pipeline decision:
await SmsClusterMemory.recordOutcome(
  templateHash: templateHash,
  transactionType: classification.type.name,
  confirmed: transactionId != null,
);
```

`recordHit()` increments `match_count` and `last_seen_at`.  
`recordOutcome()` updates `confidence` via exponential moving average and
may trigger a status transition → Phase 3 propagation.

**Confidence formula:**

```
confidence = (confirmedCount / total) with EMA smoothing
```

The `isKnown` getter returns `true` when `status == 'known' && confidence >= 0.8`.

---

## Phase 3 — Propagation

**File:** `sms_cluster_propagator.dart`

Triggered automatically when a cluster transitions to/from `known`:

- `propagateCluster(cluster)` — upserts sender into `sms_keywords`,
  upserts template hash into `sms_pattern_cache`, and reinforces
  `signal_weights` for the cluster's transaction type.

- `revokeCluster(cluster)` — soft-deactivates the `sms_keywords` /
  `sms_pattern_cache` rows by setting `is_active = 0`.

- `propagateAll()` — called once on startup, scans all `known` clusters and
  ensures their knowledge is present in live tables.

---

## Phase 4 — Probability Engine

**File:** `sms_probability_engine.dart`

### Algorithm

```
score = wPrior × senderPrior
      + wLikelihood × (clusterPosterior × 0.5 + signalScore × 0.5)
      + wUpdate × accountScore
```

Default weights (`signal_weights` table, seeded via `ensureWeightDefaults()`):

| Key | Default |
|-----|---------|
| `p_engine_w_prior` | 0.20 |
| `p_engine_w_likelihood` | 0.55 |
| `p_engine_w_update` | 0.25 |

### Signal Components

| Component | Source | Range |
|-----------|--------|-------|
| `senderPrior` | `sms_keywords` lookup | 0.0 – 1.0 |
| `clusterPosterior` | cluster status × confidence | 0.0 – 1.0 |
| `signalScore` | rule classification confidence | 0.0 – 1.0 |
| `accountScore` | account resolution quality | 0.0 – 1.0 |

**Cluster posterior mapping:**

| Status | Posterior |
|--------|-----------|
| `known` | `cluster.confidence` |
| `disputed` | `(cluster.confidence + 0.5) / 2` |
| `learning` | `classification.confidence` |

### SmsProbabilityScore

```dart
class SmsProbabilityScore {
  final double score;
  final double senderPrior;
  final double clusterPosterior;
  final double signalScore;
  final double accountScore;
  final bool patternCacheHit;
  final String? derivedFrom;

  bool get isHighConfidence => score >= 0.85;
  bool get requiresReview   => score < 0.70;
}
```

---

## Phase 5 — Stability Guard

**File:** `sms_stability_guard.dart`

Pure synchronous, zero DB queries. Evaluates four threats in priority order:

| Priority | Threat | Trigger |
|----------|--------|---------|
| 1 | `temporalBurst` | `matchCount/ageDays > 20.0` AND `ageDays < 2.0` |
| 2 | `confidenceDivergence` | `|probScore - cluster.confidence| > 0.35` AND cluster `isKnown` AND `confirmedCount >= 3` |
| 3 | `frequentDispute` | `cluster.status == 'disputed'` AND `matchCount >= 5` |
| 4 | `staleKnowledge` | cluster `isKnown` AND `daysSinceSeen > 90` |

Only the highest-priority detected threat is reported.  
`StabilityAssessment.forceReview` is `true` for all threats except `none`.

All thresholds are public constants on `SmsStabilityGuard`.

---

## Phase 6 — Replay / Audit

**File:** `sms_audit_repository.dart`

### Write

`SmsAuditRepository.insert()` is called in `processSms()` immediately after
`_eventRepo.updateStatus()`. It is only called for pipeline paths that reach
the Phase 4/5 decision point (transaction and unknown-financial paths). Non-
financial messages do not generate audit records.

```dart
await SmsAuditRepository.insert(
  eventId: eventId,
  clusterId: cluster.id,
  transactionId: result.transactionId,
  senderKnown: audit.senderKnown,
  patternCacheHit: audit.patternCacheHit,
  probScore: audit.probScore,
  stability: audit.stability,
  needsReview: audit.needsReview,
);
```

### Read / Replay

```dart
// Single event
final record = await SmsAuditRepository.queryByEventId(eventId);

// All records for a transaction
final records = await SmsAuditRepository.queryByTransactionId(txId);

// Date-window batch for replay
final batch = await SmsAuditRepository.queryByDateRange(from, to);

// Health-check counts
final burstCount = await SmsAuditRepository.countByThreat('temporalBurst', from: weekAgo);
final reviewCount = await SmsAuditRepository.countNeedsReview(from: weekAgo);
```

### Replay Workflow

1. Query `queryByDateRange(from, to)` for a time window.
2. For each `SmsAuditRecord`, re-fetch the original SMS body from `sms_events`.
3. Run through a new pipeline version.
4. Compare `probScore`, `stabilityThreat`, and `needsReview` to the archived record.
5. Use `pipeline_version` to filter records produced by a specific algorithm version.

---

## Pipeline Execution Flow

```
SmsPipelineExecutor.processSms(sms)
  1. Privacy gate (non-financial → discard)
  2. SmsNormalizer.normalize()
  3. SmsNormalizer.computeDedupeHash() → dedup check
  4. SmsNormalizer.computeHash()       → template hash
  5. SmsClusterMemory.lookupOrCreate()
  6. SmsEventRepository.insert()       → eventId
  7. _runPipeline()
     a. SmsClassificationService.classify()
     b. Route: transaction / balance / OTP / promotional / unknown-financial
     c. [transaction / unknown-financial path]
        i.  SmsEntityExtractor.extract()
        ii. SmsAccountResolver.resolve()
        iii.SmsProbabilityEngine.compute()   → SmsProbabilityScore
        iv. SmsStabilityGuard.assess()       → StabilityAssessment
        v.  needsReview = probScore.requiresReview || noAccount || stability.forceReview
        vi. AppDatabase.insertTransaction()  → transactionId
        vii.return SmsProcessingResult with _SmsAuditContext
  8. SmsClusterMemory.recordOutcome()
  9. SmsEventRepository.updateStatus()
  10.SmsAuditRepository.insert()        ← Phase 6
```

---

## Configuration & Thresholds

| Constant | Location | Value | Meaning |
|----------|----------|-------|---------|
| `ConfidenceScoring.high` | `confidence_scoring.dart` | 0.85 | Auto-accept threshold |
| `ConfidenceScoring.medium` | `confidence_scoring.dart` | 0.70 | Review boundary |
| `ConfidenceScoring.low` | `confidence_scoring.dart` | 0.50 | Minimum useful signal |
| `SmsProbabilityScore.isHighConfidence` | Phase 4 | ≥ 0.85 | Maps to `high` |
| `SmsProbabilityScore.requiresReview` | Phase 4 | < 0.70 | Maps to below `medium` |
| `SmsStabilityGuard.temporalBurstRatePerDay` | Phase 5 | 20.0 | msgs/day for burst |
| `SmsStabilityGuard.temporalBurstMaxAgeDays` | Phase 5 | 2.0 | age window for burst |
| `SmsStabilityGuard.confidenceDivergenceThreshold` | Phase 5 | 0.35 | |
| `SmsStabilityGuard.frequentDisputeMinMatches` | Phase 5 | 5 | |
| `SmsStabilityGuard.staleKnowledgeDays` | Phase 5 | 90 | |
| `SmsAuditRepository.pipelineVersion` | Phase 6 | `6.0.0` | Bump on logic changes |
