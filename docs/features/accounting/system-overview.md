# Accounting System Overview

PocketFlow implements a simplified accounting system designed for personal finance tracking with automatic SMS-based transaction entry.

## Core Principles

### 1. Modified Single-Entry System

Unlike traditional double-entry bookkeeping, PocketFlow uses a modified single-entry system:

- **Each transaction** has one entry
- **Transfers** are special: linked pair of transactions
- **Categories** replace traditional accounts
- **Simple** for end users

### 2. Account-Centric

Transactions belong to accounts:
- Bank accounts
- Credit cards
- Cash wallets
- Investment accounts

## The Double-Entry Problem

Traditional personal finance apps double-count transfers:

```
❌ Without Transfer Detection:

Day 1:  Credit Card: -Rs.500 (Amazon)
Day 30: Bank: -Rs.500 (Credit card payment)
─────────────────────────────────────────
Total:  -Rs.1000 (WRONG! Counted twice)
```

PocketFlow solves this:

```
✅ With Transfer Detection:

Day 1:  Credit Card: -Rs.500 (Amazon) [Expense]
Day 30: Transfer: Bank (-Rs.500) → Credit Card (+Rs.500)
───────────────────────────────────────────────────
Total:  -Rs.500 (Correct net worth impact)
```

## Transaction Types

### 1. Income
Money coming in (increases net worth)

```dart
Transaction(
  type: 'income',
  amount: 50000,
  category: 'Salary',
  account: BankAccount,
)
```

### 2. Expense
Money going out (decreases net worth)

```dart
Transaction(
  type: 'expense',
  amount: 500,
  category: 'Shopping',
  account: CreditCard,
)
```

### 3. Transfer
Money moving between accounts (neutral to net worth)

```dart
// Two linked transactions
TransferPair(
  outgoing: Transaction(
    type: 'transfer_out',
    amount: 5000,
    fromAccount: BankAccount,
    toAccount: CreditCard,
  ),
  incoming: Transaction(
    type: 'transfer_in',
    amount: 5000,
    fromAccount: BankAccount,
    toAccount: CreditCard,
  ),
)
```

## Account Balance Tracking

### Starting Balance

Each account has an initial balance:

```dart
Account(
  name: 'HDFC Savings',
  type: 'savings',
  balance: 10000.0,  // Starting balance
)
```

### Current Balance Calculation

```dart
double calculateCurrentBalance(Account account) {
  double balance = account.initialBalance;
  
  for (final txn in account.transactions) {
    if (txn.type == 'income' || txn.type == 'transfer_in') {
      balance += txn.amount;
    } else if (txn.type == 'expense' || txn.type == 'transfer_out') {
      balance -= txn.amount;
    }
  }
  
  return balance;
}
```

## Categories

Transactions are categorized for budgeting:

### Expense Categories
- Food & Dining
- Transportation
- Shopping
- Entertainment
- Bills & Utilities
- Healthcare
- Education

### Income Categories
- Salary
- Freelance
- Investment Income
- Gifts
- Other Income

### Special Category
- **Transfer**: Used for all transfer transactions

## Net Worth Calculation

```dart
double calculateNetWorth() {
  double total = 0.0;
  
  for (final account in accounts) {
    total += calculateCurrentBalance(account);
  }
  
  return total;
}
```

**Important**: Transfers don't affect net worth because:
- Transfer out: -Rs.500 from Account A
- Transfer in: +Rs.500 to Account B
- **Net effect**: 0

## Credit Card Handling

Credit cards are liability accounts:

```dart
Account(
  name: 'HDFC Credit Card',
  type: 'credit_card',
  balance: 0.0,          // Starting balance (owed)
  creditLimit: 50000.0,
)
```

### Example Flow

```
Month start:  Balance = Rs.0 (no debt)

Day 5:  Shopping Rs.5000
        → Balance = -Rs.5000 (owed)

Day 15: Dining Rs.1000
        → Balance = -Rs.6000 (owed)

Day 30: Payment Rs.6000 from Bank [TRANSFER]
        → Balance = Rs.0 (paid off)
```

