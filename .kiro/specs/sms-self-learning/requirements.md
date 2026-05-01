# Requirements Document

## Introduction

PocketFlow currently parses SMS bank notifications and logs user feedback when parsing is incorrect. This feature upgrades that passive feedback loop into an **active self-learning system**: every user correction is immediately stored as a rule, and every subsequent SMS parse applies those rules to produce better merchant names, categories, and confidence scores — entirely on-device with no external ML APIs.

The system must satisfy three high-level goals:
1. **Learn** — persist every user correction as a reusable rule.
2. **Apply** — consult learned rules during every future parse, before falling back to static logic.
3. **Improve** — dynamically adjust confidence scores so that well-learned transactions are auto-approved and poorly-learned ones are flagged for review.

The existing database already contains `merchant_normalization_rules` and `merchant_category_map` tables (v21 migration) and `TransactionFeedbackService` already writes to them. This feature completes the loop by ensuring those tables are **read** during parsing, that fuzzy matching is used for lookups, that signal weights are persisted and updated, and that safeguards prevent bad data from polluting the rule store.

---

## Glossary

- **Learning_Engine**: The subsystem responsible for persisting and retrieving learned rules. Implemented across `TransactionFeedbackService` and a new `SignalWeightRepository`.
- **Parser**: The `EntityExtractionService` that extracts structured fields (amount, merchant, category, account) from raw SMS text.
- **Pipeline**: The `SmsPipelineExecutor` that orchestrates privacy filtering → classification → extraction → account resolution → transaction creation.
- **Merchant_Normalizer**: The component (currently `MerchantNormalizationService` + `TransactionFeedbackService.lookupMerchantNormalization`) that maps raw SMS merchant strings to canonical display names.
- **Category_Mapper**: The component that maps a canonical merchant name to a spending category using `merchant_category_map`.
- **Signal_Weight**: A named numeric weight (e.g. `has_amount = 0.4`) stored in the `signal_weights` table and used by the confidence scoring formula.
- **Confidence_Score**: A value in [0.0, 1.0] representing how certain the system is that a parsed transaction is correct. Scores ≥ 0.85 are auto-approved; scores < 0.70 require user review.
- **Fuzzy_Match**: A string similarity check using Levenshtein distance. Two strings are considered a match when their edit distance is < 3.
- **Correction**: A user-initiated field edit recorded via `TransactionFeedbackService.recordCorrection()`.
- **Invalid_Token**: A word that must never be stored as a learned pattern (e.g. "account", "payment", "card"). Defined in `_invalidLearningTokens`.
- **Auto_Approve**: The pipeline behaviour of creating a transaction with `needsReview = false` when confidence ≥ 0.85.

---

## Requirements

### Requirement 1: Merchant Normalization Learning

**User Story:** As a user who corrects a merchant name (e.g. "AMZN MKTPLACE" → "Amazon"), I want the system to remember that correction, so that future SMS messages from the same merchant are automatically displayed with the correct name.

#### Acceptance Criteria

1. WHEN a user submits a merchant correction via `TransactionFeedbackService.recordCorrection()` with `fieldName = 'merchant'`, THE Learning_Engine SHALL persist a row in `merchant_normalization_rules` with `raw_pattern` set to the lowercased, trimmed original value and `normalized_name` set to the corrected value.

2. WHEN a merchant normalization rule already exists for a given `raw_pattern`, THE Learning_Engine SHALL increment `usage_count` and `success_count` by 1 and recalculate `confidence` as `success_count / usage_count`, clamped to [0.0, 1.0].

3. IF the `correctedValue` passed to `_learnFromCorrection()` has a trimmed length ≤ 2, THEN THE Learning_Engine SHALL discard the correction without writing to the database.

4. IF the lowercased `raw_pattern` or the lowercased `correctedValue` is contained in the `_invalidLearningTokens` set (`{'account', 'card', 'balance', 'transaction', 'payment', 'your', 'the', 'a', 'an', 'us', 'you', 'bank', 'wallet', 'upi', 'neft', 'imps', 'rtgs', 'end', 'stop', 'null', ''}`), THEN THE Learning_Engine SHALL discard the correction without writing to the database.

5. THE `merchant_normalization_rules` table SHALL enforce a UNIQUE constraint on `raw_pattern` so that duplicate rules cannot be created for the same pattern.

---

### Requirement 2: Apply Merchant Normalization During Parsing

**User Story:** As a user, I want the system to automatically apply my past merchant corrections when new SMS messages arrive, so that I don't have to correct the same merchant name repeatedly.

#### Acceptance Criteria

