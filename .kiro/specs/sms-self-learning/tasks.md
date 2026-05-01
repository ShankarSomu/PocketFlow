# Implementation Plan: SMS Self-Learning System

## Overview

Upgrade PocketFlow's passive feedback loop into an active, on-device learning engine. The implementation follows a bottom-up order: database foundation first, then the new repository, then service upgrades, then pipeline integration, and finally property-based tests.

All code is Dart/Flutter. The property-based test library is `fast_check` (already referenced in the design).

---

## Tasks

- [x] 1. Database migration v22 — add `signal_weights` table
  - [x] 1.1 Add v22 migration block to `lib/db/database.dart`
    - In `_init()`, bump `version` from `21` to `22`
    - In the `onUpgrade` handler, add `if (oldVersion < 22)` block that executes:
      ```sql
      CREATE TABLE IF NOT EXISTS signal_weights (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        signal TEXT    NOT NULL UNIQUE,
        weight REAL    NOT NULL
      );
      ```
    - Seed the five default rows (`has_amount 0.40`, `has_account 0.20`, `has_bank 0.10`, `has_merchant 0.10`, `has_transaction_verb 0.20`) inside the same migration block using `db.insert`
    - _Requirements: 4.1_

  - [x] 1.2 Write unit test — migration creates and seeds `signal_weights`
    - Open an in-memory SQLite database, run `_createAll`, verify the table exists and contains exactly 5 rows with the correct default weights
    - _Requirements: 4.1_

- [-] 2. `SignalWeightRepository` — new file
  - [x] 2.1 Create `lib/repositories/signal_weight_repository.dart`
    - Define `const Map<String, double> kDefaultSignalWeights` with the five default entries
    - Implement `SignalWeightRepository` class with a `static Map<String, double>? _cache` field
    - Implement `Future<Map<String, double>> getWeights()`: query `signal_weights`; if empty, return `kDefaultSignalWeights`; populate `_cache` on first read; return cache on subsequent calls
    - Implement `Future<void> updateWeight(String signal, double newWeight)`: update the row, call `_invalidateCache()`
    - Implement `Future<void> applyFeedback({required Set<String> presentSignals, required bool positive})`: for each signal in `presentSignals`, apply `±0.01` delta clamped to `[0.0, 1.0]`, then call `_invalidateCache()`
    - Implement `Future<void> ensureDefaults()`: insert default rows with `ConflictAlgorithm.ignore`
    - Implement `void _invalidateCache()`: sets `_cache = null`
    - Wrap all DB operations in try/catch; on read error fall back to `kDefaultSignalWeights`; on write error log at `LogLevel.error` and swallow
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 9.4_

  - [ ] 2.2 Write property test — signal weight feedback invariant (Property 11)
    - **Property 11: Signal weight feedback invariant**
    - For any weight `w` in `[0.0, 1.0]` and any feedback direction, after `applyFeedback`, the new weight equals `(w ± 0.01).clamp(0.0, 1.0)`
    - Use `fast_check` to generate random `(weight, isPositive)` pairs; seed a single-row `signal_weights` table; call `applyFeedback`; assert the stored value
    - **Validates: Requirements 4.2, 4.3**

  - [ ] 2.3 Write property test — cache consistency (Property 21)
    - **Property 21: Signal weight cache consistency**
    - For any sequence of `getWeights()` calls with no intervening writes, all calls return the same map instance; after any write the next `getWeights()` fetches fresh data
    - Generate random sequences of read/write operations; assert cache hit/miss behaviour
    - **Validates: Requirements 9.4**

  - [x] 2.4 Write unit tests for `SignalWeightRepository`
    - `signalWeightRepo_defaultsSeeded`: empty table returns `kDefaultSignalWeights` (Req 4.1, 4.5)
    - `signalWeightRepo_fallbackOnEmpty`: table missing → no exception, returns defaults (Req 4.5)
    - `signalWeightRepo_updateWeight_invalidatesCache`: after `updateWeight`, next `getWeights` hits DB (Req 9.4)
    - _Requirements: 4.1, 4.5, 9.4_

