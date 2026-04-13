# PocketFlow — Development Guidelines

## Code Quality Standards

- Linter: `package:flutter_lints/flutter.yaml` (default Flutter recommended rules)
- Run `flutter analyze` before committing
- No custom lint overrides — all default rules apply

## Naming Conventions

- Classes: `PascalCase` — `AppDatabase`, `ChatParser`, `SavingsGoal`
- Private widget classes within a file: prefixed with `_` — `_SummaryCard`, `_BudgetCard`, `_Bubble`
- Private state fields: `_camelCase` — `_loading`, `_accounts`, `_month`
- DB/service methods: `camelCase` verbs — `insertTransaction`, `getAccounts`, `upsertBudget`
- Constants: `camelCase` for static const — `Account.types`, `ApiServer.port`

## Screen Pattern (all 6 screens follow this exactly)

```dart
class FooScreen extends StatefulWidget {
  const FooScreen({super.key});
  @override
  State<FooScreen> createState() => _FooScreenState();
}

class _FooScreenState extends State<FooScreen> {
  // state fields
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    appRefresh.addListener(_load);   // subscribe to global refresh
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load); // always unsubscribe
    super.dispose();
  }

  Future<void> _load() async {
    final data = await AppDatabase.someMethod();
    if (!mounted) return;            // guard before setState
    setState(() { /* update fields */ _loading = false; });
  }
}
```

Key rules:
- Always check `if (!mounted) return;` before `setState` in async methods
- Always add AND remove `appRefresh` listener in `initState`/`dispose`
- Show `CircularProgressIndicator` while `_loading == true`
- Show empty-state text when list is empty (grey, centered, `textAlign: TextAlign.center`)

## Data Refresh Pattern

```dart
// After any write operation:
notifyDataChanged(); // increments appRefresh ValueNotifier → all screens reload
```

- Import from `services/refresh_notifier.dart`
- Call after every `insert`, `update`, `delete`, `transfer` operation
- All screens listen via `appRefresh.addListener(_load)`

## Database Access Pattern

```dart
// All methods are static on AppDatabase — no instantiation
await AppDatabase.insertTransaction(t);
await AppDatabase.getAccounts();
await AppDatabase.upsertBudget(b);
```

- Never instantiate `AppDatabase` — use static methods only
- DB is lazily initialized via `_db ??= await _init()`
- Always use `toMap()..remove('id')` when inserting (let SQLite auto-assign id)

## Model Pattern

All models follow the same structure:

```dart
class Foo {
  final int? id;          // nullable — null before insert
  final String field;

  Foo({this.id, required this.field});

  Map<String, dynamic> toMap() => {'id': id, 'field': field};

  factory Foo.fromMap(Map<String, dynamic> m) => Foo(
    id: m['id'],
    field: m['field'],
  );
}
```

- `id` is always `int?` (nullable until persisted)
- `toMap()` / `fromMap()` factory — no code generation, no json_serializable
- Computed properties go on the model (e.g. `SavingsGoal.progress`)

## UI Patterns

### Forms (add/edit)
- Use `showModalBottomSheet` with `isScrollControlled: true` for add/edit forms
- Use `MediaQuery.of(ctx).viewInsets.bottom` padding to avoid keyboard overlap
- Use `StatefulBuilder` inside bottom sheet when local state is needed (e.g. dropdowns)
- Use `showDialog` + `AlertDialog` for simple confirm/input dialogs

### Buttons
- Primary action: `FilledButton` or `FilledButton.icon`
- Secondary/cancel: `TextButton`
- Destructive: `FilledButton` with `backgroundColor: Colors.red`
- Delete inside forms: `TextButton.icon` with red icon/label

### Cards
- Wrap content in `Card` → `Padding(padding: EdgeInsets.all(16), child: ...)`
- Use `Card(margin: EdgeInsets.only(bottom: N))` for list items

### Empty states
```dart
const Center(
  child: Text('No items yet.\nTap + to add one.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.grey)),
)
```

### Loading states
```dart
_loading
  ? const Center(child: CircularProgressIndicator())
  : /* actual content */
```

### FAB for adding items
- All list screens use `FloatingActionButton` with `Icons.add`

## Color Conventions

| Meaning | Color |
|---|---|
| Income / positive | `Colors.green` |
| Expense / negative / debt | `Colors.red` |
| Neutral / info | `Colors.blue` |
| Warning / near limit | `Colors.orange` |
| Theme accent | `Colors.indigo` (colorSchemeSeed) |
| Disabled / unset | `Colors.grey` |

## Currency Formatting

```dart
final fmt = NumberFormat.currency(symbol: '\$');
fmt.format(amount); // always use this, never manual string interpolation
```

## API Server Patterns

- All handlers are private static methods on `ApiServer`
- Always return JSON with `_corsHeaders` on every response
- Validate required fields and return `Response(400, ...)` with error message
- Use `req.url.queryParameters` for GET filters
- Use `jsonDecode(await req.readAsString())` for POST bodies

## ChatParser Command Pattern

- `sealed class ParseResult` with `ParseSuccess` / `ParseError` subtypes
- Switch on `cmd` (lowercased first token) for routing
- Validate inputs early, return `ParseError` with usage hint
- Call `notifyDataChanged()` after every successful write
- Use `firstOrNull` for safe list lookups

## What NOT to Do

- Don't use state management packages (no Provider, Riverpod, Bloc) — use `ValueNotifier` + `StatefulWidget`
- Don't use `sqflite` for web/Windows builds — it's not supported
- Don't skip `if (!mounted) return` after any `await` before `setState`
- Don't forget to remove `appRefresh` listener in `dispose`
- Don't use `DateTime.now()` for transaction dates when the transaction has its own date field
