# Architecture Overview

PocketFlow follows a clean, layered architecture with clear separation of concerns, making it maintainable and testable.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│          (Screens, Widgets, Theme)                          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                   Presentation Layer                         │
│              (ViewModels, State Management)                  │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                    Business Logic Layer                      │
│    (Services: SMS Pipeline, Entity Extraction, ML, etc.)     │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                      Data Layer                              │
│            (Repositories, Database, Models)                  │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/                        # Core app infrastructure
│   ├── app_dependencies.dart    # Dependency injection
│   ├── constants.dart           # App-wide constants
│   └── config.dart              # Configuration
├── models/                      # Data models
│   ├── account.dart
│   ├── transaction.dart
│   ├── budget.dart
│   └── ...
├── db/                          # Database layer
│   └── database.dart            # SQLite database & DAOs
├── repositories/                # Data access layer
│   ├── account_repository.dart
│   ├── transaction_repository.dart
│   └── impl/                    # Repository implementations
├── services/                    # Business logic
│   ├── sms_pipeline_executor.dart
│   ├── sms_classifier.dart
│   ├── entity_extractor.dart
│   ├── account_resolver.dart
│   ├── transfer_detector.dart
│   ├── recurring_detector.dart
│   ├── export_service.dart
│   └── ...
├── viewmodels/                  # Presentation logic
│   ├── transaction_viewmodel.dart
│   ├── account_viewmodel.dart
│   ├── budget_viewmodel.dart
│   └── ...
├── screens/                     # UI screens
│   ├── home_screen.dart
│   ├── transactions_screen.dart
│   ├── accounts_screen.dart
│   └── ...
├── widgets/                     # Reusable UI components
│   ├── transaction_tile.dart
│   ├── account_card.dart
│   └── ...
└── theme/                       # App theming
    ├── app_theme.dart
    └── colors.dart
```

## Layer Responsibilities

### 1. UI Layer (Screens & Widgets)

**Purpose**: Present data to users and capture user input

**Location**: `lib/screens/`, `lib/widgets/`

**Responsibilities**:
- Display data from ViewModels
- Handle user interactions
- Navigate between screens
- Apply theming

**Rules**:
- ✅ Read data from ViewModels
- ✅ Call ViewModel methods
- ❌ No business logic
- ❌ No direct database access
- ❌ No direct service calls

**Example**:
```dart
class TransactionsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TransactionViewModel>();
    
    return ListView.builder(
      itemCount: viewModel.transactions.length,
      itemBuilder: (context, index) {
        return TransactionTile(viewModel.transactions[index]);
      },
    );
  }
}
```

### 2. Presentation Layer (ViewModels)

**Purpose**: Manage UI state and coordinate between UI and business logic

**Location**: `lib/viewmodels/`

**Responsibilities**:
- Hold UI state
- Call services to perform operations
- Transform data for UI display
- Handle loading/error states

**Rules**:
- ✅ Use services for business logic
- ✅ Update UI state via ChangeNotifier/Provider
- ❌ No direct database access
- ❌ No complex business logic

**Example**:
```dart
class TransactionViewModel extends ChangeNotifier {
  final TransactionRepository _repository;
  final SMSPipelineExecutor _smsPipeline;
  
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();
    
    _transactions = await _repository.getAllTransactions();
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> syncSMS() async {
    await _smsPipeline.processSMSMessages();
    await loadTransactions();
  }
}
```

### 3. Business Logic Layer (Services)

**Purpose**: Implement core business logic and algorithms

**Location**: `lib/services/`

**Key Services**:
- **SMSPipelineExecutor**: Orchestrates SMS processing
- **SMSClassifier**: Classifies SMS message types
- **EntityExtractor**: Extracts structured data from SMS
- **AccountResolver**: Matches transactions to accounts
- **TransferDetector**: Identifies transfer transactions
- **RecurringDetector**: Finds recurring patterns
- **ExportService**: Handles data exports

**Rules**:
- ✅ Pure business logic
- ✅ Use repositories for data access
- ✅ Return results, don't update UI
- ❌ No UI state management
- ❌ No direct database access

**Example**:
```dart
class SMSClassifier {
  ClassificationResult classify(String smsText) {
    // Business logic here
    if (containsOTP(smsText)) {
      return ClassificationResult.reject();
    }
    
    if (containsTransactionKeywords(smsText)) {
      return ClassificationResult.transaction(confidence: 0.9);
    }
    
    return ClassificationResult.unknown();
  }
}
```

### 4. Data Layer (Repositories & Database)

**Purpose**: Abstract data access and persistence

**Location**: `lib/repositories/`, `lib/db/`, `lib/models/`

**Responsibilities**:
- Database operations (CRUD)
- Data caching
- Query building
- Data model definitions

**Rules**:
- ✅ Abstract data source (DB, API, etc.)
- ✅ Return models
- ❌ No business logic
- ❌ No UI concerns

**Example**:
```dart
abstract class TransactionRepository {
  Future<List<Transaction>> getAllTransactions();
  Future<Transaction?> getTransactionById(int id);
  Future<int> insertTransaction(Transaction transaction);
  Future<void> updateTransaction(Transaction transaction);
  Future<void> deleteTransaction(int id);
}