- [x] 3. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [-] 4. `MerchantNormalizationService` — fuzzy lookup upgrade
  - [x] 4.1 Promote `_levenshteinDistance` to `static int levenshteinDistance(String a, String b)` (public)
    - Rename the existing private method in `lib/services/merchant_normalization_service.dart`
    - Update the one internal call site (`areSimilar`) to use the new public name
    - _Requirements: 5.1_

  - [ ] 4.2 Write property test — Levenshtein distance properties (Property 13)
    - **Property 13: Levenshtein distance properties**
    - For any two strings `a` and `b`: identity (`d(a,a)=0`), symmetry (`d(a,b)=d(b,a)`), triangle inequality (`d(a,c) ≤ d(a,b)+d(b,c)`)
    - Use `fast_check` to generate random string triples; assert all three properties
    - **Validates: Requirements 5.1**

  - [x] 4.3 Add `NormalizationResult` class and `lookupWithResult()` method
    - Define `class NormalizationResult { final String normalizedName; final double? ruleConfidence; final bool fromLearnedRule; }`
    - Implement `static Future<NormalizationResult> lookupWithResult(String rawMerchant)` with the four-step lookup order:
      1. Exact DB match: `SELECT * FROM merchant_normalization_rules WHERE raw_pattern = lower(trim(input)) AND confidence >= 0.6 LIMIT 1`
      2. Fuzzy DB scan: load all rules with `confidence >= 0.6`; skip if `rawMerchant.trim().length < 3`; find rule with smallest `levenshteinDistance < 3` (tie-break: highest `confidence`, then highest `usage_count`)
      3. Static `_merchantAliases` map
      4. Raw fallback
    - Implement `static Future<String> lookup(String rawMerchant)` as a convenience wrapper calling `lookupWithResult`
    - _Requirements: 2.1, 2.2, 5.2, 5.3, 5.4, 5.5_

  - [ ] 4.4 Write property test — exact-match lookup round-trip (Property 5)
    - **Property 5: Exact-match lookup round-trip**
    - For any `(pattern, normalizedName)` pair inserted into `merchant_normalization_rules` with `confidence >= 0.6`, `lookupWithResult(pattern)` returns `normalizedName`
    - Use `fast_check` to generate random valid pairs; insert; assert
    - **Validates: Requirements 2.1**

  - [ ] 4.5 Write property test — fuzzy-match lookup (Property 6)
    - **Property 6: Fuzzy-match lookup**
    - For any stored rule with `confidence >= 0.6` and any input string with `levenshteinDistance(lower(input), lower(pattern)) < 3` and `lower(input) != lower(pattern)`, `lookup(input)` returns the rule's `normalized_name`
    - Generate random strings and apply 1–2 character edits; assert lookup returns the original normalized name
    - **Validates: Requirements 2.2, 5.2**

  - [ ] 4.6 Write property test — no-match passthrough (Property 8)
    - **Property 8: No-match passthrough**
    - For any merchant string with no matching rule (empty table), `lookup(m)` returns `m` unchanged
    - Use `fast_check` to generate random merchant strings; assert identity
    - **Validates: Requirements 2.4**

  - [ ] 4.7 Write property test — fuzzy rule selection best-confidence wins (Property 14)
    - **Property 14: Fuzzy rule selection — best confidence wins**
    - When multiple rules match with `levenshteinDistance < 3`, the rule with the highest `confidence` is returned; ties broken by highest `usage_count`
    - Generate random sets of matching rules with varying confidence/usage_count; assert correct selection
    - **Validates: Requirements 5.3**

  - [ ] 4.8 Write property test — low-confidence rules excluded (Property 15)
    - **Property 15: Low-confidence rules excluded from fuzzy matching**
    - Rules with `confidence < 0.6` are never returned by fuzzy lookup regardless of edit distance
    - Generate rules with `confidence` in `[0.0, 0.59]`; assert they are never selected
    - **Validates: Requirements 5.4**

  - [ ] 4.9 Write property test — short merchant skips fuzzy (Property 16)
    - **Property 16: Short merchant skips fuzzy matching**
    - For any raw merchant string with `trimmed length < 3`, `lookup()` returns the raw string unchanged
    - Generate strings of length 0–2; assert identity
    - **Validates: Requirements 5.5**

  - [x] 4.10 Write unit tests for `MerchantNormalizationService`
    - `lookupMerchantNormalization_exactMatch`: exact DB match returns normalized name (Req 2.1)
    - `lookupMerchantNormalization_noMatch_returnsRaw`: no match returns raw string (Req 2.4)
    - _Requirements: 2.1, 2.4_

