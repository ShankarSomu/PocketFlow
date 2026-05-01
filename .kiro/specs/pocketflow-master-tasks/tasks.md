# PocketFlow — Master Task List
> Generated from full product breakdown analysis.  
> Covers: UI/UX fixes, feature gaps, technical debt, and architecture improvements.  
> Status legend: `[ ]` not started · `[-]` in progress · `[x]` done

---

## PHASE 1 — Critical Fixes (Broken / Dead Code / High-Impact UX)

### 1. Enable Transaction Search
- [x] 1.1 Change `_searchVisible` from `final bool = false` to a mutable `bool` in `TransactionsScreen`
- [x] 1.2 Add search icon button to the transactions screen header that toggles `_searchVisible`
- [x] 1.3 Show `TextField` search bar below the header when `_searchVisible = true`
- [x] 1.4 Wire `_searchQuery` to the existing `_filteredTransactions` getter (logic already exists)
- [x] 1.5 Add clear button inside search field that resets query and hides bar
- [x] 1.6 Persist search query in state across filter changes

### 2. Empty State for Filtered / Searched Results
- [x] 2.1 Detect when `_filteredTransactions` is empty but `_transactions` is not empty
- [x] 2.2 Show a dedicated "No results" empty state widget with filter description
- [x] 2.3 Add "Clear Filters" CTA button on the empty state
- [ ] 2.4 Apply same pattern to Budget screen when no budgets match the time filter

### 3. Surface Pending Actions Prominently
- [ ] 3.1 Add a badge counter on the Transactions bottom nav tab when `_pendingActionsCount > 0`
- [x] 3.2 Add a banner/card at the top of `TransactionsScreen` when pending actions exist (above account carousel)
- [x] 3.3 Make the banner tappable — navigate to `PendingActionsScreen`
- [x] 3.4 Dismiss banner when pending count reaches 0

### 4. Fix Emoji Rendering in Category Icons
- [x] 4.1 Audit `_emojiForCategory` in `BudgetScreen` — replace broken `??` placeholders with correct emoji strings
- [x] 4.2 Audit `_emojiForCategory` in `RecurringScreen` — same fix
- [ ] 4.3 Verify emoji render correctly on both Android and iOS targets

### 5. Fix Account Type Mismatch (credit vs credit_card)
- [-] 5.1 Audit `AccountsScreen._showForm` — dropdown uses value `'credit'` but `Account.types` defines `'credit_card'`
- [ ] 5.2 Standardize to `'credit_card'` everywhere (model, form, type checks, color/icon switches)
- [x] 5.3 Add a DB migration to rename any existing `'credit'` type rows to `'credit_card'`
- [ ] 5.4 Update `_typeGradient`, `_typeIcon`, `_typeColor` switch cases to use `'credit_card'`

### 6. Fix `withOpacity` Deprecation Warnings
- [x] 6.1 Replace all `.withOpacity(x)` calls with `.withValues(alpha: x)` across all screens
  - `accounts_screen.dart` — `withOpacity(0.6)` in SMS section label
  - Any other remaining instances found via grep

---

## PHASE 2 — UX Improvements (Consistency & Polish)

### 7. Standardize Transaction Detail Screen Header
- [ ] 7.1 Remove the `AppBar` from `TransactionDetailScreen` (only screen using AppBar)
- [ ] 7.2 Replace with a custom header matching the app's back-button style (see `SettingsScreen` header pattern)
- [ ] 7.3 Move Edit and Delete actions into a `PopupMenuButton` or icon row in the custom header
- [ ] 7.4 Keep the full-bleed gradient summary card below the header

### 8. Add Profile Drawer Visual Affordance
- [ ] 8.1 Add an avatar/profile icon button to the `HomeHeader` component (top-right area)
- [ ] 8.2 Tapping the icon opens `ProfileScreen` via `Navigator.push`
- [ ] 8.3 Show Google account avatar if signed in, else a default person icon
- [ ] 8.4 Add a subtle swipe-right hint on first launch (FeatureHint widget)

