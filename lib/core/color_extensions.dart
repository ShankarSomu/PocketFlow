import 'package:flutter/material.dart';

/// Color extensions for common opacity and manipulation operations
/// Reduces verbosity of repeated .withValues(alpha:) calls
extension ColorHelpers on Color {
  /// Apply subtle opacity (60% - 0.6)
  /// Common for secondary text and disabled states
  Color get subtle => withValues(alpha: 0.6);

  /// Apply lighter opacity (70% - 0.7)
  /// Useful for hover states and secondary elements
  Color get lighter => withValues(alpha: 0.7);

  /// Apply medium opacity (50% - 0.5)
  /// Half transparency
  Color get medium => withValues(alpha: 0.5);

  /// Apply faint opacity (30% - 0.3)
  /// For very subtle backgrounds
  Color get faint => withValues(alpha: 0.3);

  /// Apply very faint opacity (10% - 0.1)
  /// For extremely subtle backgrounds and overlays
  Color get veryFaint => withValues(alpha: 0.1);

  /// Apply barely visible opacity (5% - 0.05)
  /// For ultra-subtle effects
  Color get barelyVisible => withValues(alpha: 0.05);

  /// Apply custom alpha value with convenient method
  Color withAlpha(double alpha) => withValues(alpha: alpha);

  /// Create a darker version of the color
  /// [amount] - How much darker (0.0 to 1.0), default 0.1
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  /// Create a lighter version of the color
  /// [amount] - How much lighter (0.0 to 1.0), default 0.1
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  /// Get contrasting color (black or white)
  /// Useful for text color on colored backgrounds
  Color get contrastingColor {
    final luminance = computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Blend with another color
  /// [other] - Color to blend with
  /// [amount] - Blend amount (0.0 to 1.0)
  Color blend(Color other, double amount) {
    return Color.lerp(this, other, amount) ?? this;
  }
}

/// Extension for BuildContext to quickly access theme colors
extension ThemeContextExtension on BuildContext {
  /// Quick access to ColorScheme
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Quick access to TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Quick access to brightness
  Brightness get brightness => Theme.of(this).brightness;

  /// Check if dark mode is active
  bool get isDarkMode => brightness == Brightness.dark;

  /// Check if light mode is active
  bool get isLightMode => brightness == Brightness.light;
}

/// Predefined opacity constants for consistency
class AppOpacity {
  AppOpacity._();

  static const double full = 1.0;
  static const double high = 0.87;
  static const double medium = 0.6;
  static const double disabled = 0.38;
  static const double subtle = 0.5;
  static const double faint = 0.3;
  static const double veryFaint = 0.1;
  static const double overlay = 0.16;
  static const double hover = 0.08;
}