- [x] 5. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [-] 6. `TransactionFeedbackService` — read-side completion and delete methods
  - [x] 6.1 Replace `lookupMerchantNormalization` with delegation to `MerchantNormalizationService.lookupWithResult()`
    - Remove the existing exact-match + substring-scan implementation
    - Call `MerchantNormalizationService.lookupWithResult(rawMerchant)` and return `result.normalizedName` (or `null` if `!result.fromLearnedRule` and no static alias matched)
    - _Requirements: 2.1, 2.2_

  - [x] 6.2 Add missing short-value guard for category corrections in `_learnFromCorrection`
    - The merchant path already has `correctedValue.trim().length < 2`; add the same guard for the `fieldName == 'category'` branch
    - _Requirements: 1.3, 6.1_

  - [x] 6.3 Add `deleteMerchantNormalizationRule(String rawPattern)` public method
    - Execute `DELETE FROM merchant_normalization_rules WHERE raw_pattern = ?`
    - Wrap in try/catch; log errors at `LogLevel.error`
    - _Requirements: 8.1_

  - [x] 6.4 Add `deleteCategoryMapping(String merchant)` public method
    - Execute `DELETE FROM merchant_category_map WHERE merchant = ?`
    - Wrap in try/catch; log errors at `LogLevel.error`
    - _Requirements: 8.2_

  - [ ] 6.5 Write property test — merchant correction round-trip (Property 1)
    - **Property 1: Merchant correction round-trip**
    - For any valid `(rawPattern, normalizedName)` pair (trimmed length > 2, not in `_invalidLearningTokens`), after `recordCorrection` with `fieldName='merchant'`, querying `merchant_normalization_rules` for `raw_pattern` returns a row with the correct `normalized_name`
    - Use `fast_check` to generate random valid pairs; assert DB state
    - **Validates: Requirements 1.1, 1.2, 8.3**

  - [ ] 6.6 Write property test — correction count invariant (Property 2)
    - **Property 2: Correction count invariant**
    - For any existing rule with `usage_count = u` and `success_count = s`, after one additional correction, the rule has `usage_count = u+1`, `success_count = s+1`, `confidence = (s+1)/(u+1)` clamped to `[0.0, 1.0]`
    - Use `fast_check` to generate random `(u, s)` pairs; pre-seed the rule; apply correction; assert
    - **Validates: Requirements 1.2**

  - [ ] 6.7 Write property test — short-value safeguard (Property 3)
    - **Property 3: Short-value safeguard**
    - For any string with trimmed length 0, 1, or 2, `_learnFromCorrection` writes no row to `merchant_normalization_rules` or `merchant_category_map`
    - Generate strings of length 0–2 (including whitespace-padded); assert no DB writes
    - **Validates: Requirements 1.3, 6.1**

  - [ ] 6.8 Write property test — invalid-token safeguard (Property 4)
    - **Property 4: Invalid-token safeguard**
    - For any token in `_invalidLearningTokens`, `_learnFromCorrection` writes no row and throws no exception
    - Generate random elements from `_invalidLearningTokens`; assert no DB writes and no exceptions
    - **Validates: Requirements 1.4, 6.2, 6.4**

  - [ ] 6.9 Write property test — category correction round-trip (Property 9)
    - **Property 9: Category correction round-trip**
    - For any valid `(merchant, category)` pair, after `recordCorrection` with `fieldName='category'`, querying `merchant_category_map` returns a row with the correct `category`
    - Use `fast_check` to generate random valid pairs; assert DB state
    - **Validates: Requirements 3.1, 3.3**

  - [ ] 6.10 Write property test — category confidence invariant (Property 10)
    - **Property 10: Category confidence invariant**
    - For any existing mapping with `usage_count = u`, after one additional correction, `usage_count = u+1` and `confidence = (u+1)/(u+2)` clamped to `[0.5, 1.0]`
    - Use `fast_check` to generate random `u` values; pre-seed the mapping; apply correction; assert
    - **Validates: Requirements 3.2**

  - [ ] 6.11 Write property test — delete removes the rule (Property 19)
    - **Property 19: Delete removes the rule**
    - For any rule that exists in `merchant_normalization_rules` (or `merchant_category_map`), calling `deleteMerchantNormalizationRule` (or `deleteCategoryMapping`) results in that row no longer existing
    - Use `fast_check` to generate random `(pattern, normalizedName)` pairs; insert; delete; assert absence
    - **Validates: Requirements 8.1, 8.2**

  - [ ] 6.12 Write property test — low-confidence rules retained (Property 20)
    - **Property 20: Low-confidence rules are retained, not auto-deleted**
    - For any rule whose `confidence` has dropped below 0.3 due to conflicting corrections, the rule still exists in `merchant_normalization_rules`
    - Drive a rule below 0.3 via repeated conflicting corrections; assert the row still exists
    - **Validates: Requirements 8.4**

  - [x] 6.13 Write unit tests for `TransactionFeedbackService`
    - `learnFromCorrection_merchant_writesRow`: row written with correct fields (Req 1.1)
    - `learnFromCorrection_shortValue_noWrite`: trimmed length ≤ 2 is rejected (Req 1.3)
    - `learnFromCorrection_invalidToken_noWrite`: invalid tokens are rejected (Req 1.4)
    - `lookupMerchantCategory_returnsLearnedCategory`: learned category is returned (Req 3.3)
    - `deleteMerchantNormRule_removesRow`: delete removes the row (Req 8.1)
    - `deleteCategoryMapping_removesRow`: delete removes the row (Req 8.2)
    - _Requirements: 1.1, 1.3, 1.4, 3.3, 8.1, 8.2_

