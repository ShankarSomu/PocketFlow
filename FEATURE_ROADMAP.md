# PocketFlow Feature Implementation Roadmap

**Date:** April 17, 2026  
**Scope:** Data Management & Navigation Enhancements  
**Total Features:** 20  

---

## 📊 Implementation Priority Matrix

| Priority | Impact | Complexity | Features |
|----------|--------|------------|----------|
| **P0 - Critical** | High | Low-Medium | Input sanitization, Soft deletes, Deep linking, Tab persistence |
| **P1 - High** | High | Medium | Data validation, Export formats, Navigation guards, Back handling |
| **P2 - Medium** | Medium | Medium | Import CSV/Excel, Migration tests, Navigation history, Breadcrumbs |
| **P3 - Nice to Have** | Medium | High | Data compression, Archiving, Gesture navigation, Navigation shortcuts |
| **P4 - Future** | Low | High | Advanced encryption, Multi-format backup, Modal routing, URL navigation |

---

## Phase 1: Foundation (Week 1-2)

### 🔐 Data Management Foundation

#### 1.1 Input Sanitization ⭐ P0
**Status:** Missing  
**Time:** 2-3 days  
**Dependencies:** Existing validation framework

**Implementation:**
```dart
lib/core/input_sanitizer.dart
  - TextSanitizer (trim, strip HTML, SQL injection prevention)
  - NumberSanitizer (validate numeric ranges)
  - DateSanitizer (normalize date inputs)
  - AmountSanitizer (currency input cleaning)
  - CategorySanitizer (prevent injection in category names)

lib/core/sanitization_rules.dart
  - MaxLengthRule
  - AllowedCharactersRule
  - DisallowedPatterns (SQL, XSS patterns)
```

**Integration Points:**
- Transaction forms (amount, note, category)
- Account creation (name, description)
- Budget/Goal forms (name, target, notes)
- Chat input (AI queries, transaction parsing)

**Testing:**
- Test SQL injection attempts
- Test XSS patterns
- Test script tag stripping
- Test special character handling

---

#### 1.2 Soft Deletes ⭐ P0
**Status:** Missing  
**Time:** 3-4 days  
**Dependencies:** Database schema changes

**Implementation:**
```dart
lib/db/database.dart
  - Add deleted_at timestamp to all tables
  - Modify deleteTransaction() → softDeleteTransaction()
  - Add restoreTransaction(id)
  - Add permanentlyDeleteTransaction(id)
  - Update all queries to filter deleted_at IS NULL

lib/models/deletable_entity.dart
  - Base class for soft-deletable models
  - isDeleted getter
  - deletedAt property
  - restore() method

lib/screens/deleted_items_screen.dart
  - UI for viewing deleted items
  - Restore functionality
  - Permanent delete with confirmation
  - Filter by entity type (transactions, accounts, etc.)
```

**Migration Script:**
```sql
-- Migration: Add soft delete support
ALTER TABLE transactions ADD COLUMN deleted_at INTEGER;
ALTER TABLE accounts ADD COLUMN deleted_at INTEGER;
ALTER TABLE budgets ADD COLUMN deleted_at INTEGER;
ALTER TABLE savings_goals ADD COLUMN deleted_at INTEGER;
ALTER TABLE recurring_transactions ADD COLUMN deleted_at INTEGER;

-- Create indexes
CREATE INDEX idx_transactions_deleted ON transactions(deleted_at);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);
```

**Features:**
- 30-day retention before auto-purge
- Bulk restore
- Search within deleted items
- Export deleted items before purge

---

#### 1.3 Data Migration Tests ⭐ P1
**Status:** Missing  
**Time:** 2 days  
**Dependencies:** None

**Implementation:**
```dart
test/db/migration_test.dart
  - Test v1 → v2 schema upgrade
  - Test data integrity after migration
  - Test rollback scenarios
  - Test foreign key preservation

test/db/migration_scenarios/
  - sample_v1_data.db (legacy database)
  - expected_v2_output.json
  - Test helper functions

lib/db/migration_validator.dart
  - Pre-migration checks
  - Post-migration validation
  - Data integrity verification
  - Backup before migration
```

