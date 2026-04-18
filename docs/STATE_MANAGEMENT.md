# State Management & Error Handling Implementation

## Overview

Implemented comprehensive state management and error handling system for PocketFlow using Provider, with centralized loading/error states, automatic retry mechanisms, error boundaries, state persistence, and offline detection.

## What Was Implemented

### 1. Centralized State Management ✅

#### AppState Class (`lib/core/app_state.dart`)
Central hub for managing application-wide loading and error states.

**Features:**
- `LoadingState` - Tracks loading operations by key
- `ErrorState` - Manages errors with context and retry info
- `AppError` - Rich error model with type, message, and actionable guidance
- Combined `AppState` class for unified state management

**Usage:**
```dart
final appState = context.read<AppState>();

// Execute with automatic loading and error handling
await appState.execute(
  'fetch_transactions',
  () => transactionRepo.getAll(),
  onError: (error) => print('Error: ${error.userMessage}'),
);

// Check loading state
if (appState.loadingState.isLoading('fetch_transactions')) {
  // Show loading indicator
}

// Check error state
if (appState.errorState.hasError('fetch_transactions')) {
  final error = appState.errorState.getError('fetch_transactions');
  // Show error widget
}
```

#### Error Types
- `ErrorType.network` - Network/connectivity errors
- `ErrorType.database` - Database operation errors
- `ErrorType.validation` - Input validation errors (not retryable)
- `ErrorType.permission` - Permission denied errors (not retryable)
- `ErrorType.timeout` - Operation timeout errors
- `ErrorType.unknown` - Uncategorized errors

### 2. Error Boundaries ✅

#### ErrorBoundary Widget (`lib/widgets/error_boundary.dart`)
Catches and handles widget build errors gracefully to prevent app crashes.

**Features:**
- Global error handler registration
- Custom error UI
- Error logging with AppLogger
- Reset functionality
- Expandable error details

**Usage:**
```dart
ErrorBoundary(
  child: MyApp(),
  onError: (error, stackTrace) {
    // Custom error handling
    reportToAnalytics(error);
  },
  errorBuilder: (context, error, stackTrace) {
    return CustomErrorView(error: error);
  },
)
```

**SafeWidget** - Simplified error boundary for specific widgets:
```dart
SafeWidget(
  child: ComplexWidget(),
  errorBuilder: (context, error) => Text('Widget failed to load'),
)
```

### 3. Retry Mechanisms ✅

#### RetryHelper Class (`lib/core/retry_helper.dart`)
Automatic retry logic with exponential backoff.

**Features:**
- Configurable max attempts (default: 3)
- Exponential backoff strategy
- Custom retry conditions
- Retry callbacks for monitoring

**Usage:**
```dart
final result = await RetryHelper.execute(
  operation: () => apiClient.fetchData(),
  maxAttempts: 3,
  initialDelay: Duration(seconds: 1),
  maxDelay: Duration(seconds: 10),
  backoffMultiplier: 2.0,
  shouldRetry: (error) => error is NetworkException,
  onRetry: (attempt, error) {
    print('Retry $attempt after: $error');
  },
);
```

**RetryMixin** - For classes that need retry capabilities:
```dart
class MyViewModel extends ChangeNotifier with RetryMixin {
  Future<void> loadData() async {
    await withRetry(
      operation: () => _fetchDataFromApi(),
      maxAttempts: 3,
      onRetry: (attempt, error) {
        AppLogger.log('Retry', 'Attempt $attempt', 'WARNING');
      },
    );
  }
}
```

### 4. State Persistence ✅

#### StatePersistence Service (`lib/core/state_persistence.dart`)
Save and restore UI state across app restarts.

**Features:**
- JSON serialization
- SharedPreferences integration
- Automatic state management
- Type-safe state restoration

**Direct Usage:**
```dart
// Save state
await StatePersistence.saveState('my_screen', {
  'selectedTab': 2,
  'filterType': 'recent',
  'scrollPosition': 350.0,
});

// Load state
final state = await StatePersistence.loadState('my_screen');
if (state != null) {
  selectedTab = state['selectedTab'];
  filterType = state['filterType'];
}

// Clear state
await StatePersistence.removeState('my_screen');
```