- [x] 7. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. `EntityExtractionService` — category lookup integration
  - [x] 8.1 Add `learnedCategory` field to `ExtractedEntities`
    - Add `final String? learnedCategory;` to the `ExtractedEntities` class
    - Update the constructor to accept `learnedCategory` (optional, defaults to `null`)
    - _Requirements: 3.3, 7.1_

  - [x] 8.2 Upgrade merchant normalization call to use `lookupWithResult()`
    - In both the `transaction_sms_parser` path and the regex fallback path of `extract()`, replace the call to `TransactionFeedbackService.lookupMerchantNormalization(merchant)` with `MerchantNormalizationService.lookupWithResult(rawMerchant)`
    - Store the returned `NormalizationResult` so the confidence boost can be applied in the next step
    - _Requirements: 2.1, 2.2_

  - [x] 8.3 Apply confidence boost from learned normalization rule
    - After merchant normalization, if `normResult.fromLearnedRule && normResult.ruleConfidence != null`, apply: `confidence = (confidence + 0.2 * normResult.ruleConfidence!).clamp(0.0, 1.0)`
    - Apply this boost in both the `transaction_sms_parser` path and the regex fallback path
    - _Requirements: 2.3_

  - [x] 8.4 Add category lookup after merchant normalization
    - After merchant normalization in both paths, call `TransactionFeedbackService.lookupMerchantCategory(canonicalMerchant)` and store the result as `learnedCategory`
    - Pass `learnedCategory` to the `ExtractedEntities` constructor
    - _Requirements: 3.3, 7.1_

  - [ ]* 8.5 Write property test — confidence boost from learned rule (Property 7)
    - **Property 7: Confidence boost from learned rule**
    - For any base confidence `c` in `[0.0, 1.0]` and rule confidence `r` in `[0.0, 1.0]`, when a learned rule is applied, the resulting confidence equals `(c + 0.2 * r).clamp(0.0, 1.0)`
    - Use `fast_check` to generate random `(c, r)` pairs; assert the formula
    - **Validates: Requirements 2.3**

  - [x] 8.6 Write unit tests for `EntityExtractionService`
    - `extract_appliesLearnedCategory`: when `merchant_category_map` has a matching row, `learnedCategory` is populated (Req 3.3)
    - `extract_noLearnedCategory_returnsNull`: when no mapping exists, `learnedCategory` is `null` (Req 3.3)
    - _Requirements: 3.3_

