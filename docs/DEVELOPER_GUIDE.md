
# DEVELOPER_GUIDE — Best practices and onboarding checklist

This guide builds on existing conventions and adds recommended best practices for commits, branching, pull requests, testing, formatting, and CI so new contributors follow a consistent workflow.

Checklist (what I'll cover)
- Local setup & quick commands
- Branching, commits & PR checklist
- Linting, formatting, and static analysis
- Testing & CI recommendations
- Adding screens, services, repositories (practical steps)
- Database migration & data safety
- Secrets, API keys & privacy
- Documentation & release checklist
- Practical workflows (transactions, UI→DB, debugging)

1) Local setup & quick commands
- Install Flutter (stable) and platform toolchains required for targets.
- Fetch packages and generate code if needed:
```powershell
flutter pub get
# optional: codegen (if project uses build_runner)
flutter pub run build_runner build --delete-conflicting-outputs
```
- Run the app:
```powershell
flutter run
```

2) Branching, commits & PRs (recommended)
- Branch strategy: use short-lived branches named `feature/<area>-<short-desc>` or `fix/<issue-id>-<short-desc>`.
- Commits: keep atomic and use present-tense messages. Recommended format:
  - `feat(transactions): add transaction import from SMS`
  - `fix(export): handle null category during export`
- PR checklist (required before merge):
  - Link issue or describe motivation
  - Passes `flutter analyze` and `flutter test`
  - Linted and formatted (see next section)
  - Includes unit tests for new logic and widget tests for UI changes where applicable
  - Updated docs (`docs/`), and `docs/audit/INVENTORY.md` if changing docs or public behavior

3) Linting, formatting & static analysis
- Format code: `dart format .` (or `flutter format .`)
- Static analysis: `flutter analyze` — fix warnings where reasonable
- Prefer to follow existing project analysis rules (`analysis_options.yaml`) — add exceptions sparingly and document them in the PR

4) Testing & CI
- Unit tests: put under `test/`; mock repositories/services using interfaces in `lib/services/interfaces/`.
- Widget tests: test public screen behavior and critical interaction flows.
- Run tests locally: `flutter test` (and `flutter test --coverage` if measuring coverage).
- CI: ensure PRs run `flutter analyze` and `flutter test` in CI pipelines.

5) How to add a new screen / feature (practical)
1. Create UI in `lib/screens/<feature>/` and small reusable widgets in `lib/widgets/`.
2. Add a ViewModel in `lib/viewmodels/` that contains state + public actions. Keep ViewModels thin — orchestration only.
3. Put business logic in a Service under `lib/services/` and expose an interface if the service has multiple implementations.
4. Add repository interface in `lib/repositories/` and implement it in `lib/repositories/impl/` using `lib/db/database.dart`.
5. Register the dependencies in `lib/core/app_dependencies.dart` (follow existing registration patterns).
6. Add unit tests for the Service and repository; add widget tests for the screen.
7. Document the feature in `docs/` and add an entry to `docs/audit/INVENTORY.md` describing the change and priority.

6) How to add a new transaction feature (step-by-step)
This is a targeted workflow for adding features that ingest or manipulate transactions (SMS or manual):

1. Design the model & UX
- Add or update a model in `lib/models/transaction.dart` if fields change (amount, merchant, metadata).
- Sketch the screen in `lib/screens/transactions/` and the ViewModel `lib/viewmodels/transactions_viewmodel.dart` responsibilities.

2. Service & repository
- Add or update repository interface `lib/repositories/transaction_repository.dart` and the implementation in `lib/repositories/impl/transaction_repository_impl.dart` for persistence and queries.
- Add a Service under `lib/services/` (for example `transaction_import_service.dart`) to encapsulate parsing/validation and to call the repository.

3. Integrate with SMS pipeline (if relevant)
- If the feature imports from SMS, update `lib/services/sms_pipeline_executor.dart` to call the new service or extend the pipeline stages (classification → extraction → normalization → saving).
- Keep pipeline steps idempotent — avoid duplicate inserts by checking for dedup keys (message id, timestamp + amount + account).

