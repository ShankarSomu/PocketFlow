# Deep Linking Guide

PocketFlow supports deep links to navigate directly to specific screens from external apps, websites, or system actions.

## URL Scheme

All deep links use the custom URL scheme: `pocketflow://`

## Supported Deep Links

### Navigation Links

| Deep Link | Description | Example |
|-----------|-------------|---------|
| `pocketflow://home` | Navigate to home screen (dashboard) | `pocketflow://home` |
| `pocketflow://transactions` | Navigate to transactions list | `pocketflow://transactions` |
| `pocketflow://transactions/add` | Navigate to transactions and open add dialog | `pocketflow://transactions/add` |
| `pocketflow://accounts` | Navigate to accounts screen | `pocketflow://accounts` |
| `pocketflow://budgets` | Navigate to budgets screen | `pocketflow://budgets` |
| `pocketflow://goals` | Navigate to savings goals screen | `pocketflow://goals` |
| `pocketflow://settings` | Navigate to settings/profile screen | `pocketflow://settings` |
| `pocketflow://profile` | Alias for settings | `pocketflow://profile` |
| `pocketflow://chat` | Navigate to AI chat screen | `pocketflow://chat` |

## Testing Deep Links

### Android (ADB)

Test deep links using ADB commands:

```bash
# Navigate to home
adb shell am start -W -a android.intent.action.VIEW -d "pocketflow://home" com.example.pocket_flow

# Open transactions
adb shell am start -W -a android.intent.action.VIEW -d "pocketflow://transactions" com.example.pocket_flow

# Open add transaction
adb shell am start -W -a android.intent.action.VIEW -d "pocketflow://transactions/add" com.example.pocket_flow

# Navigate to budgets
adb shell am start -W -a android.intent.action.VIEW -d "pocketflow://budgets" com.example.pocket_flow
```

### iOS (Simulator)

Test deep links using xcrun:

```bash
# Navigate to home
xcrun simctl openurl booted "pocketflow://home"

# Open transactions
xcrun simctl openurl booted "pocketflow://transactions"

# Navigate to accounts
xcrun simctl openurl booted "pocketflow://accounts"
```

### Web Browser (for testing HTML links)

Create an HTML page with deep link buttons:

```html
<!DOCTYPE html>
<html>
<head>
    <title>PocketFlow Deep Link Test</title>
</head>
<body>
    <h1>PocketFlow Deep Link Test</h1>
    <ul>
        <li><a href="pocketflow://home">Home</a></li>
        <li><a href="pocketflow://transactions">Transactions</a></li>
        <li><a href="pocketflow://transactions/add">Add Transaction</a></li>
        <li><a href="pocketflow://accounts">Accounts</a></li>
        <li><a href="pocketflow://budgets">Budgets</a></li>
        <li><a href="pocketflow://goals">Savings Goals</a></li>
        <li><a href="pocketflow://settings">Settings</a></li>
        <li><a href="pocketflow://chat">AI Chat</a></li>
    </ul>
</body>
</html>
```

## Implementation Details

### Architecture

- **Package**: `app_links` (v6.0.0+)
- **Service**: [deep_link_service.dart](lib/services/deep_link_service.dart)
- **Integration**: Initialized in [main.dart](lib/main.dart) on app startup

### Platform Configuration

#### Android
Deep link intent filters are configured in [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml):

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="pocketflow"/>
</intent-filter>
```

#### iOS
URL schemes are configured in [Info.plist](ios/Runner/Info.plist):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.pocketflow.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>pocketflow</string>
        </array>
    </dict>
</array>
```

### Adding New Deep Links

1. Update the `_parseDeepLink` method in [deep_link_service.dart](lib/services/deep_link_service.dart)
2. Add the route case in the `_setupDeepLinkHandler` switch statement in [main.dart](lib/main.dart)
3. Update this documentation

Example:

```dart
// In deep_link_service.dart
case 'reports':
  return DeepLinkRoute(route: 'reports');

// In main.dart _setupDeepLinkHandler()
case 'reports':
  // Navigate to reports screen
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ReportsScreen()),
  );
  break;
```

## Use Cases

### External Integration
- Calendar reminders with direct links to add transactions
- Email templates with links to specific budgets
- Browser bookmarks for quick access to screens
- Share functionality to send deep links to other users

### Automation
- Tasker/Shortcuts: Automate navigation based on time/location
- NFC tags: Tap to open specific screen (e.g., tap at store to add transaction)
- Widget actions: Quick access buttons with deep links

### Future Enhancements
- Query parameters for pre-filling forms: `pocketflow://transactions/add?amount=50&category=Food`
- Entity-specific links: `pocketflow://transactions/123` (view transaction #123)
- Universal Links (HTTPS): `https://pocketflow.app/transactions` (requires domain setup)
- Deferred deep linking: Handle deep links after app installation

## Logging

Deep link events are logged via [AppLogger](lib/services/app_logger.dart):

```dart
AppLogger.log(
  LogLevel.info,
  LogCategory.navigation,
  'Deep link received',
  detail: 'pocketflow://transactions',
);
```

Check logs for debugging: `flutter logs` or view in the app's log viewer.
