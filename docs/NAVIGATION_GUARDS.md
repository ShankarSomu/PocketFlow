# Navigation Guards

Navigation Guards prevent users from accidentally losing unsaved changes when navigating away from a screen. The system automatically shows confirmation dialogs when users attempt to leave screens with unsaved data.

## Features

✅ **Automatic Back Button Handling** - Intercepts hardware/gesture back navigation  
✅ **Unsaved Changes Detection** - Tracks form state and modifications  
✅ **Confirmation Dialogs** - User-friendly prompts with Save/Discard/Cancel options  
✅ **FormStateTracker** - Helper class for tracking changes in forms  
✅ **Context Extension** - Easy-to-use API for manual checks  
✅ **Global Service** - Centralized navigation guard management

## Quick Start

### Basic Usage with NavigationGuardWrapper

The simplest way to protect a screen:

```dart
import 'package:pocket_flow/core/navigation_guard.dart';

class EditTransactionScreen extends StatefulWidget {
  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _hasChanges = false;

  @override
  Widget build(BuildContext context) {
    return NavigationGuardWrapper(
      hasUnsavedChanges: _hasChanges,
      onSave: _saveTransaction,
      onDiscard: () {
        // Optional cleanup before leaving
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Edit Transaction')),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() => _hasChanges = true),
          child: /* Your form widgets */,
        ),
      ),
    );
  }

  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      // Save logic here
      setState(() => _hasChanges = false);
    }
  }
}
```

### Using FormStateTracker

For more complex forms with multiple fields:

```dart
class AddBudgetScreen extends StatefulWidget {
  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formTracker = FormStateTracker();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => _formTracker.markChanged());
    _amountController.addListener(() => _formTracker.markChanged());
  }

  @override
  void dispose() {
    _formTracker.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _formTracker,
      builder: (context, _) {
        return NavigationGuardWrapper(
          hasUnsavedChanges: _formTracker.hasChanges,
          onSave: _saveBudget,
          title: 'Unsaved Budget',
          message: 'Save your budget before leaving?',
          child: Scaffold(
            appBar: AppBar(title: Text('Add Budget')),
            body: Column(
              children: [
                TextField(controller: _nameController),
                TextField(controller: _amountController),
                ElevatedButton(
                  onPressed: _saveBudget,
                  child: Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveBudget() {
    // Save logic
    _formTracker.markSaved();
    Navigator.pop(context);
  }
}
```

### Manual Navigation Check

For programmatic navigation with checks:

```dart
// Using context extension
onPressed: () async {
  final canLeave = await context.checkUnsavedChanges(
    hasUnsavedChanges: _hasChanges,
    onSave: _save,
    title: 'Leave page?',
  );
  
  if (canLeave) {
    Navigator.push(context, MaterialPageRoute(/* ... */));
  }
}

// Or using the service
onPressed: () async {
  final service = NavigationGuardService();
  final allowed = await service.canNavigate();
  
  if (allowed) {
    // Navigate to another screen
  }
}
```

## Advanced Usage

### Custom Dialog

You can create custom confirmation dialogs:

```dart
Future<bool?> _showCustomDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Discard changes?'),
      content: Text('Your draft will be lost.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Discard'),
        ),
      ],
    ),
  );
}

// Use it
PopScope(
  canPop: !_hasChanges,
  onPopInvokedWithResult: (didPop, _) async {
    if (didPop) return;
    final shouldPop = await _showCustomDialog(context);
    if (shouldPop == true && context.mounted) {
      Navigator.pop(context);
    }
  },
  child: /* Your widget */,
)
```

### Global Navigation Guard Service

Register a guard that applies to all navigation attempts:

```dart
class MyFormScreen extends StatefulWidget {
  @override
  State<MyFormScreen> createState() => _MyFormScreenState();
}

class _MyFormScreenState extends State<MyFormScreen> {
  final _service = NavigationGuardService();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _service.registerGuard(() async {
      if (!_hasChanges) return true;
      return await context.checkUnsavedChanges(
        hasUnsavedChanges: _hasChanges,
        onSave: _save,
      );
    });
  }

  @override
  void dispose() {
    _service.unregisterGuard();
    super.dispose();
  }

  void _navigateWithCheck() async {
    await _service.checkAndNavigate(
      context,
      () => NextScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(/* ... */);
  }
}
```

