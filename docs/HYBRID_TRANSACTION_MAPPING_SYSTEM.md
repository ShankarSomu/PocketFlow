# Hybrid Transaction Mapping System Documentation

## Overview

The Hybrid Transaction Mapping System provides intelligent account matching for transactions from multiple sources (SMS parsing and manual entry). It uses a unified matching engine with confidence scoring to ensure accurate account assignment while maintaining data integrity and user control.

**Location:** `lib/services/account_matching_service.dart`  
**Related Models:** `lib/models/account.dart`, `lib/models/transaction.dart`  
**Integration:** `lib/services/sms_service.dart`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  TRANSACTION SOURCES                        │
├───────────────────────────┬─────────────────────────────────┤
│      SMS Parsing          │     Manual Entry                │
│  - Bank SMS messages      │  - User-created txns            │
│  - Auto-extraction        │  - Form input                   │
│  - Pattern matching       │  - Smart suggestions            │
└───────────────────────────┴─────────────────────────────────┘
                            ↓
              ┌─────────────────────────────┐
              │  Account Matching Service   │
              │  (Unified Engine)           │
              │                             │
              │  • Priority Matching        │
              │  • Confidence Scoring       │
              │  • Fuzzy Matching           │
              │  • Historical Analysis      │
              └─────────────────────────────┘
                            ↓
              ┌─────────────────────────────┐
              │     Match Result            │
              │                             │
              │  • Account (if matched)     │
              │  • Confidence Score         │
              │  • Alternative Matches      │
              │  • Requires Confirmation?   │
              └─────────────────────────────┘
                            ↓
              ┌─────────────────────────────┐
              │    Transaction Created      │
              │                             │
              │  • Source Type              │
              │  • Account Assignment       │
              │  • Confidence Score         │
              │  • Review Flag              │
              └─────────────────────────────┘
```

---

## 1. Enhanced Account Model

### New Fields for Hybrid Matching

The `Account` model has been enhanced with intelligent matching fields:

```dart
class Account {
  // ... existing fields ...
  
  // ── Enhanced Mapping Fields ──
  final String? institutionName;    // e.g., "Chase", "Amex", "Bank of America"
  final String? accountIdentifier;  // Masked: "****1234" (primary matching key)
  final List<String>? smsKeywords;  // ["CHASE", "JP MORGAN", "VISA 1234"]
  final String? accountAlias;       // User-friendly display name
}
```

### Field Descriptions

| Field | Type | Purpose | Example | Required |
|-------|------|---------|---------|----------|
| `institutionName` | String? | Bank/institution name for matching | "Chase", "American Express" | Recommended |
| `accountIdentifier` | String? | Masked account number (primary key) | "****1234", "****5678" | Recommended |
| `smsKeywords` | List<String>? | SMS parsing keywords (fallback) | ["HDFCBK", "CHASE", "AMEX"] | Optional |
| `accountAlias` | String? | User-friendly display name | "My Main Card", "Work Checking" | Optional |

### Computed Properties

```dart
// Get display name (uses alias if available)
String get displayName => accountAlias?.isNotEmpty == true ? accountAlias! : name;

// Get formatted identifier with institution
String get formattedIdentifier {
  // Returns: "Chase ****1234" or just "Chase Checking"
}
```

---

## 2. Enhanced Transaction Model

### New Fields for Source Tracking

```dart
class Transaction {
  // ... existing fields ...
  
  // ── Hybrid Transaction Mapping Fields ──
  final String? smsSource;         // Original SMS text (if from SMS)
  final String sourceType;         // 'sms' | 'manual' | 'recurring' | 'import'
  final String? merchant;          // Standardized merchant name
  final double? confidenceScore;   // 0.0-1.0 for SMS matching confidence
  final bool needsReview;          // Flag for low-confidence SMS matches
}
```

### Field Descriptions

| Field | Type | Purpose | Usage |
|-------|------|---------|-------|
| `smsSource` | String? | Original SMS message text | Debugging, audit trail |
| `sourceType` | String | Transaction origin | UI badges, filtering |
| `merchant` | String? | Extracted/entered merchant | Matching, categorization |
| `confidenceScore` | double? | Match confidence (0.0-1.0) | Decision making, UI indicators |
| `needsReview` | bool | Requires user verification | Review queue, warnings |

### Computed Properties

```dart
// Check if transaction is from SMS
bool get isFromSms => sourceType == 'sms';