1. WHEN the Parser extracts a raw merchant string from an SMS, THE Merchant_Normalizer SHALL query `merchant_normalization_rules` for an exact match on `raw_pattern` (case-insensitive) before returning the merchant name to the Pipeline.

2. WHEN no exact match is found, THE Merchant_Normalizer SHALL perform a Fuzzy_Match against all `raw_pattern` values in `merchant_normalization_rules` where `confidence >= 0.6`, and SHALL apply the first rule whose Levenshtein distance from the raw merchant is < 3.

3. WHEN a learned normalization rule is applied during parsing, THE Parser SHALL add a confidence boost of `0.2 * rule.confidence` to the transaction's `confidence_score`, clamped to [0.0, 1.0].

4. WHEN no normalization rule matches (exact or fuzzy), THE Parser SHALL return the raw extracted merchant name unchanged.

5. THE Merchant_Normalizer SHALL complete all rule lookups within 50 milliseconds on a device with up to 10,000 stored rules.

---

### Requirement 3: Category Learning

**User Story:** As a user who corrects a transaction category (e.g. changing "Other Expense" to "Groceries" for a Swiggy transaction), I want the system to remember that merchant-to-category mapping, so that future Swiggy transactions are automatically categorized correctly.

#### Acceptance Criteria

1. WHEN a user submits a category correction via `TransactionFeedbackService.recordCorrection()` with `fieldName = 'category'`, THE Learning_Engine SHALL persist a row in `merchant_category_map` with `merchant` set to the transaction's canonical merchant name and `category` set to the corrected value.

2. WHEN a category mapping already exists for a given `merchant`, THE Learning_Engine SHALL increment `usage_count` by 1 and recalculate `confidence` as `usage_count / (usage_count + 1)`, clamped to [0.5, 1.0].

3. WHEN the Parser assigns a category to a new transaction, THE Category_Mapper SHALL first query `merchant_category_map` for the canonical merchant name with `confidence >= 0.6`; if a match is found, THE Category_Mapper SHALL use the learned category instead of the static default.

4. IF the merchant name used as the lookup key is empty or is contained in `_invalidLearningTokens`, THEN THE Learning_Engine SHALL discard the category correction without writing to the database.

5. THE `merchant_category_map` table SHALL enforce a UNIQUE constraint on `merchant` so that each merchant has at most one active category mapping.

---

### Requirement 4: Confidence Signal Weight Learning

**User Story:** As a user whose corrections consistently indicate that certain signals are more or less reliable, I want the system to adjust its confidence weights over time, so that the confidence scores become more accurate as the system learns.

#### Acceptance Criteria

1. THE Learning_Engine SHALL maintain a `signal_weights` table with columns `signal TEXT NOT NULL UNIQUE` and `weight REAL NOT NULL`, seeded with the following default values on first run:

   | signal                  | weight |
   |-------------------------|--------|
   | has_amount              | 0.40   |
   | has_account             | 0.20   |
   | has_bank                | 0.10   |
   | has_merchant            | 0.10   |
   | has_transaction_verb    | 0.20   |

2. WHEN a user provides positive feedback (thumbs-up or confirms a transaction), THE Learning_Engine SHALL increase the `weight` of each signal that was present in that transaction by 0.01, clamped to [0.0, 1.0].

3. WHEN a user provides negative feedback (marks a transaction as incorrect or disputes it), THE Learning_Engine SHALL decrease the `weight` of each signal that was present in that transaction by 0.01, clamped to [0.0, 1.0].

4. WHEN the Pipeline computes a transaction's `confidence_score`, THE Pipeline SHALL read the current signal weights from `signal_weights` (falling back to the default values if the table is empty) and compute confidence as the weighted sum of present signals.

5. WHERE the `signal_weights` table is empty or missing, THE Pipeline SHALL use the default weights defined in Acceptance Criterion 1 without error.

---

### Requirement 5: Fuzzy Merchant Matching

**User Story:** As a user, I want the system to recognize slight variations of a merchant name (e.g. "AMZN MKTPLC" vs "AMZN MKTPLACE") as the same merchant, so that minor SMS formatting differences don't prevent learned rules from being applied.

#### Acceptance Criteria

1. THE Merchant_Normalizer SHALL implement a `levenshteinDistance(String a, String b)` function that returns the minimum edit distance between two strings using the standard dynamic-programming algorithm.

2. WHEN performing a fuzzy lookup, THE Merchant_Normalizer SHALL compare the lowercased raw merchant against the lowercased `raw_pattern` of each candidate rule, and SHALL consider it a match when `levenshteinDistance(rawMerchant, rulePattern) < 3`.

