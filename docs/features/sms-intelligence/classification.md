# SMS Classification

The classification layer determines what type of financial message an SMS is and whether it should be processed.

## Classification Process

```
SMS Message
    ↓
Financial SMS Detection (Yes/No)
    ↓
Message Type Classification
    ├→ Transaction (Debit/Credit)
    ├→ Transfer
    ├→ Balance Update
    ├→ Payment Reminder
    ├→ Account Alert
    └→ Unknown Financial
```

## Step 1: Financial SMS Detection

### Purpose
Quickly filter out non-financial messages to avoid processing spam, personal messages, and marketing.

### Detection Criteria

**Financial Indicators** (must have at least one):
- Currency symbols: ₹, $, USD, INR, Rs
- Amount patterns: "500.00", "Rs.1,000", "$50"
- Financial keywords: "debited", "credited", "balance", "payment", "transfer"
- Account identifiers: "A/c XX1234", "Card ending 5678"

**Common Sender Patterns**:
- Bank codes: `HDFCBK`, `ICICIB`, `SBIIN`
- Bank names: Contains "Bank", "Card", "Credit"
- Payment platforms: PayPal, Venmo, UPI, Paytm

### What Gets Filtered Out

```
❌ "Your OTP is 123456" (OTP, not transaction)
❌ "20% off on all products!" (Marketing)
❌ "Meeting at 3pm" (Personal)
❌ "Verification code: 9876" (Security code)
✅ "Debited Rs.500 from A/c XX1234" (Financial transaction)
```

### Privacy Filters

Before classification, sensitive messages are excluded:
- **OTP messages**: Contains "OTP", "verification code", "PIN"
- **Password reset**: Contains "password", "reset", "security"
- **Authentication**: Multi-factor authentication codes

## Step 2: Message Type Classification

Once confirmed as financial, classify into specific types.

### Transaction Messages

**Characteristics**:
- Contains amount
- Has debit/credit indicator
- Mentions account or card
- Includes merchant/sender

**Patterns**:
```
Debit Examples:
- "Your A/c XX1234 debited by Rs.500.00 at Amazon"
- "Spent $50.00 at Starbucks using Card ending 1234"
- "Rs.299 deducted from your account for Netflix"

Credit Examples:
- "Your account credited with Rs.10000.00 salary"
- "Refund of $25.00 processed to Card ending 5678"
- "UPI-Cr Rs.500 received from User@bank"
```

**Keywords**:
- **Debit**: debited, deducted, spent, withdrawn, paid, charged
- **Credit**: credited, received, refund, cashback, deposited, added

### Transfer Messages

**Characteristics**:
- Mentions two accounts or parties
- Transfer-specific keywords
- May link accounts within same institution

**Patterns**:
```
- "Rs.1000 transferred from Savings XX1234 to XX5678"
- "UPI-Dr Rs.500 sent to phonepe@ybl"
- "Funds moved from Account A to Account B"
- "Transfer of $100 to your checking account"
```

**Keywords**: transferred, sent, moved, transfer, UPI-Dr, UPI-Cr, P2P

### Balance Update Messages

**Characteristics**:
- Shows account balance
- No transaction amount (or balance IS the amount)
- "Balance", "available" keywords

**Patterns**:
```
- "Your account XX1234 balance is Rs.5000.00"
- "Available balance: $1,250.50"
- "Current balance in A/c XX9876: Rs.25000"
- "Credit limit available: Rs.45000.00"
```

**Keywords**: balance, available, current balance, total balance

### Payment Reminder Messages

**Characteristics**:
- Future date mentioned
- "Due", "payment due", "reminder"
- No actual transaction occurred yet

**Patterns**:
```
- "Credit card payment of Rs.5000 due on 20-Apr-26"
- "Your loan EMI of Rs.2500 is due tomorrow"
- "Minimum payment due: $50.00 by 25th April"
- "Bill payment reminder: Pay Rs.1500 before due date"
```

**Keywords**: due, reminder, payment due, minimum payment, bill due

### Account Alert Messages

**Characteristics**:
- Account status changes
- Limit changes
- Security alerts

**Patterns**:
```
- "Your credit limit increased to Rs.100000"
- "Card ending 1234 has been blocked"
- "Low balance alert: Only Rs.100 remaining"
- "Account statement available for download"
```