// Check if requires review (confidence < 0.7)
bool get requiresReview => needsReview || (confidenceScore != null && confidenceScore! < 0.7);

// Get UI badge text
String get sourceBadge {
  // Returns: "SMS (Needs Review)", "Manual", "Recurring", etc.
}
```

---

## 3. Unified Account Matching Engine

### AccountMatchingService

The core service that powers both SMS and manual transaction account matching.

### Match Result Object

```dart
class AccountMatchResult {
  final Account? account;              // Matched account (null if no match)
  final double confidence;             // 0.0 to 1.0
  final List<Account> alternatives;    // Alternative matches if ambiguous
  final String matchReason;            // Human-readable explanation
  final bool requiresConfirmation;     // User must confirm match
  
  bool get hasMatch => account != null;
  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.5 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.5;
  bool get hasMultipleMatches => alternatives.length > 1;
}
```

---

## 4. SMS Transaction Matching

### Priority Matching Order

```dart
AccountMatchResult result = await AccountMatchingService.matchForSms(
  smsBody: smsMessage,
  detectedLast4: "1234",
  detectedInstitution: "Chase",
);
```

### Matching Algorithm

**Priority 1: Account Identifier Match (Confidence: +0.5)**
- Exact match on `accountIdentifier` field
- Most reliable matching method
- Example: "****1234" matches "****1234"

**Priority 2: Institution Name Match (Confidence: +0.3)**
- Fuzzy match on `institutionName`
- Case-insensitive, partial match allowed
- Example: "chase" matches "Chase Bank"

**Priority 3: Last 4 Digits Match (Confidence: +0.3)**
- Exact match on `last4` field
- Legacy support for existing accounts
- Example: "1234" matches last4 = "1234"

**Priority 4: SMS Keyword Match (Confidence: +0.2)**
- Fallback matching on `smsKeywords` array
- Searches SMS body for any keyword
- Example: SMS contains "HDFCBK" → matches account with keyword

### Confidence Thresholds

```dart
HIGH CONFIDENCE:    >= 0.8  (Auto-assign, no review needed)
MEDIUM CONFIDENCE:  >= 0.5  (Assign with review flag)
LOW CONFIDENCE:     <  0.5  (Mark for manual review)
```

### Ambiguous Match Handling

When multiple accounts have similar scores (< 0.1 difference):
- `requiresConfirmation = true`
- `alternatives` list populated with top 3 matches
- User must select correct account before saving

### Example SMS Flow

```dart
// SMS received: "Your Chase card ending 1234 was charged $45.99 at Amazon"

// Step 1: Parse SMS
final parsed = SmsService.parseTransaction(smsBody);
// Result: amount=$45.99, merchant="Amazon", last4="1234", institution="Chase"

// Step 2: Match account
final match = await AccountMatchingService.matchForSms(
  smsBody: smsBody,
  detectedLast4: "1234",
  detectedInstitution: "Chase",
);

