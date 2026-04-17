import 'package:flutter/material.dart';

/// Interface for theme service
abstract class IThemeService extends ChangeNotifier {
  /// Current theme mode
  ThemeMode get themeMode;

  /// Is dark mode enabled
  bool get isDark;

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode);

  /// Toggle theme
  Future<void> toggleTheme();

  /// Initialize the service
  Future<void> init();

  /// Get card gradient
  LinearGradient get cardGradient;

  /// Get primary shadow
  List<BoxShadow> get primaryShadow;
}
