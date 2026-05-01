# Configuration Guide

Learn how to configure PocketFlow for your development and production environments.

## Environment Configuration

PocketFlow uses environment-based configuration for different deployment scenarios.

### Debug vs Release

The app automatically detects debug/release mode:

```dart
// lib/core/config.dart
class AppConfig {
  static bool get isDebug => kDebugMode;
  static String get dbName => isDebug ? 'pocketflow_dev.db' : 'pocketflow.db';
}
```

## Database Configuration

### SQLite Settings

Database location and settings are configured in `lib/db/database.dart`:

```dart
// Default database name
static const String dbName = 'pocketflow.db';

// Enable foreign keys
PRAGMA foreign_keys = ON;

// Enable WAL mode for better concurrency
PRAGMA journal_mode = WAL;
```

### Database Location

- **Android**: `/data/data/com.yourpackage.pocketflow/databases/`
- **iOS**: Application Documents Directory
- **Desktop**: User's application data directory

### Database Migrations

Migrations are managed through version numbers in `database.dart`. When schema changes:

1. Increment `_version` constant
2. Add migration logic in `onUpgrade` callback
3. Test migration from previous versions

## SMS Processing Configuration

### SMS Patterns

SMS pattern configuration is in `lib/services/sms_patterns/`:

```dart
// lib/services/sms_patterns/pattern_config.dart
class SMSPatternConfig {
  // Minimum confidence threshold for auto-accepting
  static const double minConfidence = 0.75;
  
  // OTP patterns to exclude
  static final otpKeywords = ['OTP', 'verification code', 'PIN'];
}
```

### Machine Learning Model

ML model configuration in `lib/services/ml/ml_config.dart`:

```dart
class MLConfig {
  // Model files
  static const String modelPath = 'assets/ml/sms_classifier.tflite';
  static const String tokenizerPath = 'assets/ml/tokenizer_config.json';
  
  // Classification thresholds
  static const double minClassificationScore = 0.6;
}
```

## App Settings

### User Preferences

User-configurable settings stored using `shared_preferences`:

```dart
// Currency
await prefs.setString('currency', 'USD');

// Theme mode
await prefs.setString('theme_mode', 'system'); // light, dark, system

// Sync frequency
await prefs.setInt('sync_interval_hours', 24);
```

### Default Settings

Default values in `lib/core/constants.dart`:

```dart
class AppConstants {
  static const String defaultCurrency = 'INR';
  static const int defaultSyncInterval = 24; // hours
  static const int maxTransactionHistory = 90; // days
}
```

## Notification Configuration

### Android

Configure in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="@string/default_notification_channel_id" />
```

### iOS

Configure in `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## Permission Configuration

### Android Permissions

In `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Required -->
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />

<!-- Optional -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
    android:maxSdkVersion="28" />
```

### iOS Permissions

In `ios/Runner/Info.plist`:

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>We need notification access to alert you about transactions</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need photo library access to save exported reports</string>
```

## Build Configuration

### Android Build Variants

In `android/app/build.gradle.kts`:

```kotlin
android {
    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            shrinkResources = true
        }
    }
}
```

### iOS Build Configuration

In iOS project settings:
- **Debug**: Development certificates, no optimization
- **Release**: Distribution certificates, full optimization

## Feature Flags

Toggle features via `lib/core/feature_flags.dart`:

```dart
class FeatureFlags {
  static const bool enableMLClassification = true;
  static const bool enableVoiceInput = false;
  static const bool enablePremiumFeatures = true;
  static const bool enableExperimentalParser = false;
}
```

## Logging Configuration

### Development

Enable verbose logging in debug mode:

```dart
// lib/core/logger.dart
Logger.level = kDebugMode ? Level.verbose : Level.warning;
```

### Production

Disable sensitive logging:

```dart
class Logger {
  static void logTransaction(Transaction txn) {
    if (kDebugMode) {
      print('Transaction: ${txn.toJson()}');
    }
    // Never log SMS content in production
  }
}
```

## Performance Configuration

### Image Caching

```dart
// Adjust cache size if needed
PaintingBinding.instance.imageCache.maximumSize = 100;
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB
```

### List Performance

For large transaction lists:

```dart
ListView.builder(
  itemCount: transactions.length,
  cacheExtent: 100.0, // Adjust based on item height
  itemBuilder: (context, index) => TransactionTile(transactions[index]),
)
```

## Testing Configuration

### Test Environment

```dart
// test/test_helper.dart
void setUpTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Use in-memory database for tests
  AppConfig.useInMemoryDb = true;
}
```

### Mock Data

```dart
// test/fixtures/mock_data.dart
class MockData {
  static List<Transaction> transactions = [
    Transaction(id: 1, amount: 100.0, merchant: 'Test Store'),
    // ...
  ];
}
```

## Deployment Configuration

### Version Management

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1  # version+build_number
```

### Environment Variables

For sensitive configuration, use environment variables:

```bash
# .env (not committed to repo)
API_KEY=your_api_key_here
```

Load via flutter_dotenv:

```dart
await dotenv.load(fileName: ".env");
String apiKey = dotenv.env['API_KEY'] ?? '';
```

## Next Steps

- [Quick Start](quick-start.md) - Run the app
- [Developer Guide](../development/developer-guide.md) - Development workflow
- [Architecture Overview](../architecture/overview.md) - System design

---

*For production deployment configuration, see the [Developer Guide](../development/developer-guide.md#deployment).*