// Step 3: Create transaction
if (match.hasMatch && match.isHighConfidence) {
  // Auto-assign, no review needed
  final txn = Transaction(
    type: 'expense',
    amount: 45.99,
    merchant: 'Amazon',
    accountId: match.account!.id,
    sourceType: 'sms',
    confidenceScore: match.confidence,
    needsReview: false,
    date: DateTime.now(),
  );
} else {
  // Mark for review
  final txn = Transaction(
    type: 'expense',
    amount: 45.99,
    merchant: 'Amazon',
    accountId: match.account?.id, // May be null
    sourceType: 'sms',
    confidenceScore: match.confidence,
    needsReview: true,
    date: DateTime.now(),
  );
}
```

---

## 5. Manual Transaction Matching

### Smart Account Suggestions

```dart
List<AccountMatchResult> suggestions = await AccountMatchingService.suggestForManual(
  merchantName: "Starbucks",
  description: "Coffee",
  accountHint: "chase",
);
```

### Matching Algorithm

**Match Factor 1: Account Name/Alias Match (Confidence: +0.5)**
- User types "chase" → matches "Chase Sapphire" account
- Fuzzy matching on both `name` and `accountAlias`

**Match Factor 2: Institution Match (Confidence: +0.4)**
- User types "amex" → matches accounts with institutionName = "American Express"

**Match Factor 3: Historical Usage (Confidence: +0.3)**
- "Starbucks" previously used with "Chase Sapphire" → higher ranking
- Learns from transaction history
- Frequency-based scoring (0-1.0)

### Return Value

Returns top 5 suggestions sorted by confidence (highest first).

### Example Manual Entry Flow

```dart
// User starts typing merchant: "Star..."

// Step 1: Get suggestions as user types
final suggestions = await AccountMatchingService.suggestForManual(
  merchantName: "Starbucks",
  accountHint: "", // Empty initially
);

// Result: [
//   AccountMatchResult(account: Chase Sapphire, confidence: 0.7, reason: "Historical usage"),
//   AccountMatchResult(account: Amex Blue, confidence: 0.3, reason: "Historical usage"),
// ]

// Step 2: User selects or overrides
// UI shows "Suggested: Chase Sapphire" but allows dropdown to change