**Test Coverage:**
- All schema versions (v1 through current)
- Large dataset migrations (10k+ transactions)
- Corrupted database recovery
- Partial migration rollback

---

### 🧭 Navigation Foundation

#### 1.4 Deep Linking ⭐ P0
**Status:** Missing  
**Time:** 3-4 days  
**Dependencies:** None

**Implementation:**
```dart
lib/navigation/deep_link_handler.dart
  - parseDeepLink(Uri)
  - navigateFromLink(BuildContext, Uri)
  - registerRoute(pattern, handler)

lib/navigation/app_routes.dart
  - pocketflow://transaction/:id
  - pocketflow://account/:id
  - pocketflow://budget/:category/:month
  - pocketflow://goal/:id
  - pocketflow://chat
  - pocketflow://add-transaction?amount=X&category=Y

android/app/src/main/AndroidManifest.xml
  - Intent filters for URL schemes
  - Handle app links (https://pocketflow.app/...)

ios/Runner/Info.plist
  - URL scheme registration
  - Universal links support
```

**Use Cases:**
- Share transaction: `pocketflow://transaction/123`
- Open specific month budget: `pocketflow://budget/food/2026-04`
- Quick add transaction: `pocketflow://add?amount=50&note=Lunch`
- External integration: Bank SMS → deep link → auto-categorize

**Testing:**
- Test all route patterns
- Test invalid links (graceful error)
- Test link from notification
- Test link from external app

---

#### 1.5 Tab Persistence ⭐ P0
**Status:** Missing  
**Time:** 1 day  
**Dependencies:** SharedPreferences

**Implementation:**
```dart
lib/services/navigation_state.dart
  - saveLastTab(int index)
  - getLastTab() → int
  - saveScreenState(String screen, Map<String, dynamic> state)
  - getScreenState(String screen) → Map?

lib/main.dart
  - Restore last tab on app launch
  - Restore scroll positions
  - Restore filter states
```

**Persisted State:**
- Last active tab (Home, Budget, Savings, etc.)
- Scroll position per screen
- Active filters (date range, categories)
- Search queries
- Expanded/collapsed sections

---

## Phase 2: Data Export & Import (Week 3-4)

#### 2.1 Export Formats ⭐ P1
**Status:** Partially implemented (basic backup)  
**Time:** 4-5 days  
**Dependencies:** Soft deletes, existing backup

**Implementation:**
```dart
lib/services/export_service.dart
  - exportToJSON(dateRange, filters) → File
  - exportToCSV(dateRange, filters) → File
  - exportToExcel(dateRange, filters) → File
  - exportToPDF(dateRange, filters) → File

lib/models/export_config.dart
  - ExportFormat enum (JSON, CSV, Excel, PDF)
  - ExportFilters (date range, categories, accounts)
  - IncludeOptions (transactions, budgets, goals, accounts)

lib/widgets/export_dialog.dart
  - Export configuration UI
  - Format selection
  - Filter options
  - Preview before export
```

**Export Formats:**

**JSON:**
```json
{
  "export_date": "2026-04-17T10:30:00Z",
  "version": "1.0",
  "data": {
    "transactions": [...],
    "accounts": [...],
    "budgets": [...],
    "goals": [...]
  },
  "metadata": {
    "total_transactions": 1234,
    "date_range": {"from": "2025-01-01", "to": "2026-12-31"}
  }
}
```

**CSV:** (Transactions example)
```csv
Date,Type,Amount,Category,Account,Note,Tags
2026-04-17,expense,45.50,Food,Cash,Lunch,dining,work
2026-04-16,income,3000.00,Salary,Checking,Monthly salary,income
```

**Excel:**
- Multiple sheets (Transactions, Budgets, Summary)
- Charts (spending by category, income vs expenses)
- Pivot tables
- Formatting (currency, dates)

