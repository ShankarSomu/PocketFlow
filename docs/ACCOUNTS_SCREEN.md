# Accounts Screen Documentation

> **Last Updated:** January 2025  
> **Database Schema Version:** 11  
> **Features:** Hybrid Transaction Mapping, Source Tracking, Smart Suggestions

## Overview
The Accounts Screen is a comprehensive financial accounts management interface that tracks all your financial accounts (checking, savings, credit cards, cash, investments) and provides net worth calculations. It now includes intelligent account matching and transaction source tracking capabilities.

**Location:** `lib/screens/accounts/accounts_screen.dart`  
**Model:** `lib/models/account.dart` (101 lines)  
**Service:** `lib/services/account_matching_service.dart` (314 lines)

---

## Main Features

### 1. Net Worth Summary Card
A gradient card at the top of the screen displaying:
- **Net Worth**: Total assets minus total debt in large, bold text
- **Account Count Badge**: Shows number of accounts (e.g., "3 accounts")
- **Assets Breakdown**: Total value of all non-credit accounts with trending up icon 📈
- **Debt Breakdown**: Total credit card balances owed with trending down icon 📉

**Visual Layout:**
```
┌─────────────────────────────────────┐
│ Net Worth          🏷️ 3 accounts     │
│ $15,234.50                          │
│                                     │
│ [📈 Assets]      [📉 Debt]         │
│ $18,500.00       $3,265.50         │
└─────────────────────────────────────┘
```

---

## Account Types

The application supports 6 account types, each with unique styling:

| Type | Icon | Color Scheme | Purpose |
|------|------|--------------|---------|
| **Checking/Debit** | `Icons.account_balance_rounded` | Primary Blue | Day-to-day banking accounts |
| **Savings** | `Icons.savings_rounded` | Tertiary Purple | Savings accounts |
| **Credit Card** | `Icons.credit_card_rounded` | Error Red | Credit card debt tracking |
| **Cash** | `Icons.payments_rounded` | Secondary Amber | Physical cash on hand |
| **Investment** | `Icons.trending_up_rounded` | Light Blue | Investment portfolios |
| **Other** | `Icons.account_balance_wallet_rounded` | Default | Miscellaneous accounts |

---

## Account Properties

Each account stores the following information:

### Core Fields
- **ID**: Auto-generated unique identifier
- **Name**: Custom account name (e.g., "Chase Checking", "Emergency Fund")
- **Type**: One of the 6 types listed above
- **Balance**: Current balance
  - For regular accounts: actual balance
  - For credit cards: amount currently owed

### Hybrid Transaction Mapping Fields (All Account Types)
- **Institution Name**: Bank/financial institution name (e.g., "Chase", "American Express", "Bank of America")
  - Used for intelligent SMS transaction matching
  - Recommended for all accounts
- **Account Identifier**: Masked account number in format `****1234`
  - Primary matching key for transaction auto-assignment
  - Auto-generated from Last 4 if not provided
  - Recommended for all accounts
- **SMS Keywords**: Array of keywords for SMS parsing fallback
  - Examples: `["CHASE", "JP MORGAN", "VISA 1234"]`
  - Optional, helps with edge cases and less common banks
- **Account Alias**: User-friendly display name
  - Examples: "My Main Card", "Work Checking"
  - Optional, used for manual transaction entry suggestions

### Credit Card Specific Fields
- **Last 4 Digits**: Last 4 digits of card number (displayed as "·· 1234")
  - Also used as fallback for matching if accountIdentifier not set
- **Credit Limit**: Maximum credit available
- **Due Date Day**: Day of month (1-31) when payment is due

### System Fields
- **Deleted At**: Soft delete timestamp (null = active account)

### Computed Properties
- `isCredit`: Boolean indicating if account is a credit card
- `nextDueDate`: Calculated next payment due date
- `daysUntilDue`: Days remaining until payment due
- `displayName`: Returns accountAlias if set, otherwise name
- `formattedIdentifier`: Returns "Institution ****1234" format for display

---

