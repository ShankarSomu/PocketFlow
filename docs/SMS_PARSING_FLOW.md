# SMS Parsing Flow - Complete Reference

**Last Updated**: 2026-04-23  
**Status**: Production  
**Version**: 2.0

> **📋 Active Development**: See [SMS_RULE_IMPROVEMENTS_PLAN.md](SMS_RULE_IMPROVEMENTS_PLAN.md) for upcoming rule-based enhancements (Transfer accuracy 88%→95%, Account type grouping, Weighted confidence scoring)

---

## 📊 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Files & Responsibilities](#files--responsibilities)
3. [Complete Processing Pipeline](#complete-processing-pipeline)
4. [Input/Output Formats](#inputoutput-formats)
5. [Regex Patterns & Extraction Logic](#regex-patterns--extraction-logic)
6. [Edge Cases Handled](#edge-cases-handled)
7. [Known Issues & Pain Points](#known-issues--pain-points)
8. [Performance Characteristics](#performance-characteristics)

---

## Architecture Overview

### High-Level Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                      SMS ARRIVES (Android)                       │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1: PRIVACY FILTER (PrivacyGuard)                         │
│  ─────────────────────────────────────────                       │
│  • Block OTP, passwords, auth codes                              │
│  • Sanitize sensitive data                                       │
│  • Return: blocked | sanitized SMS text                          │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 2: CLASSIFICATION (SmsClassificationService)              │
│  ────────────────────────────────────────────────                │
│  • Rule-based keyword matching                                   │
│  • Categories: expense | income | transfer | balance | reminder  │
│  • Return: { type, confidence, reason }                          │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 3: ENTITY EXTRACTION (EntityExtractionService)            │
│  ──────────────────────────────────────────────────              │
│  • Extract: amount, merchant, account, institution               │
│  • Regex-based parsing (14-step algorithm)                       │
│  • Return: ExtractedEntities                                     │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 4: ACCOUNT RESOLUTION (AccountResolutionEngine)           │
│  ───────────────────────────────────────────────────             │
│  • Match to existing accounts (5 strategies)                     │
│  • Create account candidate if new                               │
│  • Return: { accountId, confidence, method }                     │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 5: TRANSACTION CREATION (SmsPipelineExecutor)             │
│  ─────────────────────────────────────────────────               │
│  • Create Transaction record                                     │
│  • Handle transfers (create pending action)                      │
│  • Set confidence & review flags                                 │
│  • Return: SmsProcessingResult                                   │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  POST-PROCESSING (Background)                                    │
│  ──────────────────────────                                      │
│  • Transfer Detection (pair matching)                            │
│  • Account Graph Building                                        │
│  • Data Integrity Validation                                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## Files & Responsibilities

### Core Pipeline Files

| File | Responsibility | Lines | Key Functions |
|------|---------------|-------|---------------|
| [sms_pipeline_executor.dart](../lib/services/sms_pipeline_executor.dart) | **Orchestration** - Coordinates all layers | 453 | `processSms()` |
| [sms_classification_service.dart](../lib/services/sms_classification_service.dart) | **Classification** - Rule-based categorization | 210 | `classify()` |
| [entity_extraction_service.dart](../lib/services/entity_extraction_service.dart) | **Extraction** - Parse structured data | 393 | `extract()` |
| [advanced_sms_parser.dart](../lib/services/advanced_sms_parser.dart) | **Advanced Parsing** - 14-step algorithm | 1132 | `parse()`, `reviewParse()` |
| [account_resolution_engine.dart](../lib/services/account_resolution_engine.dart) | **Account Matching** - 5-strategy resolution | 394 | `resolve()` |
| [privacy_guard.dart](../lib/services/privacy_guard.dart) | **Privacy** - Filter sensitive SMS | ~200 | `isSensitive()`, `sanitize()` |

### Supporting Services

| File | Purpose |
|------|---------|
| [transfer_detection_engine.dart](../lib/services/transfer_detection_engine.dart) | Post-processing: Find transfer pairs |
| [data_integrity_service.dart](../lib/services/data_integrity_service.dart) | Validate accounting rules |
| [ml_sms_classifier.dart](../lib/services/ml_sms_classifier.dart) | ML classification (optional hybrid mode) |

---

## Complete Processing Pipeline

### Layer 1: Privacy Filter

```dart
// File: lib/services/privacy_guard.dart

if (PrivacyGuard.isSensitive(messageBody)) {
  // Block: OTP, passwords, verification codes
  return blocked;
}

final sanitizedBody = PrivacyGuard.sanitize(messageBody);
// Removes: Card CVV, full account numbers, SSN/Aadhaar
```

**Blocked Patterns**:
- OTP: `123456`, `OTP is 834729`
- Authentication: `verification code`, `security code`
- Passwords: `password reset`, `temporary password`
- PII: Full card numbers, SSN, Aadhaar

---

### Layer 2: Classification

```dart
// File: lib/services/sms_classification_service.dart

final classification = SmsClassificationService.classify(rawSms);

// Returns:
SmsClassification {
  type: SmsType.transactionDebit,    // or income, transfer, accountUpdate, etc.
  confidence: 0.95,
  reason: 'Contains debit keywords and amount'
}
```

**Categories**:
1. **`transactionDebit`** - Money leaving account
   - Keywords: `debited`, `spent`, `withdrawn`, `charged`, `purchase`, `paid`
   
2. **`transactionCredit`** - Money entering account
   - Keywords: `credited`, `received`, `deposited`, `refund`, `cashback`, `salary`
   
3. **`transfer`** - Between your accounts
   - Keywords: `payment posted to`, `transferred to`, `payment received from`
   
4. **`accountUpdate`** - Balance alerts
   - Keywords: `balance is`, `available balance`, `credit limit`
   
5. **`paymentReminder`** - Due date alerts
   - Keywords: `payment due`, `bill due`, `minimum amount due`
   
6. **`nonFinancial`** - Not financial
   - Rejection: No amount, no financial keywords

---

### Layer 3: Entity Extraction

```dart
// File: lib/services/entity_extraction_service.dart

final entities = await EntityExtractionService.extract(rawSms, classification);

// Returns:
ExtractedEntities {
  amount: 1234.56,
  merchant: "Target",
  accountIdentifier: "****5517",
  institutionName: "Chase Bank",
  balance: null,
  referenceNumber: "TXN123456",
  transactionType: SmsType.transactionDebit,
  timestamp: DateTime,
  confidenceScore: 0.82
}
```

**Extraction Process** (14 Steps):

#### Step 1: Analyze Signals
- Detect transaction keywords
- Find currency indicators
- Identify patterns (balance alerts, statements)

#### Step 2: Detect Region
```dart
// Auto-detect region from:
// 1. Sender ID (HDFCBK → India, CHASE → US)
// 2. Currency (₹ → India, $ → US)
// 3. Phone format (+91 → India, +1 → US)

region: RegionEnum.us  // or india, uk, unknown
```

#### Step 3: Determine Type
```dart
// Based on keywords:
// - Debit: debited, spent, withdrawn, charged
// - Credit: credited, received, deposited, refund
// - Transfer: payment posted, transferred, sent
// - Unknown: No clear indicators

transactionType: TransactionTypeEnum.debit
```

#### Step 4: Extract Amount
```dart
// Patterns (priority order):
// 1. Currency symbol + amount: $1,234.56
// 2. Currency code + amount: USD 1234, INR 500
// 3. Amount + currency code: 1234 USD
// 4. Keyword + amount: amount: 1234.56
// 5. Generic decimal: 1234.56

// Edge cases handled:
// - Skip card numbers in parentheses: (7330)
// - Avoid amounts after "card ending"
// - Filter out account numbers

amount: 1234.56
```

#### Step 5: Extract Currency
```dart
// Priority:
// 1. Explicit symbols: ₹ → INR, $ → USD, € → EUR, £ → GBP
// 2. Currency codes: INR, USD, EUR, GBP, Rs
// 3. Region fallback: India → INR, US → USD

currency: "USD"
```

#### Step 6: Extract Merchant
```dart
// Patterns:
// 1. "at MERCHANT" → at Target
// 2. "to MERCHANT" → to Chase Paymentech
// 3. "from MERCHANT" → from Starbucks
// 4. "for MERCHANT" → for Amazon Prime
// 5. "via MERCHANT" → via PayPal

// Special cases:
// - Credit card payments: "payment posted to" → "Credit Card Payment"
// - Electronic drafts: "electronic draft" → Extract payee or "Electronic Draft"

// Filters:
// - Exclude: your, account, card, balance, transaction
// - Skip if part of account identifier

merchant: "Target"
```

#### Step 7: Identify Bank
```dart
// Mapping: Sender ID → Bank Name
// US: CHASE → Chase Bank, BOFA → Bank of America, CAPONE → Capital One
// India: HDFCBK → HDFC Bank, ICICIBK → ICICI Bank, SBIINB → State Bank of India

// Fallback: Keywords in message body

bank: "Chase Bank"
```

#### Step 8: Extract Account
```dart
// Patterns:
// 1. Masked formats: XX1234, XXXX1234, ****1234
// 2. "ending in 1234"
// 3. Account formats: A/C XX1234, account - 3281
// 4. Card formats: card - 5517, Card x9993
// 5. UPI: user@okicici
// 6. Parenthesis: (XXXX), …(XXXX)

accountIdentifier: "****5517"
```

#### Step 9: Cross-Validate Sender
```dart
// Check if sender ID matches bank
// Known aliases: BOFA → Bank of America, HDFCBK → HDFC

// If mismatch, add suggestion for review
```

#### Step 10-14: Validation & Scoring
```dart
// Step 10: Validate all fields present
// Step 11: Generate improvement suggestions
// Step 12: Calculate confidence (see scoring below)
// Step 13: Apply region-specific rules
// Step 14: Final transaction classification

confidenceScore: 0.82
```

---

### Layer 4: Account Resolution

```dart
// File: lib/services/account_resolution_engine.dart

final resolution = await AccountResolutionEngine.resolve(entities);

// Returns:
AccountResolution {
  accountId: 123,                    // Matched account ID
  confidence: 0.95,
  method: 'exact_identifier',
  requiresUserConfirmation: false,
  reason: 'Exact match on account identifier'
}
```

**5 Matching Strategies** (in priority order):

#### Strategy 1: Exact Identifier Match (95% confidence)
```sql
SELECT * FROM accounts 
WHERE account_identifier = '****5517' 
AND deleted_at IS NULL
```

#### Strategy 2: Institution + Partial Match (80% confidence)
```sql
SELECT * FROM accounts 
WHERE institution_name = 'Chase Bank' 
AND (account_identifier LIKE '%5517' OR last4 = '5517')
AND deleted_at IS NULL
```

#### Strategy 3: SMS Keyword Match (70% confidence)
```sql
SELECT * FROM accounts 
WHERE institution_name = 'Chase Bank' 
OR sms_keywords LIKE '%Chase%'
AND deleted_at IS NULL
```

#### Strategy 4: Historical Pattern Match (60% confidence)
```sql
-- Find account that frequently has transactions with this merchant
SELECT account_id, COUNT(*) as match_count
FROM transactions
WHERE merchant = 'Target'
AND institution_name = 'Chase Bank'
GROUP BY account_id
ORDER BY match_count DESC
```

#### Strategy 5: Create Account Candidate (50% confidence)
```dart
// No match found → Create candidate for user confirmation
await createAccountCandidate(entities);

return AccountResolution(
  accountCandidateId: 456,
  method: 'new_candidate',
  requiresUserConfirmation: true
);
```

---

### Layer 5: Transaction Creation

```dart
// File: lib/services/sms_pipeline_executor.dart

// High confidence (≥80%) → Create transaction directly
if (resolution.isHighConfidence) {
  final transaction = Transaction(
    accountId: resolution.accountId,
    amount: entities.amount!,
    merchant: entities.merchant,
    category: _getDefaultCategory(classification.type, entities.merchant),
    type: transactionType,  // 'expense' or 'income'
    smsSource: rawSms.body,
    confidenceScore: resolution.confidence,
    needsReview: false
  );
  
  await AppDatabase.insertTransaction(transaction);
}

// Medium confidence (60-79%) → Create but mark for review
else if (resolution.confidence >= 0.60) {
  transaction.needsReview = true;
  await AppDatabase.insertTransaction(transaction);
}

// Low confidence (<60%) → Create pending action
else {
  await PendingActionService.createAction(
    type: 'account_unresolved',
    data: entities
  );
}
```

**Special Handling: Transfers**
```dart
// ⚠️ CRITICAL: Never create single expense for transfers
// Would cause double-counting in reports

if (classification.type == SmsType.transfer) {
  // Create pending action instead
  // Transfer Detection Engine will create proper 2-transaction transfer later
  await PendingActionService.createAction(
    type: 'confirm_transfer',
    priority: 'medium',
    data: {
      'sms_body': rawSms.body,
      'amount': entities.amount,
      'confidence': resolution.confidence
    }
  );
}
```

---

## Input/Output Formats

### Input: Raw SMS

```dart
RawSmsMessage {
  id: 0,                          // Temporary, assigned later
  sender: "CHASE",                // Sender ID
  body: "Target debit card ...",  // Full message text
  timestamp: DateTime             // Received time
}
```

**Example SMS Messages**:

```
1. Debit Transaction (US - Chase)
"Target debit card ..5517 $45.82 on 06/04/24 Available credit limit $7,330 – Chase"

2. Credit Card Payment (US - Capital One)
"CAPITAL ONE: Payment of $1,175.03 posted to credit card acct ending in …(XXXX) at 11-03-2024 4:28 PM"

3. Debit Transaction (India - HDFC)
"Rs 500.00 debited from A/C XX1234 on 23-APR-26 at HDFC Bank ATM. Avl Bal: Rs 45,000.00"

4. Salary Credit (India - SBI)
"INR 50000.00 credited to your A/C XX5678 on 01-APR-26. Salary from ABC Corp. Avl bal: Rs 55000"

5. Transfer (India - ICICI)
"Rs 10000 transferred from A/C XX1234 to A/C XX5678 on 23-APR-26. Ref: UPI/123456"
```

---

### Output: SmsProcessingResult

```dart
SmsProcessingResult {
  success: true,
  message: "Transaction created",
  transactionId: 789,              // Database ID
  pendingActionId: null,
  smsType: SmsType.transactionDebit,
  requiresUserAction: false,
  confidence: 0.95
}
```

**Success Scenarios**:
1. **High Confidence Transaction**: `transactionId` set, `needsReview = false`
2. **Medium Confidence Transaction**: `transactionId` set, `needsReview = true`
3. **Pending Action**: `pendingActionId` set, requires user input
4. **Ignored**: Non-financial SMS, no action needed

**Failure Scenarios**:
1. **Privacy Block**: Sensitive data detected
2. **Parsing Error**: Exception in pipeline
3. **Validation Fail**: Required data missing

---

## Regex Patterns & Extraction Logic

### Amount Extraction Patterns

```dart
// Priority order (most specific → least specific)

// 1. Currency symbol + amount (highest priority)
RegExp(r'[₹\$€£¥]\s*(\d+(?:,\d{3})*(?:\.\d{2})?)')
// Matches: ₹1,234.56, $45.82, €100.00

// 2. Currency code before amount
RegExp(r'\b(?:inr|usd|eur|gbp|rs\.?)\s*(\d+(?:,\d{3})*(?:\.\d{2})?)')
// Matches: INR 500, USD 1234.56, Rs. 100

// 3. Amount + currency code after
RegExp(r'\b(\d+(?:,\d{3})*(?:\.\d{2})?)\s*(?:inr|usd|eur|gbp|rs)')
// Matches: 1234.56 INR, 500 Rs

// 4. Keyword + amount
RegExp(r'\b(?:amount|amt|sum|value)[:\s]*[₹\$€£¥]?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)')
// Matches: amount: 1234.56, amt Rs 500

// 5. Generic decimal (lowest priority)
RegExp(r'\b(\d+(?:,\d{3})*\.\d{2})\b')
// Matches: 45.82, 1,175.03
```

**Edge Case Handling**:
```dart
// Skip if amount is in parentheses after "card"
// Example: "card ending 1234 (5517)" → 5517 is card number, not amount
if (originalText.contains('($amountStr)') && !lowerText.contains('amount')) {
  continue; // Skip
}

// Skip if after "ending" or "last"
// Example: "ending 1234" → 1234 is card number, not amount
if (lowerText.substring(0, index).contains(RegExp(r'card.*\(|ending|last'))) {
  continue; // Skip
}

// Validate reasonable range
if (amount != null && amount > 0 && amount < 1000000) {
  return amount; // Accept
}
```

---

### Account Identifier Patterns

```dart
// 1. Standard masked formats
RegExp(r'\b([xX]{2,}\d{4})\b')          // XX1234, XXXX1234
RegExp(r'(\*{4}\d{4})\b')               // ****1234

// 2. "ending in" / "last" formats
RegExp(r'\b(?:ending|last)\s+(?:in\s+)?(\d{4})\b')  // ending in 1234, last 5517

// 3. Account number with keywords
RegExp(r'\b(?:a\/c|ac|acc|account)\s*(?:no\.?|number)?\s*[:\s-]*([xX*]{2,}\d{4,6}|\d{4,16})\b')
// Matches: A/C XX1234, account - 3281, Acc XX026

// 4. Card formats
RegExp(r'\b(?:card|debit|credit)\s*(?:card)?\s*[:\s-]+\s*([xX*]{1,4}\d{4})\b')
// Matches: card - 5517, Card x9993, debit card - 5517

RegExp(r'\bcard\s+(?:ending|no\.?)\s*[:\s]*([xX*]{2,}\d{4}|\d{4})\b')
// Matches: card ending 1234

// 5. UPI formats
RegExp(r'\b([a-z0-9._%+-]+@[a-z0-9.-]+)\b')    // user@okicici
RegExp(r'\bupi:\s*([a-z0-9._%+-]+@[a-z0-9.-]+)\b')  // UPI: user@ybl

// 6. Parenthesis formats (Capital One style)
RegExp(r'\(([xX*]{4})\)')                       // (XXXX)
RegExp(r'…\(([xX*]{4})\)')                      // …(XXXX) with ellipsis
```

---

### Merchant Extraction Patterns

```dart
// Special patterns first:

// 1. Credit card payment indicator
if (lowerText.contains('payment posted to') || 
    lowerText.contains('payment applied to')) {
  return 'Credit Card Payment';
}

// 2. Electronic draft/ACH
if (lowerText.contains('electronic draft') || 
    lowerText.contains('ach debit')) {
  // Try to extract payee
  RegExp(r'draft\s+(?:to|from)\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')
  // If found: return payee name
  // Else: return 'Electronic Draft'
}

// Standard patterns:
RegExp(r'\bat\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')      // at Target
RegExp(r'\bto\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')      // to Starbucks
RegExp(r'\bfrom\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')    // from Amazon
RegExp(r'\bfor\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')     // for Netflix
RegExp(r'\bvia\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')     // via PayPal
RegExp(r'\bon\s+([A-Z][A-Za-z0-9\s&\-]{2,30})')      // on Uber
RegExp(r'\bmerchant[:\s]+([A-Z][A-Za-z0-9\s&\-]{2,30})')  // merchant: NAME

// Filter exclusions:
excludeWords = ['your', 'account', 'card', 'balance', 'transaction', 'payment']
if (merchantLower.startsWithAny(excludeWords)) {
  continue; // Skip
}
```

---

### Bank/Institution Detection

**Sender ID Mapping**:
```dart
// US Banks
'CHASE' → 'Chase Bank'
'BOFA' → 'Bank of America'
'CAPONE' → 'Capital One'
'CITI' → 'Citibank'
'WELLSFARGO' → 'Wells Fargo'
'AMEX' → 'American Express'

// Indian Banks
'HDFCBK' → 'HDFC Bank'
'ICICIBK' → 'ICICI Bank'
'SBIINB' → 'State Bank of India'
'AXISBK' → 'Axis Bank'
'KOTAKB' → 'Kotak Mahindra Bank'
'PAYTM' → 'Paytm Payments Bank'
```

**Fallback: Message Body Keywords**
```dart
if (lowerText.contains('chase')) return 'Chase Bank';
if (lowerText.contains('bank of america') || lowerText.contains('bofa')) 
  return 'Bank of America';
// etc.
```

---

### Region Detection

```dart
// Priority order:

// 1. Sender ID patterns
if (senderId.matches(r'^[A-Z]{6}$')) {
  // Indian format: HDFCBK, ICICIBK
  return RegionEnum.india;
}
if (senderId.matches(r'^[A-Z]{4,}$')) {
  // US format: CHASE, BOFA, CAPONE
  return RegionEnum.us;
}

// 2. Currency indicators
if (text.contains('₹') || text.contains('INR') || text.contains('Rs')) {
  return RegionEnum.india;
}
if (text.contains('$') || text.contains('USD')) {
  return RegionEnum.us;
}

// 3. Phone format
if (senderId.startsWith('+91') || senderId.startsWith('91')) {
  return RegionEnum.india;
}
if (senderId.startsWith('+1') || senderId.startsWith('1')) {
  return RegionEnum.us;
}

// 4. Date format
// DD-MM-YYYY → India
// MM/DD/YYYY → US

// Fallback
return RegionEnum.unknown;
```

---

## Edge Cases Handled

### 1. Card Numbers vs. Amounts
**Problem**: `(7330)` could be card number or amount

**Solution**:
```dart
// Skip amounts in parentheses near "card" keyword
if (text.contains('($amountStr)') && 
    text.before(amountStr).contains(RegExp(r'card|ending|last'))) {
  continue; // It's a card number
}
```

**Examples**:
- ✅ "Available credit limit $7,330" → Amount: 7330
- ❌ "card ending 1234 (7330)" → Skipped (card number)

---

### 2. Multiple Amounts in SMS
**Problem**: "Spent $50 at Target. Balance $1,200"

**Solution**:
```dart
// Priority: First amount with currency/keyword context
// 1. Try patterns with keywords: "amount:", "spent", "debited"
// 2. Take first currency-prefixed amount
// 3. Ignore "balance" amounts (handled separately)
```

**Examples**:
- "Spent $50 at Target. Balance $1,200" → Amount: 50
- "INR 500 debited. Avl bal: 45,000" → Amount: 500

---

### 3. Credit Card Payment vs. Merchant Transaction
**Problem**: "Payment to Target" could be bill pay or purchase

**Solution**:
```dart
// Detect "payment posted to" pattern
if (text.contains('payment posted to') || 
    text.contains('payment applied to')) {
  // This is a credit card payment (transfer)
  type = SmsType.transfer;
  merchant = 'Credit Card Payment';
}
```

**Examples**:
- ✅ "Payment posted to credit card 1234" → Transfer
- ✅ "Spent $50 at Target" → Expense

---

### 4. UPI Transfer Detection
**Problem**: UPI transfers can look like expenses

**Solution**:
```dart
// Check for transfer keywords
if (text.contains('transferred to') || 
    text.contains('transferred from') ||
    text.contains('upi transfer')) {
  type = SmsType.transfer;
}
```

---

### 5. Balance Alerts Without Transactions
**Problem**: "Your balance is $1,000" - not a transaction

**Solution**:
```dart
// Classify as accountUpdate, not transaction
if (hasBalanceKeywords && !hasTransactionKeywords) {
  type = SmsType.accountUpdate;
  // Extract balance, update account, don't create transaction
}
```

---

### 6. Reminders vs. Transactions
**Problem**: "Payment due $100" - future event, not transaction

**Solution**:
```dart
// Check for reminder keywords
if (text.contains('payment due') || 
    text.contains('bill due') ||
    text.contains('minimum amount due')) {
  type = SmsType.paymentReminder;
  // Don't create transaction, just log
}
```

---

### 7. Foreign Characters & Emojis
**Problem**: "₹500 💰", "…(XXXX)"

**Solution**:
```dart
// Regex patterns include Unicode:
RegExp(r'[₹\$€£¥]')  // Currency symbols
RegExp(r'…\(([xX*]{4})\)')  // Ellipsis handling

// Emoji filtering:
final cleanText = text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}]'), '');
```

---

### 8. Inconsistent Date Formats
**Problem**: "23-APR-26" vs. "06/04/24" vs. "11-03-2024"

**Solution**:
```dart
// Multiple date parsers:
// 1. DD-MMM-YY (23-APR-26)
// 2. MM/DD/YY (06/04/24)
// 3. DD-MM-YYYY (23-04-2026)
// 4. YYYY-MM-DD (2026-04-23)

// Fallback: Use SMS received timestamp
```

---

### 9. Missing Currency
**Problem**: "Spent 500 at Target" - no currency

**Solution**:
```dart
// Use region to infer:
if (region == RegionEnum.india) return 'INR';
if (region == RegionEnum.us) return 'USD';

// Or default: INR
```

---

### 10. Duplicate/Similar SMS
**Problem**: Bank sends multiple SMS for same transaction

**Solution**:
```dart
// Fingerprinting in SMS service:
final fingerprint = md5('$amount|$merchant|$date');

// Check if fingerprint exists in last 24 hours
if (await isDuplicate(fingerprint)) {
  // Skip processing
}
```

---

## Known Issues & Pain Points

### 1. ⚠️ Transfer Detection Accuracy (88%)

**Issue**: Rule-based transfer classification misses edge cases

**Examples of failures**:
```
❌ "Payment sent via Venmo to John" → Classified as expense, should be transfer
❌ "Autopay for credit card" → May create single transaction instead of transfer pair
```

**Workaround**: Post-processing Transfer Detection Engine finds pairs

**Future**: Upgrade to 4-class ML classifier (expense | income | transfer | noise)

---

### 2. ⚠️ Merchant Extraction Inconsistency

**Issue**: Merchant names vary across banks

**Examples**:
```
Bank A: "at AMAZON MKTPLACE"
Bank B: "AMZN*AMAZON.COM"
Bank C: "AMAZON.COM AMZN.COM/BILL"
```

**Impact**: Same merchant appears as 3 different entries

**Workaround**: Manual merchant mapping (user correction)

**Future**: Merchant normalization service

---

### 3. ⚠️ Account Resolution Ambiguity

**Issue**: Multiple accounts from same bank with similar identifiers

**Example**:
```
Account 1: Chase Checking ****1234
Account 2: Chase Savings  ****1234 (different account, same last 4)
```

**Current behavior**: Matches first account found (may be wrong)

**Workaround**: Mark transaction for review if multiple matches

**Future**: User preference learning (usually uses Checking for Target)

---

### 4. ⚠️ Balance Updates Don't Trigger Sync

**Issue**: Balance alert SMS doesn't update account balance

**Example**:
```
SMS: "Your balance is $1,500"
Database: Account balance still shows old value
```

**Impact**: Balance drift over time

**Current**: Partially implemented in `_processBalanceInquiry()`

**Future**: Full balance sync integration

---

### 5. ⚠️ New Bank Format Handling

**Issue**: Unknown bank SMS format requires manual pattern addition

**Example**:
```
New bank: "DISCOVER: You made a payment of $50 to WALMART on 04/23"
```

**Current**: Falls through to ML classifier (lower confidence)

**Workaround**: Add new pattern to `advanced_sms_parser.dart`

**Future**: Automatic pattern learning from user corrections

---

### 6. ⚠️ Multi-Currency Transactions

**Issue**: Foreign transactions may have 2 amounts

**Example**:
```
"Spent €50 (USD 54.25) at Paris Store"
```

**Current**: May extract wrong amount (either 50 or 54.25)

**Impact**: Incorrect transaction amount

**Workaround**: Manual correction

**Future**: Multi-currency transaction support

---

### 7. ⚠️ Pending Transaction Updates

**Issue**: Pending → Posted updates create duplicate

**Example**:
```
Day 1: "Pending charge $50 at Target"
Day 3: "Posted charge $50 at Target"
```

**Current**: Creates 2 separate transactions

**Impact**: Duplicate transactions

**Workaround**: Duplicate detection via fingerprinting

**Future**: Transaction state management (pending → posted)

---

### 8. ⚠️ Installment Payments

**Issue**: "1 of 3 payments" not tracked as series

**Example**:
```
Month 1: "Payment 1/3 of $100"
Month 2: "Payment 2/3 of $100"
```

**Current**: Creates 3 unrelated transactions

**Impact**: Can't track payment series

**Future**: Installment tracking feature

---

## Performance Characteristics

### Processing Time

| Operation | Typical Time | Notes |
|-----------|-------------|-------|
| Privacy Filter | < 1ms | Regex matching |
| Classification | 2-5ms | Rule-based |
| Entity Extraction | 5-15ms | 14-step algorithm |
| Account Resolution | 10-30ms | Database queries |
| Transaction Creation | 5-10ms | Database insert |
| **Total Pipeline** | **25-60ms** | Per SMS |

### Batch Processing

```dart
// Process 100 SMS messages
Time: ~3-5 seconds

// Breakdown:
// - Phase 1: Parse all SMS (100 × 30ms = 3s)
// - Phase 2: Deduplicate (fingerprinting)
// - Phase 3: Batch insert to DB
```

### Confidence Scoring

**Score Calculation** (0.0 - 1.0):
```dart
score = 0.0;

// Amount (25%)
if (amount != null && amount > 0) score += 0.25;

// Transaction type (20%)
if (type != unknown) score += 0.20;

// Account identifier (15%)
if (accountId != null) score += 0.15;

// Bank (15%)
if (bank != null) score += 0.15;

// Region (10%)
if (region != unknown) score += 0.10;

// Currency (8%)
if (currency != null) score += 0.08;

// Merchant (7%)
if (merchant != null) score += 0.07;
```

**Thresholds**:
- **≥ 0.80**: High confidence - Auto-create transaction
- **0.60 - 0.79**: Medium confidence - Create + mark for review
- **< 0.60**: Low confidence - Create pending action

---

## Testing Examples

### Example 1: US Debit Transaction

**Input SMS**:
```
Target debit card ..5517 $45.82 on 06/04/24 Available credit limit $7,330 – Chase
```

**Processing**:
```
Layer 1: Pass (not sensitive)
Layer 2: Classification = transactionDebit (confidence: 0.95)
Layer 3: Extracted entities:
  - amount: 45.82
  - merchant: "Target"
  - accountIdentifier: "5517"
  - institutionName: "Chase Bank"
  - currency: "USD"
  - region: us
Layer 4: Account matched (method: institution_partial, confidence: 0.80)
Layer 5: Transaction created (id: 789)
```

**Output**:
```dart
SmsProcessingResult {
  success: true,
  transactionId: 789,
  smsType: SmsType.transactionDebit,
  confidence: 0.92
}
```

---

### Example 2: India Credit Transaction

**Input SMS**:
```
INR 50000.00 credited to your A/C XX5678 on 01-APR-26. Salary from ABC Corp. Avl bal: Rs 55000
```

**Processing**:
```
Layer 1: Pass
Layer 2: Classification = transactionCredit (confidence: 0.95)
Layer 3: Extracted entities:
  - amount: 50000.00
  - merchant: "ABC Corp"
  - accountIdentifier: "XX5678"
  - institutionName: null (no sender provided)
  - currency: "INR"
  - region: india
Layer 4: Account matched (method: exact_identifier, confidence: 0.95)
Layer 5: Transaction created (category: "Salary")
```

---

### Example 3: Transfer (Pending Action)

**Input SMS**:
```
CAPITAL ONE: Payment of $1,175.03 posted to credit card acct ending in …(XXXX) at 11-03-2024 4:28 PM
```

**Processing**:
```
Layer 1: Pass
Layer 2: Classification = transfer (confidence: 0.89)
Layer 3: Extracted entities:
  - amount: 1175.03
  - merchant: "Credit Card Payment"
  - accountIdentifier: "XXXX"
  - institutionName: "Capital One"
  - currency: "USD"
Layer 4: Account matched (confidence: 0.75)
Layer 5: Pending action created (type: confirm_transfer)
         ⚠️ Does NOT create single transaction (prevents double-counting)
```

**Output**:
```dart
SmsProcessingResult {
  success: true,
  pendingActionId: 456,
  smsType: SmsType.transfer,
  requiresUserAction: true,
  confidence: 0.82
}
```

---

## Summary

### ✅ Strengths
- **Comprehensive**: 14-step parsing algorithm
- **Region-aware**: Auto-detects India/US/global formats
- **Accurate**: 90%+ classification accuracy
- **Fast**: 25-60ms per SMS
- **Edge case handling**: Card numbers, duplicates, transfers

### ⚠️ Weaknesses
- Transfer detection (88% accuracy)
- Merchant normalization
- Multi-account ambiguity
- New bank format adaptation

### 🎯 Future Improvements
1. Upgrade to 4-class ML classifier
2. Merchant normalization service
3. Balance sync integration
4. Automatic pattern learning
5. Installment tracking

---

## Related Documentation

- **[ML_RESPONSIBILITIES.md](ML_RESPONSIBILITIES.md)** - ML model scope
- **[ACCOUNTING_SYSTEM.md](ACCOUNTING_SYSTEM.md)** - Transaction handling
- **[DOUBLE_ENTRY_SOLUTION.md](DOUBLE_ENTRY_SOLUTION.md)** - Transfer detection
- **[SMS_INTELLIGENCE_ENGINE_DESIGN.md](SMS_INTELLIGENCE_ENGINE_DESIGN.md)** - Original design

---

**Maintained By**: PocketFlow Development Team  
**Version**: 2.0  
**Last Updated**: 2026-04-23
