# Design Document: SMS Self-Learning System

## Overview

The SMS Self-Learning System upgrades PocketFlow's passive feedback loop into an active, on-device learning engine. Every user correction is immediately persisted as a reusable rule; every subsequent SMS parse consults those rules before falling back to static logic. The result is a system that improves merchant names, categories, and confidence scores automatically — with no external ML APIs and no cloud dependency.

The design completes the read-side of the existing write-side infrastructure. `TransactionFeedbackService` already writes corrections to `merchant_normalization_rules` and `merchant_category_map` (v21 migration). This feature adds:

1. **Fuzzy-matching read path** in `MerchantNormalizationService` — replaces the current substring scan with a proper Levenshtein-distance lookup against the DB-backed rule store.
2. **Category lookup integration** in `EntityExtractionService` — after merchant normalization, the canonical merchant name is used to look up a learned category.
3. **Signal weight persistence** via a new `SignalWeightRepository` and a new `signal_weights` DB table (v22 migration).
4. **Signal weight caching** in `SmsPipelineExecutor` — weights are loaded once per pipeline lifecycle and invalidated only on write.
5. **Rule reversibility** — explicit delete methods and low-confidence flagging.
6. **Learning safeguards** — already partially implemented; this design formalises the contract and adds the missing guard for category corrections.

### Design Goals

- Sub-50 ms end-to-end parse time (excluding cold-start DB I/O).
- Zero breaking changes to existing parsing behaviour when no rules are stored.
- All learning is local-first; no data leaves the device.
- Rules are reversible: users can delete or override any learned rule.

---

## Architecture

### Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SmsPipelineExecutor                          │
│  (orchestrator — owns signal weight cache)                          │
│                                                                     │
│  ① Privacy Filter → ② Classify → ③ Extract → ④ Normalize           │
│  → ⑤ Category Lookup → ⑥ Confidence (signal weights) → ⑦ Store     │
└──────┬──────────────────────┬──────────────────────┬───────────────┘
       │                      │                      │
       ▼                      ▼                      ▼
┌─────────────┐   ┌───────────────────────┐  ┌──────────────────────┐
│ EntityExtrac│   │ MerchantNormalization  │  │ SignalWeightRepository│
│ tionService │   │ Service               │  │ (new)                │
│ (Parser)    │   │ (upgraded with fuzzy) │  │                      │
│             │──▶│ 1. Exact DB lookup    │  │ read()  → weights    │
│ extracts:   │   │ 2. Fuzzy DB lookup    │  │ write() → DB + cache │
│  amount     │   │    (Levenshtein < 3)  │  │    invalidation      │
│  merchant   │   │ 3. Static alias map   │  └──────────┬───────────┘
│  account    │   │ 4. Raw fallback       │             │
│  institution│   └──────────┬────────────┘             │
└─────────────┘              │                          │
                             ▼                          ▼
                  ┌──────────────────────┐   ┌──────────────────────┐
                  │ TransactionFeedback  │   │     SQLite DB        │
                  │ Service              │   │                      │
                  │                     │   │ merchant_normalization│
                  │ write-side (exists) │   │ _rules               │
                  │ read-side (new):    │   │ merchant_category_map │
                  │  lookupMerchant     │   │ signal_weights (new) │
                  │  Normalization()    │   │ user_corrections     │
                  │  lookupMerchant     │   └──────────────────────┘
                  │  Category()         │
                  │  deleteMerchant     │
                  │  NormRule()         │
                  │  deleteCategoryMap()│
                  └─────────────────────┘
```

### Layered Placement

| Component | Layer | File |
|---|---|---|
| `SignalWeightRepository` | Data (new) | `lib/repositories/signal_weight_repository.dart` |
| `MerchantNormalizationService` | Business Logic (upgraded) | `lib/services/merchant_normalization_service.dart` |
| `TransactionFeedbackService` | Business Logic (read-side added) | `lib/services/transaction_feedback_service.dart` |
| `EntityExtractionService` | Business Logic (category lookup added) | `lib/services/entity_extraction_service.dart` |
| `SmsPipelineExecutor` | Business Logic (signal weight cache added) | `lib/services/sms_pipeline_executor.dart` |
| DB migration v22 | Data | `lib/db/database.dart` |

---

## Components and Interfaces

### 1. SignalWeightRepository (new)

Owns all reads and writes to the `signal_weights` table. Maintains an in-memory cache that is invalidated on every write.

```dart
/// Default signal weights used when the table is empty.
const Map<String, double> kDefaultSignalWeights = {
  'has_amount':           0.40,
  'has_account':          0.20,
  'has_bank':             0.10,
  'has_merchant':         0.10,
  'has_transaction_verb': 0.20,
};