## Classification Algorithm

### Confidence Scoring

Each classification receives a confidence score:

```dart
class ClassificationResult {
  final MessageType type;           // transaction, transfer, balance, etc.
  final double confidence;          // 0.0 - 1.0
  final List<String> matchedKeywords;
  final Map<String, dynamic> metadata;
}
```

### Classification Logic

```
1. Run Privacy Filters
   ├─ If OTP/Password → REJECT
   └─ Continue

2. Financial Detection
   ├─ Check currency/amount patterns
   ├─ Check financial keywords
   ├─ Check sender patterns
   └─ If score < 0.5 → REJECT (not financial)

3. Type Classification (in priority order)
   ├─ Transfer Detection (highest priority)
   │  └─ Keywords + account patterns
   │
   ├─ Transaction Detection
   │  ├─ Debit keywords + amount
   │  └─ Credit keywords + amount
   │
   ├─ Payment Reminder
   │  └─ "due" + future date + amount
   │
   ├─ Balance Update
   │  └─ "balance" + amount + no debit/credit
   │
   └─ Account Alert
      └─ Account-related updates

4. Assign Confidence Score
   └─ Based on keyword matches + pattern strength
```

### Priority Order

When multiple types could match:
1. **Transfer** (highest priority - prevents double-counting)
2. **Transaction** (debit/credit)
3. **Payment Reminder** (not actual transaction yet)
4. **Balance Update** (informational)
5. **Account Alert** (informational)

## Multi-Language Support

### India (English + Hinglish)
```
- "Aapke A/c XX1234 se Rs.500 nikala gaya"
- "₹500 received in your account"
- "Debited Rs.500 from your khata"
```

### Regional Variations
- Indian Rupee formats: "Rs.500", "₹500", "INR 500"
- US Dollar formats: "$500", "USD 500", "500.00 dollars"
- Date formats: "15-Apr-26", "04/15/2026", "April 15, 2026"

## Machine Learning Classification

### TFLite Model

For complex or ambiguous cases, an ML model provides classification:

```dart
class MLClassifier {
  Future<ClassificationResult> classify(String smsText) async {
    // Tokenize text
    final tokens = tokenize(smsText);
    
    // Run TFLite inference
    final output = await interpreter.run(tokens);
    
    // Return type and confidence
    return ClassificationResult(
      type: parseType(output),
      confidence: output.maxScore,
    );
  }
}
```

**Model Training Data**:
- 100,000+ labeled SMS messages
- Multiple bank formats (India + US)
- Diverse transaction types

**Accuracy**: 97%+ on common bank formats

## Handling Edge Cases

### Ambiguous Messages

```
"Rs.500 added to your account for payment to merchant"
```
Could be:
- Credit (money received)
- Debit (payment made)

**Resolution**: Check surrounding keywords:
- "added", "received", "credited" → Credit
- "to merchant", "payment to", "sent" → Debit

### Multi-Transaction SMS

```
"Rs.500 debited for Amazon. Available balance: Rs.9500"
```
Split into:
- Transaction: Rs.500 debit
- Balance update: Rs.9500 (ignored or stored separately)

### Unclear Amounts

```
"Minimum payment due: Rs.500. Total outstanding: Rs.5000"
```
Extract both but classify as Payment Reminder with primary amount Rs.500.

## Testing Classification

### Unit Tests

Test various SMS formats:

```dart
test('Debit transaction classification', () {
  final sms = "Debited Rs.500 from A/c XX1234 at Amazon";
  final result = classifier.classify(sms);
  
  expect(result.type, MessageType.transaction);
  expect(result.subType, TransactionType.debit);
  expect(result.confidence, greaterThan(0.9));
});
```

### Test Coverage

- Standard bank formats (50+ templates)
- Edge cases and ambiguous messages
- Multi-language messages
- Corrupt or partial messages

## Performance

- **Average time**: 10-20ms per message
- **Memory**: < 5MB for classifier
- **Accuracy**: 97% for known formats, 85% for new formats

## Next Steps

After classification, proceed to:
- [Entity Extraction](entity-extraction.md) - Parse details from classified messages
- [Account Resolution](account-resolution.md) - Match to accounts

---

*For implementation details, see `lib/services/sms_classifier.dart`*