**PDF:**
- Professional financial report
- Charts and graphs
- Summary statistics
- Custom date range headers

**Features:**
- Email export (share as attachment)
- Cloud upload (Drive, Dropbox)
- Schedule automatic exports
- Template customization

---

#### 2.2 Import from CSV/Excel ⭐ P2
**Status:** Missing  
**Time:** 3-4 days  
**Dependencies:** Export formats, sanitization

**Implementation:**
```dart
lib/services/import_service.dart
  - parseCSV(File) → List<Transaction>
  - parseExcel(File) → List<Transaction>
  - validateImportData(data) → ValidationResult
  - importTransactions(data, options) → ImportResult

lib/models/import_config.dart
  - ColumnMapping (CSV column → model field)
  - DuplicateHandling (skip, update, create)
  - DateFormat detection
  - Currency detection

lib/screens/import_screen.dart
  - File picker
  - Column mapping interface
  - Preview parsed data
  - Conflict resolution UI
  - Import progress
```

**Import Features:**
- Auto-detect column headers
- Smart date parsing (multiple formats)
- Currency symbol detection
- Duplicate transaction detection
- Validation with error reporting
- Dry-run mode (preview without saving)
- Batch import with rollback

**Supported Formats:**
- Standard CSV (UTF-8)
- Excel (.xlsx)
- Bank statement formats (pre-configured templates)
- Mint/YNAB export formats

---

## Phase 3: Advanced Data Features (Week 5-6)

#### 3.1 Data Compression ⭐ P3
**Status:** Missing  
**Time:** 2-3 days  
**Dependencies:** Backup system

**Implementation:**
```dart
lib/services/compression_service.dart
  - compressDatabase() → File
  - decompressDatabase(File) → Database
  - calculateCompressionRatio()

lib/db/archive_manager.dart
  - archiveOldData(DateTime cutoffDate)
  - unarchiveData(DateTime from, to)
```

**Features:**
- Gzip compression for exports
- Archive transactions older than 2 years
- Compressed backup storage
- Background compression (no UI blocking)

**Compression Targets:**
- Transaction notes (text compression)
- Backup files (gzip)
- Attachment images (JPEG optimization)
- Logs (rotate and compress)

---

#### 3.2 Data Archiving ⭐ P3
**Status:** Missing  
**Time:** 3 days  
**Dependencies:** Soft deletes, compression

**Implementation:**
```dart
lib/db/archive_database.dart
  - Separate SQLite DB for archived data
  - archiveTransaction(id)
  - unarchiveTransaction(id)
  - getArchivedData(dateRange) → List

lib/screens/archive_screen.dart
  - Browse archived transactions
  - Search archived data
  - Unarchive functionality
  - Export archived data

lib/services/archive_policy.dart
  - AutoArchiveRule (e.g., >2 years old)
  - ManualArchive(selection)
  - ArchiveScheduler (monthly job)
```

**Archive Rules:**
- Transactions older than 2 years
- Deleted items after 90 days
- Inactive accounts
- Completed goals (after 6 months)

**Benefits:**
- Faster main database queries
- Reduced app storage
- Historical data preserved
- Compliance (data retention policies)

---

#### 3.3 Data Backup Scheduling ⭐ P1
**Status:** Partially implemented  
**Time:** 2 days  
**Dependencies:** Existing backup system

**Enhancement:**
```dart
lib/services/backup_scheduler.dart
  - scheduleBackup(frequency, time)
  - BackupFrequency enum (hourly, daily, weekly, monthly)
  - BackupConditions (WiFi only, charging, idle)
  - NotifyBackupComplete()

lib/services/backup_verification.dart
  - verifyBackupIntegrity(File)
  - testRestore(backup, tempDb)
  - BackupHealthCheck (last backup time, size, errors)
```

**Features:**
- Smart scheduling (WiFi + charging)
- Multiple backup destinations
- Incremental backups (only changes)
- Backup rotation (keep last 10)
- Failed backup retry logic
- Backup verification