class SignalWeightRepository {
  static Map<String, double>? _cache;

  /// Returns current weights. Reads from DB on first call; returns cache thereafter.
  Future<Map<String, double>> getWeights() async { ... }

  /// Updates a single signal weight and invalidates the cache.
  Future<void> updateWeight(String signal, double newWeight) async { ... }

  /// Applies a ±0.01 delta to each signal present in [presentSignals].
  /// [positive] = true for thumbs-up / confirmation, false for thumbs-down / dispute.
  Future<void> applyFeedback({
    required Set<String> presentSignals,
    required bool positive,
  }) async { ... }

  /// Seeds default weights if the table is empty.
  Future<void> ensureDefaults() async { ... }

  /// Invalidates the in-memory cache (called after any write).
  void _invalidateCache() { _cache = null; }
}
```

**Cache strategy**: `_cache` is a static nullable `Map<String, double>`. It is populated on the first `getWeights()` call and set to `null` by `_invalidateCache()` after every `updateWeight()` or `applyFeedback()` call. This ensures O(1) reads for the common case (no feedback between parses) while guaranteeing freshness after any write.

---

### 2. MerchantNormalizationService (upgraded)

Adds a DB-backed fuzzy lookup on top of the existing static alias map. The lookup order is:

1. **Exact DB match** — query `merchant_normalization_rules` where `raw_pattern = lower(input)` AND `confidence >= 0.6`.
2. **Fuzzy DB match** — scan all rules with `confidence >= 0.6`; apply the rule with the smallest Levenshtein distance < 3 (ties broken by highest `confidence`, then `usage_count`).
3. **Static alias map** — existing `_merchantAliases` dictionary.
4. **Raw fallback** — return the input unchanged.

The existing `_levenshteinDistance` method is already implemented in `MerchantNormalizationService`. It will be promoted to a `static` public method and used by the new DB lookup path.

```dart
/// Result of a merchant normalization lookup.
class NormalizationResult {
  final String normalizedName;
  final double? ruleConfidence; // null if no DB rule was applied
  final bool fromLearnedRule;
}

class MerchantNormalizationService {
  /// Public Levenshtein distance (already exists, promoted to public).
  static int levenshteinDistance(String a, String b) { ... }

  /// Full lookup pipeline: DB exact → DB fuzzy → static alias → raw.
  static Future<NormalizationResult> lookupWithResult(String rawMerchant) async { ... }

  /// Convenience wrapper returning just the name (backward-compatible).
  static Future<String> lookup(String rawMerchant) async { ... }
}
```

**Performance**: The exact-match query uses the `idx_merchant_norm_rules_pattern` index (O(log n)). The fuzzy scan is O(n) over rules with `confidence >= 0.6`. With 10,000 rules and the Levenshtein DP running on strings of average length ~15, the scan completes in < 50 ms on a mid-range Android device (each comparison is O(|a|×|b|) ≈ 225 ops; 10,000 × 225 = 2.25M ops, well within budget).

**Short-string guard**: If `rawMerchant.trim().length < 3`, fuzzy matching is skipped entirely and the raw string is returned.

---

### 3. TransactionFeedbackService (read-side additions)

The existing `lookupMerchantNormalization` method performs an exact match then a substring scan. This is replaced by delegating to `MerchantNormalizationService.lookupWithResult()`, which adds the proper fuzzy path.

New public methods added:

```dart
/// Delete a merchant normalization rule by raw pattern.
static Future<void> deleteMerchantNormalizationRule(String rawPattern) async { ... }