## User Actions & Operations

### 1. Add Account
**Access:** Speed Dial FAB (bottom-right) → "Add Account"

**Form Fields:**
- Account Type (dropdown)
  - Debit/Checking
  - Savings
  - Credit Card
  - Cash
  - Investment
- Account Name (text input, required)
- Balance (number input with $ prefix, required)

**Recommended Fields for Smart Transaction Matching:**
- Institution Name (text input, optional but recommended)
  - Examples: "Chase", "American Express", "Wells Fargo"
  - Enables automatic SMS transaction assignment
- Account Identifier (text input, optional but recommended)
  - Format: ****1234 (last 4 digits)
  - Auto-generated from last4 if not provided
  - Primary key for transaction matching
- Account Alias (text input, optional)
  - User-friendly name for manual transaction selection
  - Examples: "My Daily Card", "Emergency Fund"

**Additional Fields for Credit Cards:**
- Last 4 digits (4-character number input, optional)
- Credit limit (number input with $ prefix, optional)
- Payment due date (dropdown, 1st-28th of month, optional)
  - Displays as "15th of each month", "1st of each month", etc.
  - Uses ordinal suffixes (st, nd, rd, th)
- SMS Keywords (advanced, optional)
  - Comma-separated keywords for SMS matching
  - Examples: "CHASE,JPM,VISA 1234"

**Behavior:**
- Validates required fields before saving
- Auto-generates accountIdentifier from last4 if not provided
- Creates new account in database
- Refreshes account list
- Closes form automatically on success

**Note:** Populating Institution Name and Account Identifier enables the **Hybrid Transaction Mapping System**, which automatically matches SMS transactions and provides smart suggestions during manual entry.

---

### 2. Edit Account
**Access:** Tap any account card

**Form:** Same as Add Account, with pre-filled values

**Additional Option:**
- **Delete Button** (red, icon + text)
  - Shows confirmation dialog
  - Warning: "Transactions linked to this account will be unlinked but not deleted."
  - Requires confirmation before deletion
  - Triggers haptic feedback on delete

---

### 3. View Transactions
**Access Methods:**
1. Long-press on any account card
2. Tap "view txns" link on account card (bottom-right)

**Behavior:**
- Opens TransactionsScreen
- Pre-filtered to show only transactions for selected account
- Passes `initialAccountId` parameter

---

### 4. Transfer Between Accounts
**Access:** Speed Dial FAB → "Transfer" (requires 2+ accounts)

**Form Fields:**
- **From Account** (dropdown)
  - Shows account name and current balance
  - Format: "Chase Checking ($5,234.50)"
  
- **To Account** (dropdown)
  - Shows account name
  - If credit card, shows badge: "owes $X.XX" in red
  
- **Special Credit Card Feature:**
  - If TO account is a credit card with balance > 0:
    - Checkbox: "Pay full outstanding: $X.XX"
    - When checked: auto-fills amount field
    - Helper text: "Amount will update automatically each time"
    - Useful for paying off entire credit card balance

- **Amount** (number input with $ prefix)
  - Disabled when "Pay full outstanding" is checked
  
- **Note** (text input, optional)
  - Custom memo for the transfer

**Validation:**
- Cannot transfer from and to same account
- Amount must be > 0
- Both accounts must be selected

**Behavior:**
- Creates two offsetting transactions in database
- Updates both account balances
- Refreshes all data
- Shows success feedback

---

## Visual Features

### Account List Display

**Grouping:**
- Accounts automatically grouped by type
- Section headers: "Checking", "Savings", "Credit", etc.
- Styled with uppercase labels and subtle color

**Account Card Structure:**
```
┌─────────────────────────────────────────┐
│  🔵  Account Name            $1,234.50  │
│      ·· 5678                view txns   │
│      ⚠️ Due in 2d                       │
└─────────────────────────────────────────┘
```

**Elements:**
1. **Left Icon** (44x44 circle)
   - Type-specific icon
   - Colored background matching account type
   - 12% opacity fill