---

## Phase 4: Navigation Improvements (Week 7-8)

#### 4.1 Navigation Guards ⭐ P1
**Status:** Missing  
**Time:** 2-3 days  
**Dependencies:** Navigation system

**Implementation:**
```dart
lib/navigation/navigation_guard.dart
  - abstract class NavigationGuard
  - canNavigate(from, to) → bool
  - onNavigationBlocked(reason) → Widget

lib/navigation/guards/
  - unsaved_changes_guard.dart
  - authentication_guard.dart
  - permission_guard.dart
  - form_validation_guard.dart

lib/widgets/unsaved_changes_dialog.dart
  - "You have unsaved changes. Discard?"
  - Save and continue
  - Cancel navigation
```

**Guard Types:**
1. **Unsaved Changes Guard**
   - Detect dirty forms
   - Show confirmation dialog
   - Save draft option

2. **Authentication Guard**
   - Check login status
   - Redirect to login if needed
   - Preserve navigation intent

3. **Permission Guard**
   - Check feature access (premium features)
   - Show upgrade prompt
   - Alternative navigation

**Integration:**
- Transaction form (unsaved transaction)
- Budget editing (unsaved changes)
- Settings changes (unsaved preferences)

---

#### 4.2 Navigation History ⭐ P2
**Status:** Missing  
**Time:** 2 days  
**Dependencies:** Navigation system

**Implementation:**
```dart
lib/services/navigation_history.dart
  - push(Route)
  - pop() → Route?
  - canGoBack() → bool
  - getHistory() → List<Route>
  - clearHistory()

lib/widgets/navigation_history_drawer.dart
  - Show last 10 screens
  - Quick jump to any screen
  - Clear history
  - Visual breadcrumb

lib/screens/debug_navigation_screen.dart
  - Full navigation history
  - Route parameters
  - Navigation timing
  - Debug navigation issues
```

**Features:**
- Long-press back button → show history
- Breadcrumb trail in complex flows
- Jump back multiple screens
- History persistence across sessions

---

#### 4.3 Navigation Animations ⭐ P1
**Status:** Basic animations exist  
**Time:** 3 days  
**Dependencies:** None

**Enhancement:**
```dart
lib/navigation/transitions.dart
  - SlideTransition (left/right/up/down)
  - FadeTransition
  - ScaleTransition
  - SharedElementTransition

lib/navigation/transition_config.dart
  - Configure transition per route
  - Duration customization
  - Curve customization
  - Conditional transitions (modal vs push)
```

**Transition Types:**
- **Slide Right:** Back navigation
- **Slide Left:** Forward navigation
- **Slide Up:** Modal screens
- **Fade:** Tab switches
- **Scale:** Detail views
- **Shared Element:** Transaction → Detail (amount animates)

**Custom Animations:**
- Transaction card → Transaction detail (hero animation)
- Budget progress bar → Budget screen
- Account balance → Account detail
- Category pie chart → Category breakdown

---

#### 4.4 Breadcrumb Navigation ⭐ P2
**Status:** Missing  
**Time:** 2 days  
**Dependencies:** Navigation history

**Implementation:**
```dart
lib/widgets/breadcrumb_bar.dart
  - Show current path (Home > Budgets > Food > Details)
  - Clickable breadcrumbs
  - Auto-collapse long paths
  - Responsive design

lib/navigation/breadcrumb_config.dart
  - Route title mapping
  - Icon mapping
  - Separator customization
```

**Example Paths:**
```
Home > Accounts > Checking > Transaction #123
Home > Budgets > April 2026 > Food Category
Home > Savings > Vacation > Edit Goal
Home > Chat > Transaction Analysis
```

**Features:**
- Tap any breadcrumb to jump
- Show/hide based on screen size
- Animation when path changes
- Custom icons per route

---