/// Delete a merchant → category mapping.
static Future<void> deleteCategoryMapping(String merchant) async { ... }
```

The existing `lookupMerchantCategory` method is retained unchanged (it already queries `merchant_category_map` with `confidence >= 0.6`).

The existing `_learnFromCorrection` method gains one additional guard: if `correctedValue.trim().length <= 2` it returns early (this guard already exists for the merchant path but is missing for the category path — this design adds it).

---

### 4. EntityExtractionService (category lookup integration)

After merchant normalization, the canonical merchant name is passed to `TransactionFeedbackService.lookupMerchantCategory()`. If a learned category is found, it is stored on the `ExtractedEntities` object and used by the pipeline instead of the static default.

```dart
// In extract() — after merchant normalization:
String? learnedCategory;
if (merchant != null) {
  learnedCategory = await TransactionFeedbackService.lookupMerchantCategory(merchant);
}

return ExtractedEntities(
  ...
  learnedCategory: learnedCategory, // new field
);
```

`ExtractedEntities` gains a `learnedCategory` field. `SmsPipelineExecutor._processTransaction()` uses `learnedCategory ?? _getDefaultCategory(...)` when building the `Transaction`.

The confidence boost from a learned normalization rule is applied inside `EntityExtractionService.extract()`:

```dart
if (normResult.fromLearnedRule && normResult.ruleConfidence != null) {
  confidence = (confidence + 0.2 * normResult.ruleConfidence!).clamp(0.0, 1.0);
}
```

---

### 5. SmsPipelineExecutor (signal weight integration)

The pipeline gains a `SignalWeightRepository` dependency (injected or accessed as a singleton). Signal weights are loaded once per `processSms()` call via `getWeights()` (which returns the cache on subsequent calls within the same batch).

The confidence formula changes from the current hardcoded weights to:

```dart
final weights = await _signalWeightRepo.getWeights();

double confidence = 0.0;
if (amount != null)      confidence += weights['has_amount']!;
if (accountId != null)   confidence += weights['has_account']!;
if (institution != null) confidence += weights['has_bank']!;
if (merchant != null)    confidence += weights['has_merchant']!;
if (hasTransactionVerb)  confidence += weights['has_transaction_verb']!;
confidence = confidence.clamp(0.0, 1.0);
```

The `needsReview` flag is set according to the thresholds already defined in `ConfidenceScoring`:

| Confidence | `needsReview` |
|---|---|
| >= 0.85 | `false` (auto-approve) |
| 0.70 – 0.84 | `false` (medium — UI shows indicator) |
| < 0.70 | `true` |

Positive/negative feedback triggers `SignalWeightRepository.applyFeedback()` with the set of signals that were present in the transaction.

---

## Data Models

### New Table: `signal_weights` (v22 migration)

```sql
CREATE TABLE signal_weights (
  id     INTEGER PRIMARY KEY AUTOINCREMENT,
  signal TEXT    NOT NULL UNIQUE,
  weight REAL    NOT NULL
);

-- Seeded on first run:
INSERT INTO signal_weights (signal, weight) VALUES
  ('has_amount',           0.40),
  ('has_account',          0.20),
  ('has_bank',             0.10),
  ('has_merchant',         0.10),
  ('has_transaction_verb', 0.20);
```

No index is needed — the table has at most 5 rows and is always read in full.

### Existing Table: `merchant_normalization_rules` (v21, unchanged schema)

```sql
CREATE TABLE merchant_normalization_rules (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  raw_pattern     TEXT    NOT NULL UNIQUE,   -- lowercased, trimmed
  normalized_name TEXT    NOT NULL,
  usage_count     INTEGER NOT NULL DEFAULT 1,
  success_count   INTEGER NOT NULL DEFAULT 1,
  confidence      REAL    NOT NULL DEFAULT 1.0,  -- success_count / usage_count
  last_used_at    TEXT    NOT NULL
);
CREATE INDEX idx_merchant_norm_rules_pattern
  ON merchant_normalization_rules(raw_pattern);
```

### Existing Table: `merchant_category_map` (v21, unchanged schema)

```sql
CREATE TABLE merchant_category_map (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant     TEXT    NOT NULL UNIQUE,
  category     TEXT    NOT NULL,
  usage_count  INTEGER NOT NULL DEFAULT 1,
  confidence   REAL    NOT NULL DEFAULT 1.0,  -- usage_count / (usage_count + 1), clamped [0.5, 1.0]
  last_used_at TEXT    NOT NULL
);
CREATE INDEX idx_merchant_category_map_merchant
  ON merchant_category_map(merchant);