### 9. Centralize Category Color & Icon Logic
- [ ] 9.1 Create `lib/core/category_display.dart` with:
  - `static Color colorForCategory(BuildContext context, String category)`
  - `static IconData iconForCategory(String category)`
  - `static String emojiForCategory(String category)`
- [ ] 9.2 Replace duplicated logic in `BudgetScreen._BudgetItem`
- [ ] 9.3 Replace duplicated logic in `TransactionsScreen` / transaction components
- [ ] 9.4 Replace duplicated logic in `RecurringScreen._RecurringItem`
- [ ] 9.5 Replace duplicated logic in `HomeScreen` category spend display

### 10. Replace SpeedDialFab with Simple FAB on Single-Action Screens
- [ ] 10.1 `BudgetScreen` — replace `SpeedDialFab` with `FloatingActionButton` (only one action: Add Budget)
- [ ] 10.2 `SavingsScreen` — same (only one action: Add Goal)
- [ ] 10.3 `RecurringScreen` — same (only one action: Add Recurring)
- [ ] 10.4 Keep `SpeedDialFab` only on screens with 2+ actions (Transactions, Accounts, Home)

### 11. Add CalendarFab Tooltip / Label
- [ ] 11.1 Wrap `CalendarFab` in a `Tooltip` widget with label "Filter by time period"
- [ ] 11.2 Add a `FeatureHint` for first-time users pointing to the CalendarFab
- [ ] 11.3 Show current active filter label as a small badge on the CalendarFab when a non-default filter is active

### 12. Add Swipe-to-Delete on Transaction Rows
- [ ] 12.1 Wrap transaction list items in `Dismissible` widget with right-to-left swipe
- [ ] 12.2 Show red delete background with trash icon on swipe
- [ ] 12.3 On dismiss: call `AppDatabase.deleteTransaction`, trigger `notifyDataChanged()`
- [ ] 12.4 Show undo `SnackBar` with 4-second timeout (see task 13)

### 13. Wire Undo Manager to Delete Actions
- [ ] 13.1 `UndoManager` exists in `lib/core/undo_manager.dart` — verify its API
- [ ] 13.2 On transaction delete (swipe or detail screen): push undo action to `UndoManager`
- [ ] 13.3 Show `SnackBar` with "Undo" action that calls `UndoManager.undo()`
- [ ] 13.4 Apply same pattern to account delete, goal delete, budget delete, recurring delete

### 14. Improve Budget Screen Section Labels
- [ ] 14.1 Add section label "On Budget" above the on-budget items list (currently unlabeled)
- [ ] 14.2 Wrap all three sections (On Budget, Over Budget, Untracked) in `_BudgetSection` widget (already defined but unused in build method)
- [ ] 14.3 Remove the inline `Text('Over Budget')` and `Text('Untracked')` — use the `_BudgetSection` widget consistently

### 15. Savings Goal — Add Target Date Field
- [ ] 15.1 Add `targetDate` optional field to `SavingsGoal` model
- [ ] 15.2 Add DB migration to add `target_date TEXT` column to `savings_goals` table
- [ ] 15.3 Add date picker to savings goal form (below priority slider)
- [ ] 15.4 Display target date on goal item row (below saved/target amounts)
- [ ] 15.5 Show "X days remaining" or "Overdue" badge when target date is set

### 16. Savings Goal — Projected Completion Date
- [ ] 16.1 Calculate average monthly contribution from linked recurring transactions
- [ ] 16.2 If average > 0, compute `projectedDate = today + (remaining / monthlyRate) months`
- [ ] 16.3 Display projected completion date on goal item row when calculable
- [ ] 16.4 Show "On track" / "Behind" indicator based on target date vs projected date

### 17. Add Last Backup Date to Profile
- [ ] 17.1 Store last backup timestamp in `SharedPreferences` after each successful backup
- [ ] 17.2 Read and display "Last backed up: X days ago" in `ProfileHeroCard`
- [ ] 17.3 Show "Never backed up" if no backup has been performed
- [ ] 17.4 Color the label amber/warning if last backup > 7 days ago

