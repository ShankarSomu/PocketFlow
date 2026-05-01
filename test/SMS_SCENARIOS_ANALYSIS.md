# SMS Import Scenarios - Code Analysis

## Scenario 1: Transfer Pair Detection ✅

**Input:**
```
SMS 1 (BofA):  "Electronic draft of $1,543.23 for account - 3286 was deducted on 04/03/2026"
SMS 2 (Citi): "A $1,543.23 payment posted to acct ending in 3130 on 04/03/2026"
```

**Code Flow:**

### Step 1: Import both SMS (sms_service.dart lines 377-398)
```dart
// Both SMS pass financial check
// Both SMS parse successfully with amount $1,543.23
// Both SMS have transaction date 04/03/2026
// Both SMS pass duplicate check (different SMS bodies)
// Both transactions inserted into database
```

### Step 2: Transfer detection runs (sms_service.dart lines 410-422)
```dart
if (imported > 0) {
  final fixedCount = await cleanupDuplicateTransfers();
}
```

### Step 3: cleanupDuplicateTransfers() finds the pair (sms_service.dart lines 781-894)
```dart
// Query all SMS transactions
// Group by date (both on 04/03/2026)
// Find matching amounts ($1,543.23 == $1,543.23)

// Check transfer keywords:
final is1Payment = body1.contains('payment') || body1.contains('posted');
// Citi: contains('payment posted') → TRUE

final is1Debit = body1.contains('debit') || body1.contains('draft') || 
                 body1.contains('deducted');
// BofA: contains('deducted') → TRUE

// One is payment, other is debit → TRANSFER!
if ((is1Payment && is2Debit) || (is2Payment && is1Debit)) {
  // Convert both to type='transfer', category='Transfer'
  await db.update('transactions', {'type': 'transfer', 'category': 'Transfer'});
}
```

**Result:**
- ✅ 2 transactions in database
- ✅ Both have `type: 'transfer'`
- ✅ Both have `category: 'Transfer'`
- ✅ Both amounts: $1,543.23
- ✅ Both dates: 04/03/2026

---

## Scenario 2: Multiple Transactions at Same Merchant ✅

**Input:**
```
SMS 1: "A $8.00 transaction was made at WASH LAUNDRY WAVERID on card ending in 3130"
       Received: 2026-04-17 15:54:12

SMS 2: "A $8.00 transaction was made at WASH LAUNDRY WAVERID on card ending in 3130"
       Received: 2026-04-17 16:55:41
       (Same exact text, 1 hour later)
```

**Code Flow:**

### Step 1: Import first SMS (15:54:12)
```dart
// Parse SMS → $8.00 transaction at WASH LAUNDRY WAVERID
// Check duplicate: _isDuplicateInDatabase(parsed, smsBody, DateTime(15:54:12))
// No existing transactions → not duplicate
// Insert transaction #1
```

### Step 2: Import second SMS (16:55:41)
```dart
// Parse SMS → $8.00 transaction at WASH LAUNDRY WAVERID
// Check duplicate: _isDuplicateInDatabase(parsed, smsBody, DateTime(16:55:41))
```

### Step 3: Duplicate check logic (sms_service.dart lines 712-758)
```dart
// Find exact SMS body matches
final exactMatches = await db.query(
  'transactions',
  where: 'sms_source = ? AND source_type = ?',
  whereArgs: [smsBody, 'sms'],
);
// Found 1 match (transaction #1)

// Check timestamp difference:
for (final match in exactMatches) {
  final existingDate = DateTime.fromMillisecondsSinceEpoch(match['date']);
  // existingDate = 2026-04-17 15:54:12
  // smsReceivedTime = 2026-04-17 16:55:41
  
  final timeDiff = smsReceivedTime.difference(existingDate).abs();
  // timeDiff = 61 minutes
  
  if (timeDiff.inMinutes < 5) {
    return true; // Duplicate
  }
}

// 61 minutes > 5 minutes → NOT duplicate
AppLogger.log('Same merchant, different transaction');
return false;
```

### Step 4: Insert second transaction
```dart
// Not a duplicate → insert transaction #2
await AppDatabase.insertTransaction(parsed);
```

**Result:**
- ✅ 2 transactions in database
- ✅ Both have `type: 'expense'`
- ✅ Both amounts: $8.00
- ✅ Both merchants: "WASH LAUNDRY WAVERID"
- ✅ Different timestamps: 15:54:12 and 16:55:41
- ✅ NOT marked as duplicates or transfers

---

## Edge Case: Resent SMS (Within 5 Minutes)

**Input:**
```
SMS 1: "A $8.00 transaction was made at WASH LAUNDRY..."
       Received: 2026-04-17 15:54:12

SMS 2: "A $8.00 transaction was made at WASH LAUNDRY..."
       Received: 2026-04-17 15:56:30
       (Same text, 2 minutes later - network glitch)
```

**Code Flow:**
```dart
// Check duplicate:
final timeDiff = DateTime(15:56:30).difference(DateTime(15:54:12)).abs();
// timeDiff = 2 minutes

if (timeDiff.inMinutes < 5) {
  AppLogger.log('Exact duplicate detected', '${timeDiff.inSeconds}s apart');
  return true; // DUPLICATE - block insertion
}
```

**Result:**
- ✅ Only 1 transaction in database
- ✅ Second SMS correctly blocked as duplicate

---

## Summary

| Scenario | Same Amount | Same Date | Time Diff | Same SMS Body | Result |
|----------|-------------|-----------|-----------|---------------|--------|
| **Transfer Pair** | ✅ Yes | ✅ Yes | N/A | ❌ No (different keywords) | 2 transactions marked as **transfers** |
| **Multiple at Merchant** | ✅ Yes | ✅ Yes | 1 hour | ✅ Yes | 2 separate **expense** transactions |
| **Network Duplicate** | ✅ Yes | ✅ Yes | 2 min | ✅ Yes | 1 transaction (2nd blocked) |

## Code References

- Duplicate check: [sms_service.dart#L712-L758](../lib/services/sms_service.dart#L712-L758)
- Transfer detection: [sms_service.dart#L781-L894](../lib/services/sms_service.dart#L781-L894)
- SMS import loop: [sms_service.dart#L340-L460](../lib/services/sms_service.dart#L340-L460)

## Key Algorithm Features

1. **Time-based duplicate detection**: Same SMS body within 5 minutes = duplicate
2. **Transfer pair detection**: Same amount + same date + payment/debit keywords = transfer
3. **Batch processing**: Transfer detection runs once after all imports (not per-message)
4. **Context-aware parser**: "sent you" = income (not expense)
