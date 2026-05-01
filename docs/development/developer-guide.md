# Developer Guide

Welcome to PocketFlow development! This guide will help you contribute effectively.

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio or VS Code
- Git

See [Installation Guide](../getting-started/installation.md) for setup.

## Development Workflow

### 1. Clone & Setup

```bash
git clone https://github.com/ShankarSomu/PocketFlow.git
cd PocketFlow
flutter pub get
```

### 2. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 3. Make Changes

Follow the architecture patterns in [Architecture Overview](../architecture/overview.md).

### 4. Test

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/services/sms_classifier_test.dart

# Run with coverage
flutter test --coverage
```

### 5. Commit

Use conventional commits:

```bash
git commit -m "feat: add transfer detection improvement"
git commit -m "fix: resolve account matching bug"
git commit -m "docs: update SMS intelligence guide"
```

**Types**: feat, fix, docs, style, refactor, test, chore

### 6. Push & PR

```bash
git push origin feature/your-feature-name
```

Open a Pull Request on GitHub.

## Project Structure

```
lib/
├── core/          # App infrastructure
├── models/        # Data models
├── db/            # Database layer
├── repositories/  # Data access
├── services/      # Business logic
├── viewmodels/    # Presentation logic
├── screens/       # UI screens
├── widgets/       # UI components
└── theme/         # Theming

test/
├── unit/          # Unit tests
├── widget/        # Widget tests
└── integration/   # Integration tests
```

## Coding Standards

### Dart Style

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart):

```dart
// ✅ Good
class TransactionService {
  final TransactionRepository _repository;
  
  TransactionService(this._repository);
  
  Future<List<Transaction>> getRecent() async {
    return await _repository.getRecentTransactions();
  }
}

// ❌ Bad
class transactionService {
  var repo;
  
  getRecent() {
    return repo.getRecentTransactions();
  }
}
```

### Naming Conventions

- **Classes**: PascalCase (`TransactionViewModel`)
- **Files**: snake_case (`transaction_viewmodel.dart`)
- **Variables**: camelCase (`transactionList`)
- **Constants**: lowerCamelCase or SCREAMING_SNAKE_CASE
- **Private**: prefix with `_` (`_repository`)

### File Organization

```dart
// 1. Imports (grouped)
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pocketflow/models/transaction.dart';

// 2. Class definition
class MyWidget extends...

// 3. Overrides first
@override
Widget build(BuildContext context) {}

// 4. Public methods
void publicMethod() {}

// 5. Private methods
void _privateMethod() {}
```

## Testing Strategy

### Unit Tests

Test business logic in services:

```dart
void main() {
  group('SMSClassifier', () {
    late SMSClassifier classifier;
    
    setUp(() {
      classifier = SMSClassifier();
    });
    
    test('classifies transaction SMS correctly', () {
      final sms = "Debited Rs.500 from A/c XX1234";
      final result = classifier.classify(sms);
      
      expect(result.type, MessageType.transaction);
      expect(result.confidence, greaterThan(0.9));
    });
  });
}
```

### Widget Tests

Test UI components:

```dart
void main() {
  testWidgets('TransactionTile displays amount', (tester) async {
    final transaction = Transaction(
      amount: 500.0,
      merchant: 'Amazon',
      type: 'expense',
    );
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(transaction),
        ),
      ),
    );
    
    expect(find.text('Rs.500.00'), findsOneWidget);
    expect(find.text('Amazon'), findsOneWidget);
  });
}
```

### Integration Tests

Test full workflows:

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('SMS sync workflow', (tester) async {
    // 1. Launch app
    app.main();
    await tester.pumpAndSettle();
    
    // 2. Navigate to transactions
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    
    // 3. Trigger SMS sync
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    
    // 4. Verify transactions loaded
    expect(find.byType(TransactionTile), findsWidgets);
  });
}
```

## Adding Features

### Example: Add New SMS Pattern

1. **Add Pattern** to `lib/services/sms_patterns/`

```dart
class NewBankPattern extends SMSPattern {
  @override
  bool matches(String sms) {
    return sms.contains('NEWBANK');
  }
  
  @override
  ExtractedEntities extract(String sms) {
    // Extract entities
    return ExtractedEntities(...);
  }
}
```

2. **Register Pattern** in `sms_classifier.dart`

```dart
final patterns = [
  ExistingPattern(),
  NewBankPattern(),  // Add here
];
```

3. **Add Tests**

```dart
test('NewBank SMS pattern', () {
  final sms = "NEWBANK: Rs.500 debited from XX1234";
  final pattern = NewBankPattern();
  
  expect(pattern.matches(sms), true);
  
  final entities = pattern.extract(sms);
  expect(entities.amount, 500.0);
});
```

4. **Update Documentation**

Add to [Classification](../features/sms-intelligence/classification.md).

## Debugging

### Flutter DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

Then run app in debug mode and open DevTools URL.

### Logging

```dart
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

### Database Inspection

```bash
# Android
adb shell
cd /data/data/com.yourpackage.pocketflow/databases/
sqlite3 pocketflow.db

# Query tables
SELECT * FROM transactions LIMIT 10;
```

## Performance

### Optimization Tips

1. **Use const constructors** where possible
2. **Avoid rebuilding** expensive widgets
3. **Lazy load** data
4. **Paginate** large lists
5. **Cache** frequently accessed data

### Profiling

```bash
flutter run --profile
# Open DevTools performance tab
```

## Code Review Checklist

Before submitting PR:

- [ ] Code follows style guide
- [ ] All tests pass
- [ ] New features have tests
- [ ] Documentation updated
- [ ] No console.log/print statements (use logger)
- [ ] No hardcoded values
- [ ] Error handling implemented
- [ ] Performance considered

## Common Tasks

### Add Dependency

```bash
flutter pub add package_name
```

### Update Dependencies

```bash
flutter pub upgrade
```

### Generate Code (Models, etc.)

```bash
flutter pub run build_runner build
```

### Format Code

```bash
flutter dart format .
```

### Analyze Code

```bash
flutter analyze
```

## Building for Release

### Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
# Then archive in Xcode
```

## Troubleshooting

### Common Issues

**"Flutter SDK not found"**
```bash
export PATH="$PATH:$HOME/flutter/bin"
```

**"Package not found"**
```bash
flutter pub get
flutter clean
flutter pub get
```

**"Build failed"**
```bash
flutter clean
flutter pub get
flutter run
```

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [PocketFlow Architecture](../architecture/overview.md)

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/ShankarSomu/PocketFlow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ShankarSomu/PocketFlow/discussions)
- **Documentation**: Check `/docs` folder

## Contributing

See [Contributing Guide](contributing.md) for:
- Code of Conduct
- Pull Request process
- Issue reporting guidelines

---

*Happy coding! 🚀*
