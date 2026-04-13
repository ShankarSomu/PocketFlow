# PocketFlow — Technology Stack

## Language & Runtime
- **Dart** `>=3.0.0 <4.0.0`
- **Flutter** stable channel, `3.41.6`

## Key Dependencies (`pubspec.yaml`)

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.0 | SQLite local database (Android/iOS only) |
| `path` | ^1.9.0 | File path utilities for DB location |
| `intl` | ^0.19.0 | Currency and date formatting |
| `fl_chart` | ^0.68.0 | Charts and data visualizations |
| `shelf` | ^1.4.0 | Embedded HTTP server |
| `shelf_router` | ^1.1.0 | Route handling for the local API |
| `network_info_plus` | ^5.0.0 | Get device IP address for QR sharing |
| `qr_flutter` | ^4.1.0 | QR code widget for Connect screen |
| `wakelock_plus` | ^1.2.0 | Keep screen on while API server is running |

## Database Schema (SQLite, version 2)

```sql
accounts(id, name, type, balance, last4)
transactions(id, type, amount, category, note, date, account_id)
budgets(id, category, limit, month, year)  -- UNIQUE(category, month, year)
savings_goals(id, name, target, saved)     -- name UNIQUE
```

## Local REST API Endpoints (port 8080)

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Server status |
| GET | `/summary` | Monthly income/expenses/net + savings goals |
| GET | `/transactions` | List transactions (filters: type, from, to, keyword) |
| POST | `/transactions` | Add transaction |
| GET | `/budgets` | Budgets with spent/remaining for month |
| POST | `/budgets` | Upsert budget |
| GET | `/savings` | List savings goals with progress % |
| POST | `/savings` | Create savings goal |
| POST | `/savings/<name>/contribute` | Add amount to a goal |

## Build & Development Commands

```bash
# Run on connected device / emulator
flutter run

# Run on specific device
flutter run -d chrome
flutter run -d android

# Build release APK
flutter build apk

# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Platform Notes
- `sqflite` does **not** support Web or Windows desktop — use Android/iOS for full functionality
- The embedded HTTP server (`shelf`) works on Android and iOS but requires network permissions
- Android: targets SDK 36, minimum SDK defined in `android/app/build.gradle.kts`