**StatePersistenceMixin** - For ViewModels:
```dart
class MyViewModel extends ChangeNotifier with StatePersistenceMixin {
  int _counter = 0;
  String _filter = 'all';

  @override
  String get persistenceKey => 'my_screen';

  @override
  Map<String, dynamic> toJson() => {
    'counter': _counter,
    'filter': _filter,
  };

  @override
  void fromJson(Map<String, dynamic> json) {
    _counter = json['counter'] ?? 0;
    _filter = json['filter'] ?? 'all';
  }

  void increment() {
    _counter++;
    notifyListeners();
    saveState(); // Auto-save
  }

  // Load in constructor or init
  Future<void> initialize() async {
    await loadState();
  }
}
```

### 5. Offline Detection ✅

#### ConnectivityService (`lib/services/connectivity_service.dart`)
Monitors network connectivity and provides offline handling.

**Features:**
- Periodic connectivity checks (every 10 seconds)
- Manual connectivity verification
- Offline operation fallbacks
- ChangeNotifier for reactive UI

**Usage:**
```dart
// In widget
final connectivity = context.watch<ConnectivityService>();

if (connectivity.isOffline) {
  return OfflineWarning();
}

// Require online for operation
await connectivity.requireOnline(() async {
  return await apiClient.syncData();
});

// With offline fallback
final data = await connectivity.withOfflineFallback(
  onlineOperation: () => apiClient.fetchData(),
  offlineFallback: () => cachedData,
);
```

**ConnectivityAware Mixin** - For ViewModels:
```dart
class MyViewModel extends ChangeNotifier with ConnectivityAware {
  Future<void> syncData() async {
    if (isOffline) {
      throw OfflineException('Cannot sync while offline');
    }
    
    await requireOnline(() async {
      // Online-only operation
    });
  }
}
```

### 6. Enhanced Error Widget ✅

#### Updated ErrorStateWidget (`lib/widgets/error_state_widget.dart`)
Enhanced to support rich error display with offline detection.

**Features:**
- Error type-specific icons and colors
- Actionable error messages
- Offline status indicator
- Conditional retry button (based on `isRetryable`)
- Integration with ConnectivityService

**Usage:**
```dart
// With AppError
ErrorStateWidget(
  appError: AppError.network('Failed to load data'),
  onRetry: () => viewModel.loadData(),
)

// With string message
ErrorStateWidget(
  message: 'Something went wrong',
  onRetry: () => retry(),
)

// Custom title
ErrorStateWidget(
  appError: error,
  title: 'Unable to Load Transactions',
  onRetry: () => reload(),
)
```

### 7. Updated AppDependencies ✅

#### Enhanced DI Container (`lib/core/app_dependencies.dart`)
Now includes services alongside repositories.

**Services Registered:**
- `ConnectivityService` - Network monitoring
- `AppState` - Centralized state management

**Usage:**
```dart
// Access services
final connectivity = context.read<ConnectivityService>();
final appState = context.read<AppState>();

// Access repositories  
final transactionRepo = context.read<TransactionRepository>();
```

### 8. Enhanced ViewModels ✅

#### Updated HomeViewModel (Example)
Demonstrates new patterns:
- Uses `RetryMixin` for automatic retries
- Uses `AppError` instead of string errors
- Integrated AppLogger for proper error logging
- Retry attempts logged with warnings

**Pattern:**
```dart
class HomeViewModel extends ChangeNotifier with RetryMixin {
  AppError? _error;
  
  Future<void> loadData() async {
    await withRetry(
      operation: () => _loadDataImpl(),
      maxAttempts: 3,
      onRetry: (attempt, error) {
        AppLogger.log('Data Load', 'Retry $attempt', 'WARNING');
      },
    );
  }
  
  Future<void> _loadDataImpl() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();
      
      // Load data...
      
      _loading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _error = AppError.fromException(e, stackTrace);
      _loading = false;
      notifyListeners();
      rethrow; // For retry mechanism
    }
  }
}
```

### 9. Global Error Handler ✅