- [x] 9. `SmsPipelineExecutor` — signal weight cache and category lookup integration
  - [x] 9.1 Inject `SignalWeightRepository` into `SmsPipelineExecutor`
    - Add a `static final SignalWeightRepository _signalWeightRepo = SignalWeightRepository()` field (or accept via constructor for testability)
    - Call `_signalWeightRepo.ensureDefaults()` once during app startup (or lazily on first `processSms` call)
    - _Requirements: 4.4, 9.4_

  - [x] 9.2 Replace hardcoded confidence weights with signal-weight-based formula
    - In `_processTransaction()`, after entity extraction, call `final weights = await _signalWeightRepo.getWeights()`
    - Compute confidence as the weighted sum of present signals:
      - `has_amount`: `entities.amount != null`
      - `has_account`: `entities.accountIdentifier != null`
      - `has_bank`: `entities.institutionName != null`
      - `has_merchant`: `entities.merchant != null`
      - `has_transaction_verb`: `classification.isHighConfidence` (proxy)
    - Clamp result to `[0.0, 1.0]`
    - _Requirements: 4.4, 7.1_

  - [x] 9.3 Use `learnedCategory` when building the `Transaction`
    - In `_processTransaction()`, replace `_getDefaultCategory(classification.type, entities.merchant)` with `entities.learnedCategory ?? _getDefaultCategory(classification.type, entities.merchant)`
    - _Requirements: 3.3, 7.1_

  - [x] 9.4 Apply `needsReview` thresholds from `ConfidenceScoring`
    - Set `needsReview = confidence < ConfidenceScoring.thresholdMedium` (i.e., `< 0.70`)
    - Auto-approve (`needsReview = false`) when `confidence >= ConfidenceScoring.thresholdHigh` (i.e., `>= 0.85`)
    - For `0.70 <= confidence < 0.85`, set `needsReview = false` (medium — UI shows indicator)
    - _Requirements: 7.2, 7.3, 7.4_

  - [x] 9.5 Wire `applyFeedback` to existing feedback entry points
    - In `recordQuickFeedback` (positive) and `recordAccountConfirmation` (confirmed), call `_signalWeightRepo.applyFeedback(presentSignals: _signalsFromTransaction(transaction), positive: true/false)`
    - Add a private helper `Set<String> _signalsFromTransaction(Transaction t)` that returns the set of signal keys present in the transaction
    - _Requirements: 4.2, 4.3_

  - [ ]* 9.6 Write property test — confidence is weighted sum of present signals (Property 12)
    - **Property 12: Confidence is weighted sum of present signals**
    - For any combination of present signals and their weights from `signal_weights`, the computed `confidence_score` equals the sum of the weights of all present signals, clamped to `[0.0, 1.0]`
    - Use `fast_check` to generate random signal presence bitmasks and weight maps; assert the formula
    - **Validates: Requirements 4.4**

  - [ ]* 9.7 Write property test — `needsReview` thresholds (Property 17)
    - **Property 17: needsReview is determined by confidence thresholds**
    - For `c >= 0.85`: `needsReview = false`; for `c < 0.70`: `needsReview = true`; for `0.70 <= c < 0.85`: `needsReview = false`
    - Use `fast_check` to generate random confidence values in `[0.0, 1.0]`; assert the correct `needsReview` value
    - **Validates: Requirements 7.2, 7.3, 7.4**

  - [ ]* 9.8 Write property test — no-rule baseline preservation (Property 18)
    - **Property 18: No-rule baseline preservation**
    - When `merchant_normalization_rules`, `merchant_category_map`, and `signal_weights` are all empty, the pipeline output is identical to the pre-learning baseline (default weights, raw merchant name, static default category)
    - Use `fast_check` to generate random SMS messages with empty rule tables; assert output matches baseline
    - **Validates: Requirements 7.6**

  - [x] 9.9 Write unit tests for `SmsPipelineExecutor`
    - `pipeline_autoApprove_highConfidence`: `needsReview=false` when `confidence >= 0.85` (Req 7.2)
    - `pipeline_requiresReview_lowConfidence`: `needsReview=true` when `confidence < 0.70` (Req 7.3)
    - `pipeline_usesLearnedCategory`: when `learnedCategory` is set, transaction uses it (Req 3.3)
    - `pipeline_usesSignalWeights`: confidence formula uses weights from `signal_weights` table (Req 4.4)
    - _Requirements: 3.3, 4.4, 7.2, 7.3_

- [x] 10. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at each layer boundary
- Property tests validate universal correctness properties across the full input space; unit tests validate specific examples and edge cases
- The `fast_check` library must be added to `dev_dependencies` in `pubspec.yaml` before running property tests
- The `signal_weights` table has at most 5 rows and requires no index — always read in full
- The fuzzy scan in `MerchantNormalizationService` is O(n) over rules with `confidence >= 0.6`; a future optimisation (top-500 by `usage_count`) is noted in the design but not required here

---

## Requirement 10 Tasks: Learnable Financial Sender Gate