```

### Updated Model: `ExtractedEntities`

```dart
class ExtractedEntities {
  // ... existing fields ...
  final String? learnedCategory;  // NEW: category from merchant_category_map
}
```

### Signal Presence Detection

The pipeline determines which signals are present by inspecting `ExtractedEntities`:

| Signal | Present when |
|---|---|
| `has_amount` | `entities.amount != null` |
| `has_account` | `entities.accountIdentifier != null` |
| `has_bank` | `entities.institutionName != null` |
| `has_merchant` | `entities.merchant != null` |
| `has_transaction_verb` | `classification.isHighConfidence` (proxy for strong verb match) |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Merchant correction round-trip

*For any* valid merchant correction (non-empty, non-invalid-token, trimmed length > 2), after calling `_learnFromCorrection()` with `fieldName = 'merchant'`, querying `merchant_normalization_rules` for the lowercased `raw_pattern` SHALL return a row whose `normalized_name` equals the corrected value.

**Validates: Requirements 1.1, 1.2, 8.3**

---

### Property 2: Correction count invariant

*For any* existing merchant normalization rule with `usage_count = u` and `success_count = s`, after one additional correction for the same `raw_pattern`, the rule SHALL have `usage_count = u + 1`, `success_count = s + 1`, and `confidence = (s + 1) / (u + 1)` clamped to [0.0, 1.0].

**Validates: Requirements 1.2**

---

### Property 3: Short-value safeguard

*For any* string whose trimmed length is 0, 1, or 2, calling `_learnFromCorrection()` with that string as `correctedValue` SHALL NOT write any row to `merchant_normalization_rules` or `merchant_category_map`.

**Validates: Requirements 1.3, 6.1**

---

### Property 4: Invalid-token safeguard

*For any* token that is an element of `_invalidLearningTokens`, calling `_learnFromCorrection()` with that token as either `rawPattern` or `correctedValue` SHALL NOT write any row to the database, and SHALL NOT throw an exception.

**Validates: Requirements 1.4, 6.2, 6.4**

---

### Property 5: Exact-match lookup round-trip

*For any* merchant normalization rule stored in the database with `confidence >= 0.6`, calling `MerchantNormalizationService.lookup()` with the exact `raw_pattern` (in any case) SHALL return the rule's `normalized_name`.

**Validates: Requirements 2.1**

---

### Property 6: Fuzzy-match lookup

*For any* raw merchant string `m` and any stored rule with `raw_pattern = p` and `confidence >= 0.6`, if `levenshteinDistance(lower(m), lower(p)) < 3` and `lower(m) != lower(p)`, then `MerchantNormalizationService.lookup(m)` SHALL return the rule's `normalized_name`.

**Validates: Requirements 2.2, 5.2**

---

### Property 7: Confidence boost from learned rule

*For any* base confidence value `c` in [0.0, 1.0] and any rule confidence `r` in [0.0, 1.0], when a learned normalization rule with confidence `r` is applied during parsing, the resulting confidence SHALL equal `(c + 0.2 * r).clamp(0.0, 1.0)`.

**Validates: Requirements 2.3**

---

### Property 8: No-match passthrough

*For any* merchant string that has no matching rule in `merchant_normalization_rules` (neither exact nor fuzzy), `MerchantNormalizationService.lookup()` SHALL return the input string unchanged.

**Validates: Requirements 2.4**

---

### Property 9: Category correction round-trip

*For any* valid category correction (non-empty merchant, non-invalid-token, trimmed length > 2), after calling `_learnFromCorrection()` with `fieldName = 'category'`, querying `merchant_category_map` for the merchant SHALL return a row whose `category` equals the corrected value.

**Validates: Requirements 3.1, 3.3**

---

### Property 10: Category confidence invariant

*For any* existing category mapping with `usage_count = u`, after one additional correction for the same merchant, the mapping SHALL have `usage_count = u + 1` and `confidence = (u + 1) / (u + 2)` clamped to [0.5, 1.0].

**Validates: Requirements 3.2**

---

### Property 11: Signal weight feedback invariant

*For any* signal weight `w` in [0.0, 1.0] and any feedback direction (positive or negative), after applying feedback, the new weight SHALL equal `(w + 0.01).clamp(0.0, 1.0)` for positive feedback and `(w - 0.01).clamp(0.0, 1.0)` for negative feedback.

**Validates: Requirements 4.2, 4.3**

---

### Property 12: Confidence is weighted sum of present signals

*For any* combination of present signals and their corresponding weights from `signal_weights`, the computed `confidence_score` SHALL equal the sum of the weights of all present signals, clamped to [0.0, 1.0].

**Validates: Requirements 4.4**

---

### Property 13: Levenshtein distance properties

*For any* two strings `a` and `b`:
- `levenshteinDistance(a, a) = 0` (identity)
- `levenshteinDistance(a, b) = levenshteinDistance(b, a)` (symmetry)
- `levenshteinDistance(a, c) <= levenshteinDistance(a, b) + levenshteinDistance(b, c)` (triangle inequality)

**Validates: Requirements 5.1**

---

### Property 14: Fuzzy rule selection — best confidence wins

*For any* set of fuzzy-matching rules (all with `levenshteinDistance < 3` and `confidence >= 0.6`), `MerchantNormalizationService.lookup()` SHALL return the `normalized_name` of the rule with the highest `confidence`; when confidence values are equal, the rule with the highest `usage_count` SHALL be selected.

**Validates: Requirements 5.3**

---

### Property 15: Low-confidence rules excluded from fuzzy matching

*For any* rule with `confidence < 0.6`, that rule SHALL never be returned by a fuzzy lookup, regardless of how small the Levenshtein distance is.

**Validates: Requirements 5.4**

---

### Property 16: Short merchant skips fuzzy matching

*For any* raw merchant string with `trimmed length < 3`, calling `MerchantNormalizationService.lookup()` SHALL return the raw string unchanged without performing any fuzzy scan.

**Validates: Requirements 5.5**

---

### Property 17: needsReview is determined by confidence thresholds

*For any* transaction confidence score `c` in [0.0, 1.0]:
- If `c >= 0.85`, `needsReview` SHALL be `false`.
- If `c < 0.70`, `needsReview` SHALL be `true`.
- If `0.70 <= c < 0.85`, `needsReview` SHALL be `false`.

**Validates: Requirements 7.2, 7.3, 7.4**

---

### Property 18: No-rule baseline preservation

*For any* SMS message processed when `merchant_normalization_rules`, `merchant_category_map`, and `signal_weights` are all empty, the pipeline output SHALL be identical to the pre-learning baseline (default weights, raw merchant name, static default category).

**Validates: Requirements 7.6**

---

### Property 19: Delete removes the rule

*For any* rule that exists in `merchant_normalization_rules` (or `merchant_category_map`), calling `deleteMerchantNormalizationRule(rawPattern)` (or `deleteCategoryMapping(merchant)`) SHALL result in that row no longer existing in the table.

**Validates: Requirements 8.1, 8.2**

---

### Property 20: Low-confidence rules are retained, not auto-deleted

*For any* rule whose `confidence` has dropped below 0.3 due to conflicting corrections, the rule SHALL still exist in `merchant_normalization_rules` (i.e., it is not automatically deleted).

**Validates: Requirements 8.4**

---

### Property 21: Signal weight cache consistency

*For any* sequence of `getWeights()` calls with no intervening `applyFeedback()` or `updateWeight()` calls, all calls SHALL return the same `Map<String, double>` instance (cache hit). After any write, the next `getWeights()` call SHALL fetch fresh data from the database.

**Validates: Requirements 9.4**

---

## Error Handling

### Safeguard Rejection (non-throwing)

All safeguard checks in `_learnFromCorrection()` log at debug level and return early without throwing. The calling code (`recordCorrection()`) continues normally. This ensures a bad user input never crashes the feedback flow.

```dart
if (correctedValue == null || correctedValue.trim().length <= 2) {
  AppLogger.log(LogLevel.debug, LogCategory.system,
    'learning_rejected', detail: 'value too short: "$correctedValue"');
  return;
}
```

### Database Errors

All DB operations in `SignalWeightRepository`, `TransactionFeedbackService`, and `MerchantNormalizationService` are wrapped in try/catch. On error:
- Reads fall back to defaults (signal weights → `kDefaultSignalWeights`; merchant lookup → raw string).
- Writes log the error at `LogLevel.error` and swallow the exception so the pipeline continues.

### Fuzzy Scan Timeout Guard

The fuzzy scan iterates over all rules with `confidence >= 0.6`. If the table grows beyond 10,000 rows, the scan could exceed 50 ms. A future mitigation is to limit the candidate set to the top-N rules by `usage_count DESC` (e.g., top 500). This is noted as a performance escape hatch but is not required for the initial implementation.

### Invalid Rule Update Guard

Before writing a `normalized_name` update, `_upsertMerchantNormalizationRule()` checks whether the new value is in `_invalidLearningTokens`. If it is, the update is skipped and the existing `normalized_name` is preserved (Requirement 6.5).

```dart
if (_invalidLearningTokens.contains(normalizedName.toLowerCase())) {
  AppLogger.log(LogLevel.debug, LogCategory.system,
    'learning_rejected', detail: 'normalized_name is invalid token: "$normalizedName"');
  return; // retain existing normalized_name
}
```

---

## Testing Strategy

### Unit Tests (example-based)

| Test | What it verifies |
|---|---|
| `learnFromCorrection_merchant_writesRow` | Req 1.1 — row is written with correct fields |
| `learnFromCorrection_shortValue_noWrite` | Req 1.3 — trimmed length ≤ 2 is rejected |
| `learnFromCorrection_invalidToken_noWrite` | Req 1.4 — invalid tokens are rejected |
| `lookupMerchantNormalization_exactMatch` | Req 2.1 — exact DB match returns normalized name |
| `lookupMerchantNormalization_noMatch_returnsRaw` | Req 2.4 — no match returns raw string |
| `lookupMerchantCategory_returnsLearnedCategory` | Req 3.3 — learned category is returned |
| `signalWeightRepo_defaultsSeeded` | Req 4.1 — defaults are seeded on empty table |
| `signalWeightRepo_fallbackOnEmpty` | Req 4.5 — empty table uses defaults without error |
| `pipeline_autoApprove_highConfidence` | Req 7.2 — needsReview=false when confidence >= 0.85 |
| `pipeline_requiresReview_lowConfidence` | Req 7.3 — needsReview=true when confidence < 0.70 |
| `deleteMerchantNormRule_removesRow` | Req 8.1 — delete removes the row |
| `deleteCategoryMapping_removesRow` | Req 8.2 — delete removes the row |

### Property-Based Tests

PBT is appropriate for this feature because the core logic consists of pure functions (Levenshtein distance, confidence formula, weight clamping) and DB round-trips whose correctness must hold across a wide input space.

**Library**: [`dart_test`](https://pub.dev/packages/test) with [`fast_check`](https://pub.dev/packages/fast_check) (Dart property-based testing library). Each property test runs a minimum of **100 iterations**.

**Tag format**: `// Feature: sms-self-learning, Property {N}: {property_text}`