#### Updated main.dart
Sets up global error handler logging all uncaught errors.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global error handler
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.log('Flutter Error', details.exceptionAsString(), 'ERROR');
    if (details.stack != null) {
      AppLogger.log('Stack Trace', details.stack.toString(), 'ERROR');
    }
  };
  
  // ... rest of initialization
  runApp(const PocketFlowApp());
}
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌─────────────────┐  │
│  │ ErrorBoundary  │  │ ErrorState     │  │ Connectivity    │  │
│  │ (catches       │  │ Widget         │  │ Indicator       │  │
│  │  widget errors)│  │ (smart errors) │  │ (offline UI)    │  │
│  └────────┬───────┘  └────────┬───────┘  └────────┬────────┘  │
└───────────┼──────────────────┼──────────────────┼─────────────┘
            │                  │                  │
            │ Logs             │ Displays         │ Monitors
            │                  │                  │
┌───────────▼──────────────────▼──────────────────▼─────────────┐
│                   State Management Layer                       │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │  AppState   │  │ Connectivity │  │ StatePersistence   │   │
│  │ ┌─────────┐ │  │  Service     │  │  Service           │   │
│  │ │Loading  │ │  │              │  │                    │   │
│  │ │State    │ │  │ • isOnline   │  │ • saveState()      │   │
│  │ └─────────┘ │  │ • isOffline  │  │ • loadState()      │   │
│  │ ┌─────────┐ │  │ • checkNow() │  │ • clearAll()       │   │
│  │ │Error    │ │  │              │  │                    │   │
│  │ │State    │ │  └──────────────┘  └────────────────────┘   │
│  │ └─────────┘ │                                              │
│  └─────────────┘                                              │
└───────────┬────────────────────────────────────────────────────┘
            │
            │ Provides state
            │
┌───────────▼────────────────────────────────────────────────────┐
│                     ViewModel Layer                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ViewModels with:                                         │  │
│  │ • RetryMixin (auto-retry with backoff)                  │  │
│  │ • StatePersistenceMixin (save/restore state)            │  │
│  │ • ConnectivityAware (offline handling)                  │  │
│  │ • AppError (rich error context)                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
            │
            │ Business logic
            │
┌───────────▼────────────────────────────────────────────────────┐
│                    Repository Layer                             │
│  Database access, API calls, local storage                     │
└────────────────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────┐
│  User Action    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ViewModel      │
│  withRetry()    │
└────────┬────────┘
         │
         ▼
    ┌────────┐
    │ Attempt│◄──────┐
    │    1   │       │
    └───┬────┘       │
        │            │
    Success?    ┌────┴────┐
        │       │ Retry?  │
        │       │ (max 3) │
        │       └─────────┘
        ▼              │
    ┌────────┐         │
    │ Update │    Exponential
    │   UI   │     Backoff
    └────────┘         │
                       │
    ┌────────┐    ┌────▼────┐
    │ Show   │◄───│ Failure │
    │ Error  │    │ Final   │
    └────────┘    └─────────┘
         │
         ▼
    ┌────────────────┐
    │ ErrorState     │
    │ Widget         │
    │ • Actionable   │
    │ • Retryable    │
    │ • Logged       │
    └────────────────┘
```

## Best Practices

### 1. Always Use AppError
```dart
// ❌ DON'T
catch (e) {
  _error = e.toString();
}

// ✅ DO
catch (e, stackTrace) {
  _error = AppError.fromException(e, stackTrace);
  AppLogger.log('Operation', _error!.message, 'ERROR');
}
```

### 2. Wrap Critical Operations with Retry
```dart
// ❌ DON'T - Single attempt
Future<void> loadData() async {
  final data = await repository.fetchData();
}

// ✅ DO - Auto-retry on failure
Future<void> loadData() async {
  await withRetry(
    operation: () => _loadDataImpl(),
    maxAttempts: 3,
  );
}
```

### 3. Provide Actionable Error Messages
```dart
// ❌ DON'T
AppError(message: 'Error occurred', type: ErrorType.unknown);

// ✅ DO
AppError(
  message: 'Failed to sync transactions',
  type: ErrorType.network,
  actionableMessage: 'Please check your internet connection and try again.',
);
```

### 4. Use Error Boundaries for Widget Trees
```dart
// ❌ DON'T - Let widget errors crash app
return MyComplexWidget();

// ✅ DO - Wrap with error boundary
return ErrorBoundary(
  child: MyComplexWidget(),
  onError: (error, stack) {
    reportErrorToAnalytics(error);
  },
);
```

### 5. Check Connectivity Before Network Operations
```dart
// ❌ DON'T - Attempt without checking
await apiClient.syncData();