#### 4.5 Gesture Navigation ⭐ P3
**Status:** Missing  
**Time:** 3-4 days  
**Dependencies:** Navigation system

**Implementation:**
```dart
lib/navigation/gesture_detector.dart
  - Swipe right → Go back
  - Swipe left → Go forward (if history exists)
  - Swipe down → Dismiss modal
  - Long press → Quick actions
  - Two-finger swipe → Switch accounts

lib/services/gesture_config.dart
  - Enable/disable gestures
  - Sensitivity settings
  - Conflict resolution with scrolling
```

**Gesture Types:**
1. **Edge Swipe (Right):** Go back
2. **Edge Swipe (Left):** Forward in history
3. **Card Swipe (Left/Right):** Quick actions (edit/delete)
4. **Pull to Refresh:** Reload data
5. **Long Press:** Context menu
6. **Two-Finger Pinch:** Quick stats overlay

**Conflicts:**
- Disable during horizontal scrolling
- Disable in text input fields
- Respect system gesture zones (Android navigation)

---

#### 4.6 Navigation Shortcuts ⭐ P3
**Status:** Missing  
**Time:** 2 days  
**Dependencies:** Deep linking

**Implementation:**
```dart
lib/navigation/keyboard_shortcuts.dart
  - Ctrl+T → New transaction
  - Ctrl+A → Accounts view
  - Ctrl+B → Budgets view
  - Ctrl+S → Savings view
  - Ctrl+F → Search

lib/widgets/command_palette.dart
  - Cmd+K → Open command palette
  - Fuzzy search commands
  - Recent commands
  - Quick navigation

lib/navigation/app_shortcuts.dart
  - Android: Home screen shortcuts
  - iOS: Quick actions (3D Touch)
  - Add transaction shortcut
  - View balance shortcut
```

**Home Screen Shortcuts:**
- Add Transaction (expense)
- Add Transaction (income)
- View Balance
- Open Chat
- Quick Search

---

#### 4.7 Modal Routing Improvements ⭐ P4
**Status:** Basic modals exist  
**Time:** 2-3 days  
**Dependencies:** None

**Enhancement:**
```dart
lib/navigation/modal_navigator.dart
  - showModalRoute(builder, config)
  - ModalConfig (fullscreen, bottom sheet, dialog)
  - Modal stack management
  - Persistent modals

lib/widgets/advanced_bottom_sheet.dart
  - Draggable bottom sheet
  - Snap points
  - Nested scrolling
  - Modal backdrop customization
```

**Modal Types:**
1. **Bottom Sheet:** Transaction form, filters
2. **Full Screen Modal:** Multi-step wizards
3. **Dialog:** Confirmations, quick actions
4. **Popover:** Tooltips, help text
5. **Snackbar:** Notifications, undo actions

**Features:**
- Dismissible with swipe
- Persistent modals (survive navigation)
- Modal history (stack of modals)
- Backdrop blur
- Custom animations

---

## Phase 5: Advanced Features (Week 9-10)

#### 5.1 Back Button Handling ⭐ P1
**Status:** Basic handling exists  
**Time:** 2 days  
**Dependencies:** Navigation guards

**Enhancement:**
```dart
lib/navigation/back_button_handler.dart
  - registerBackHandler(callback)
  - handleBackPress() → bool (true = handled)
  - BackPressedEvent(canPop, hasUnsavedChanges)

lib/utils/back_button_dispatcher.dart
  - Priority-based handlers
  - Intercept system back
  - Custom back behavior per screen
```

**Behaviors:**
- **Form Screen:** Show unsaved changes dialog
- **Modal:** Close modal
- **Search:** Clear search, then go back
- **Tab:** Go to previous tab, then exit app
- **Nested Navigation:** Pop inner navigator first

**Double Tap to Exit:**
- Show "Press again to exit" toast
- 2-second window for second press
- Configurable per app section

---

#### 5.2 URL-Based Navigation ⭐ P4
**Status:** Missing  
**Time:** 3-4 days  
**Dependencies:** Deep linking