3. WHEN multiple fuzzy rules match, THE Merchant_Normalizer SHALL apply the rule with the highest `confidence` value; ties SHALL be broken by the highest `usage_count`.

4. THE Merchant_Normalizer SHALL only perform fuzzy matching against rules with `confidence >= 0.6` to avoid applying low-quality learned rules.

5. WHEN the raw merchant string has fewer than 3 characters, THE Merchant_Normalizer SHALL skip fuzzy matching and return the raw string unchanged.

---

### Requirement 6: Learning Safeguards

**User Story:** As a developer, I want the learning system to reject low-quality or noisy corrections, so that bad user input doesn't corrupt the rule store and degrade future parsing accuracy.

#### Acceptance Criteria

1. IF a correction value (merchant or category) has a trimmed length ≤ 2, THEN THE Learning_Engine SHALL reject the correction and SHALL NOT write any row to `merchant_normalization_rules` or `merchant_category_map`.

2. IF a correction value (lowercased) is an element of `_invalidLearningTokens`, THEN THE Learning_Engine SHALL reject the correction and SHALL NOT write any row to the database.

3. THE `_invalidLearningTokens` set SHALL contain at minimum: `{'account', 'card', 'balance', 'transaction', 'payment', 'your', 'the', 'a', 'an', 'us', 'you', 'bank', 'wallet', 'upi', 'neft', 'imps', 'rtgs', 'end', 'stop', 'null', ''}`.

4. WHEN a correction is rejected by a safeguard, THE Learning_Engine SHALL log the rejection reason at debug level without throwing an exception, so that the calling code continues normally.

5. THE Learning_Engine SHALL NOT modify any existing rule's `normalized_name` to an invalid token; IF such an update is attempted, THE Learning_Engine SHALL retain the previous `normalized_name`.

---

### Requirement 7: End-to-End Adaptive Parsing Flow

**User Story:** As a user, I want the complete SMS parsing pipeline to incorporate all learned rules automatically, so that the system improves with every correction I make without requiring any manual configuration.

#### Acceptance Criteria

1. WHEN the Pipeline processes an SMS, THE Pipeline SHALL execute the following ordered steps:
   - (a) Privacy filter
   - (b) Classification
   - (c) Raw field extraction (amount, account, institution, raw merchant)
   - (d) Apply Merchant_Normalizer to raw merchant → canonical merchant
   - (e) Apply Category_Mapper to canonical merchant → learned category (if available)
   - (f) Compute confidence using current Signal_Weights
   - (g) Assign transaction type and final confidence
   - (h) Store transaction

2. WHEN a transaction is stored after step (h) with `confidence_score >= 0.85`, THE Pipeline SHALL set `needsReview = false` (Auto_Approve).

3. WHEN a transaction is stored after step (h) with `confidence_score < 0.70`, THE Pipeline SHALL set `needsReview = true`.

4. WHEN a transaction is stored after step (h) with `0.70 <= confidence_score < 0.85`, THE Pipeline SHALL set `needsReview = false` but SHALL NOT suppress the medium-confidence indicator in the UI.

5. THE Pipeline SHALL complete steps (a) through (h) for a single SMS within 50 milliseconds on a mid-range Android device (excluding database I/O latency for initial cold-start).

6. THE Pipeline SHALL NOT break existing parsing behaviour for SMS messages that have no matching learned rules; in that case, the output SHALL be identical to the pre-learning baseline.

---

### Requirement 8: Rule Reversibility

**User Story:** As a user who made an incorrect correction, I want to be able to undo or override a learned rule, so that a single bad correction doesn't permanently degrade parsing accuracy.

#### Acceptance Criteria

1. THE Learning_Engine SHALL expose a `deleteMerchantNormalizationRule(String rawPattern)` method that removes the corresponding row from `merchant_normalization_rules`.

2. THE Learning_Engine SHALL expose a `deleteCategoryMapping(String merchant)` method that removes the corresponding row from `merchant_category_map`.

3. WHEN a user submits a new correction for a `raw_pattern` that already has a rule, THE Learning_Engine SHALL update the `normalized_name` to the new value (adopting the latest correction) rather than creating a duplicate row.

4. WHEN a rule's `confidence` drops below 0.3 due to repeated conflicting corrections, THE Learning_Engine SHALL flag the rule as low-confidence but SHALL NOT automatically delete it; deletion SHALL require explicit user action.

5. THE Learning_Engine SHALL preserve a full correction history in `user_corrections` so that any rule can be audited or reconstructed from the history.

---

### Requirement 9: Performance Constraints

**User Story:** As a user, I want SMS parsing to remain fast even as the rule store grows, so that the app stays responsive when processing batches of SMS messages.

#### Acceptance Criteria

