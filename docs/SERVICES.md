# SERVICES — Service catalog and responsibilities

This document lists the primary services in `lib/services/`, what they do, and their observable side effects (DB, file system, notifications, network, etc.). For interfaces see `lib/services/interfaces/`.

1) SMS & Intelligence
- `sms_service.dart` — platform-facing SMS access and basic helpers (side effects: reads SMS via platform plugins).
- `sms_pipeline_executor.dart` — orchestrates SMS processing pipeline (classification, extraction, saving). Side effects: writes to repositories/DB, triggers notifications or pending actions.
- `sms_classification_service.dart` — classifies SMS as transactions, promos, etc. Side effects: returns classification results used by pipeline.
- `entity_extraction_service.dart` — extracts amounts, dates, merchants from SMS. Side effects: produces structured entities saved by repositories.

2) Transfer, Account & Matching
- `transfer_detection_engine.dart` — identifies possible transfers between accounts. Side effects: creates `TransferPair` suggestions in DB or pending actions.
- `account_matching_service.dart` & `account_resolution_engine.dart` — match SMS-derived account candidates to existing accounts. Side effects: updates account records and matching metadata.

3) Recurring detection & scheduling
- `recurring_pattern_engine.dart` — detects recurring transaction patterns from history.
- `recurring_scheduler.dart` (and `i_recurring_scheduler.dart`) — schedule background checks; side effects: may schedule platform timers or create pending actions.

4) Exports & IO
- `csv_export_service.dart`, `json_export_service.dart`, `excel_export_service.dart`, `pdf_export_service.dart` — export repository data to files. Side effects: write files to local storage or share via platform APIs.
- `seed_data.dart` — provides initial demo/seed data on fresh installs (DB writes).

5) Notifications & deep linking
- `notification_service.dart`, `notification_manager.dart` — manage local notifications (side effects: schedule or post notifications via platform channels).
- `deep_link_service.dart` — handle inbound deep links and app navigation.

6) Infrastructure & support
- `api_server.dart` — local API surface for debug or local integrations (side effects: opens a local server socket).
- `app_logger.dart` (and `i_logger_service.dart`) — centralized logging.
- `privacy_guard.dart` — enforces privacy-related checks and policies.
- `connectivity_service.dart` — network connectivity monitoring (no DB side-effect, but informs behavior).
- `auth_service.dart` & `i_auth_service.dart` — authentication support (may interact with secure storage).

7) AI, chat & NLP
- `chat_parser.dart` — parse chat-like input into intents/actions.
- `i_ai_service.dart` — AI service interface used by chat and intelligence features (side effects depend on implementation — could call network or local models).

How to use and extend services
- Most services are resolved through `lib/core/app_dependencies.dart`. To add or replace a service, register it in the dependency wiring and update any interfaces in `lib/services/interfaces/`.
- Services that persist data should accept repository interfaces (not concrete DB classes) so implementations remain testable.

---
For method-level details search the service file for public methods (constructors and exported methods). The service names above map directly to files under `lib/services/`.

