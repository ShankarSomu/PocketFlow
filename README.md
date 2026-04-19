# PocketFlow — Personal finance & SMS intelligence (Overview)

PocketFlow is a cross-platform personal finance application built with Flutter. The app focuses on extracting transaction data from SMS messages, classifying and normalizing merchant information, and presenting budgets, accounts, and insights in a responsive UI.

## App purpose
- Automatically detect and classify transactions from SMS messages
- Provide account and budget views, recurring detection, transfer identification, and intelligence-driven insights
- Allow users to export and backup their financial data locally

## Key features
- SMS parsing & intelligence (classification, entity extraction, scoring)
- Transaction list, filtering, and categorization
- Account matching and transfer detection
- Budgeting, savings goals, and recurring transaction detection
- Export (CSV/JSON/XLS/PDF) and backup/restore
- In-app chat/parser for query-like interactions

## Target users
- End users who want local-first, privacy-conscious finance tracking from message data
- Developers and maintainers working on SMS intelligence, Flutter UI, and local persistence

## Tech stack
- Flutter (Dart) — UI and cross-platform runtime
- SQLite for local persistence (accessed via `lib/db/database.dart` and repository implementations in `lib/repositories/impl/`)
- Native integrations (SMS, notifications, platform plugins) under `android/`, `ios/`, etc.
- Services & engines implemented in Dart under `lib/services/` (SMS pipeline, entity extraction, export, scheduling)

## High-level architecture summary
- UI layer: `lib/screens/`, `lib/widgets/` — presentation
- Presentation controllers: `lib/viewmodels/` — screen state and interaction logic
- Services: `lib/services/` — business logic, SMS pipeline, AI/NLP helpers
- Data layer: `lib/repositories/` + `lib/db/database.dart` + `lib/models/`

## Setup & run (developer)
Prerequisites: Flutter SDK and any platform toolchains for targets you need (Android SDK, Xcode for iOS).

Common commands (PowerShell):
```powershell
# fetch packages
flutter pub get

# run on connected device or emulator
flutter run

# run tests
flutter test
```

## Folder overview
- `lib/` — main app code: core, services, models, viewmodels, screens, widgets, theme
- `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/` — platform-specific project files
- `docs/` — design and contributor documentation (start with `docs/ARCHITECTURE.md` and `docs/DEVELOPER_GUIDE.md`)
- `test/` — unit and widget tests

## Where to look first in code
1. `lib/main.dart` — application entrypoint
2. `lib/core/app_dependencies.dart` — dependency wiring and service registration
3. `lib/services/sms_pipeline_executor.dart` — SMS processing orchestration
4. `lib/db/database.dart` and `lib/repositories/impl/` — persistence

---
For more detailed contributor docs, see the files in `docs/`.

**Last updated:** April 18, 2026