2. **Account Info** (center)
   - Account name (bold, 14px)
   - Last 4 digits (if set)
   - Due date warning (if credit card due within 3 days)

3. **Balance & Action** (right)
   - Balance amount (bold, 15px)
   - Color-coded:
     - Credit cards with debt: Red
     - Credit cards paid off: Green
     - Regular accounts: Default
   - "view txns" link in primary variant color

### Due Date Warnings

Displayed when credit card payment is due within 3 days:
- ⚠️ Warning icon (12px, red)
- Text: "Due today" or "Due in Xd"
- Styled in error/red color
- Positioned below last 4 digits

---

## Color Coding System

### Balance Colors
- **Positive Assets**: Default text color
- **Credit Card Debt** (owed > 0): Red/Error color
- **Credit Card Paid Off** (owed = 0): Green/Success color

### Status Indicators
- **Due Soon** (≤3 days): Red warning with icon
- **Due Today**: "Due today" in red/error color
- **Normal**: Default text color

### Account Type Colors
- **Checking/Debit**: Primary color (blue)
- **Savings**: Tertiary color (purple)
- **Credit**: Error color (red)
- **Cash**: Secondary color (amber)
- **Investment**: Light primary (light blue)

---

## Data Calculations

### Net Worth Formula
```
Net Worth = Total Assets - Total Debt

Where:
  Total Assets = Sum of (Checking + Savings + Cash + Investment balances)
  Total Debt = Sum of (Credit card balances owed)
```

### Account Balance
- Retrieved via `AppDatabase.accountBalance(accountId, account)`
- Calculates current balance based on:
  - Initial opening balance
  - All income transactions (added)
  - All expense transactions (subtracted)
  - All transfers in/out

---

## Floating Action Buttons

### Calendar FAB (Bottom-Left)
- Standard calendar/time filter button
- Allows filtering accounts by time period
- Shared across all screens

### Speed Dial FAB (Bottom-Right)
Dynamic actions based on context:

**Always Available:**
- ➕ **Add Account** - Opens account creation form

**Conditional (requires 2+ accounts):**
- ⇄ **Transfer** - Opens transfer dialog

---

## User Flow Examples

### Example 1: Adding a Credit Card (with Smart Matching)

1. User taps Speed Dial FAB (bottom-right)
2. Selects "Add Account"
3. Sheet opens with form
4. Selects "Credit Card" from type dropdown
5. Enters name: "Chase Sapphire"
6. Enters balance owed: "1234.50"
7. **Enters institution name: "Chase"** (recommended for SMS matching)
8. **Enters account identifier: "****5678"** (recommended for auto-assignment)
9. **Enters account alias: "My Travel Card"** (optional, for manual entry)
10. Enters last 4 digits: "5678"
11. Enters credit limit: "5000"
12. Selects due date: "15th of each month"
13. Taps "Save"
14. Account appears in "Credit" section with red balance
15. **System now ready to auto-match SMS transactions from Chase mentioning ****5678**

### Example 2: Paying Off Credit Card

1. User taps Speed Dial FAB
2. Selects "Transfer"
3. Sheet opens with transfer form
4. From: Selects "Checking Account"
5. To: Selects "Chase Sapphire" (shows "owes $1,234.50" badge)
6. Checks ✓ "Pay full outstanding: $1,234.50"
   - Amount field auto-fills and becomes read-only
7. Enters note: "Monthly payment"
8. Taps "Transfer"
9. Both accounts update
10. Credit card balance changes to green (paid off)

### Example 3: Viewing Account Transactions

**Method A (Long Press):**
1. User finds account in list
2. Long-presses on account card
3. TransactionsScreen opens filtered to that account

**Method B (Link):**
1. User taps "view txns" link on account card
2. TransactionsScreen opens filtered to that account

### Example 4: Configuring Existing Account for Smart Matching

