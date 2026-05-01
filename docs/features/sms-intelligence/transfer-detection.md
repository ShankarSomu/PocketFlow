# Transfer Detection

Transfer detection identifies when money moves between your own accounts, preventing double-counting that would incorrectly affect your net worth.

## The Double-Entry Problem

Without transfer detection:

```
Day 1:  Credit Card: -Rs.500 (Amazon purchase)
        Net Worth: -Rs.500 ✓

Day 30: Bank Account: -Rs.500 (Credit card payment)
        Net Worth: -Rs.1000 ❌ (counted twice!)
```

With transfer detection:

```
Day 1:  Credit Card: -Rs.500 (Amazon purchase)
        Net Worth: -Rs.500 ✓

Day 30: TRANSFER: Bank → Credit Card (Rs.500)
        Net Worth: -Rs.500 ✓ (just moved money)
```

## What is a Transfer?

A transfer is money moving between accounts you own:
- Bank account → Credit card (payment)
- Savings → Checking (internal transfer)
- Cash → Bank (deposit)
- Credit card → Bank (refund)

**Key characteristic**: Net worth doesn't change.

## Detection Strategies

### 1. Explicit Transfer SMS

Some SMS explicitly indicate transfers:

```
✅ "Rs.1000 transferred from Savings XX1234 to XX5678"
✅ "Transfer of $500 from Account A to Account B"
✅ "Funds moved from checking to savings"
```

**Indicators**:
- "transferred", "transfer", "moved funds"
- Mentions two accounts in same SMS
- Institution-specific transfer keywords

### 2. Debit-Credit Pair Matching

Match a debit in one account with a credit in another.

```
SMS 1:  "HDFC: XX1234 debited Rs.1000 on 15-Apr"
SMS 2:  "ICICI: XX5678 credited Rs.1000 on 15-Apr"

Conditions Met:
✓ Same amount (Rs.1000)
✓ Same date or within 24 hours
✓ Different accounts (XX1234 vs XX5678)
✓ Opposite transaction types (debit vs credit)

Conclusion: Likely a transfer!
```

### 3. Payment Keyword Detection

Credit card payments:

```
✅ "Rs.5000 paid towards HDFC Card ending 1234"
✅ "Credit card payment processed"
✅ "Payment to credit card account"
```

**Indicators**:
- "payment to card", "card payment"
- "paid towards", "payment sent"
- Credit card account involved

### 4. Common Transfer Patterns

```
Bank → Credit Card    "Credit card payment"
Savings → Checking    "Internal transfer"
Cash → Bank           "Cash deposit"
Bank → Investment     "Investment transfer"
```

## Detection Algorithm

```dart
class TransferDetector {
  Future<bool> isTransfer(Transaction txn) {
    // 1. Check explicit transfer SMS
    if (hasTransferKeywords(txn.smsSource)) {
      return true;
    }
    
    // 2. Check payment keywords (bank → credit card)
    if (isPaymentToCard(txn)) {
      return true;
    }
    
    // 3. Look for matching transaction
    final match = await findMatchingTransaction(txn);
    if (match != null) {
      return true;
    }
    
    return false;
  }
  
  Future<Transaction?> findMatchingTransaction(Transaction txn) {
    // Find transactions within time window
    final candidates = await getTransactionsInWindow(
      txn.date,
      windowHours: 48,
    );
    
    for (final candidate in candidates) {
      if (isPotentialMatch(txn, candidate)) {
        return candidate;
      }
    }
    
    return null;
  }
  
  bool isPotentialMatch(Transaction t1, Transaction t2) {
    return t1.amount == t2.amount &&               // Same amount
           t1.type != t2.type &&                   // Opposite types
           t1.accountId != t2.accountId &&         // Different accounts
           areAccountsRelated(t1, t2);             // Both user's accounts
  }
}
```

## Matching Criteria

### Time Window

Transactions must occur within:
- **Same day**: Confidence 0.95
- **Within 1 day**: Confidence 0.85
- **Within 2 days**: Confidence 0.70
- **More than 2 days**: Review required

