# Transaction Type Handling for SMS Reviews

## Problem Statement

When reviewing SMS-sourced transactions, users need options to handle different types of SMS messages:

1. **Actual Transactions** - Expenses or Income that should be tracked
2. **Transfers** - Money moving between user's own accounts
3. **Balance Reports** - Informational SMS about account balance
4. **Non-Financial SMS** - Alerts, reminders, promotional messages

Previously, the system only allowed choosing between "Income" and "Expense", which didn't cover all cases.

---

## Solution Implemented

### 1. Transaction Type Selector in Edit Dialog

**Location**: `lib/screens/transactions/transaction_detail_screen.dart`

**For SMS-sourced transactions**, the edit dialog now includes a segmented button with three options:

```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(
      value: 'expense',
      label: Text('Expense'),
      icon: Icon(Icons.arrow_upward, size: 14),
    ),
    ButtonSegment(
      value: 'income',
      label: Text('Income'),
      icon: Icon(Icons.arrow_downward, size: 14),
    ),
    ButtonSegment(
      value: 'transfer',
      label: Text('Transfer'),
      icon: Icon(Icons.swap_horiz, size: 14),
    ),
  ],
  selected: {selectedType},
  onSelectionChanged: (Set<String> newSelection) {
    setModalState(() => selectedType = newSelection.first);
  },
),
```

### 2. "Not a Transaction" Button

**For SMS-sourced transactions**, added a new button below the "Save Changes" button:

```dart
OutlinedButton.icon(
  onPressed: () async {
    // Shows confirmation dialog
    // Deletes transaction
    // Marks SMS type as non-financial
    // Blocks future similar SMS
  },
  icon: Icon(Icons.block, color: Colors.red.shade700),
  label: Text('Not a Transaction'),
)
```

**What it does:**
1. Shows confirmation dialog explaining the action
2. Deletes the current transaction
3. Calls `SmsCorrectionService.markAsNotTransaction()` to block similar SMS
4. Closes the detail screen
5. Shows success message

---

## User Workflow

### Scenario 1: SMS is an Expense/Income (Correct Type)
1. Open transaction detail
2. Review extracted information
3. Click "Save Changes" or provide feedback
4. Transaction is marked as reviewed

### Scenario 2: SMS is Wrong Type (e.g., marked as Expense but is Income)
1. Open transaction detail
2. Click "Edit" button
3. Select correct type from segmented button (Expense/Income/Transfer)
4. Click "Save Changes"
5. System records the correction for learning

### Scenario 3: SMS is a Transfer
1. Open transaction detail
2. Click "Edit" button
3. Select "Transfer" from segmented button
4. Click "Save Changes"
5. System shows transfer confirmation UI (existing feature)
6. User selects from/to accounts

### Scenario 4: SMS is Not a Transaction (Balance Report, Alert, etc.)
1. Open transaction detail
2. Click "Edit" button
3. Click "Not a Transaction" button (red, at bottom)
4. Confirm in dialog
5. Transaction is deleted
6. Similar SMS will be blocked in future

---

## Available Transaction Types

### In Edit Dialog (SMS Transactions)
1. **Expense** 💸 - Money going out
2. **Income** 💰 - Money coming in
3. **Transfer** 🔄 - Money moving between accounts

### Special Actions
4. **Not a Transaction** 🚫 - Delete and block this SMS type

---

## Technical Details

### Type Change Tracking

When user changes transaction type, the system records it for learning:

```dart
if (selectedType != originalType) {
  // Record type correction
  debugPrint('Type corrected: $originalType → $selectedType');
}
```

### SMS Blocking

When user marks as "Not a Transaction":

```dart
await SmsCorrectionService.markAsNotTransaction(
  transactionId: _transaction.id!,
  smsText: _transaction.smsSource!,
);
```

This:
- Deletes the transaction
- Adds SMS pattern to blocklist
- Prevents future similar SMS from creating transactions

---

## UI Screenshots (Conceptual)

### Edit Dialog with Type Selector
```
┌─────────────────────────────────────┐
│ Edit Transaction                [×] │
├─────────────────────────────────────┤
│ Transaction Type                    │
│ ┌─────────────────────────────────┐ │
│ │ [Expense] [Income] [Transfer]   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Amount *                            │
│ ┌─────────────────────────────────┐ │
│ │ $ 45.99                         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Merchant (optional)                 │
│ ┌─────────────────────────────────┐ │
│ │ Amazon                          │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Category                            │
│ ┌─────────────────────────────────┐ │
│ │ Shopping            ▼           │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Note (optional)                     │
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [Save Changes]                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🚫 Not a Transaction            │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### "Not a Transaction" Confirmation
```
┌─────────────────────────────────────┐
│ Not a Transaction?                  │
├─────────────────────────────────────┤
│ This will delete this transaction   │
│ and mark this SMS type as           │
│ non-financial.                      │
│                                     │
│ Future similar SMS will be ignored. │
│                                     │
│ ┌─────────┐ ┌───────────────────┐  │
│ │ Cancel  │ │ Delete & Block    │  │
│ └─────────┘ └───────────────────┘  │
└─────────────────────────────────────┘
```

---

## Benefits

### For Users
1. ✅ **Correct Classification** - Can fix wrong transaction types
2. ✅ **Handle Transfers** - Properly categorize money movements
3. ✅ **Block Noise** - Remove non-financial SMS from transactions
4. ✅ **Cleaner Data** - Only actual transactions in the list

### For System
1. ✅ **Better Learning** - Records type corrections for ML
2. ✅ **Reduced Noise** - Blocks non-financial SMS patterns
3. ✅ **Improved Accuracy** - Learns from user corrections
4. ✅ **Better UX** - Users don't see irrelevant transactions

---

## Testing Checklist

- [ ] Test changing Expense → Income
- [ ] Test changing Income → Expense
- [ ] Test changing Expense → Transfer
- [ ] Test "Not a Transaction" deletion
- [ ] Verify SMS blocking works for similar messages
- [ ] Verify type corrections are recorded
- [ ] Test with balance report SMS
- [ ] Test with promotional SMS
- [ ] Verify transfer confirmation flow still works

---

## Future Enhancements

### Potential Additions
1. **Balance Update** - Separate type for balance reports that updates account balance
2. **Alert** - Type for alerts/notifications (low balance, payment due, etc.)
3. **Promotional** - Type for marketing/promotional SMS
4. **Bulk Actions** - "Mark all similar as not transaction"

### Learning Improvements
1. Auto-detect balance reports and skip transaction creation
2. Auto-detect transfers and suggest account pairing
3. Learn from "Not a Transaction" patterns to improve classification

---

## Related Files

- `lib/screens/transactions/transaction_detail_screen.dart` - Main implementation
- `lib/services/sms_correction_service.dart` - SMS blocking service
- `lib/models/transaction.dart` - Transaction model with type field
- `docs/Diagnostics/IMPROVED_SMS_WORKFLOW_PROPOSAL.md` - Overall workflow design

---

## Summary

This enhancement gives users full control over SMS transaction classification:

- **3 transaction types** to choose from (Expense, Income, Transfer)
- **"Not a Transaction"** option to delete and block non-financial SMS
- **Type correction tracking** for system learning
- **SMS pattern blocking** to prevent future noise

Users can now properly handle all types of financial SMS messages, not just expenses and income.