## Components

### 1. NavigationGuardWrapper

Main widget that wraps screens needing protection.

**Parameters:**
- `child` (required): The screen content
- `hasUnsavedChanges` (required): Boolean indicating unsaved state
- `onSave`: Callback to save changes before leaving
- `onDiscard`: Callback when user discards changes
- `title`: Custom dialog title
- `message`: Custom dialog message

### 2. UnsavedChangesDialog

Confirmation dialog shown to users.

**Actions:**
- **Cancel**: Stay on current screen
- **Discard/Leave**: Leave without saving
- **Save**: Save changes and leave (if onSave provided)

### 3. FormStateTracker

ChangeNotifier for tracking form modifications.

**Methods:**
- `markChanged()`: Mark form as modified
- `markSaved()`: Mark form as saved
- `reset()`: Reset to initial state
- `hasChanges`: Boolean getter for change state

### 4. NavigationGuardService

Singleton service for global guard management.

**Methods:**
- `registerGuard(callback)`: Set active guard
- `unregisterGuard()`: Remove active guard
- `canNavigate()`: Check if navigation allowed
- `checkAndNavigate()`: Check and navigate if allowed

### 5. NavigationGuardExtension

Extension on BuildContext for manual checks.

**Methods:**
- `checkUnsavedChanges()`: Show dialog and return result

## Best Practices

### 1. Always Dispose Trackers

```dart
@override
void dispose() {
  _formTracker.dispose();
  super.dispose();
}
```

### 2. Mark Saved After Successful Save

```dart
void _save() async {
  final success = await _repository.save(data);
  if (success) {
    _formTracker.markSaved(); // Important!
  }
}
```

### 3. Track All Input Changes

```dart
TextField(
  controller: _controller,
  onChanged: (_) => _formTracker.markChanged(),
)

DropdownButton(
  onChanged: (value) {
    setState(() => _selectedValue = value);
    _formTracker.markChanged();
  },
)
```

### 4. Handle Context After Async

```dart
if (shouldPop == true && context.mounted) {
  Navigator.pop(context);
}
```

### 5. Provide User-Friendly Messages

```dart
NavigationGuardWrapper(
  title: 'Unsaved Transaction',
  message: 'You have an unsaved transaction. Would you like to save it?',
  // ...
)
```

## Testing

### Unit Testing Guards

```dart
testWidgets('Shows dialog on back press with changes', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NavigationGuardWrapper(
        hasUnsavedChanges: true,
        child: Scaffold(body: Text('Test')),
      ),
    ),
  );

  // Simulate back press
  final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
  await widgetsAppState.didPopRoute();
  await tester.pumpAndSettle();

  // Verify dialog appears
  expect(find.text('Unsaved Changes'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
});
```

### Manual Testing

1. Open a form screen (e.g., Add Transaction)
2. Make changes to any field
3. Press back button → Dialog should appear
4. Test all three buttons:
   - **Cancel**: Should stay on screen
   - **Discard**: Should leave immediately
   - **Save**: Should save then leave

## Examples in PocketFlow

Navigation Guards should be applied to:

1. **Add/Edit Transaction Screens**
   - Protect amount, category, note fields

2. **Add/Edit Account Screens**
   - Protect account name, type, balance

3. **Budget Creation/Edit**
   - Protect budget amount, category

4. **Savings Goal Creation/Edit**
   - Protect goal name, target amount

5. **Recurring Transaction Setup**
   - Protect frequency, amount, category

## Performance Considerations

- FormStateTracker uses ChangeNotifier for efficient updates
- Guards only trigger on actual navigation attempts
- Dialog only shown when changes detected
- No performance impact when no changes exist

## Future Enhancements

- Auto-save drafts to local storage
- Restore drafts after app restart
- Configurable auto-save intervals
- Network-aware save (only save when online)
- Undo/redo support for complex forms

## Implementation

File: [lib/core/navigation_guard.dart](lib/core/navigation_guard.dart)

The implementation uses Flutter's `PopScope` widget (introduced in Flutter 3.16) which provides better control over navigation blocking compared to the deprecated `WillPopScope`.