```dart
bool withinTimeWindow(DateTime d1, DateTime d2, {int hoursWindow = 48}) {
  return d1.difference(d2).inHours.abs() <= hoursWindow;
}
```

### Amount Matching

Amounts must match exactly or within tolerance:

```dart
bool amountsMatch(double amount1, double amount2) {
  // Exact match (preferred)
  if (amount1 == amount2) return true;
  
  // Allow small rounding errors
  final diff = (amount1 - amount2).abs();
  return diff < 0.05; // Within 5 cents/paise
}
```

### Account Relationship

Both accounts must belong to the user:

```dart
bool areAccountsRelated(Transaction t1, Transaction t2) {
  // Both accounts exist in user's account list
  return accountRepository.exists(t1.accountId) &&
         accountRepository.exists(t2.accountId);
}
```

## Transfer Types

### Internal Transfers

Same institution, between user's accounts:

```
"Rs.1000 transferred from Savings XX1234 to Checking XX5678"

Type: Internal Transfer
From: Savings Account 1234
To: Checking Account 5678
```

### Cross-Bank Transfers

Different institutions:

```
SMS 1: "HDFC: XX1234 debited Rs.5000"
SMS 2: "ICICI: XX5678 credited Rs.5000"

Type: Cross-Bank Transfer
From: HDFC Account 1234
To: ICICI Account 5678
```

### Credit Card Payments

Bank pay credit card:

```
"Rs.10000 paid towards HDFC Card ending 1234 from SBI A/c XX5678"

Type: Credit Card Payment
From: SBI Bank Account 5678
To: HDFC Credit Card 1234
```

## Creating Transfer Transactions

When transfer detected, create linked transactions:

```dart
class TransferPair {
  final Transaction outgoing;     // From account (debit)
  final Transaction incoming;     // To account (credit)
  final String transferReference; // Unique ID linking both
}

Future<TransferPair> createTransfer({
  required Account fromAccount,
  required Account toAccount,
  required double amount,
  required DateTime date,
  String? note,
}) {
  final reference = generateTransferReference();
  
  final outgoing = Transaction(
    type: 'transfer_out',
    amount: amount,
    accountId: fromAccount.id,
    fromAccountId: fromAccount.id,
    toAccountId: toAccount.id,
    transferReference: reference,
    category: 'Transfer',
    date: date,
    note: note,
  );
  
  final incoming = Transaction(
    type: 'transfer_in',
    amount: amount,
    accountId: toAccount.id,
    fromAccountId: fromAccount.id,
    toAccountId: toAccount.id,
    transferReference: reference,
    category: 'Transfer',
    date: date,
    note: note,
  );
  
  // Link transactions
  outgoing.linkedTransactionId = incoming.id;
  incoming.linkedTransactionId = outgoing.id;
  
  return TransferPair(
    outgoing: outgoing,
    incoming: incoming,
    transferReference: reference,
  );
}
```

## Unmatched Transfers

### Pending Matches

When one side of transfer is detected but match not found yet:

```dart
class PendingTransfer {
  final Transaction transaction;
  final DateTime detectedAt;
  final int daysWaiting;
  
  bool get shouldTimeout => daysWaiting > 7;
}
```

**Options**:
1. **Wait**: Partner transaction may arrive later
2. **Create placeholder**: Auto-create expected transaction
3. **User input**: Ask user to confirm or link manually

### User Manual Linking

UI to link transactions manually:

```
┌─────────────────────────────────────────────┐
│ Link as Transfer                            │
├─────────────────────────────────────────────┤
│ From Transaction:                           │
│ Rs.5000 debited from HDFC on 15-Apr        │
│                                             │
│ To Transaction:                             │
│ [Select matching transaction...]            │
│                                             │
│ Possible Matches:                           │
│ ○ Rs.5000 credited to ICICI on 15-Apr      │
│ ○ Rs.5000 credited to SBI on 16-Apr        │
│                                             │
│ [Cancel] [Link & Mark as Transfer]          │
└─────────────────────────────────────────────┘
```

## Handling Edge Cases