### 18. Recurring Screen — Add Next Due Date Picker to Form
- [ ] 18.1 The `nextDue` variable in `_showForm` is initialized but never editable by the user
- [ ] 18.2 Add a `GestureDetector` date picker field (matching the pattern in `TransactionsScreen._showAddTransactionForm`)
- [ ] 18.3 Display selected next due date in the form
- [ ] 18.4 Validate that next due date is not in the past (show warning, not hard block)

---

## PHASE 3 — Feature Enhancements

### 19. Transaction Import (CSV)
- [ ] 19.1 Add "Import CSV" action to `ExportScreen` or a new `ImportScreen`
- [ ] 19.2 Use `file_picker` to select a CSV file
- [ ] 19.3 Parse CSV: detect columns (date, amount, type, category, note, account)
- [ ] 19.4 Show column mapping UI (dropdown per column)
- [ ] 19.5 Preview first 5 rows before import
- [ ] 19.6 Insert parsed transactions via `AppDatabase.insertTransaction`
- [ ] 19.7 Show import summary: X imported, Y skipped (duplicates)
- [ ] 19.8 Handle duplicate detection (same date + amount + account = likely duplicate)

### 20. Budget Approaching-Limit Notifications
- [ ] 20.1 Add a background check in `RecurringScheduler` or a new `BudgetAlertService`
- [ ] 20.2 When spending reaches 80% of a budget limit, schedule a local notification
- [ ] 20.3 When spending exceeds 100%, schedule an "over budget" notification
- [ ] 20.4 Add toggle in Settings → Preferences to enable/disable budget notifications
- [ ] 20.5 Avoid duplicate notifications (track last-notified % per category in `SharedPreferences`)

### 21. Recurring Execution History
- [ ] 21.1 Add `recurring_executions` table: `id, recurring_id, executed_at, amount, status`
- [ ] 21.2 Add DB migration for the new table
- [ ] 21.3 Log each execution in `RecurringScheduler` when a recurring item fires
- [ ] 21.4 Add "History" section to recurring item detail/edit view
- [ ] 21.5 Show last 5 executions with date and amount

### 22. Recurring — Add End Date Support
- [ ] 22.1 Add `endDate` optional field to `RecurringTransaction` model
- [ ] 22.2 Add DB migration for `end_date TEXT` column
- [ ] 22.3 Add date picker to recurring form for end date
- [ ] 22.4 In `RecurringScheduler`, skip execution if `endDate != null && today > endDate`
- [ ] 22.5 Show "Ends on X" label on recurring item rows

### 23. Recurring — Skip Next Occurrence
- [ ] 23.1 Add "Skip Next" action to recurring item row (long-press or swipe action)
- [ ] 23.2 Advance `nextDueDate` by one frequency period without creating a transaction
- [ ] 23.3 Show "Skipped" badge on the item until the new due date

### 24. Batch Review UI for Flagged SMS Transactions
- [ ] 24.1 Add a "Review All" screen accessible from the pending actions banner (task 3)
- [ ] 24.2 Show all `needsReview = true` transactions in a card stack or list
- [ ] 24.3 Each card shows: amount, category, merchant, SMS source snippet, confidence badge
- [ ] 24.4 Add "Approve All" and "Review One by One" actions
- [ ] 24.5 "Approve All" marks all as `needsReview = false` and submits positive feedback
- [ ] 24.6 "Review One by One" navigates through each transaction detail screen

### 25. SMS Setup Onboarding Flow
- [ ] 25.1 After `WelcomeScreen`, detect if SMS permission has never been requested
- [ ] 25.2 Show a dedicated "Enable SMS Auto-Import" onboarding card
- [ ] 25.3 Explain the feature with a simple illustration and bullet points
- [ ] 25.4 "Enable" button → request SMS permission → if granted, navigate to account setup
- [ ] 25.5 "Skip" button → proceed to main app, show reminder in profile
- [ ] 25.6 Guide user to add their first account with institution name and account identifier