// Step 3: Create transaction
final txn = Transaction(
  type: 'expense',
  amount: 5.50,
  merchant: 'Starbucks',
  category: 'Coffee',
  accountId: selectedAccountId, // User's final choice
  sourceType: 'manual',
  confidenceScore: null, // Not applicable for manual
  needsReview: false,
  date: DateTime.now(),
);
```

---

## 6. Safety & Data Integrity Rules

### Rule 1: Manual Transactions Must Have Account

```dart
// Manual transactions REQUIRE account assignment
if (sourceType == 'manual' && accountId == null) {
  return false; // Validation fails
}
```

**Enforcement:**
- UI requires account selection before save
- Validation in `AccountMatchingService.validateAccountAssignment()`

### Rule 2: SMS Transactions Can Be Unassigned

```dart
// SMS transactions can be null if flagged for review
if (sourceType == 'sms' && accountId == null) {
  return needsReview; // OK if needs review
}
```

**Behavior:**
- Low-confidence SMS matches → `accountId = null, needsReview = true`
- User reviews later from dedicated queue

### Rule 3: Never Overwrite Without Confirmation

```dart
// If requiresConfirmation = true, show dialog
if (match.requiresConfirmation) {
  final confirmed = await showAccountSelectionDialog(
    suggested: match.account,
    alternatives: match.alternatives,
  );
  // Use confirmed account
}
```

### Rule 4: Account Must Exist and Be Active

```dart
// Verify account before assignment
final account = await getAccountById(accountId);
if (account == null || account.deletedAt != null) {
  return false; // Invalid account
}
```

### Rule 5: No Sensitive Data Stored

```dart
// SMS source stored for audit ONLY
// Full SMS text: ✅ Stored
// Personal info: ❌ Stripped during parsing
// PIN/CVV/OTP: ❌ Never stored
```

---

## 7. User Experience Flows

### UX Flow 1: SMS Auto-Import (High Confidence)

```
┌────────────────────────────────────────────────────┐
│ 1. SMS received: "Chase ****1234 charged $50"     │
│    ↓                                               │
│ 2. Auto-parsed: amount=$50, last4=1234            │
│    ↓                                               │
│ 3. Match found: Chase Sapphire (confidence: 0.9)  │
│    ↓                                               │
│ 4. Transaction created automatically              │
│    ↓                                               │
│ 5. Notification: "Transaction added: $50 Amazon"  │
│    Badge: "SMS" (green)                           │
└────────────────────────────────────────────────────┘
```

### UX Flow 2: SMS Import (Low Confidence - Needs Review)

```
┌────────────────────────────────────────────────────┐
│ 1. SMS received: "Payment of $50 processed"       │
│    ↓                                               │
│ 2. Auto-parsed: amount=$50, account=unknown       │
│    ↓                                               │
│ 3. No match found (confidence: 0.0)               │
│    ↓                                               │
│ 4. Transaction created with:                      │
│    - accountId = null                             │
│    - needsReview = true                           │
│    ↓                                               │
│ 5. Notification: "Review needed: $50 transaction" │
│    Badge: "SMS (Needs Review)" (yellow/warning)   │
│    ↓                                               │
│ 6. User taps notification                         │
│    ↓                                               │
│ 7. Review screen shows:                           │
│    - Original SMS                                 │
│    - Extracted details                            │
│    - Account dropdown (required)                  │
│    ↓                                               │
│ 8. User selects account → saved                   │
└────────────────────────────────────────────────────┘
```

### UX Flow 3: Manual Entry with Smart Suggestions

```
┌────────────────────────────────────────────────────┐
│ 1. User taps "Add Transaction"                    │
│    ↓                                               │
│ 2. Form opens                                      │
│    ↓                                               │
│ 3. User types merchant: "Star..."                 │
│    ↓                                               │
│ 4. Real-time suggestions:                         │
│    ┌─────────────────────────────────┐            │
│    │ Suggested Account:              │            │
│    │ 💳 Chase Sapphire (****1234)   │ ← Historical│
│    │ 📊 Used 8 times at coffee shops│            │
│    └─────────────────────────────────┘            │
│    ↓                                               │
│ 5. User can:                                       │
│    ✓ Accept suggestion                            │
│    ✓ Tap to see all accounts                      │
│    ✓ Override with different account              │
│    ↓                                               │
│ 6. User enters amount: $5.50                      │
│    ↓                                               │
│ 7. Category auto-suggested: "Coffee" (from merch) │
│    ↓                                               │
│ 8. User taps "Save"                               │
│    ↓                                               │
│ 9. Transaction created:                           │
│    Badge: "Manual" (blue)                         │
└────────────────────────────────────────────────────┘
```

### UX Flow 4: Ambiguous Match Resolution

```
┌────────────────────────────────────────────────────┐
│ 1. SMS: "Card ****1234 charged $100"              │
│    ↓                                               │
│ 2. Multiple matches found:                        │
│    - Chase Sapphire ****1234 (confidence: 0.6)    │
│    - Amex Blue ****1234 (confidence: 0.55)        │
│    ↓                                               │
│ 3. Dialog shown:                                   │
│    ┌─────────────────────────────────┐            │
│    │ Which account was used?         │            │
│    │                                 │            │
│    │ ○ Chase Sapphire (****1234)    │ ← Suggested│
│    │ ○ Amex Blue (****1234)         │            │
│    │                                 │            │
│    │ [Cancel]        [Confirm]      │            │
│    └─────────────────────────────────┘            │
│    ↓                                               │
│ 4. User selects correct account                   │
│    ↓                                               │
│ 5. Transaction saved with selected account        │
└────────────────────────────────────────────────────┘
```

---

## 8. UI Components & Indicators

### Source Type Badges

Displayed on each transaction in the list:

```dart
┌──────────────────────────────────────────┐
│ 🍔 Starbucks                      $5.50  │
│    Coffee • 2 days ago                   │
│    💳 Chase Sapphire                     │
│    [SMS] ← Badge                         │
└──────────────────────────────────────────┘
```

**Badge Colors:**
- `SMS` - Green (successfully matched)
- `SMS (Needs Review)` - Yellow/Warning (low confidence)
- `Manual` - Blue (user-entered)
- `Recurring` - Purple (automated)
- `Imported` - Gray (from file)

### Confidence Indicators

For SMS transactions, show confidence level:

```dart
┌──────────────────────────────────────────┐
│ Transaction Details                      │
├──────────────────────────────────────────┤
│ Source: SMS                              │
│ Confidence: ████████░░ 80%    ← Visual   │
│ Matched by: Account identifier           │
│                                          │
│ ✓ High confidence - Auto-assigned       │
└──────────────────────────────────────────┘
```

### Review Queue

Dedicated screen for transactions needing review:

```dart
┌──────────────────────────────────────────┐
│ Transactions Need Review (3)             │
├──────────────────────────────────────────┤
│ ⚠️ $45.99 • Amazon                       │
│    No account matched                    │
│    [Assign Account] →                    │
├──────────────────────────────────────────┤
│ ⚠️ $12.50 • Unknown Merchant             │
│    Low confidence (45%)                  │
│    Suggested: Chase ****1234             │
│    [Review] →                            │
└──────────────────────────────────────────┘
```

---

## 9. Database Schema

### Accounts Table

```sql
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  balance REAL NOT NULL DEFAULT 0,
  last4 TEXT,
  due_date_day INTEGER,
  credit_limit REAL,
  
  -- Hybrid matching fields
  institution_name TEXT,
  account_identifier TEXT,
  sms_keywords TEXT,        -- Comma-separated
  account_alias TEXT,
  
  deleted_at INTEGER
);