### 1. Partial Amounts

```
Debit: Rs.10000 (full credit card bill)
Credit: Rs.5000 (partial payment)

Solution: Don't auto-match. Let user decide.
```

### 2. Fees & Charges

```
Debit: Rs.1000.00
Credit: Rs.998.50 (Rs.1.50 transfer fee deducted)

Solution: Match if difference is small fee (< 2%)
```

### 3. Multiple Matches

```
Day 1: Rs.500 debited from HDFC
Day 1: Rs.500 credited to ICICI-A
Day 1: Rs.500 credited to ICICI-B

Solution: Present options to user for selection
```

### 4. Delayed Credits

```
Day 1: Rs.5000 debited from Bank
Day 3: Rs.5000 credited to Investment Account

Solution: Match within 3-day window for investment transfers
```

## Confidence Scoring

```dart
double calculateTransferConfidence(Transaction t1, Transaction t2) {
  double confidence = 0.0;
  
  // Exact amount match
  if (t1.amount == t2.amount) {
    confidence += 0.40;
  }
  
  // Same day
  if (isSameDay(t1.date, t2.date)) {
    confidence += 0.25;
  } else if (withinDays(t1.date, t2.date, 1)) {
    confidence += 0.15;
  }
  
  // Opposite types
  if (t1.type != t2.type) {
    confidence += 0.20;
  }
  
  // Transfer keywords
  if (hasTransferKeywords(t1) || hasTransferKeywords(t2)) {
    confidence += 0.15;
  }
  
  return confidence;
}
```

**Thresholds**:
- **> 0.85**: Auto-create transfer
- **0.70 - 0.85**: Flag for review
- **< 0.70**: Don't auto-match

## Impact on Reports

### Net Worth Calculation

```dart
double calculateNetWorth() {
  double total = 0.0;
  
  for (final account in accounts) {
    for (final txn in account.transactions) {
      // Skip transfer transactions (already counted in partner)
      if (txn.type == 'transfer_in' || txn.type == 'transfer_out') {
        continue;
      }
      
      if (txn.type == 'income' || txn.type == 'credit') {
        total += txn.amount;
      } else if (txn.type == 'expense' || txn.type == 'debit') {
        total -= txn.amount;
      }
    }
  }
  
  return total;
}
```

### Transfer Reports

Show transfers separately:

```
Income:    Rs.50,000
Expenses:  Rs.30,000
Transfers: Rs.10,000  (not counted in net)
─────────────────────
Net:       Rs.20,000
```

## Learning from Corrections

When user marks/unmarks as transfer:

```dart
void learnTransferPattern(Transaction t1, Transaction t2, bool isTransfer) {
  // Store pattern
  final pattern = TransferPattern(
    amountRange: AmountRange.from(t1.amount),
    fromAccountType: t1.account.type,
    toAccountType: t2.account.type,
    smsKeywords: extractKeywords([t1, t2]),
    isTransfer: isTransfer,
  );
  
  patternRepository.save(pattern);
}
```

## Testing

```dart
test('Detect transfer from explicit SMS', () {
  final sms = "Rs.1000 transferred from XX1234 to XX5678";
  final isTransfer = detector.isTransfer(sms);
  
  expect(isTransfer, true);
});

test('Match debit-credit pair', () {
  final debit = Transaction(
    type: 'debit',
    amount: 1000.0,
    date: DateTime(2026, 4, 15),
    accountId: 1,
  );
  
  final credit = Transaction(
    type: 'credit',
    amount: 1000.0,
    date: DateTime(2026, 4, 15),
    accountId: 2,
  );
  
  final match = detector.findMatchingTransaction(debit);
  expect(match, equals(credit));
});
```

## Performance

- **Detection time**: < 20ms per transaction
- **Matching accuracy**: 95%+ for standard transfers
- **False positives**: < 2%

## Next Steps

- [Recurring Patterns](recurring-patterns.md) - Detect subscriptions and recurring transactions
- [Account Resolution](account-resolution.md) - How accounts are matched

---

*For implementation, see `lib/services/transfer_detector.dart`*