- [ ] 11. Make `SmsClassificationService._isFinancialSender` DB-aware
  - [ ] 11.1 Convert `_isFinancialSender` to `async` and add Tier 1 DB lookup
    - Change signature to `static Future<bool> _isFinancialSender(String sender, String body)`
    - As the first step, query `sms_keywords` WHERE `keyword = sender AND type = 'sender_pattern' AND confidence >= 0.6 LIMIT 1`
    - If a row is found, return `true` immediately
    - Wrap the DB call in try/catch; on error fall through to Tier 2
    - _Requirements: 10.1, 10.7, 10.8_

  - [ ] 11.2 Add Tier 2: permissive body-signal pass-through for unknown senders
    - Add a private `static bool _hasFinancialBodySignal(String body)` helper
    - It returns `true` if the body contains any currency pattern (`\$`, `Rs`, `₹`, `INR`, `USD` followed by digits or `X`) OR any of: `['debited','credited','transaction','payment','balance','transfer','deposit','withdraw','charge']`
    - In `_isFinancialSender`, after the DB lookup fails, call `_hasFinancialBodySignal(body)`; if true, return `true`
    - _Requirements: 10.2, 10.3_

  - [ ] 11.3 Convert `classify()` to `async` and update all call sites
    - Change `static SmsClassification classify(RawSmsMessage sms)` to `static Future<SmsClassification> classify(RawSmsMessage sms)`
    - In `SmsPipelineExecutor.processSms()`, add `await` to the `classify()` call (it likely already awaits — verify)
    - Search for any other callers of `SmsClassificationService.classify()` and add `await`
    - _Requirements: 10.1_

  - [ ] 11.4 Write unit tests for the upgraded sender gate
    - `senderGate_knownSender_passes`: seed a row in `sms_keywords`, assert `_isFinancialSender` returns `true` (Req 10.1)
    - `senderGate_unknownSender_bodySignal_passesAsUnknown`: no DB row, body has `$50.00 debited`, assert returns `true` (Req 10.2)
    - `senderGate_unknownSender_noSignal_drops`: no DB row, body has no financial signal, assert returns `false` (Req 10.3)
    - `senderGate_dbError_fallsBackToStatic`: DB throws, assert static fallback still works (Req 10.8)
    - _Requirements: 10.1, 10.2, 10.3, 10.8_

- [ ] 12. Wire sender learning into `TransactionFeedbackService`
  - [ ] 12.1 Add `_learnSender(String senderAddress)` private method
    - Insert into `sms_keywords`: `keyword = senderAddress`, `type = 'sender_pattern'`, `confidence = 1.0`, `priority = 10`, `is_active = 1`, `usage_count = 1`, `created_at = now`
    - Use `ConflictAlgorithm.ignore` so re-confirming an already-known sender is a no-op
    - Wrap in try/catch; log errors at `LogLevel.error` and swallow
    - _Requirements: 10.4_

  - [ ] 12.2 Call `_learnSender` from `recordAccountConfirmation` on positive confirmation
    - Add optional `String? senderAddress` parameter to `recordAccountConfirmation`
    - When `confirmed == true` and `senderAddress != null` and `senderAddress.isNotEmpty`, call `await _learnSender(senderAddress)`
    - When `confirmed == false`, do NOT call `_learnSender` (Req 10.5)
    - _Requirements: 10.4, 10.5_

  - [ ] 12.3 Pass `senderAddress` from `SmsPipelineExecutor` to `recordAccountConfirmation`
    - In `SmsPipelineExecutor`, the `rawSms.sender` is available at the point where feedback is recorded
    - Ensure the sender address flows through to `recordAccountConfirmation` calls
    - _Requirements: 10.4_

  - [ ] 12.4 Write unit tests for sender learning
    - `senderConfirmation_learnsSender`: after `recordAccountConfirmation(confirmed: true, senderAddress: '692484')`, query `sms_keywords` and assert a row exists (Req 10.4)
    - `senderRejection_doesNotLearnSender`: after `recordAccountConfirmation(confirmed: false, senderAddress: '999999')`, assert no row in `sms_keywords` (Req 10.5)
    - `senderLearning_idempotent`: calling `_learnSender` twice for the same sender does not throw and results in exactly one row (Req 10.4)
    - _Requirements: 10.4, 10.5_

- [ ] 13. Checkpoint — ensure all tests pass
  - Run the full test suite; fix any regressions introduced by the `classify()` async change
  - Verify the training data messages from senders `692484`, `692632`, `227898` now pass the sender gate