1. User taps on existing "Wells Fargo Checking" account card
2. Edit form opens with current values
3. Scrolls to recommended fields section
4. **Adds institution name: "Wells Fargo"**
5. **Adds account identifier: "****9012"** (based on last 4)
6. **Adds account alias: "Daily Checking"**
7. Optionally adds SMS keywords: "WELLS,WF,WELLSFARGO"
8. Taps "Save"
9. Returns to accounts list
10. **Future SMS from Wells Fargo will now auto-match to this account**
11. **Manual transactions will suggest "Daily Checking" based on merchant patterns**

---

## Data Safety & Validation

### Account Deletion
- **Soft Delete**: Account marked as deleted, not removed from database
- **Transaction Safety**: Linked transactions are NOT deleted
  - Transactions become unlinked
  - Transaction history preserved
- **Confirmation Required**: Dialog warns user before deletion
- **Haptic Feedback**: Heavy impact on delete confirms action

### Transfer Validation
- Cannot transfer to same account
- Both from/to accounts must be selected
- Amount must be greater than zero
- Empty amount not accepted

### Form Validation
- Account name required (cannot be empty)
- Balance defaults to 0 if not provided
- Last 4 digits limited to 4 characters
- Due date limited to 1-28 (avoids month-end edge cases)

---

## Empty State

When no accounts exist:
- Custom empty state widget displayed
- Message encouraging user to add first account
- "Add Account" button prominently displayed
- Illustrative icon/graphic
- Uses `EmptyStates.accounts(context, onAdd: callback)`

---

## Refresh Behavior

### Automatic Refresh Triggers
- Data change notifications via `notifyDataChanged()`
- Time filter changes via `appTimeFilter` listener
- Returns from other screens

### Manual Refresh
- Pull-to-refresh gesture
- Reloads all accounts and recalculates balances
- Shows loading indicator during refresh

---

## Technical Implementation Details

### State Management
- Uses StatefulWidget with local state
- Listens to `appRefresh` and `appTimeFilter` notifiers
- Loads data asynchronously on init and when notifiers fire

### Data Sources
- Database: `AppDatabase` class
- Methods used:
  - `getAccounts()` - Fetch all accounts
  - `accountBalance(id, account)` - Calculate current balance
  - `insertAccount(account)` - Create new account
  - `updateAccount(account)` - Update existing account
  - `deleteAccount(id)` - Soft delete account
  - `transfer(fromId, toId, amount, note)` - Execute transfer

### Screen Layout
- SafeArea for system UI avoidance
- Stack for overlaying FABs
- Column for main content
- ScrollView for account list
- RefreshIndicator for pull-to-refresh

### Dependencies
- `intl` - Currency formatting (`NumberFormat.currency`)
- `AppDatabase` - Data persistence
- `Account` model - Data structure
- `TransactionsScreen` - Navigation target
- `EmptyStates` - Empty state UI
- `SpeedDialFab` - Custom FAB widget
- `CalendarFab` - Time filter widget
- `ScreenHeader` - Consistent header widget
- `HapticFeedbackHelper` - Tactile feedback

---

## File Structure

```
lib/
├── screens/
│   └── accounts/
│       └── accounts_screen.dart (814 lines)
├── models/
│   └── account.dart (Enhanced with hybrid mapping fields, 101 lines)
├── services/
│   └── account_matching_service.dart (Unified matching engine, 314 lines)
├── db/
│   └── database.dart (AppDatabase with account methods, schema v11)
└── widgets/
    ├── empty_states.dart (EmptyStates.accounts)
    └── [shared widgets]
```

---

## Integration with Hybrid Transaction Mapping

The Accounts Screen is fully integrated with the **Hybrid Transaction Mapping System**, which provides intelligent account matching for both SMS-parsed and manually-entered transactions.

### How It Works

**When you populate these fields:**
- `institutionName` - Bank name (e.g., "Chase")
- `accountIdentifier` - Masked number (e.g., "****1234")
- `smsKeywords` (optional) - SMS patterns (e.g., "CHASE,JPM")
- `accountAlias` (optional) - Friendly name (e.g., "My Main Card")

**You enable:**