4. UI wiring & tests
- In the ViewModel, expose methods like `importFromSms(SmsMessage msg)` and `createTransaction(Transaction t)` that call the service.
- Add unit tests for the service and repository; add widget tests for the screen behavior and edge cases (empty lists, large amounts, duplicate suggestions).

Example commands (quick)
```powershell
# run a single unit test file
flutter test test/services/transaction_import_service_test.dart

# run only widget tests in a folder
flutter test test/widgets
```

7) How to add a new screen (expanded)
Practical checklist for beginners:
- Create `lib/screens/<feature>/<feature>_screen.dart` and a `<feature>_components.dart` for smaller widgets.
- Create `lib/viewmodels/<feature>_viewmodel.dart` and expose streams/ChangeNotifiers that the screen listens to.
- Use existing widgets under `lib/widgets/` to keep UI consistent (cards, headers, lists).
- Register the ViewModel in `lib/core/app_dependencies.dart` and decide whether it is provided per-route or globally.
- Add route entry where your app composes routes (search for route map in `lib/` to locate it).

8) How to connect UI to database (step-by-step)
This describes the simplest, recommended path that follows project patterns:

1. Repository first
- Implement repository APIs in `lib/repositories/` and `lib/repositories/impl/` that expose the queries you need (e.g., `Stream<List<Transaction>> watchTransactions(TimeRange range)`)

2. ViewModel subscribes
- In your ViewModel (`lib/viewmodels/`), inject the repository and create a stream or ChangeNotifier that listens to repository watch methods and maps data to UI models.

3. UI listens & renders
- In the Screen widget, use a `StreamBuilder` or a provider-based consumer (depending on app patterns) to listen to the ViewModel and render the list.

Example (pseudo-code viewmodel snippet)
```dart
class TransactionsViewModel {
  final TransactionRepository _repo;
  Stream<List<Transaction>> transactions;

  TransactionsViewModel(this._repo) {
    transactions = _repo.watchTransactions(defaultRange);
  }
}
```

Example (pseudo-code UI snippet)
```dart
StreamBuilder<List<Transaction>>(
  stream: viewModel.transactions,
  builder: (ctx, snapshot) {
    if (!snapshot.hasData) return LoadingSkeleton();
    return ListView(... build using snapshot.data ...);
  }
)
```

9) How to debug common issues (practical tips)
- App won't start / build fails:
  - Run `flutter clean` then `flutter pub get` and `flutter run`.
  - Check platform SDKs (Android SDK path in `local.properties`).
- Missing DI registration / runtime error that a service is null:
  - Search `lib/core/app_dependencies.dart` and ensure the service/repository is registered and the constructor signature matches.
- Database errors (migrations or missing tables):
  - Inspect `lib/services/database_migration.dart` and confirm migration steps run. Remove old DB in emulator/sim to test fresh migration.
  - Use logs and `lib/services/app_logger.dart` for diagnostic output.
- UI not updating after DB change:
  - Ensure ViewModel subscribes to repository watch streams (not single-shot queries) and calls notify/listener updates.
  - Check for streams being canceled or providers not wired in the widget tree.
- Duplicate transactions from SMS imports:
  - Implement deduplication checks in pipeline/service (check message id or composite dedup key) and add tests.

10) Example commands & handy snippets
```powershell
# format and analyze
> dart format .
> flutter analyze

# run all tests
> flutter test

# run a single test file
> flutter test test/viewmodels/transactions_viewmodel_test.dart

# clear and rerun if build artifacts are stale
> flutter clean; flutter pub get; flutter run
```

11) Documentation & release checklist (reminder)
- Update `docs/` and `docs/audit/INVENTORY.md` for user-visible changes.
- Run full test suite and validate DB migrations on a copy of production data where possible.

---
This expanded Developer Guide is intended to be beginner-friendly while preserving professional standards. If you want, I will add a small PR template and `CONTRIBUTING.md` to the repo next.