**Implementation:**
```dart
lib/navigation/url_router.dart
  - parseURL(String) → NavigationState
  - buildURL(NavigationState) → String
  - URLPattern matching

lib/navigation/url_routes.dart
  - /transactions
  - /transactions/:id
  - /budgets?month=2026-04&category=food
  - /accounts/:accountId/transactions
  - /search?q=coffee&from=2026-01-01
```

**Features:**
- Shareable URLs (web version)
- Query parameters support
- Route parameters
- Bookmark specific views
- Copy link to clipboard

**Use Cases:**
- Share budget view: `pocketflow://budgets?month=2026-04`
- Share transaction: `pocketflow://transaction/123`
- Share search: `pocketflow://search?category=food&month=april`

---

## 📈 Implementation Metrics

### Complexity Breakdown
| Feature | Lines of Code | Files | Time (days) |
|---------|--------------|-------|-------------|
| Input Sanitization | ~300 | 3 | 2-3 |
| Soft Deletes | ~500 | 5 | 3-4 |
| Migration Tests | ~400 | 4 | 2 |
| Deep Linking | ~600 | 6 | 3-4 |
| Tab Persistence | ~150 | 2 | 1 |
| Export Formats | ~800 | 8 | 4-5 |
| Import CSV/Excel | ~600 | 6 | 3-4 |
| Data Compression | ~300 | 3 | 2-3 |
| Data Archiving | ~400 | 4 | 3 |
| Backup Scheduling | ~300 | 3 | 2 |
| Navigation Guards | ~400 | 5 | 2-3 |
| Navigation History | ~250 | 3 | 2 |
| Navigation Animations | ~350 | 4 | 3 |
| Breadcrumbs | ~200 | 2 | 2 |
| Gesture Navigation | ~450 | 5 | 3-4 |
| Navigation Shortcuts | ~300 | 3 | 2 |
| Modal Routing | ~350 | 4 | 2-3 |
| Back Button Handling | ~250 | 3 | 2 |
| URL Navigation | ~500 | 5 | 3-4 |
| **TOTAL** | **~7,400** | **78** | **48-59** |

### Time Estimate
- **Total Development Time:** 48-59 working days (~10-12 weeks)
- **Testing & QA:** +25% (12-15 days)
- **Documentation:** +10% (5-6 days)
- **Total Project Time:** **65-80 days (13-16 weeks)**

---

## 🎯 Quick Win Features (Implement First)

These provide maximum impact with minimal effort:

1. **Tab Persistence** (1 day) - User convenience
2. **Input Sanitization** (2-3 days) - Security critical
3. **Soft Deletes** (3-4 days) - User safety
4. **Deep Linking** (3-4 days) - External integration
5. **Navigation Guards** (2-3 days) - Prevent data loss

**Total Quick Wins:** 11-16 days for 5 high-impact features

---

## 🔄 Dependencies Graph

```
Input Sanitization
    └── Import CSV/Excel
    └── Data Validation

Soft Deletes
    └── Data Archiving
    └── Deleted Items Screen

Deep Linking
    └── URL Navigation
    └── Navigation Shortcuts
    └── External Integrations

Tab Persistence
    └── Navigation State
    └── Screen State

Backup System (Existing)
    └── Export Formats
    └── Data Compression
    └── Backup Scheduling

Navigation System (Existing)
    └── Navigation Guards
    └── Navigation History
    └── Back Button Handling
    └── Gesture Navigation
```

---

## 🧪 Testing Strategy

### Unit Tests
- All sanitization functions
- Export/import parsers
- Navigation guard logic
- Deep link parsing
- Data compression
- Archive functionality

### Integration Tests
- Complete export → import cycle
- Navigation flow with guards
- Deep linking from external apps
- Backup → restore → verify
- Multi-format export compatibility

### UI Tests
- Navigation gestures
- Back button scenarios
- Modal dismissal
- Breadcrumb interaction
- Export wizard flow

