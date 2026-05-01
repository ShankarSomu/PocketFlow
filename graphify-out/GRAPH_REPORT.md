# Graph Report - lib + tools + docs + test  (2026-04-30)

## Corpus Check
- 295 files · ~266,467 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2696 nodes · 3326 edges · 56 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.89)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_SMS Parsing & State Persistence|SMS Parsing & State Persistence]]
- [[_COMMUNITY_App State, Repositories & Architecture Docs|App State, Repositories & Architecture Docs]]
- [[_COMMUNITY_Chat & UI Components|Chat & UI Components]]
- [[_COMMUNITY_Haptic Feedback & Settings|Haptic Feedback & Settings]]
- [[_COMMUNITY_Transaction UI & Theming|Transaction UI & Theming]]
- [[_COMMUNITY_App Error & State Management|App Error & State Management]]
- [[_COMMUNITY_Settings, Backup & AI Tab|Settings, Backup & AI Tab]]
- [[_COMMUNITY_SMS Account Resolution (Code + Docs)|SMS Account Resolution (Code + Docs)]]
- [[_COMMUNITY_Transfer Detection (Code + Docs)|Transfer Detection (Code + Docs)]]
- [[_COMMUNITY_SMS Import & Navigation|SMS Import & Navigation]]
- [[_COMMUNITY_Accounts Quick View & SMS Source|Accounts Quick View & SMS Source]]
- [[_COMMUNITY_Budget & Notifications|Budget & Notifications]]
- [[_COMMUNITY_App Constants & Feature Flags|App Constants & Feature Flags]]
- [[_COMMUNITY_Image Cache & Assets|Image Cache & Assets]]
- [[_COMMUNITY_Backup & Folder Picker|Backup & Folder Picker]]
- [[_COMMUNITY_Intelligence Dashboard|Intelligence Dashboard]]
- [[_COMMUNITY_Database Optimization|Database Optimization]]
- [[_COMMUNITY_Recurring Patterns|Recurring Patterns]]
- [[_COMMUNITY_Intelligence Carousel|Intelligence Carousel]]
- [[_COMMUNITY_Currency & Date Formatting|Currency & Date Formatting]]
- [[_COMMUNITY_Chat Messages|Chat Messages]]
- [[_COMMUNITY_Home Header & Notifications|Home Header & Notifications]]
- [[_COMMUNITY_Accessibility Helpers|Accessibility Helpers]]
- [[_COMMUNITY_Debounce Utilities|Debounce Utilities]]
- [[_COMMUNITY_Synthetic SMS Generator (test)|Synthetic SMS Generator (test/)]]
- [[_COMMUNITY_API Key Setup|API Key Setup]]
- [[_COMMUNITY_Keyword Extraction for Training (test)|Keyword Extraction for Training (test/)]]
- [[_COMMUNITY_Animated Blob & Micro-interactions|Animated Blob & Micro-interactions]]
- [[_COMMUNITY_ML Training Data Formatter (tools)|ML Training Data Formatter (tools/)]]
- [[_COMMUNITY_SMS Transaction Result & Account Extraction|SMS Transaction Result & Account Extraction]]
- [[_COMMUNITY_Input Sanitization|Input Sanitization]]
- [[_COMMUNITY_Widget Optimization|Widget Optimization]]
- [[_COMMUNITY_NER Model Trainer (test)|NER Model Trainer (test/)]]
- [[_COMMUNITY_Undo Manager|Undo Manager]]
- [[_COMMUNITY_Settings Action Rows|Settings Action Rows]]
- [[_COMMUNITY_Entity Extraction Training Data Generator (test)|Entity Extraction Training Data Generator (test/)]]
- [[_COMMUNITY_Financial Calculations|Financial Calculations]]
- [[_COMMUNITY_Form Validation & Navigation Guards|Form Validation & Navigation Guards]]
- [[_COMMUNITY_Memoization Cache|Memoization Cache]]
- [[_COMMUNITY_Refactored Widget Examples|Refactored Widget Examples]]
- [[_COMMUNITY_ML Negative Sample Generator (tools)|ML Negative Sample Generator (tools/)]]
- [[_COMMUNITY_Transfer Label Annotator (tools)|Transfer Label Annotator (tools/)]]
- [[_COMMUNITY_Sanitization Rules|Sanitization Rules]]
- [[_COMMUNITY_SMS Data Masking|SMS Data Masking]]
- [[_COMMUNITY_Pull-to-Refresh|Pull-to-Refresh]]
- [[_COMMUNITY_SMS Pattern Analyzer (test)|SMS Pattern Analyzer (test/)]]
- [[_COMMUNITY_Continuous Learning Setup (test)|Continuous Learning Setup (test/)]]
- [[_COMMUNITY_Training Data Preparer (test)|Training Data Preparer (test/)]]
- [[_COMMUNITY_SMS Signature & Fingerprint|SMS Signature & Fingerprint]]
- [[_COMMUNITY_Logger Interface|Logger Interface]]
- [[_COMMUNITY_TFLite Model Converter (test)|TFLite Model Converter (test/)]]
- [[_COMMUNITY_Privacy Guard|Privacy Guard]]
- [[_COMMUNITY_Architecture Layer Docs|Architecture Layer Docs]]
- [[_COMMUNITY_Auth Interface|Auth Interface]]
- [[_COMMUNITY_TFLite Model Tester (test)|TFLite Model Tester (test/)]]
- [[_COMMUNITY_SMS Classifier Trainer (test)|SMS Classifier Trainer (test/)]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 142 edges
2. `../db/database.dart` - 93 edges
3. `../main.dart` - 51 edges
4. `package:intl/intl.dart` - 49 edges
5. `../../theme/app_theme.dart` - 41 edges
6. `../models/transaction.dart` - 36 edges
7. `../models/account.dart` - 32 edges
8. `../services/app_logger.dart` - 31 edges
9. `../../../../core/formatters.dart` - 27 edges
10. `../../services/theme_service.dart` - 26 edges

## Surprising Connections (you probably didn't know these)
- `SMS Account Mapping (Learning)` --references--> `../db/database.dart`  [INFERRED]
  docs/features/sms-intelligence/account-resolution.md → widgets\category_picker.dart
- `Layered Architecture` --references--> `../main.dart`  [INFERRED]
  docs/architecture/overview.md → debug\sms_scan_debugger.dart
- `../main.dart` --defines--> `PocketFlowApp`  [EXTRACTED]
  debug\sms_scan_debugger.dart → main.dart
- `../main.dart` --defines--> `_PocketFlowAppState`  [EXTRACTED]
  debug\sms_scan_debugger.dart → main.dart
- `../main.dart` --defines--> `_RootNav`  [EXTRACTED]
  debug\sms_scan_debugger.dart → main.dart

## Hyperedges (group relationships)
- **Full SMS Processing Pipeline** — doc_ingestion_layer, doc_classification_layer, doc_entity_extraction_layer, doc_account_resolution_engine, doc_transfer_detection_engine [EXTRACTED 1.00]
- **ML + Rule-Based Classification System** — doc_tflite_model, doc_ml_fallback_strategy, doc_tokenization, doc_classification_layer [EXTRACTED 0.95]
- **Transfer & Accounting Integrity** — doc_double_counting_problem, doc_transfer_pair, doc_net_worth_calculation, doc_modified_single_entry [EXTRACTED 0.95]

## Communities

### Community 0 - "SMS Parsing & State Persistence"
Cohesion: 0.01
Nodes (174): fromJson, jsonDecode, StatePersistence, StatePersistenceMixin, _explainWhyNotFinancial, _hasBankNameInBody, _hasFinancialKeywords, SmsScanDebugger (+166 more)

### Community 1 - "App State, Repositories & Architecture Docs"
Cohesion: 0.01
Nodes (163): ../account_repository.dart, app_state.dart, ../budget_repository.dart, AppDependencies, MultiProvider, wrapApp, account_candidates, accounts (+155 more)

### Community 2 - "Chat & UI Components"
Cohesion: 0.01
Nodes (130): build, Card, ChatInputBar, ActionChip, build, ChatSuggestions, Function, Wrap (+122 more)

### Community 3 - "Haptic Feedback & Settings"
Cohesion: 0.01
Nodes (145): disable, enable, HapticFeedbackHelper, HapticSettings, heavyImpact, lightImpact, mediumImpact, selectionClick (+137 more)

### Community 4 - "Transaction UI & Theming"
Cohesion: 0.02
Nodes (127): AppOpacity, blend, darken, lighten, withAlpha, build, ListTile, TransactionTile (+119 more)

### Community 5 - "App Error & State Management"
Cohesion: 0.02
Nodes (92): AppError, AppState, clearAll, clearError, dispose, ErrorState, Function, hasError (+84 more)

### Community 6 - "Settings, Backup & AI Tab"
Cohesion: 0.02
Nodes (89): appearance_section.dart, backup_widgets.dart, AITab, AITabState, build, Container, initState, ListView (+81 more)

### Community 7 - "SMS Account Resolution (Code + Docs)"
Cohesion: 0.02
Nodes (84): account_resolution_engine.dart, app_logger.dart, AccountCandidate, PendingAction, RawSmsMessage, SmsClassification, AccountResolution, AccountResolutionEngine (+76 more)

### Community 8 - "Transfer Detection (Code + Docs)"
Cohesion: 0.02
Nodes (90): TransferPair, build, Container, dispose, Divider, GestureDetector, GlassCard, Icon (+82 more)

### Community 9 - "SMS Import & Navigation"
Cohesion: 0.02
Nodes (87): AnimatedContainer, _BottomNav, build, Container, dispose, Expanded, _goTo, initState (+79 more)

### Community 10 - "Accounts Quick View & SMS Source"
Cohesion: 0.02
Nodes (85): accounts_quick_view.dart, build, _buildBullet, _buildSmsSourceCard, Card, DropdownMenuItem, EditTransactionScreen, _EditTransactionScreenState (+77 more)

### Community 11 - "Budget & Notifications"
Cohesion: 0.03
Nodes (78): ../../accounts/accounts_screen.dart, _barColor, BudgetProgressPage, build, Column, Expanded, Panel, SizedBox (+70 more)

### Community 12 - "App Constants & Feature Flags"
Cohesion: 0.02
Nodes (78): AnimationConstants, AppMetadata, DatabaseConstants, FeatureFlags, LayoutConstants, NetworkConstants, StorageConstants, TextConstants (+70 more)

### Community 13 - "Image Cache & Assets"
Cohesion: 0.03
Nodes (69): AssetImagePreloader, build, clearCache, clearImageCache, configureImageCache, createMemoryImage, getImageCacheSize, ImageCacheConfig (+61 more)

### Community 14 - "Backup & Folder Picker"
Cohesion: 0.03
Nodes (70): build, Divider, DraggableScrollableSheet, FolderPickerSheet, _FolderPickerSheetState, ListTile, Padding, ProfileDialogs (+62 more)

### Community 15 - "Intelligence Dashboard"
Cohesion: 0.03
Nodes (68): _ActionTile, build, dispose, Divider, GestureDetector, GlassCard, initState, IntelligenceDashboardScreen (+60 more)

### Community 16 - "Database Optimization"
Cohesion: 0.03
Nodes (64): and, BatchOperationHelper, budgets, _buildKey, clear, clearExpired, DatabaseConnectionPool, DatabaseOptimizer (+56 more)

### Community 17 - "Recurring Patterns"
Cohesion: 0.03
Nodes (57): RecurringPattern, build, Container, dispose, Divider, _getFrequencyText, _getPatternColor, _getPatternIcon (+49 more)

### Community 18 - "Intelligence Carousel"
Cohesion: 0.03
Nodes (53): build, CarouselArrow, Container, GestureDetector, _IntelligenceStatItem, _next, _prev, SizedBox (+45 more)

### Community 19 - "Currency & Date Formatting"
Cohesion: 0.04
Nodes (53): compact, csv, CurrencyFormatter, custom, DateFormat, DateFormatter, dateTime, decimal (+45 more)

### Community 20 - "Chat Messages"
Cohesion: 0.04
Nodes (43): Align, build, ChatMessage, Function, MessageBubble, SizedBox, BackupNowButton, BackupSettingRow (+35 more)

### Community 21 - "Home Header & Notifications"
Cohesion: 0.05
Nodes (39): AppNotification, copyWith, Align, build, FadeTransition, GestureDetector, HomeHeader, _HomeHeaderState (+31 more)

### Community 22 - "Accessibility Helpers"
Cohesion: 0.05
Nodes (40): AccessibilityHelper, AccessibleCard, AccessibleFormField, AccessibleIconButton, AccessibleText, AccessibleWidget, announce, announceComplete (+32 more)

### Community 23 - "Debounce Utilities"
Cohesion: 0.06
Nodes (34): call, cancel, cancelDebounce, debounce, debounced, DebouncedValueNotifier, DebounceMixin, Debouncer (+26 more)

### Community 24 - "Synthetic SMS Generator (test/)"
Cohesion: 0.08
Nodes (22): main(), Generate variations of a single transaction SMS, Load real SMS data and extract patterns, Replace verbs with synonyms, Replace bank names with variants, Vary formatting of amounts, dates, accounts, Reorder sentence components, Add or remove optional words (+14 more)

### Community 25 - "API Key Setup"
Cohesion: 0.08
Nodes (24): ApiKeySetup, ApiKeySetupState, build, GestureDetector, initState, Padding, ProviderCard, Row (+16 more)

### Community 26 - "Keyword Extraction for Training (test/)"
Cohesion: 0.11
Nodes (14): EnhancedTrainingDataGenerator, KeywordExtractor, main(), Parse Dart string array into Python set, Save extracted keywords to JSON, Generate training data using extracted keywords, Generate debit transaction SMS using keywords, Generate credit transaction SMS using keywords (+6 more)

### Community 27 - "Animated Blob & Micro-interactions"
Cohesion: 0.08
Nodes (23): AnimatedBuilder, build, Container, dispose, initState, LinearGradient, Padding, ProfileSkeleton (+15 more)

### Community 28 - "ML Training Data Formatter (tools/)"
Cohesion: 0.12
Nodes (13): main(), Format a single record, Determine if record is a transaction, Determine transaction type, Normalize amount to decimal format, Detect currency from text, Detect region from SMS content, Extract sender from SMS header or assume from bank name (+5 more)

### Community 29 - "SMS Transaction Result & Account Extraction"
Cohesion: 0.09
Nodes (21): fromString, SmsTransactionResult, toString, AccountExtractionService, AccountIdentity, _BankMatch, _IdentifierCandidate, _IdentifierMatch (+13 more)

### Community 30 - "Input Sanitization"
Cohesion: 0.09
Nodes (21): AmountSanitizer, CategorySanitizer, _containsHtml, _containsSqlPatterns, _containsXssPatterns, DateSanitizer, InputSanitizers, needsSanitization (+13 more)

### Community 31 - "Widget Optimization"
Cohesion: 0.09
Nodes (21): build, ConstWidgets, didUpdateWidget, expensiveWidget, Function, LazyWidget, _LazyWidgetState, object (+13 more)

### Community 32 - "NER Model Trainer (test/)"
Cohesion: 0.14
Nodes (14): evaluate_model(), load_training_data(), main(), SMS Named Entity Recognition (NER) Model Training =============================, Convert training data to model format using BIO tagging., Predict entities in texts, Save model and tokenizer, Evaluate model performance (+6 more)

### Community 33 - "Undo Manager"
Cohesion: 0.1
Nodes (20): action, addAction, AppUndoManager, build, clear, DeletionWithUndo, dispose, Function (+12 more)

### Community 34 - "Settings Action Rows"
Cohesion: 0.1
Nodes (20): ActionRow, build, DropdownRow, GestureDetector, InkWell, Padding, SettingsActionButton, SizedBox (+12 more)

### Community 35 - "Entity Extraction Training Data Generator (test/)"
Cohesion: 0.14
Nodes (19): apply_mobile_noise(), augment_dataset(), extract_entities_from_sms(), generate_training_data(), _mask_account_numbers(), _mask_amounts(), _mask_dates(), _mask_reference_ids() (+11 more)

### Community 36 - "Financial Calculations"
Cohesion: 0.11
Nodes (18): calculateAverage, calculateBudgetCompliance, calculateCategoryPercentage, calculateCategoryTotal, calculateGrowthRate, calculateNetWorth, calculatePercentageChange, calculateProgress (+10 more)

### Community 37 - "Form Validation & Navigation Guards"
Cohesion: 0.12
Nodes (16): AlertDialog, build, FormStateTracker, Function, hasUnsavedChanges, markChanged, markSaved, NavigationGuard (+8 more)

### Community 38 - "Memoization Cache"
Cohesion: 0.12
Nodes (15): AsyncMemoizer, call, clear, clearAllMemos, clearMemo, containsKey, Function, ListMemoizer (+7 more)

### Community 39 - "Refactored Widget Examples"
Cohesion: 0.12
Nodes (15): build, Container, Divider, ExampleRefactoredWidget, _InfoRow, NewWayExample, OldWayExample, Padding (+7 more)

### Community 40 - "ML Negative Sample Generator (tools/)"
Cohesion: 0.23
Nodes (8): gen_app_notification(), gen_delivery(), gen_login_security(), gen_misc(), gen_receipt(), Generate realistic non-financial SMS negatives across multiple categories for re, short_link(), tracking_code()

### Community 41 - "Transfer Label Annotator (tools/)"
Cohesion: 0.23
Nodes (11): is_non_transaction(), is_transfer(), main(), process_file(), Add transfer labels (label=2) to existing training data.  This script identifi, Process a training file and relabel records., Process all training files., Check if SMS text matches transfer patterns. (+3 more)

### Community 42 - "Sanitization Rules"
Cohesion: 0.18
Nodes (10): AllowedCharactersRule, DisallowedPatternRule, isValid, MaxLengthRule, MinLengthRule, RuleSets, RuleValidator, SanitizationRule (+2 more)

### Community 43 - "SMS Data Masking"
Cohesion: 0.18
Nodes (10): getMaskingSummary, _maskAccountNumbers, _maskAmounts, _maskDates, MaskingSummary, _maskNumber, _maskReferenceIds, maskSms (+2 more)

### Community 44 - "Pull-to-Refresh"
Cohesion: 0.18
Nodes (10): build, CustomPullToRefresh, _CustomPullToRefreshState, CustomRefreshIndicator, Function, onRefresh, PullToRefreshWrapper, RefreshIndicator (+2 more)

### Community 45 - "SMS Pattern Analyzer (test/)"
Cohesion: 0.25
Nodes (10): analyze_sms_dataset(), classify_message_type(), create_message_template(), extract_sender_pattern(), load_sms_data(), Load SMS training data JSON., Classify SMS message into categories., Group senders into banks/services. (+2 more)

### Community 46 - "Continuous Learning Setup (test/)"
Cohesion: 0.29
Nodes (9): create_correction_table_migration(), create_dart_correction_service(), create_merge_corrections_script(), create_workflow_doc(), main(), Generate Dart service to record user corrections, Generate SQL migration to add user corrections table, Script to merge user corrections with training data (+1 more)

### Community 47 - "Training Data Preparer (test/)"
Cohesion: 0.28
Nodes (4): generate_synthetic(), label(), main(), prepare_training_data.py  Reads  : test/SMS Training Data Current.csv  (real u

### Community 48 - "SMS Signature & Fingerprint"
Cohesion: 0.29
Nodes (6): _detectPatternType, _extractBusinessFingerprint, _mlLabelToPattern, _normalizeSender, similarityTo, SmsSignature

### Community 49 - "Logger Interface"
Cohesion: 0.33
Nodes (5): db, error, ILoggerService, info, userAction

### Community 50 - "TFLite Model Converter (test/)"
Cohesion: 0.33
Nodes (5): convert_to_tflite(), create_dart_example(), Convert trained SMS NER model to TensorFlow Lite for mobile deployment., Generate example Dart code for using the TFLite model., Convert Keras model to TensorFlow Lite format for Flutter deployment.

### Community 51 - "Privacy Guard"
Cohesion: 0.4
Nodes (4): isFinancialNotSensitive, isSensitive, PrivacyGuard, validateStorageSafe

### Community 52 - "Architecture Layer Docs"
Cohesion: 0.4
Nodes (5): Business Logic Layer (Services), Data Layer (Repositories & DB), Presentation Layer (ViewModels), Provider + ChangeNotifier State, UI Layer (Screens & Widgets)

### Community 53 - "Auth Interface"
Cohesion: 0.67
Nodes (2): autoBackupIfDue, IAuthService

### Community 54 - "TFLite Model Tester (test/)"
Cohesion: 0.67
Nodes (2): Test the saved TFLite model, test_saved_model()

### Community 55 - "SMS Classifier Trainer (test/)"
Cohesion: 0.67
Nodes (1): train_sms_classifier.py  Trains a 6-way SMS classifier and exports:   assets/

## Knowledge Gaps
- **2240 isolated node(s):** `PocketFlowApp`, `_PocketFlowAppState`, `_RootNav`, `_RootNavState`, `_KeepAlivePage` (+2235 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Auth Interface`** (3 nodes): `autoBackupIfDue`, `IAuthService`, `i_auth_service.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `TFLite Model Tester (test/)`** (3 nodes): `Test the saved TFLite model`, `test_saved_model()`, `test_tflite_model.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `SMS Classifier Trainer (test/)`** (3 nodes): `clean()`, `train_sms_classifier.py  Trains a 6-way SMS classifier and exports:   assets/`, `train_sms_classifier.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Chat & UI Components` to `SMS Parsing & State Persistence`, `App State, Repositories & Architecture Docs`, `Haptic Feedback & Settings`, `Transaction UI & Theming`, `App Error & State Management`, `Settings, Backup & AI Tab`, `Transfer Detection (Code + Docs)`, `SMS Import & Navigation`, `Accounts Quick View & SMS Source`, `Budget & Notifications`, `App Constants & Feature Flags`, `Image Cache & Assets`, `Backup & Folder Picker`, `Intelligence Dashboard`, `Database Optimization`, `Recurring Patterns`, `Intelligence Carousel`, `Currency & Date Formatting`, `Chat Messages`, `Home Header & Notifications`, `Accessibility Helpers`, `Debounce Utilities`, `API Key Setup`, `Animated Blob & Micro-interactions`, `Widget Optimization`, `Undo Manager`, `Settings Action Rows`, `Form Validation & Navigation Guards`, `Refactored Widget Examples`, `Pull-to-Refresh`?**
  _High betweenness centrality (0.476) - this node is a cross-community bridge._
- **Why does `../db/database.dart` connect `App State, Repositories & Architecture Docs` to `SMS Parsing & State Persistence`, `Haptic Feedback & Settings`, `App Error & State Management`, `Settings, Backup & AI Tab`, `SMS Account Resolution (Code + Docs)`, `Transfer Detection (Code + Docs)`, `SMS Import & Navigation`, `Accounts Quick View & SMS Source`, `Backup & Folder Picker`, `Intelligence Dashboard`, `Database Optimization`, `Recurring Patterns`, `Intelligence Carousel`, `Currency & Date Formatting`, `SMS Transaction Result & Account Extraction`?**
  _High betweenness centrality (0.129) - this node is a cross-community bridge._
- **Why does `package:intl/intl.dart` connect `Transaction UI & Theming` to `SMS Parsing & State Persistence`, `App State, Repositories & Architecture Docs`, `Chat & UI Components`, `Haptic Feedback & Settings`, `App Error & State Management`, `Settings, Backup & AI Tab`, `Transfer Detection (Code + Docs)`, `SMS Import & Navigation`, `Accounts Quick View & SMS Source`, `Budget & Notifications`, `Backup & Folder Picker`, `Intelligence Dashboard`, `Recurring Patterns`, `Intelligence Carousel`, `Currency & Date Formatting`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **What connects `PocketFlowApp`, `_PocketFlowAppState`, `_RootNav` to the rest of the system?**
  _2240 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `SMS Parsing & State Persistence` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `App State, Repositories & Architecture Docs` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Chat & UI Components` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._