class TransactionRepositoryImpl implements TransactionRepository {
  final Database database;
  
  @override
  Future<List<Transaction>> getAllTransactions() async {
    final maps = await database.query('transactions');
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }
  // ... other implementations
}
```

## Dependency Injection

**Location**: `lib/core/app_dependencies.dart`

All dependencies are registered at app startup:

```dart
class AppDependencies {
  static Future<void> setup() async {
    // Database
    final database = await openDatabase('pocketflow.db');
    
    // Repositories
    final accountRepo = AccountRepositoryImpl(database);
    final transactionRepo = TransactionRepositoryImpl(database);
    
    // Services
    final classifier = SMSClassifier();
    final extractor = EntityExtractor();
    final resolver = AccountResolver(accountRepo);
    final smsPipeline = SMSPipelineExecutor(
      classifier: classifier,
      extractor: extractor,
      resolver: resolver,
      repository: transactionRepo,
    );
    
    // ViewModels
    final transactionVM = TransactionViewModel(transactionRepo, smsPipeline);
    final accountVM = AccountViewModel(accountRepo);
    
    // Register with service locator or provider
  }
}
```

## Data Flow Example

User syncs SMS messages:

```
1. UI: User taps "Sync SMS" button
   └→ TransactionsScreen.onSyncPressed()

2. Presentation: ViewModel handles action
   └→ TransactionViewModel.syncSMS()

3. Business Logic: Process SMS messages
   └→ SMSPipelineExecutor.processSMSMessages()
      ├→ Read SMS from device
      ├→ SMSClassifier.classify()
      ├→ EntityExtractor.extract()
      ├→ AccountResolver.resolve()
      └→ TransferDetector.detect()

4. Data Layer: Save transactions
   └→ TransactionRepository.insertTransaction()
      └→ Database.insert()

5. Presentation: Reload data
   └→ TransactionViewModel.loadTransactions()
      └→ ViewM.notifyListeners()

6. UI: Display updated list
   └→ TransactionsScreen rebuilds with new data
```

## Key Design Patterns

### 1. Repository Pattern
Abstract data access behind interfaces

### 2. Service Layer Pattern
Encapsulate business logic in services

### 3. MVVM (Model-View-ViewModel)
Separate UI from business logic

### 4. Observer Pattern
ViewModels notify UI of state changes (ChangeNotifier)

### 5. Dependency Injection
Loosely couple components

## State Management

**Primary**: Provider + ChangeNotifier

```dart
// In main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => TransactionViewModel(...)),
    ChangeNotifierProvider(create: (_) => AccountViewModel(...)),
  ],
  child: MyApp(),
)

// In widgets
final viewModel = context.watch<TransactionViewModel>();
```

See [State Management](state-management.md) for details.

## Database Architecture

**Technology**: SQLite with sqflite package

**Schema**: See [Database](database.md)

**Key Tables**:
- `accounts` - User accounts
- `transactions` - All transactions
- `recurring_patterns` - Detected patterns
- `budgets` - Budget definitions
- `sms_account_mappings` - Learning data

## Testing Architecture

```
test/
├── unit/                    # Unit tests for services/repositories
├── widget/                  # Widget tests for UI components
├── integration/             # Integration tests
└── fixtures/                # Test data
```

## Performance Considerations

- **Lazy loading**: Load data on-demand
- **Pagination**: For transaction lists
- **Caching**: In repositories
- **Background processing**: For SMS parsing
- **Indexed queries**: Database indexes

## Security

- **Local-first**: All data stays on device
- **SQLite encryption**: Optional (via sqlcipher)
- **No cloud sync**: Privacy-focused
- **Permission checks**: Runtime permission handling

## Next Steps

- [Components](components.md) - Detailed component descriptions
- [Database](database.md) - Database schema & design
- [Services](services.md) - Service layer details
- [State Management](state-management.md) - State management patterns

---

*Last updated: April 23, 2026*