-- Indexes for fast matching
CREATE INDEX idx_accounts_institution ON accounts(institution_name);
CREATE INDEX idx_accounts_identifier ON accounts(account_identifier);
CREATE INDEX idx_accounts_last4 ON accounts(last4);
```

### Transactions Table

```sql
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  category TEXT NOT NULL,
  note TEXT,
  date TEXT NOT NULL,
  account_id INTEGER,
  recurring_id INTEGER,
  
  -- Hybrid transaction fields
  sms_source TEXT,          -- Original SMS text
  source_type TEXT NOT NULL DEFAULT 'manual',
  merchant TEXT,
  confidence_score REAL,    -- 0.0 to 1.0
  needs_review INTEGER DEFAULT 0,
  
  deleted_at INTEGER,
  
  FOREIGN KEY (account_id) REFERENCES accounts(id)
);

-- Indexes for review queue and filtering
CREATE INDEX idx_transactions_needs_review ON transactions(needs_review);
CREATE INDEX idx_transactions_source_type ON transactions(source_type);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_merchant ON transactions(merchant);
```

---

## 10. API Reference

### AccountMatchingService Methods

#### matchForSms()

Match account for SMS-parsed transaction.

```dart
static Future<AccountMatchResult> matchForSms({
  required String smsBody,
  String? detectedLast4,
  String? detectedInstitution,
})
```

**Parameters:**
- `smsBody` - Full SMS message text
- `detectedLast4` - Extracted last 4 digits (optional)
- `detectedInstitution` - Extracted institution name (optional)

**Returns:** `AccountMatchResult` with match details

#### suggestForManual()

Get smart account suggestions for manual entry.

```dart
static Future<List<AccountMatchResult>> suggestForManual({
  String? merchantName,
  String? description,
  String? accountHint,
})
```

**Parameters:**
- `merchantName` - Merchant name entered by user
- `description` - Transaction description
- `accountHint` - User's search/filter text

**Returns:** List of up to 5 suggested accounts, sorted by confidence

#### validateAccountAssignment()

Validate account assignment before saving.

```dart
static Future<bool> validateAccountAssignment({
  required int? accountId,
  required String sourceType,
  required bool needsReview,
})
```

**Returns:** `true` if valid, `false` otherwise

---

## 11. Configuration & Settings

### SMS Auto-Import Settings

Users can control SMS behavior:

```dart
// Enable/disable SMS auto-import
await SmsService.setEnabled(true);

// Set scan range
await SmsService.setScanRange(SmsScanRange.threeMonths);

