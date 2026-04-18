# Quick Reference: Using the New Architecture

## How to Access Repositories

### Option 1: Using Provider.of (doesn't rebuild on changes)
```dart
final transactionRepo = Provider.of<TransactionRepository>(context, listen: false);
await transactionRepo.insert(transaction);
```

### Option 2: Using context.read (shorter syntax, same as above)
```dart
final transactionRepo = context.read<TransactionRepository>();
await transactionRepo.insert(transaction);
```

### Option 3: Using context.watch (rebuilds when repository changes)
```dart
final transactionRepo = context.watch<TransactionRepository>();
// Widget rebuilds when notifyListeners() is called
```

## How to Use ViewModels

### 1. Wrap your screen with ChangeNotifierProvider
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(
        transactionRepo: context.read<TransactionRepository>(),
        accountRepo: context.read<AccountRepository>(),
      )..loadData(), // Call loadData immediately
      child: const _HomeScreenContent(),
    );
  }
}
```

### 2. Use Consumer to rebuild on state changes
```dart
class _HomeScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const LoadingIndicator();
        }
        
        if (viewModel.error != null) {
          return ErrorStateWidget(
            error: viewModel.error!,
            onRetry: viewModel.loadData,
          );
        }
        
        return Column(
          children: [
            Text('Income: \$${viewModel.monthlyIncome}'),
            Text('Expenses: \$${viewModel.monthlyExpenses}'),
          ],
        );
      },
    );
  }
}
```

### 3. Alternative: Use context.watch for simpler cases
```dart
class _HomeScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    
    if (viewModel.isLoading) return const LoadingIndicator();
    if (viewModel.error != null) return ErrorStateWidget(error: viewModel.error!);
    
    return Column(
      children: [
        Text('Income: \$${viewModel.monthlyIncome}'),
      ],
    );
  }
}
```

### 4. Call ViewModel methods
```dart
// From within a Consumer or widget that can access the ViewModel
ElevatedButton(
  onPressed: () {
    final viewModel = context.read<HomeViewModel>();
    viewModel.refresh(); // Calls the method, rebuilds UI on state change
  },
  child: const Text('Refresh'),
)
```

## Common Patterns

### Loading State Pattern
```dart
Consumer<MyViewModel>(
  builder: (context, vm, _) {
    if (vm.isLoading) return const LoadingIndicator();
    if (vm.error != null) return ErrorStateWidget(error: vm.error!, onRetry: vm.loadData);
    
    return MyContent(data: vm.data);
  },
)
```

### Adding/Updating Items with Optimistic Updates
```dart
// In your screen/widget:
Future<void> _addTransaction() async {
  final viewModel = context.read<TransactionsViewModel>();
  
  final transaction = Transaction(/* ... */);
  await viewModel.addTransaction(transaction); // Optimistically updates UI
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction added')),
    );
  }
}
```

### Pull-to-Refresh Pattern
```dart
RefreshIndicator(
  onRefresh: () async {
    await context.read<HomeViewModel>().loadData();
  },
  child: Consumer<HomeViewModel>(
    builder: (context, vm, _) => ListView(
      children: [...],
    ),
  ),
)
```

## Using Reusable Widgets

### NavigablePageView (Carousel)
```dart
NavigablePageView(
  pages: [
    MonthlyOverviewCard(),
    CategoryBreakdownCard(),
    TrendsCard(),
  ],
  labels: ['Overview', 'Categories', 'Trends'],
  height: 260,
)
```

### StatsCard
```dart
StatsGrid(
  cards: [
    StatsCard(
      title: 'Monthly Income',
      value: 5000,
      valuePrefix: '\$',
      percentChange: '+12.5%',
      icon: Icons.trending_up,
      iconColor: Colors.green,
    ),
    StatsCard(
      title: 'Monthly Expenses',
      value: 3500,
      valuePrefix: '\$',
      percentChange: '-5.2%',
      icon: Icons.trending_down,
      iconColor: Colors.red,
    ),
  ],
)
```

### SectionHeader
```dart
SectionHeader(
  title: 'Recent Transactions',
  subtitle: 'Last 30 days',
  actionText: 'View All',
  actionIcon: Icons.arrow_forward,
  onActionTap: () => Navigator.push(...),
)
```

### EmptyState
```dart
EmptyState(
  icon: Icons.account_balance_wallet,
  title: 'No Accounts Yet',
  subtitle: 'Add your first account to track your finances',
  actionText: 'Add Account',
  onActionTap: () => _showAddAccountDialog(),
)
```

### LoadingIndicator
```dart
LoadingIndicator(message: 'Loading transactions...')
```

### ErrorStateWidget
```dart
ErrorStateWidget(
  error: 'Failed to load data',
  onRetry: () => viewModel.loadData(),
)
```

## Migration Checklist

When migrating a screen to use the new architecture:

- [ ] Import required packages
  ```dart
  import 'package:provider/provider.dart';
  import '../viewmodels/my_viewmodel.dart';
  import '../repositories/my_repository.dart';
  import '../widgets/common_widgets.dart';
  import '../widgets/error_state_widget.dart';
  ```

- [ ] Convert StatefulWidget to StatelessWidget (if only used for data loading)

- [ ] Wrap screen with `ChangeNotifierProvider<MyViewModel>`

- [ ] Replace `AppDatabase.db.method()` calls with `context.read<MyRepository>().method()`

- [ ] Use `Consumer<MyViewModel>` or `context.watch<MyViewModel>()` for reactive UI

- [ ] Add loading state handling with `LoadingIndicator`

- [ ] Add error state handling with `ErrorStateWidget`

- [ ] Extract large widgets into separate component files

- [ ] Remove manual `setState()` calls (handled by ViewModel's `notifyListeners()`)

- [ ] Test the screen works correctly

## Available Repositories

All registered in `AppDependencies`:
- `TransactionRepository` - Transaction CRUD and queries
- `AccountRepository` - Account management
- `BudgetRepository` - Budget operations
- `SavingsRepository` - Savings goals
- `CategoryRepository` - Category management
- `RecurringRepository` - Recurring transactions

## Available ViewModels

All extend `ChangeNotifier`:
- `HomeViewModel` - Home screen logic
- `AccountsViewModel` - Account management with computed properties
- `TransactionsViewModel` - Transaction list with optimistic updates
- `BudgetViewModel` - Budget tracking
- `SavingsViewModel` - Savings goals tracking
- `RecurringViewModel` - Recurring transaction management

Each ViewModel has:
- `bool isLoading` - Loading state flag
- `String? error` - Error message if any
- `Future<void> loadData()` - Refresh data method
- Computed properties for derived data (e.g., `totalAssets`, `netWorth`)

## Common Mistakes to Avoid

❌ **DON'T** use `context.watch()` inside callbacks
```dart
// WRONG:
onPressed: () {
  final vm = context.watch<MyViewModel>(); // Error!
  vm.doSomething();
}
```

✅ **DO** use `context.read()` inside callbacks
```dart
// CORRECT:
onPressed: () {
  final vm = context.read<MyViewModel>();
  vm.doSomething();
}
```

❌ **DON'T** forget to call `loadData()` in ViewModel creation
```dart
// WRONG:
create: (context) => HomeViewModel(...)
```

✅ **DO** call `loadData()` with cascade operator
```dart
// CORRECT:
create: (context) => HomeViewModel(...)..loadData()
```

❌ **DON'T** access repositories directly before MaterialApp
```dart
// WRONG - Provider not available yet:
void main() {
  final repo = AppDependencies.repositories[0]; // Error!
  runApp(MyApp());
}
```

✅ **DO** access repositories within widget tree
```dart
// CORRECT:
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final repo = context.read<TransactionRepository>();
    // ...
  }
}
```

## Testing with the New Architecture

### Mock Repository
```dart
class MockTransactionRepository implements TransactionRepository {
  final List<Transaction> _transactions = [];

  @override
  Future<int> insert(Transaction t) async {
    _transactions.add(t);
    return t.id;
  }

  @override
  Future<List<Transaction>> getAll() async => _transactions;
  
  // Implement other methods...
}
```

### Test ViewModel
```dart
void main() {
  test('HomeViewModel calculates net worth correctly', () async {
    final mockTransactionRepo = MockTransactionRepository();
    final mockAccountRepo = MockAccountRepository();
    
    final viewModel = HomeViewModel(
      transactionRepo: mockTransactionRepo,
      accountRepo: mockAccountRepo,
    );
    
    await viewModel.loadData();
    
    expect(viewModel.netWorth, equals(5000));
  });
}
```
