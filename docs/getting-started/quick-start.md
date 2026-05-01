# Quick Start Guide

Get PocketFlow running in 5 minutes!

## Step 1: Prerequisites Check

Ensure you have Flutter installed:
```bash
flutter --version
```

Expected output: Flutter 3.0 or higher

> **New to Flutter?** See [Installation Guide](installation.md) first.

## Step 2: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/ShankarSomu/PocketFlow.git
cd PocketFlow

# Get dependencies
flutter pub get
```

## Step 3: Run the App

### Option A: Android Emulator

```bash
# Start an emulator (if not already running)
flutter emulators --launch <emulator_id>

# Run the app
flutter run
```

### Option B: Physical Device

1. Enable Developer Mode on your device:
   - **Android**: Settings → About Phone → Tap "Build Number" 7 times
   - **iOS**: Xcode → Window → Devices and Simulators

2. Connect device via USB

3. Run the app:
   ```bash
   flutter run
   ```

### Option C: Web (Development Only)

```bash
flutter run -d chrome
```

## Step 4: Grant Permissions

On first launch, PocketFlow will request permissions:

1. **SMS Permission** (Required)
   - Allows reading financial SMS messages
   - All processing happens locally

2. **Notification Permission** (Optional)
   - For transaction alerts and reminders

3. **Storage Permission** (For exports)
   - Needed to export data as CSV/JSON/PDF

## Step 5: Initial Setup

### Add Your First Account

1. Tap **"Accounts"** tab
2. Tap **"+"** button
3. Enter account details:
   - Name (e.g., "HDFC Savings")
   - Type (Bank/Credit Card/Cash/Investment)
   - Currency
   - Initial balance

### Sync SMS Messages

1. Tap **"Transactions"** tab
2. Pull to refresh or tap **"Sync SMS"**
3. App scans SMS for financial messages
4. Review and confirm detected transactions

## What's Next?

### Essential Features

- **Transactions**: View all detected transactions
- **Accounts**: Manage multiple accounts
- **Budgets**: Set spending limits by category
- **Insights**: View spending trends and patterns

### Learn More

- [Architecture Overview](../architecture/overview.md) - Understand system design
- [SMS Intelligence](../features/sms-intelligence/overview.md) - How SMS parsing works
- [Developer Guide](../development/developer-guide.md) - Contribute to the project

## Common Tasks

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/sms_parser_test.dart
```

### Hot Reload During Development

While app is running, press:
- `r` - Hot reload (preserves app state)
- `R` - Hot restart (resets app state)
- `q` - Quit

### Building for Production

```bash
# Android APK
flutter build apk --release

# iOS (requires macOS)
flutter build ios --release

# Web
flutter build web --release
```

## Troubleshooting Quick Fixes

### App Won't Build

```bash
flutter clean
flutter pub get
flutter run
```

### SMS Not Detected

1. Check SMS permission granted
2. Verify SMS format matches known patterns
3. Check app logs: `flutter logs`

### Performance Issues

```bash
# Run in profile mode for performance profiling
flutter run --profile
```

## Development Workflow

1. **Make Changes**: Edit code in `lib/`
2. **Hot Reload**: Press `r` to see changes
3. **Test**: Write tests in `test/`
4. **Commit**: Use conventional commits
5. **Push**: Create pull request

## Project Structure Quick Reference

```
lib/
├── main.dart           # App entry point
├── core/              # App initialization
├── services/          # Business logic (SMS parsing, etc.)
├── viewmodels/        # Screen state management
├── screens/           # UI screens
├── widgets/           # Reusable components
├── models/            # Data models
├── repositories/      # Data access
└── db/               # Database layer
```

## Get Help

- **Documentation**: Check [docs/index.md](../index.md)
- **Issues**: [GitHub Issues](https://github.com/ShankarSomu/PocketFlow/issues)
- **Troubleshooting**: [Reference guide](../reference/troubleshooting.md)

---

**Ready to dive deeper?** Check out the [Architecture Overview](../architecture/overview.md) to understand how PocketFlow works under the hood.