| Property Test | Design Property | Generator |
|---|---|---|
| Merchant correction round-trip | Property 1 | Random (rawPattern, normalizedName) pairs passing safeguards |
| Correction count invariant | Property 2 | Random (usageCount, successCount) pairs |
| Short-value safeguard | Property 3 | Strings of length 0–2 (including whitespace-padded) |
| Invalid-token safeguard | Property 4 | Random elements from `_invalidLearningTokens` |
| Exact-match lookup round-trip | Property 5 | Random (pattern, normalizedName) pairs |
| Fuzzy-match lookup | Property 6 | Random strings with 1–2 character edits applied |
| Confidence boost formula | Property 7 | Random (baseConfidence, ruleConfidence) in [0.0, 1.0] |
| No-match passthrough | Property 8 | Random merchant strings with empty rule table |
| Category correction round-trip | Property 9 | Random (merchant, category) pairs |
| Category confidence invariant | Property 10 | Random usageCount values |
| Signal weight feedback invariant | Property 11 | Random weight values in [0.0, 1.0] |
| Confidence is weighted sum | Property 12 | Random signal presence bitmasks and weight maps |
| Levenshtein properties | Property 13 | Random string pairs |
| Fuzzy rule selection | Property 14 | Random sets of matching rules with varying confidence/usage_count |
| Low-confidence rules excluded | Property 15 | Rules with confidence in [0.0, 0.59] |
| Short merchant skips fuzzy | Property 16 | Strings of length 0–2 |
| needsReview thresholds | Property 17 | Random confidence values in [0.0, 1.0] |
| No-rule baseline preservation | Property 18 | Random SMS messages with empty rule tables |
| Delete removes rule | Property 19 | Random (pattern, normalizedName) pairs |
| Low-confidence rule retained | Property 20 | Rules driven below 0.3 via conflicting corrections |
| Cache consistency | Property 21 | Random sequences of read/write operations |

