# PocketFlow — Project Structure

## Directory Layout

```
PocketFlow/
├── lib/
│   ├── main.dart              # App entry point, MaterialApp, bottom nav shell
│   ├── db/
│   │   └── database.dart      # AppDatabase — all SQLite CRUD, static methods
│   ├── models/
│   │   ├── account.dart       # Account model (checking/savings/credit/cash)
│   │   ├── transaction.dart   # Transaction model (income/expense)
│   │   ├── budget.dart        # Budget model (category + monthly limit)
│   │   └── savings_goal.dart  # SavingsGoal model with progress computed property
│   ├── screens/
│   │   ├── home_screen.dart       # Monthly summary + spending by category
│   │   ├── accounts_screen.dart   # Account list, net worth, transfer dialog
│   │   ├── budget_screen.dart     # Budget list with spent vs limit
│   │   ├── savings_screen.dart    # Savings goals with progress bars
│   │   ├── chat_screen.dart       # Command input + history log
│   │   └── connect_screen.dart    # Local API server toggle + QR code
│   └── services/
│       ├── api_server.dart        # Shelf HTTP server, REST endpoints
│       ├── chat_parser.dart       # Parses text commands → DB writes
│       └── refresh_notifier.dart  # Global ValueNotifier for cross-screen refresh
├── android/                   # Android platform project
├── ios/                       # iOS platform project
├── web/                       # Web platform assets
├── windows/                   # Windows platform project
├── macos/                     # macOS platform project
├── linux/                     # Linux platform project
├── test/
│   └── widget_test.dart
├── pubspec.yaml
└── CONNECT.md                 # Docs for the local API / Connect feature
```

## Core Components & Relationships

```
main.dart (_RootNav)
  └── IndexedStack of 6 screens
        ├── HomeScreen          ──reads──► AppDatabase
        ├── ChatScreen          ──calls──► ChatParser ──writes──► AppDatabase
        ├── AccountsScreen      ──reads/writes──► AppDatabase
        ├── BudgetScreen        ──reads/writes──► AppDatabase
        ├── SavingsScreen       ──reads/writes──► AppDatabase
        └── ConnectScreen       ──starts/stops──► ApiServer ──reads──► AppDatabase

refresh_notifier (appRefresh: ValueNotifier<int>)
  └── All screens listen to this; ChatParser + screens call notifyDataChanged()
      to trigger cross-screen UI refresh after any write
```

## Architectural Patterns

- **Static singleton DB** — `AppDatabase` uses a static `_db` field with lazy init (`??=`); all methods are static, no instantiation needed
- **No state management library** — uses Flutter's built-in `StatefulWidget` + `ValueNotifier` for reactivity
- **IndexedStack navigation** — all 6 screens are kept alive simultaneously; switching tabs does not rebuild screens
- **Sealed class results** — `ChatParser` returns `ParseResult` (sealed) with `ParseSuccess` / `ParseError` subtypes
- **Model layer** — plain Dart classes with `toMap()` / `fromMap()` factory constructors for SQLite serialization; no code generation
- **Local REST API** — `ApiServer` runs an embedded `shelf` HTTP server on port 8080; mirrors all DB operations as JSON endpoints
