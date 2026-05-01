# Quick Reference

Common tasks and code patterns for PocketFlow developers.

## Running the App

```bash
# Run on connected device
flutter run

# Run on specific device
flutter run -d <device-id>

# Run in release mode
flutter run --release

# Hot reload: press 'r'
# Hot restart: press 'R'
# Quit: press 'q'
```

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/sms_classifier_test.dart

# Run with coverage
flutter test --coverage

# Watch mode
flutter test --watch
```

## Database Queries

### Get All Transactions

```dart
final transactions = await database.query('transactions');
```

### Insert Transaction

```dart
await database.insert('transactions', {
  'amount': 500.0,
  'type': 'expense',
  'category': 'Shopping',
  'merchant': 'Amazon',
  'date': DateTime.now().toIso8601String(),
});
```

### Update Transaction

```dart
await database.update(
  'transactions',
  {'category': 'Food'},
  where: 'id = ?',
  whereArgs: [transactionId],
);
```

## SMS Processing

### Classify SMS

```dart
final classifier = SMSClassifier();
final result = classifier.classify(smsText);

if (result.isFinancial) {
  // Process financial SMS
}
```

### Extract Entities

```dart
final extractor = EntityExtractor();
final entities = extractor.extract(smsText);

print('Amount: ${entities.amount}');
print('Merchant: ${entities.merchant}');
```

### Resolve Account

```dart
final resolver = AccountResolver();
final resolution = await resolver.resolve(entities, sender);

if (resolution.confidence > 0.9) {
  // Auto-accept
} else {
  // Ask user
}
```

## State Management

### Using Provider

```dart
// In widget
final viewModel = context.watch<TransactionViewModel>();

// Call method
viewModel.loadTransactions();

// Access state
Text('${viewModel.transactions.length} transactions')
```

### Update State

```dart
class TransactionViewModel extends ChangeNotifier {
  List<Transaction> _transactions = [];
  
  List<Transaction> get transactions => _transactions;
  
  void addTransaction(Transaction txn) {
    _transactions.add(txn);
    notifyListeners(); // Trigger rebuild
  }
}
```

## Navigation

### Push Screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TransactionDetailScreen(transaction),
  ),
);
```

### Pop Screen

```dart
Navigator.pop(context);
```

### Named Routes

```dart
Navigator.pushNamed(context, '/transactions');
```

## Common Patterns

### Async Loading

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    final data = await repository.getTransactions();
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircularProgressIndicator();
    }
    return ListView.builder(...);
  }
}
```

### Error Handling

```dart
try {
  await repository.saveTransaction(transaction);
} on DatabaseException catch (e) {
  showErrorDialog(context, 'Failed to save: ${e.message}');
} catch (e) {
  showErrorDialog(context, 'Unexpected error');
}
```

## Formatting

### Currency

```dart
import 'package:intl/intl.dart';

final formatter = NumberFormat.currency(
  symbol: 'Rs.',
  decimalDigits: 2,
);

print(formatter.format(500.0)); // Rs.500.00
```

### Dates

```dart
import 'package:intl/intl.dart';

final dateFormatter = DateFormat('MMM dd, yyyy');
print(dateFormatter.format(DateTime.now())); // Apr 23, 2026

final timeFormatter = DateFormat('hh:mm a');
print(timeFormatter.format(DateTime.now())); // 03:45 PM
```

## Dialogs

### Confirmation Dialog

```dart
Future<bool> showConfirmDialog(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirm'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Confirm'),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

### Input Dialog

```dart
Future<String?> showInputDialog(BuildContext context) async {
  final controller = TextEditingController();
  
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Enter value'),
      content: TextField(controller: controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

## Useful Commands

```bash
# Check Flutter setup
flutter doctor

# List devices
flutter devices

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Format code
flutter format .

# Analyze code
flutter analyze

# Build APK
flutter build apk

# Build iOS
flutter build ios

# Run tests with coverage
flutter test --coverage

# Generate code
flutter pub run build_runner build
```

## Debugging

### Print Statements

```dart
print('Debug: $value');
debugPrint('Debug message');
```

### Logger

```dart
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug');
logger.i('Info');
logger.w('Warning');
logger.e('Error');
```

### VS Code Launch Configuration

`.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "request": "launch",
      "type": "dart"
    },
    {
      "name": "Flutter (Profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile"
    }
  ]
}
```

## Git Commands

```bash
# Create branch
git checkout -b feature/my-feature

# Stage changes
git add .

# Commit
git commit -m "feat: add feature"

# Push
git push origin feature/my-feature

# Pull latest
git pull origin main

# Rebase
git rebase main

# Stash changes
git stash
git stash pop
```

## Environment Variables

```dart
// Check environment
if (kDebugMode) {
  print('Running in debug mode');
}

if (kReleaseMode) {
  // Production code
}
```

## File Paths

```dart
import 'package:path_provider/path_provider.dart';

// Get app directory
final directory = await getApplicationDocumentsDirectory();
final path = '${directory.path}/myfile.txt';

// Read file
final file = File(path);
final contents = await file.readAsString();

// Write file
await file.writeAsString('Hello World');
```

## Permissions

### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
```

### iOS (Info.plist)

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>We need notifications to alert you about transactions</string>
```

### Request at Runtime

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestSMSPermission() async {
  final status = await Permission.sms.request();
  return status.isGranted;
}
```

## Performance Tips

1. Use `const` constructors
2. Avoid rebuilding with `const` widgets
3. Use `ListView.builder` for long lists
4. Implement pagination
5. Cache expensive computations
6. Use `compute()` for heavy tasks

## Keyboard Shortcuts

### VS Code

- `F5` - Start debugging
- `Shift+F5` - Stop debugging
- `Ctrl+F5` - Run without debugging
- `Ctrl+Shift+P` - Command palette
- `Ctrl+` - Toggle terminal

### Android Studio

- `Shift+F10` - Run
- `Shift+F9` - Debug
- `Ctrl+F9` - Make project
- `Alt+Enter` - Show intention actions

---

*For detailed guides, see [Documentation Index](../index.md)*