### Integration Tests

- **Performance benchmark**: Insert 10,000 rows into `merchant_normalization_rules`, measure exact-match and fuzzy-scan latency (Req 9.2, 9.3).
- **Index usage**: Use `EXPLAIN QUERY PLAN` to verify `idx_merchant_norm_rules_pattern` is used for exact-match queries (Req 9.1).
- **End-to-end pipeline**: Process a known SMS with pre-seeded rules, verify the full output (normalized merchant, learned category, signal-weight-based confidence, correct `needsReview` flag).
- **Async writes**: Verify `recordCorrection()` completes without blocking the calling isolate (Req 9.5).

---

## Requirement 10 Design: Learnable Financial Sender Gate

### Problem

`SmsClassificationService._isFinancialSender()` is a pure in-memory function. It checks a hardcoded regex (`_financialSenderPattern`) and a hardcoded body-keyword list. The `sms_keywords` table — which already contains seeded sender IDs including US numeric short codes — is never consulted. Messages from unknown senders are silently dropped before the feedback system can ever surface them to the user.

### Solution: Three-tier sender evaluation

```
Tier 1 (DB lookup)     → sms_keywords WHERE type='sender_pattern' AND confidence >= 0.6
                          → KNOWN: pass through, full classification
                          ↓ not found
Tier 2 (body signals)  → currency amount OR debit/credit/financial keyword in body
                          → UNKNOWN but financial: pass as unknownFinancial (confidence 0.40)
                          ↓ no signals
Tier 3 (static fallback) → hardcoded _financialSenderPattern regex + body keyword list
                          → match: pass through
                          → no match: drop as nonFinancial (existing behaviour)
```