### 26. Auto-Backup Scheduling
- [ ] 26.1 Add "Auto-backup" toggle in Settings → Backup tab
- [ ] 26.2 Add frequency selector: Daily / Weekly / Monthly
- [ ] 26.3 Store preference in `SharedPreferences`
- [ ] 26.4 Check and trigger backup in `RecurringScheduler` or app resume lifecycle
- [ ] 26.5 Show last backup date in Settings → Backup tab (see task 17)

### 27. Transaction Duplication
- [ ] 27.1 Add "Duplicate" action to `TransactionDetailScreen` action buttons
- [ ] 27.2 Open the add transaction form pre-filled with the current transaction's data
- [ ] 27.3 Default date to today (not the original date)

### 28. Credit Card Utilization Display
- [ ] 28.1 In `AccountsScreen`, for credit card accounts with a `creditLimit`, show utilization %
- [ ] 28.2 Formula: `utilization = balance / creditLimit * 100`
- [ ] 28.3 Show a small progress bar below the balance on the account card
- [ ] 28.4 Color: green < 30%, amber 30–70%, red > 70%

### 29. Account Reordering
- [ ] 29.1 Add `sort_order` column to `accounts` table via DB migration
- [ ] 29.2 Add `ReorderableListView` to `AccountsScreen` account list
- [ ] 29.3 Persist new order to DB on drag-end
- [ ] 29.4 Default sort order = insertion order

---

## PHASE 4 — Technical Debt & Architecture

### 30. Split AppDatabase God Class
- [ ] 30.1 Create `lib/db/transaction_queries.dart` — extract all transaction-related SQL methods
- [ ] 30.2 Create `lib/db/account_queries.dart` — extract all account-related SQL methods
- [ ] 30.3 Create `lib/db/budget_queries.dart` — extract budget + category SQL methods
- [ ] 30.4 Create `lib/db/savings_queries.dart` — extract savings goal SQL methods
- [ ] 30.5 Create `lib/db/recurring_queries.dart` — extract recurring transaction SQL methods
- [ ] 30.6 Create `lib/db/sms_queries.dart` — extract all SMS intelligence SQL methods
- [ ] 30.7 Keep `AppDatabase` as a thin facade that delegates to the domain query classes
- [ ] 30.8 Update all call sites (screens, services) to still use `AppDatabase.*` (no breaking changes)

### 31. Make Screens Use ViewModels Consistently
- [ ] 31.1 `HomeScreen` — wire to `HomeViewModel` (already exists in `lib/viewmodels/`)
- [ ] 31.2 `TransactionsScreen` — wire to `TransactionsViewModel`
- [ ] 31.3 `AccountsScreen` — wire to `AccountsViewModel`
- [ ] 31.4 `BudgetScreen` — wire to `BudgetViewModel`
- [ ] 31.5 `RecurringScreen` — wire to `RecurringViewModel`
- [ ] 31.6 `SavingsScreen` — wire to `SavingsViewModel`
- [ ] 31.7 Remove direct `AppDatabase` calls from screen `_load()` methods — delegate to ViewModels

### 32. Add Transaction List Pagination
- [ ] 32.1 Add `limit` and `offset` parameters to `AppDatabase.getTransactions()`
- [ ] 32.2 Implement infinite scroll in `TransactionsScreen` using `ScrollController`
- [ ] 32.3 Load first 50 transactions on initial load
- [ ] 32.4 Load next 50 when user scrolls near the bottom
- [ ] 32.5 Show loading indicator at bottom of list while fetching next page
- [ ] 32.6 Apply same pagination to `HomeScreen` recent transactions (already limited to 5 — keep as-is)

### 33. Selective Data Refresh (Replace Broadcast Reload)
- [ ] 33.1 Extend `appRefresh` notifier to carry a `RefreshEvent` enum (transactions, accounts, budgets, goals, recurring, all)
- [ ] 33.2 Update `notifyDataChanged()` to accept an optional `RefreshEvent`
- [ ] 33.3 Update each screen to only reload when its relevant event fires
- [ ] 33.4 Default to `RefreshEvent.all` for backward compatibility