1. **Automatic SMS Transaction Assignment**
   - Incoming bank SMS messages automatically matched to correct account
   - Confidence scoring (0-1.0) for assignment reliability
   - Low-confidence matches flagged for review

2. **Smart Manual Entry Suggestions**
   - When manually adding transactions, system suggests most likely account
   - Based on merchant name, historical usage, and account properties
   - Real-time suggestions as you type

3. **Transaction Source Tracking**
   - Every transaction tagged with source: SMS, Manual, Recurring, or Import
   - Full audit trail and transparency

### Best Practices

✅ **DO:**
- Set `institutionName` for all bank accounts (e.g., "Chase", "Amex")
- Set `accountIdentifier` in ****XXXX format for all accounts
- Use `accountAlias` for accounts you frequently use manually
- Add `smsKeywords` for banks with unique SMS patterns

❌ **DON'T:**
- Leave `institutionName` blank if you use SMS auto-import
- Use full account numbers (always use masked format ****1234)
- Store sensitive data in any field

### Example: Well-Configured Account

```dart
Account(
  name: "Chase Sapphire Preferred",
  type: "credit",
  balance: 0,
  last4: "1234",
  creditLimit: 10000,
  dueDateDay: 15,
  
  // Hybrid mapping fields ↓
  institutionName: "Chase",           // Enables SMS matching
  accountIdentifier: "****1234",      // Primary matching key
  smsKeywords: ["CHASE", "JPM"],      // Fallback patterns
  accountAlias: "My Travel Card",     // Manual entry friendly name
)
```

**Result:** 
- SMS from Chase mentioning "****1234" → Auto-assigned with high confidence
- Manually adding transaction → "My Travel Card" appears as suggestion
- Transaction history shows source badges: "SMS" or "Manual"

### Related Documentation

For complete details on the transaction mapping system:
- See [HYBRID_TRANSACTION_MAPPING_SYSTEM.md](HYBRID_TRANSACTION_MAPPING_SYSTEM.md) - Full technical documentation
- See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Quick start guide



---

## Future Enhancement Ideas

- **Account Search/Filter**: Search accounts by name or institution
- **Account Categories**: Group custom categories beyond type
- **Import/Export**: CSV import for bulk account creation
- **Account Insights**: Spending trends per account over time
- **Reconciliation**: Mark transactions as reconciled with bank statements
- **Multi-Currency**: Support for foreign currency accounts
- **Account Goals**: Savings targets per account
- **Auto-Transfer**: Scheduled automatic transfers between accounts
- **Account Sorting**: Custom sort order and favorites
- **Institution Logos**: Display bank logos instead of generic icons
- **Balance History**: Track and chart balance changes over time
- **Account Sharing**: Joint account support with multiple users

### Recently Implemented ✅

- ✅ **Hybrid Transaction Mapping**: Intelligent account matching for SMS and manual transactions
- ✅ **Institution Tracking**: `institutionName` field for better organization
- ✅ **Account Identifiers**: Masked account numbers for secure matching
- ✅ **Account Aliases**: User-friendly display names
- ✅ **SMS Keywords**: Custom keywords for automatic transaction matching
- ✅ **Source Tracking**: Transaction tagging by origin (SMS/Manual/Recurring/Import)

---

## Accessibility Features

- **Tap Targets**: All interactive elements ≥44px
- **Color Independence**: Not solely relying on color for warnings
- **Icons + Text**: Warnings use both icon and text
- **Semantic Labels**: Descriptive labels for screen readers
- **Keyboard Navigation**: Full keyboard support in forms
- **Focus States**: Clear focus indicators on form fields

---

## Performance Considerations

- **Lazy Loading**: Only loads visible accounts
- **Efficient Calculations**: Balance calculations cached in map
- **Single Query**: Fetches all accounts in one database call
- **Optimistic Updates**: UI updates immediately, syncs in background
- **Minimal Rebuilds**: Only rebuilds affected widgets

---

*Last Updated: April 18, 2026*  
*App Version: 1.0.0*  
*Flutter Version: Latest*