// Options:
// - SmsScanRange.allTime
// - SmsScanRange.sixMonths
// - SmsScanRange.threeMonths
// - SmsScanRange.oneMonth
// - SmsScanRange.oneWeek
```

### Confidence Threshold Adjustment

Developers can adjust thresholds in `AccountMatchingService`:

```dart
// Current defaults
static const double _confidenceThresholdHigh = 0.8;   // Auto-assign
static const double _confidenceThresholdMedium = 0.5; // Assign with review
```

---

## 12. Testing & Validation

### Test Scenarios

**Scenario 1: Perfect Match**
```dart
// Given: Account with institutionName="Chase", accountIdentifier="****1234"
// When: SMS contains "Chase ****1234"
// Then: Confidence >= 0.8, auto-assigned, no review needed
```

**Scenario 2: Partial Match**
```dart
// Given: Account with last4="1234", no institution
// When: SMS contains "****1234" but no institution
// Then: Confidence ~0.3, needs review
```

**Scenario 3: Keyword Fallback**
```dart
// Given: Account with smsKeywords=["HDFCBK"]
// When: SMS from "HDFCBK" but no last4
// Then: Confidence ~0.2, needs review
```

**Scenario 4: No Match**
```dart
// Given: No matching accounts
// When: SMS from unknown sender
// Then: Confidence = 0.0, accountId = null, needs review
```

**Scenario 5: Ambiguous Match**
```dart
// Given: Two accounts with same last4
// When: SMS contains only last4
// Then: requiresConfirmation = true, show alternatives
```

### Manual Testing Checklist

- [ ] Create account with all matching fields
- [ ] Send test SMS and verify auto-assignment
- [ ] Send SMS with unknown account → verify review queue
- [ ] Manually add transaction → verify suggestions
- [ ] Manually add with known merchant → verify historical scoring
- [ ] Create duplicate last4 → verify ambiguous handling
- [ ] Delete account → verify transactions unlinked
- [ ] Test with empty institutionName
- [ ] Test with empty smsKeywords
- [ ] Test all source types (sms, manual, recurring, import)

---

## 13. Security & Privacy

### Data Protection

**SMS Data:**
- ✅ Full SMS text stored in `sms_source` for audit
- ❌ No personal info beyond transaction details
- ❌ PIN, CVV, OTP never stored
- ❌ Full account numbers never stored

**Sensitive Fields:**
- `accountIdentifier` - Masked format only (****1234)
- `last4` - Last 4 digits only (no full number)
- `smsKeywords` - Public identifiers only (bank codes)

### User Control

**Transparency:**
- Source type always visible (`sourceBadge`)
- Confidence scores shown for SMS
- Match reasons displayed ("Account identifier match")
- Original SMS accessible for verification

**Override Capability:**
- User can always change account assignment
- Manual corrections override auto-matching
- Review queue for low-confidence matches
- Confirmation dialogs for ambiguous cases

---

## 14. Performance Optimization

### Caching Strategy

```dart
// Cache accounts in memory during active session
static List<Account>? _cachedAccounts;
static DateTime? _cacheTime;