### 34. Persist Filter State Across Sessions
- [ ] 34.1 Save `_filterType`, `_filterAccountId`, `_filterCategory`, `_filterSourceType` to `SharedPreferences` on change
- [ ] 34.2 Restore filter state on `TransactionsScreen` init
- [ ] 34.3 Add "Reset Filters" option that clears persisted state

### 35. Fix Dead Code — Remove or Implement
- [ ] 35.1 `_searchVisible = false` (final) in `TransactionsScreen` — fixed by task 1
- [ ] 35.2 `_showBalance = true` (final) in `HomeScreen` — either implement balance hide or remove the field
- [ ] 35.3 `_showRecent = false` (final) in `ChatScreen` — either implement or remove
- [ ] 35.4 `_buildSpendingChart()` in `HomeScreen` — method exists but is never called; implement or remove
- [ ] 35.5 `_BudgetSection` widget in `BudgetScreen` — defined but not used in `build()`; fixed by task 14

### 36. Centralize Form Validation
- [ ] 36.1 `lib/core/form_validation.dart` exists — audit its current contents
- [ ] 36.2 Add validators: `validateAmount`, `validateCategory`, `validateAccountName`, `validateGoalName`
- [ ] 36.3 Replace inline `if (amount == null || amount <= 0)` guards in all form `onPressed` handlers
- [ ] 36.4 Show inline validation errors on fields (not just silent no-ops)

### 37. Add Error Boundaries to Screens
- [ ] 37.1 `ErrorBoundary` widget exists in `lib/widgets/error_boundary.dart` — verify its API
- [ ] 37.2 Wrap each screen's main content in `ErrorBoundary`
- [ ] 37.3 Ensure uncaught widget errors show `ErrorStateWidget` instead of red screen

### 38. Improve Loading States
- [ ] 38.1 `LoadingSkeleton` widget exists — use it instead of `CircularProgressIndicator` on list screens
- [ ] 38.2 `TransactionsScreen` — show skeleton rows while loading
- [ ] 38.3 `AccountsScreen` — show skeleton account cards while loading
- [ ] 38.4 `BudgetScreen` — show skeleton budget rows while loading
- [ ] 38.5 Keep `CircularProgressIndicator` only for action-triggered loading (save, delete, backup)

### 39. Add Missing DB Indexes
- [ ] 39.1 Add index on `transactions(date)` for date-range queries
- [ ] 39.2 Add index on `transactions(account_id)` for account-filtered queries
- [ ] 39.3 Add index on `transactions(category)` for category-grouped queries
- [ ] 39.4 Add index on `transactions(source_type)` for SMS filter queries
- [ ] 39.5 Add index on `transactions(needs_review)` for review queue queries
- [ ] 39.6 Add these via a new DB migration block

### 40. Add Unit Tests for Core Business Logic
- [ ] 40.1 `AppDatabase.accountBalance()` — test with income, expense, and transfer transactions
- [ ] 40.2 `AppDatabase.rangeTotal()` — test with date range boundaries
- [ ] 40.3 `Transaction.isTransfer` — test all transfer direction cases
- [ ] 40.4 `Account.isLiability` — test all account types
- [ ] 40.5 `Account.nextDueDate` — test with past and future due dates
- [ ] 40.6 `Account.daysUntilDue` — test boundary conditions
- [ ] 40.7 Budget over/under calculation logic
- [ ] 40.8 Savings goal progress calculation

### 41. Add Widget Tests for Key Screens
- [ ] 41.1 `HomeScreen` — renders summary card with correct balance
- [ ] 41.2 `TransactionsScreen` — renders filtered list correctly
- [ ] 41.3 `BudgetScreen` — shows over-budget section when applicable
- [ ] 41.4 `AccountsScreen` — shows net worth summary card
- [ ] 41.5 `SavingsScreen` — shows completed vs in-progress sections