### Component changes

#### `SmsClassificationService` (upgraded)

`_isFinancialSender()` becomes `async` and gains a DB lookup as Tier 1:

```dart
static Future<bool> _isFinancialSender(String sender, String body) async {
  // Tier 1: DB lookup — sms_keywords seeded + user-learned senders
  try {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_keywords',
      where: 'keyword = ? AND type = ? AND confidence >= 0.6',
      whereArgs: [sender, 'sender_pattern'],
      limit: 1,
    );
    if (rows.isNotEmpty) return true;
  } catch (_) { /* fall through */ }

  // Tier 2: body financial signals (unknown sender, permissive pass-through)
  if (_hasFinancialBodySignal(body)) return true;  // caller sets confidence 0.40

  // Tier 3: static fallback (first-install, no DB yet)
  if (_financialSenderPattern.hasMatch(sender)) return true;
  for (final inst in _financialInstitutions) {
    if (body.contains(inst)) return true;
  }

  return false;
}
```

Because `_isFinancialSender` becomes async, `classify()` must also become `async`:

```dart
static Future<SmsClassification> classify(RawSmsMessage sms) async { ... }
```

All callers of `classify()` in `SmsPipelineExecutor` already `await` the result, so no further changes are needed there.

**`_hasFinancialBodySignal(String body)`** — a new private helper that checks for:
- Any currency amount pattern: `$`, `Rs`, `₹`, `INR`, `USD` followed by digits or `X` (to handle masked training data)
- Any word from a minimal inline set: `['debited','credited','transaction','payment','balance','transfer','deposit','withdraw','charge']`

This is intentionally narrow — it is only a tiebreaker for unknown senders, not a full classification.

**Confidence signalling**: When Tier 2 fires (unknown sender, body signal only), `classify()` returns `SmsType.unknownFinancial` with `confidence = 0.40`. The pipeline already handles `unknownFinancial` by treating it as a debit and marking `needsReview = true`. No pipeline changes needed.