1. THE Merchant_Normalizer SHALL use indexed database queries (via the existing `idx_merchant_norm_rules_pattern` index) for exact-match lookups, ensuring O(log n) lookup time.

2. WHEN the `merchant_normalization_rules` table contains up to 10,000 rows, THE Merchant_Normalizer SHALL complete an exact-match lookup within 10 milliseconds.

3. WHEN the `merchant_normalization_rules` table contains up to 10,000 rows, THE Merchant_Normalizer SHALL complete a full fuzzy-match scan within 50 milliseconds.

4. THE Pipeline SHALL cache the current `signal_weights` in memory after the first database read and SHALL invalidate the cache only when a weight update is written, to avoid repeated database reads per SMS.

5. THE Learning_Engine SHALL perform all database writes asynchronously (using `async/await` without blocking the UI thread) so that recording a correction does not delay the UI response.

---

### Requirement 10: Learnable Financial Sender Gate

**User Story:** As a user, I want the app to process SMS messages from any bank or financial institution — even ones it has never seen before — so that I don't have to manually configure senders and the system gets smarter about which senders are financial over time.

#### Background

The current `_isFinancialSender()` check in `SmsClassificationService` is a hard binary gate: messages from unknown senders are silently dropped as `nonFinancial` before the feedback system ever sees them. This means:
- US banks that use numeric short codes (e.g. Citi → `692484`, BofA → `692632`) are dropped even though their sender IDs are already seeded in the `sms_keywords` table with `type = 'sender_pattern'`.
- The `sms_keywords` table is written to but never read during classification.
- Users have no way to teach the system about a new sender because dropped messages never surface for review.

The fix is to make the gate **permissive and learnable**: unknown senders with financial body signals pass through at low confidence, surface for user review, and the sender is learned from that confirmation.

#### Glossary additions

- **Sender_Gate**: The `_isFinancialSender()` check in `SmsClassificationService` that decides whether an SMS is eligible for financial processing.
- **Known_Sender**: A sender ID present in the `sms_keywords` table with `type = 'sender_pattern'` and `confidence >= 0.6`.
- **Financial_Body_Signal**: Any of the following present in the SMS body (case-insensitive): a currency amount pattern (`$`, `Rs`, `₹`, `INR`, `USD`), or any keyword from the `sms_keywords` table with `type IN ('debit', 'credit', 'financial')`.
- **Sender_Confirmation**: A user action (confirming a transaction or marking it correct) that causes the sender ID to be persisted as a `Known_Sender`.

#### Acceptance Criteria

1. WHEN the Sender_Gate evaluates an SMS, THE Classifier SHALL first query the `sms_keywords` table for the sender ID with `type = 'sender_pattern'` AND `confidence >= 0.6`. IF a matching row exists, THE Classifier SHALL treat the sender as financial (equivalent to the current hardcoded match).

2. WHEN the sender ID is not a Known_Sender, THE Classifier SHALL inspect the SMS body for Financial_Body_Signals. IF at least one Financial_Body_Signal is present, THE Classifier SHALL pass the message through as `unknownFinancial` with confidence 0.40 rather than dropping it as `nonFinancial`.

3. WHEN the sender ID is not a Known_Sender AND no Financial_Body_Signal is present, THE Classifier SHALL classify the message as `nonFinancial` and drop it (existing behaviour, unchanged).

4. WHEN a user confirms a transaction (via `TransactionFeedbackService.recordAccountConfirmation(confirmed: true)` or any positive feedback action), THE Learning_Engine SHALL upsert a row in `sms_keywords` with `keyword = senderAddress`, `type = 'sender_pattern'`, `confidence = 1.0`, and `region = null`, so that all future messages from that sender are treated as financial without requiring body-signal fallback.

5. WHEN a user rejects a transaction (via `recordAccountConfirmation(confirmed: false)` or negative feedback), AND the sender is not yet a Known_Sender, THE Learning_Engine SHALL NOT persist the sender, leaving it in the unknown state.

6. WHEN a sender has been confirmed by the user and stored in `sms_keywords`, subsequent messages from that sender SHALL be classified using the full keyword/signal pipeline (debit/credit/transfer/balance detection) rather than being forced to `unknownFinancial`.

7. THE Sender_Gate DB query SHALL use the existing index on `sms_keywords(type)` and SHALL complete within 10 milliseconds for a table with up to 10,000 rows.

8. THE hardcoded `_financialSenderPattern` regex and the hardcoded `financialInstitutions` body-keyword list in `_isFinancialSender()` SHALL be retained as a **last-resort static fallback** after the DB lookup, so that the system works correctly on first install before any DB rows exist.