### Performance Tests
- Large dataset export (10k+ transactions)
- Import performance
- Compression speed
- Archive operation time
- Navigation transition smoothness

---

## 📦 Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  # Export/Import
  csv: ^6.0.0               # CSV parsing
  excel: ^4.0.0              # Excel export/import
  pdf: ^3.10.0               # PDF generation
  path_provider: ^2.1.0      # File system access
  
  # Compression
  archive: ^3.4.0            # Gzip compression
  
  # Navigation
  go_router: ^13.0.0         # Advanced routing (optional)
  uni_links: ^0.5.1          # Deep linking
  
  # Utilities
  mime: ^1.0.4               # File type detection
  file_picker: ^6.1.0        # Already exists
  
dev_dependencies:
  # Testing
  mockito: ^5.4.0            # Mocking
  integration_test: ^1.0.0   # Integration tests
```

---

## 🚀 Recommended Implementation Order

### Sprint 1-2 (Weeks 1-2): Foundation
1. Input Sanitization
2. Soft Deletes
3. Tab Persistence
4. Deep Linking

### Sprint 3-4 (Weeks 3-4): Data I/O
5. Export Formats (JSON, CSV, Excel, PDF)
6. Import CSV/Excel
7. Migration Tests

### Sprint 5-6 (Weeks 5-6): Navigation
8. Navigation Guards
9. Navigation History
10. Navigation Animations
11. Back Button Handling

### Sprint 7-8 (Weeks 7-8): Advanced Data
12. Data Compression
13. Data Archiving
14. Backup Scheduling

### Sprint 9-10 (Weeks 9-10): Advanced Navigation
15. Breadcrumb Navigation
16. Gesture Navigation
17. Navigation Shortcuts
18. Modal Routing
19. URL Navigation

---

## 💡 Implementation Tips

### Code Organization
```
lib/
  core/
    input_sanitizer.dart
    sanitization_rules.dart
  db/
    archive_database.dart
    soft_delete_mixin.dart
  navigation/
    deep_link_handler.dart
    navigation_guard.dart
    gesture_detector.dart
    url_router.dart
  services/
    export_service.dart
    import_service.dart
    compression_service.dart
  widgets/
    export_dialog.dart
    import_screen.dart
    navigation_history_drawer.dart
    breadcrumb_bar.dart
  screens/
    deleted_items_screen.dart
    archive_screen.dart
```

### Best Practices
1. **Incremental Migration:** Don't break existing functionality
2. **Feature Flags:** Toggle new features during development
3. **Backward Compatibility:** Support old data formats
4. **Error Handling:** Graceful degradation for missing features
5. **Performance:** Profile before optimizing
6. **Testing:** TDD for critical features
7. **Documentation:** Update as you build

---

## 📋 Success Criteria

### Data Management
- ✅ 100% input sanitization coverage
- ✅ Zero data loss with soft deletes
- ✅ <10s for 10k transaction export
- ✅ 99% import success rate
- ✅ <50% storage reduction with compression
- ✅ Successful migration tests for all schema versions

### Navigation
- ✅ All deep links working (0 errors)
- ✅ <200ms navigation transition time
- ✅ 100% gesture recognition accuracy
- ✅ Zero data loss on navigation (guards working)
- ✅ Persistent state across sessions
- ✅ Smooth animations (60fps)

### User Experience
- ✅ Users can recover deleted data
- ✅ Users can export/import seamlessly
- ✅ Navigation feels intuitive
- ✅ No accidental data loss
- ✅ Fast app startup (<2s)

---

## 🎬 Next Steps

**Ready to start implementation?** I recommend:

1. **Start with Phase 1 (Foundation)** - Critical security and UX features
2. **Implement in order** - Respect dependencies
3. **Test thoroughly** - Each feature before moving forward
4. **Iterate quickly** - Ship working features incrementally

**Command to begin:**
```
"Start with Phase 1: Implement Input Sanitization"
```

Or customize the order based on your priorities!
