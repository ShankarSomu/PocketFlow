# Installation Guide

This guide will help you set up PocketFlow for development or building from source.

## Prerequisites

Before installing PocketFlow, ensure you have the following:

### Required

- **Flutter SDK** 3.0 or higher
- **Dart** 3.0 or higher (included with Flutter)
- **Git** for version control

### Platform-Specific Requirements

#### Android Development
- Android Studio or Android SDK Command-line Tools
- Android SDK Platform 21 (Android 5.0) or higher
- Java Development Kit (JDK) 11 or higher

#### iOS Development (macOS only)
- Xcode 14 or higher
- CocoaPods (`sudo gem install cocoapods`)
- iOS 12.0 or higher deployment target

#### Desktop Development (Optional)
- **Windows**: Visual Studio 2019 or higher with C++ desktop development workload
- **Linux**: Required system libraries (GTK+ 3, X11, etc.)
- **macOS**: Xcode and command-line tools

## Flutter SDK Setup

### 1. Download Flutter

Visit [flutter.dev](https://flutter.dev/docs/get-started/install) and download Flutter for your platform.

### 2. Extract and Add to PATH

**Windows (PowerShell):**
```powershell
# Extract to a location (e.g., C:\src\flutter)
$env:Path += ";C:\src\flutter\bin"

# Verify installation
flutter --version
```

**macOS/Linux:**
```bash
# Extract to a location (e.g., ~/development/flutter)
export PATH="$PATH:$HOME/development/flutter/bin"

# Add to shell profile (~/.bashrc, ~/.zshrc, etc.)
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc

# Verify installation
flutter --version
```

### 3. Run Flutter Doctor

```bash
flutter doctor
```

This command checks your environment and displays a report. Follow any instructions to install missing dependencies.

## Clone the Repository

```bash
git clone https://github.com/ShankarSomu/PocketFlow.git
cd PocketFlow
```

## Install Dependencies

```bash
flutter pub get
```

This command downloads all Dart dependencies specified in `pubspec.yaml`.

## Platform-Specific Setup

### Android

1. **Accept Android Licenses:**
   ```bash
   flutter doctor --android-licenses
   ```

2. **Configure Local Properties (if needed):**
   Create `android/local.properties`:
   ```properties
   sdk.dir=C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
   ```

3. **Build APK (optional):**
   ```bash
   flutter build apk
   ```

### iOS (macOS only)

1. **Install CocoaPods Dependencies:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. **Open Xcode Project:**
   ```bash
   open ios/Runner.xcworkspace
   ```

3. **Configure Signing:**
   - Select your development team in Xcode
   - Configure bundle identifier

4. **Build IPA (optional):**
   ```bash
   flutter build ios
   ```

## Verify Installation

```bash
# Check for connected devices
flutter devices

# Run the app
flutter run
```

If successful, the app should launch on your connected device or emulator.

## Troubleshooting

### Common Issues

**Problem: "flutter: command not found"**
- Ensure Flutter bin directory is in your PATH
- Restart your terminal after modifying PATH

**Problem: Android licenses not accepted**
```bash
flutter doctor --android-licenses
```

**Problem: CocoaPods not found (iOS)**
```bash
sudo gem install cocoapods
```

**Problem: Build fails with "SDK version" errors**
- Update Flutter: `flutter upgrade`
- Clean and rebuild: `flutter clean && flutter pub get`

### Getting Help

- Check [Troubleshooting](../reference/troubleshooting.md)
- Run `flutter doctor -v` for detailed diagnostics
- Visit [Flutter Documentation](https://flutter.dev/docs)

## Next Steps

- [Quick Start Guide](quick-start.md) - Run the app in 5 minutes
- [Configuration](configuration.md) - Set up environment and settings
- [Developer Guide](../development/developer-guide.md) - Learn development workflow

---

*For production builds and distribution, see the [Developer Guide](../development/developer-guide.md).*
