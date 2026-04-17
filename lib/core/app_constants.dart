/// Application-wide constants
/// Keep all magic numbers, durations, and configuration values here
library app_constants;

import 'package:flutter/material.dart';

/// UI Layout Constants
class LayoutConstants {
  LayoutConstants._();

  // Padding & Margins
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Aliases for shorter names
  static const double paddingXS = paddingXSmall;
  static const double paddingS = paddingSmall;
  static const double paddingM = paddingMedium;
  static const double paddingL = paddingLarge;
  static const double paddingXL = paddingXLarge;

  // Border Radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Aliases for border radius
  static const double borderRadiusS = radiusSmall;
  static const double borderRadiusM = radiusMedium;
  static const double borderRadiusL = radiusLarge;
  static const double borderRadiusXL = radiusXLarge;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
  static const double iconXXLarge = 64.0;

  // Widget Heights
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double listItemHeight = 72.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 56.0;

  // Card/Container Elevation
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
}

/// Animation & Timing Constants
class AnimationConstants {
  AnimationConstants._();

  // Durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVerySlow = Duration(milliseconds: 1000);

  // Shorter aliases
  static const Duration fast = durationFast;
  static const Duration normal = durationNormal;
  static const Duration slow = durationSlow;
  static const Duration verySlow = durationVerySlow;

  // Debounce/Throttle
  static const Duration debounceDelay = Duration(milliseconds: 500);
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration filterDebounce = Duration(milliseconds: 400);

  // Curves
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveAccelerate = Curves.easeIn;
  static const Curve curveDecelerate = Curves.easeOut;
}

/// Network & API Constants
class NetworkConstants {
  NetworkConstants._();

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Retry
  static const int maxRetryAttempts = 3;
  static const Duration retryInitialDelay = Duration(seconds: 1);
  static const Duration retryMaxDelay = Duration(seconds: 10);
  static const double retryBackoffMultiplier = 2.0;

  // Connection Check
  static const Duration connectivityCheckInterval = Duration(seconds: 10);
  static const String connectivityTestHost = 'google.com';
}

/// Database Constants
class DatabaseConstants {
  DatabaseConstants._();

  // Database Info
  static const String databaseName = 'pocket_flow.db';
  static const int databaseVersion = 1;

  // Pagination
  static const int defaultPageSize = 20;
  static const int transactionPageSize = 50;
  static const int searchResultPageSize = 30;

  // Cache
  static const Duration cacheExpirationTime = Duration(minutes: 5);
  static const int maxCacheSize = 100;

  // Query Limits
  static const int maxQueryResults = 1000;
  static const int recentItemsLimit = 10;
  static const int topCategoriesLimit = 5;
}

/// File & Storage Constants
class StorageConstants {
  StorageConstants._();

  // File Sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5 MB
  static const int maxExportSize = 50 * 1024 * 1024; // 50 MB
  static const int maxBackupSize = 100 * 1024 * 1024; // 100 MB

  // Keys for SharedPreferences
  static const String keyHasSeenWelcome = 'has_seen_welcome';
  static const String keyThemeMode = 'theme_mode';
  static const String keyTextScale = 'text_scale';
  static const String keyLeftHanded = 'left_handed';
  static const String keyLastBackup = 'last_backup';
  static const String keyAutoBackup = 'auto_backup';

  // State Persistence
  static const String statePersistencePrefix = 'ui_state_';
}

/// Validation Constants
class ValidationConstants {
  ValidationConstants._();

  // String Lengths
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxNoteLength = 1000;
  static const int minPasswordLength = 8;

  // Number Ranges
  static const double minAmount = 0.01;
  static const double maxAmount = 999999999.99;
  static const int minAmountCents = 1; // Minimum amount in cents
  static const int minYear = 2000;
  static const int maxYear = 2100;

  // Patterns
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phonePattern = r'^\+?[\d\s-()]+$';
}

/// UI Text Constants
class TextConstants {
  TextConstants._();

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'No internet connection. Please check your network.';
  static const String errorDatabase = 'Database error occurred. Please try again.';
  static const String errorValidation = 'Please check your input and try again.';
  static const String errorPermission = 'Permission denied. Please grant required permissions.';
  static const String errorTimeout = 'Request timed out. Please try again.';

  // Success Messages
  static const String successSave = 'Saved successfully';
  static const String successDelete = 'Deleted successfully';
  static const String successUpdate = 'Updated successfully';
  static const String successExport = 'Exported successfully';
  static const String successImport = 'Imported successfully';

  // Confirmation Messages
  static const String confirmDelete = 'Are you sure you want to delete this item?';
  static const String confirmClear = 'Are you sure you want to clear all data?';
  static const String confirmLogout = 'Are you sure you want to log out?';

  // Empty States
  static const String emptyTransactions = 'No transactions yet';
  static const String emptyAccounts = 'No accounts yet';
  static const String emptyBudgets = 'No budgets yet';
  static const String emptySavings = 'No savings goals yet';
  static const String emptySearch = 'No results found';
}

/// Feature Flags
class FeatureFlags {
  FeatureFlags._();

  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  static const bool enablePremiumFeatures = true;
  static const bool enableAIChat = true;
  static const bool enableOfflineMode = true;
  static const bool enableDebugLogging = true;
}

/// App Metadata
class AppMetadata {
  AppMetadata._();

  static const String appName = 'PocketFlow';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String supportEmail = 'support@pocketflow.app';
  static const String websiteUrl = 'https://pocketflow.app';
  static const String privacyPolicyUrl = 'https://pocketflow.app/privacy';
  static const String termsOfServiceUrl = 'https://pocketflow.app/terms';
}
