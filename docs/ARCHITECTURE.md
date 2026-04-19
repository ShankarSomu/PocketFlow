# ARCHITECTURE — PocketFlow (compact)

This file summarizes the overall application structure, layers, data flow, and key design decisions to help a new developer get productive quickly.

1) High-level layers
- Presentation (UI): `lib/screens/`, `lib/widgets/` — screens, page components, and reusable widgets
- Presentation controllers: `lib/viewmodels/` — ViewModels that manage UI state and expose actions to the UI
- Services / business logic: `lib/services/` — SMS pipeline, classification, export, notification, scheduling, normalization, and other engines
- Repositories / persistence adapter: `lib/repositories/` and `lib/repositories/impl/` — interfaces and DB-backed implementations
- Database: `lib/db/database.dart` — DB access and migrations
- Models: `lib/models/` — domain entities (Transaction, Account, Category, RecurringPattern, etc.)

2) Typical data flow
- UI event (user taps / filter changes) → ViewModel handles event (`lib/viewmodels/*`).
- ViewModel calls Services for business actions (for example, `sms_pipeline_executor.dart`, `merchant_normalization_service.dart`).
- Services interact with Repositories (interfaces in `lib/repositories/`) which persist or query data using the database adapter in `lib/db/database.dart`.
- Repositories return models; ViewModel updates `AppState` (`lib/core/app_state.dart`) or local state; UI rebuilds.

3) State handling approach
- Centralized app-level state container: `lib/core/app_state.dart` holds global pieces of state.
- ViewModels maintain screen-local state and coordinate with `AppState` for global concerns.
- Dependency wiring and service registration are handled from startup in `lib/core/app_dependencies.dart` (read this file to see how services are resolved for ViewModels and widgets).

4) Key design decisions observed
- Separation of concerns: UI, ViewModels, Services, Repositories are clearly separated allowing easier testing and replacement of implementations.
- Interface-first repositories and service interfaces (see `lib/services/interfaces/`) — aids test doubles and platform-specific implementations.
- Local-first architecture: persistent local DB (SQLite), seed data (`lib/services/seed_data.dart`) and offline-capable features.
- Pluggable intelligence stack: SMS classification, entity extraction, and normalization are implemented as services that can be replaced or extended.
- Export & backups are implemented as services (CSV/JSON/PDF/Excel) that depend on repository data rather than UI logic.

5) Cross-cutting concerns
- Logging: centralized logging via `lib/services/app_logger.dart`.
- Performance: utilities in `lib/core/` and `lib/utils/performance_utils.dart` (image optimizer, widget optimizer, memoization, debounce).
- Accessibility & UX: `lib/core/accessibility.dart` and theme files under `lib/theme/` ensure consistent presentation.

6) Where to look for architecture-level changes
- App entry & DI: `lib/main.dart` and `lib/core/app_dependencies.dart`.
- App state model: `lib/core/app_state.dart`.
- Database and migrations: `lib/db/database.dart` and `lib/services/database_migration.dart`.
- SMS intelligence core: `lib/services/sms_pipeline_executor.dart`, `lib/services/sms_classification_service.dart`, `lib/services/entity_extraction_service.dart`.

7) Quick orientation checklist
1. Open `lib/main.dart` to see startup sequence.
2. Inspect `lib/core/app_dependencies.dart` to find how services are registered.
3. Pick a feature screen (e.g., `lib/screens/transactions/transactions_screen.dart`) and trace to its viewmodel and repository.

---
This file is intended to be concise — use `docs/FEATURES.md` and `docs/SERVICES.md` for feature- and service-level details.

