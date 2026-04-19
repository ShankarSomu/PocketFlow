# FEATURES — Major feature breakdown

This file lists the major features of PocketFlow, describes what they do, and points to the primary code locations to inspect.

1) Transactions
- What: Display, filter, and manage transactions detected from SMS and manual entries; supports categorization and transfer detection.
- Key files: `lib/screens/transactions/transactions_screen.dart`, `lib/viewmodels/transactions_viewmodel.dart`, `lib/repositories/transaction_repository.dart`, `lib/repositories/impl/transaction_repository_impl.dart`, `lib/models/transaction.dart`.
- Data flow: SMS pipeline or manual input → `sms_pipeline_executor` / UI action → `transactions_viewmodel` → `transaction_repository` → `lib/db/database.dart`.

2) Accounts
- What: Show account list and quick reconciliation insights; support account matching and candidates.
- Key files: `lib/screens/accounts/accounts_screen.dart`, `lib/viewmodels/accounts_viewmodel.dart`, `lib/models/account.dart`, `lib/services/account_matching_service.dart`, `lib/services/account_resolution_engine.dart`.

3) Profile & Settings
- What: User profile, backups, preferences, API keys (for AI features), and appearance settings.
- Key files: `lib/screens/profile/`, `lib/screens/settings/settings_screen.dart`, `lib/services/backup/` (backup-related services are under `lib/services/`), `lib/services/auth_service.dart`.

4) SMS parsing & intelligence
- What: Parse incoming SMS, classify messages, extract entities (amount, merchant, date), detect recurring transactions and transfers, score predictions.
- Key files: `lib/services/sms_pipeline_executor.dart`, `lib/services/sms_classification_service.dart`, `lib/services/entity_extraction_service.dart`, `lib/services/recurring_pattern_engine.dart`, `lib/services/transfer_detection_engine.dart`, `lib/services/confidence_scoring.dart`.
- Data flow: Raw SMS (platform plugin) → `sms_service.dart` → pipeline executor → classifiers & extractors → repositories → viewmodels.

5) Export & Backup
- What: Export data to CSV, JSON, Excel, PDF; backup and restore user data.
- Key files: `lib/services/csv_export_service.dart`, `lib/services/json_export_service.dart`, `lib/services/excel_export_service.dart`, `lib/services/pdf_export_service.dart`, `lib/services/seed_data.dart`.

6) Intelligence & Insights
- What: Merchant insights, recurring pattern insights, transfer pairs and dashboard of intelligence metrics.
- Key files: `lib/screens/intelligence/`, `lib/screens/intelligence/intelligence_dashboard_screen.dart`, `lib/services/merchant_normalization_service.dart`, `lib/services/recurring_pattern_engine.dart`.

7) Chat & AI helper
- What: Chat interface and parser for conversational queries over SMS/transactions (may integrate with local AI / external API via `i_ai_service.dart`).
- Key files: `lib/screens/chat/chat_screen.dart`, `lib/screens/chat/components/`, `lib/services/chat_parser.dart`, `lib/services/interfaces/i_ai_service.dart`.

8) Notifications & Background Tasks
- What: Notify users on relevant events and run scheduled tasks for recurring detection or exports.
- Key files: `lib/services/notification_service.dart`, `lib/services/notification_manager.dart`, `lib/services/recurring_scheduler.dart`.

Each feature has corresponding tests under `test/` where available. To trace behavior, pick a feature screen and follow UI → ViewModel → Services → Repositories → DB.