#### `TransactionFeedbackService` (upgraded)

`recordAccountConfirmation()` gains sender learning:

```dart
static Future<void> recordAccountConfirmation({
  required model.Transaction transaction,
  required bool confirmed,
  String? senderAddress,   // NEW optional param
}) async {
  // ... existing logic ...

  if (confirmed && senderAddress != null && senderAddress.isNotEmpty) {
    await _learnSender(senderAddress);
  }
}

static Future<void> _learnSender(String senderAddress) async {
  final db = await database;
  await db.insert(
    'sms_keywords',
    {
      'keyword': senderAddress,
      'type': 'sender_pattern',
      'region': null,
      'confidence': 1.0,
      'priority': 10,
      'is_active': 1,
      'usage_count': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    },
    conflictAlgorithm: ConflictAlgorithm.ignore, // don't overwrite existing
  );
}
```

### Data flow

```
SMS arrives (sender: "692484", body: "Citi Alert: A $XX.XX transaction was made at...")
  │
  ▼
_isFinancialSender("692484", body)
  │
  ├─ Tier 1: DB query sms_keywords WHERE keyword="692484" AND type="sender_pattern"
  │          → ROW FOUND (seeded at install) → return true
  │
  ▼
classify() → body has "transaction was made" → weakDebit + hasAmount → transactionDebit (0.70)
  │
  ▼
Pipeline processes normally → transaction created, needsReview=true (confidence < 0.85)
  │
  ▼
User confirms → recordAccountConfirmation(confirmed: true, senderAddress: "692484")
             → _learnSender("692484") → ConflictAlgorithm.ignore (already exists, no-op)
```

For a truly unknown sender (not in seed data):

```
SMS arrives (sender: "999999", body: "NewBank: $50.00 debited from your account")
  │
  ▼
_isFinancialSender("999999", body)
  │
  ├─ Tier 1: DB query → no row found
  ├─ Tier 2: body has "$50.00" + "debited" → _hasFinancialBodySignal = true → return true
  │
  ▼
classify() → hasDebit + hasAmount → transactionDebit (0.95)
           BUT: sender unknown → blended confidence will be lower → needsReview=true
  │
  ▼
User confirms → _learnSender("999999") → INSERT into sms_keywords
             → future messages from "999999" hit Tier 1 directly
```

### Correctness Properties (additions)

**Property 22: Known sender passes gate**
For any sender ID present in `sms_keywords` with `type = 'sender_pattern'` and `confidence >= 0.6`, `_isFinancialSender(sender, anyBody)` SHALL return `true`.

**Property 23: Unknown sender with body signal passes as unknownFinancial**
For any sender ID not in `sms_keywords` and any body containing a Financial_Body_Signal, `classify()` SHALL return a type other than `nonFinancial`.

**Property 24: Unknown sender without body signal is dropped**
For any sender ID not in `sms_keywords` and any body with no Financial_Body_Signal and no static fallback match, `classify()` SHALL return `nonFinancial`.

**Property 25: Sender confirmation persists to DB**
After `recordAccountConfirmation(confirmed: true, senderAddress: s)`, querying `sms_keywords` for `keyword = s` AND `type = 'sender_pattern'` SHALL return at least one row.

**Property 26: Sender rejection does not persist**
After `recordAccountConfirmation(confirmed: false, senderAddress: s)` where `s` was not previously in `sms_keywords`, querying `sms_keywords` for `keyword = s` AND `type = 'sender_pattern'` SHALL return no rows.

### Testing additions

| Test | What it verifies |
|---|---|
| `senderGate_knownSender_passes` | Req 10.1 — seeded sender ID passes gate |
| `senderGate_unknownSender_bodySignal_passesAsUnknown` | Req 10.2 — unknown sender + financial body → unknownFinancial |
| `senderGate_unknownSender_noSignal_drops` | Req 10.3 — unknown sender + no signal → nonFinancial |
| `senderConfirmation_learnsSender` | Req 10.4 — confirmation writes sender to sms_keywords |
| `senderRejection_doesNotLearnSender` | Req 10.5 — rejection does not write sender |
| `learnedSender_usesFullClassification` | Req 10.6 — confirmed sender gets full debit/credit classification |