static Future<List<Account>> _getAccounts() async {
  if (_cachedAccounts != null && 
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < Duration(minutes: 5)) {
    return _cachedAccounts!;
  }
  _cachedAccounts = await AppDatabase.getAccounts();
  _cacheTime = DateTime.now();
  return _cachedAccounts!;
}
```

### Index Usage

```sql
-- Fast lookups for matching
CREATE INDEX idx_accounts_identifier ON accounts(account_identifier);
CREATE INDEX idx_transactions_merchant ON transactions(merchant);
CREATE INDEX idx_transactions_needs_review ON transactions(needs_review);
```

### Batch Processing

```dart
// Process multiple SMS messages in batch
static Future<List<Transaction>> processBatchSms(List<SmsMessage> messages) async {
  final txns = <Transaction>[];
  final accounts = await AppDatabase.getAccounts(); // Single query
  
  for (final sms in messages) {
    // Process each with cached account list
    final match = await matchForSms(/* ... */);
    txns.add(/* ... */);
  }
  
  return txns;
}
```

---

## 15. Future Enhancements

### Planned Features

**Machine Learning Integration:**
- Train on user's historical corrections
- Improve fuzzy matching accuracy
- Detect new merchant patterns

**Multi-Account Support:**
- Handle transactions affecting multiple accounts
- Split transactions across accounts
- Joint account sharing

**Advanced Historical Analysis:**
- Time-of-day patterns (lunch vs dinner)
- Location-based suggestions (GPS-aware)
- Spending category correlations

**Enhanced SMS Parsing:**
- Support more bank formats
- International SMS patterns
- Multi-currency handling

**Conflict Resolution:**
- Detect duplicate transactions (same amount, merchant, time)
- Merge duplicates automatically
- Smart deduplication

---

## 16. Troubleshooting

### Common Issues

**Issue: SMS not auto-importing**
- Check SMS permission granted
- Verify SMS enabled: `await SmsService.isEnabled()`
- Check sender matches `_bankSenderRe` pattern
- Review scan range setting

**Issue: Wrong account matched**
- Check account `accountIdentifier` format (must be ****XXXX)
- Verify `institutionName` matches SMS text
- Add `smsKeywords` for better matching
- Review SMS parsing logs

**Issue: All transactions need review**
- Accounts missing `institutionName` or `accountIdentifier`
- SMS doesn't contain identifiable info
- Add smsKeywords as fallback

**Issue: Manual suggestions not working**
- No historical transactions with merchant
- Account alias/name doesn't match search
- Clear and rebuild transaction history

**Issue: Historical scoring always 0**
- Merchant field not consistently filled
- Transaction note doesn't contain merchant
- Database query optimization needed

---

## 17. Migration Guide

### Existing Installation

If upgrading from a system without hybrid matching:

**Step 1: Run database migration**
```dart
await AppDatabase.db.execute('''
  ALTER TABLE accounts ADD COLUMN institution_name TEXT;
  ALTER TABLE accounts ADD COLUMN account_identifier TEXT;
  ALTER TABLE accounts ADD COLUMN sms_keywords TEXT;
  ALTER TABLE accounts ADD COLUMN account_alias TEXT;
  
  ALTER TABLE transactions ADD COLUMN sms_source TEXT;
  ALTER TABLE transactions ADD COLUMN source_type TEXT DEFAULT 'manual';
  ALTER TABLE transactions ADD COLUMN merchant TEXT;
  ALTER TABLE transactions ADD COLUMN confidence_score REAL;
  ALTER TABLE transactions ADD COLUMN needs_review INTEGER DEFAULT 0;
''');
```

**Step 2: Backfill existing data**
```dart
// Set all existing transactions to 'manual'
await AppDatabase.db.execute('''
  UPDATE transactions 
  SET source_type = 'manual' 
  WHERE source_type IS NULL;
''');

// Generate account identifiers from last4
await AppDatabase.db.execute('''
  UPDATE accounts 
  SET account_identifier = '****' || last4 
  WHERE last4 IS NOT NULL AND account_identifier IS NULL;
''');
```

**Step 3: Prompt users to update accounts**
- Show one-time setup wizard
- Ask users to add institution names
- Suggest common smsKeywords based on account type

---

## Conclusion

The Hybrid Transaction Mapping System provides a robust, intelligent solution for managing transactions from multiple sources. By combining priority-based matching, confidence scoring, and user control, it ensures accurate account assignment while maintaining transparency and data integrity.

**Key Strengths:**
- ✅ Unified matching engine for all sources
- ✅ Confidence-based decision making
- ✅ User override capability
- ✅ Privacy-focused design
- ✅ Extensible architecture

**Best Practices:**
1. Always populate `institutionName` and `accountIdentifier` for best matching
2. Add `smsKeywords` for banks with unique SMS patterns
3. Review low-confidence matches to improve system learning
4. Keep merchant names consistent for historical accuracy
5. Regularly audit review queue to catch edge cases

---

*Last Updated: April 18, 2026*  
*System Version: 1.0.0*  
*Documentation Version: 1.0*