// ✅ DO - Check first, provide fallback
final connectivity = context.read<ConnectivityService>();
if (connectivity.isOffline) {
  showOfflineMessage();
  return cachedData;
}
await apiClient.syncData();
```

### 6. Persist Important UI State
```dart
// ViewModel with StatePersistenceMixin
class MyViewModel extends ChangeNotifier with StatePersistenceMixin {
  @override
  String get persistenceKey => 'my_screen';
  
  @override
  Map<String, dynamic> toJson() => {
    'currentTab': _currentTab,
    'selectedFilter': _selectedFilter,
  };
  
  @override
  void fromJson(Map<String, dynamic> json) {
    _currentTab = json['currentTab'] ?? 0;
    _selectedFilter = json['selectedFilter'] ?? 'all';
  }
  
  void changeTab(int tab) {
    _currentTab = tab;
    notifyListeners();
    saveState(); // Auto-persist
  }
}
```

### 7. Log All Errors with Context
```dart
catch (e, stackTrace) {
  final error = AppError.fromException(e, stackTrace);
  
  AppLogger.log(
    'Transaction Load',
    'Failed to load transactions\n'
    'Error: ${error.message}\n'
    'Type: ${error.type}\n'
    'Details: ${error.technicalDetails}',
    'ERROR',
  );
  
  _error = error;
  notifyListeners();
}
```

## Migration Checklist

To update existing ViewModels:

- [ ] Change `String? _error` to `AppError? _error`
- [ ] Add `RetryMixin` to class definition
- [ ] Wrap data loading in `withRetry()`
- [ ] Use `AppError.fromException()` in catch blocks
- [ ] Add `AppLogger.log()` calls for errors
- [ ] Update error widget usage to pass `AppError`
- [ ] Consider adding `StatePersistenceMixin` for screens with filters/tabs
- [ ] Add `ConnectivityAware` for operations requiring network

## Files Created

1. `lib/core/app_state.dart` - Centralized state management
2. `lib/core/retry_helper.dart` - Retry mechanisms
3. `lib/core/state_persistence.dart` - State persistence
4. `lib/widgets/error_boundary.dart` - Error boundaries
5. `lib/services/connectivity_service.dart` - Offline detection

## Files Updated

1. `lib/core/app_dependencies.dart` - Added services to DI
2. `lib/widgets/error_state_widget.dart` - Enhanced with AppError
3. `lib/viewmodels/home_viewmodel.dart` - Example using new patterns
4. `lib/main.dart` - Global error handler

## Next Steps

1. **Update remaining ViewModels** to use new error handling patterns
2. **Wrap main screens** with ErrorBoundary
3. **Add offline indicators** to UI where network operations occur
4. **Implement state persistence** for screens with complex filters
5. **Add retry buttons** to all error states
6. **Monitor error logs** to identify common failure patterns
7. **Add analytics** for error tracking
8. **Write unit tests** for error scenarios

## Testing Error Scenarios

```dart
// Test retry logic
test('loads data with retry on failure', () async {
  int attempts = 0;
  final viewModel = MyViewModel();
  
  when(() => repository.getData()).thenAnswer((_) async {
    attempts++;
    if (attempts < 3) throw Exception('Temporary failure');
    return mockData;
  });
  
  await viewModel.loadData();
  
  expect(attempts, equals(3));
  expect(viewModel.error, isNull);
});

// Test offline handling
test('shows offline message when disconnected', () async {
  final connectivity = ConnectivityService();
  connectivity.checkNow(); // Simulate offline
  
  expect(connectivity.isOffline, isTrue);
  
  expect(
    () => connectivity.requireOnline(() => apiCall()),
    throwsA(isA<OfflineException>()),
  );
});
```

## Benefits Delivered

✅ **Centralized State** - Single source of truth for loading/error states  
✅ **Automatic Retries** - Transient failures handled automatically  
✅ **Rich Error Context** - Actionable error messages for users  
✅ **Offline Awareness** - Graceful degradation when offline  
✅ **State Persistence** - Better UX with restored state  
✅ **Error Boundaries** - App doesn't crash on widget errors  
✅ **Comprehensive Logging** - All errors logged with context  
✅ **Better UX** - Users can retry failed operations  
✅ **Type Safety** - AppError instead of string errors  
✅ **Testability** - All components mockable and testable