### 42. Accessibility Improvements
- [ ] 42.1 Add `Semantics` labels to all icon-only buttons (FABs, icon buttons)
- [ ] 42.2 Add `Semantics` to progress bars (value, label)
- [ ] 42.3 Ensure all interactive elements have minimum 44×44 touch target
- [ ] 42.4 Add `excludeSemantics` to decorative icons
- [ ] 42.5 Test with TalkBack (Android) — verify screen reader announces amounts correctly
- [ ] 42.6 Ensure color is not the only differentiator (income/expense — add +/- prefix, already done in some places)

---

## PHASE 5 — Advanced Features

### 43. Multi-Currency Support
- [ ] 43.1 Add `currency` field to `Account` model (ISO 4217 code, default `USD`)
- [ ] 43.2 Add DB migration for `currency TEXT DEFAULT 'USD'` on accounts
- [ ] 43.3 Add currency selector to account form
- [ ] 43.4 Store exchange rates (manual entry or API) in a `exchange_rates` table
- [ ] 43.5 Convert all amounts to base currency for net worth calculation
- [ ] 43.6 Display original currency on transaction rows for non-base accounts

### 44. Spending Trend Chart on Home Screen
- [ ] 44.1 `_buildSpendingChart()` already exists in `HomeScreen` with hardcoded data
- [ ] 44.2 Replace hardcoded `FlSpot` data with real monthly expense totals from DB
- [ ] 44.3 Load last 6 months of expense data
- [ ] 44.4 Add the chart to the home screen carousel (as a third carousel page)
- [ ] 44.5 Make chart interactive — tap a month to filter transactions to that month

### 45. Persistent Chat History
- [ ] 45.1 Add `chat_messages` table: `id, role, content, timestamp`
- [ ] 45.2 Add DB migration for the table
- [ ] 45.3 Load last 20 messages on `ChatScreen` init
- [ ] 45.4 Save each message to DB on send/receive
- [ ] 45.5 Add "Clear History" option (already exists for in-memory — extend to DB)

### 46. Transaction from Chat
- [ ] 46.1 When `ChatParser.parse()` returns `ParseSuccess`, show a confirmation card in chat
- [ ] 46.2 Card shows: type, amount, category, account
- [ ] 46.3 "Confirm" button inserts the transaction
- [ ] 46.4 "Edit" button opens the add transaction form pre-filled
- [ ] 46.5 "Cancel" dismisses without saving

### 47. Backup Versioning
- [ ] 47.1 Name backup files with timestamp: `pocketflow_backup_YYYYMMDD_HHmm.json`
- [ ] 47.2 List available backups in Settings → Backup tab (read from Google Drive folder)
- [ ] 47.3 Allow user to select which backup to restore from
- [ ] 47.4 Keep last 5 backups, auto-delete older ones

### 48. Conflict Resolution on Restore
- [ ] 48.1 Before restore, check if local DB has data
- [ ] 48.2 Show dialog: "Replace all local data" vs "Merge (keep newer)"
- [ ] 48.3 Implement merge strategy: keep transaction with later `date` on conflict
- [ ] 48.4 Show restore summary: X added, Y updated, Z skipped

---

## Quick Reference — Priority Matrix

| Phase | Tasks | Priority | Effort |
|---|---|---|---|
| Phase 1 — Critical Fixes | 1–6 | 🔴 High | S–M |
| Phase 2 — UX Improvements | 7–18 | 🟠 Medium-High | S–M |
| Phase 3 — Feature Enhancements | 19–29 | 🟡 Medium | M–L |
| Phase 4 — Technical Debt | 30–42 | 🟠 Medium-High | M–L |
| Phase 5 — Advanced Features | 43–48 | 🟢 Low-Medium | L–XL |

---

## Notes

- Tasks in Phase 1 should be completed before any Phase 2 work
- Tasks 9 (centralize category logic) and 30 (split AppDatabase) are prerequisites for many other tasks — do them early in their respective phases
- Tasks 31 (ViewModels) and 33 (selective refresh) should be done together
- Tasks 12 (swipe-to-delete) and 13 (undo manager) must be done together
- Tasks 15 and 16 (savings goal dates) should be done in sequence
- The `sms-self-learning` spec tasks are separate and should continue on their own track
- All DB changes require a migration version bump (currently at v22)