## Budget System

Track spending vs. budget by category:

```dart
class Budget {
  final String category;
  final double monthlyLimit;
  final double spent;          // Calculated from transactions
  
  double get remaining => monthlyLimit - spent;
  double get percentageUsed => (spent / monthlyLimit) * 100;
  bool get isOverBudget => spent > monthlyLimit;
}
```

## Reconciliation

### SMS vs. Actual

PocketFlow relies on SMS, but users can:
1. **Review** auto-detected transactions
2. **Correct** amounts or categories
3. **Add** manual transactions for cash/non-SMS
4. **Delete** incorrect detections

### Balance Verification

Compare calculated balance with actual:

```
Calculated Balance: Rs.10,500
Actual Balance:     Rs.10,500
Difference:         Rs.0 ✓
```

If mismatch:
- Check for missing transactions
- Verify transfer detection
- Look for incorrectly categorized transfers

## Reports

### Spending by Category

```
Food & Dining:    Rs.5,000 (25%)
Transportation:   Rs.3,000 (15%)
Shopping:         Rs.8,000 (40%)
Other:            Rs.4,000 (20%)
──────────────────────────────
Total Expenses:   Rs.20,000
```

### Income vs. Expense

```
Total Income:     Rs.50,000
Total Expenses:   Rs.30,000
Transfers:        Rs.10,000 (not counted)
──────────────────────────────
Net Savings:      Rs.20,000
```

### Account Summary

```
Bank Account:     Rs.15,000
Credit Card:      -Rs.5,000
Cash Wallet:      Rs.2,000
──────────────────────────────
Net Worth:        Rs.12,000
```

## Data Integrity

### Rules

1. **No orphaned transfers**: Every transfer must have both sides
2. **Linked transactions**: Transfer pairs are linked via `transferReference`
3. **Category consistency**: Transfers always use "Transfer" category
4. **Amount matching**: Transfer pairs must have same amount

### Validation

```dart
bool validateTransfer(Transaction out, Transaction in) {
  return out.amount == in.amount &&
         out.transferReference == in.transferReference &&
         out.toAccountId == in.fromAccountId &&
         out.fromAccountId == in.accountId;
}
```

## Database Schema Summary

```sql
-- Core tables
accounts
transactions
budgets
recurring_patterns

-- Learning/feedback
sms_account_mappings
user_corrections
```

See [Database](../../architecture/database.md) for full schema.

## Best Practices

### For Users

1. **Review SMS transactions** regularly
2. **Confirm or correct** auto-detected transfers
3. **Set budgets** for categories
4. **Reconcile** with bank statements monthly

### For Developers

1. **Always validate** transfer pairs
2. **Test edge cases** (partial payments, fees)
3. **Handle corrections** gracefully
4. **Maintain data integrity**

## Common Scenarios

### Scenario 1: Credit Card Payment

```
SMS 1: "Rs.5000 debited from SBI A/c XX1234"
SMS 2: "Rs.5000 payment received for HDFC Card XX5678"

Detection: Transfer (Bank → Credit Card)
Effect: No change to net worth
```

### Scenario 2: Cash Withdrawal

```
SMS: "Rs.2000 withdrawn from ATM from A/c XX1234"

Options:
1. Expense (if not tracking cash)
2. Transfer (Bank → Cash account)
```

### Scenario 3: Refund

```
SMS: "Rs.500 credited to Card XX1234 - Amazon refund"

Detection: Income/Credit
Category: Shopping (refund)
Effect: Increase net worth by Rs.500
```

## Next Steps

- [Double-Entry Solution](double-entry.md) - Detailed transfer handling
- [Feedback System](feedback-system.md) - User corrections
- [Transaction Mapping](transaction-mapping.md) - Category mapping

---

*See implementation in `lib/services/` and `lib/repositories/`*
