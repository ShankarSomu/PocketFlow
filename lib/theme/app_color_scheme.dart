import 'package:flutter/material.dart';

/// Semantic color tokens for the finance app, supporting light/dark modes.
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  // Core tokens
  final Color primary;
  final Color primaryVariant;
  final Color success;
  final Color warning;
  final Color error;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;

  // Graph tokens
  final Color graphPositiveStart;
  final Color graphPositiveEnd;
  final Color graphNegativeStart;
  final Color graphNegativeEnd;
  final Color graphNeutralStart;
  final Color graphNeutralEnd;
  final Color graphBackground;

  const AppColorScheme({
    required this.primary,
    required this.primaryVariant,
    required this.success,
    required this.warning,
    required this.error,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.graphPositiveStart,
    required this.graphPositiveEnd,
    required this.graphNegativeStart,
    required this.graphNegativeEnd,
    required this.graphNeutralStart,
    required this.graphNeutralEnd,
    required this.graphBackground,
  });

  static const light = AppColorScheme(
    primary: Color(0xFF5B8DBE),
    primaryVariant: Color(0xFF7BA5D1),
    success: Color(0xFF6EAD6F),
    warning: Color(0xFFE89C4A),
    error: Color(0xFFD96969),
    surface: Color(0xFFFAFAFA),
    onSurface: Color(0xFF212121),
    onSurfaceVariant: Color(0xFF757575),
    outline: Color(0xFFE0E0E0),
    graphPositiveStart: Color(0xFF4CAF50),
    graphPositiveEnd: Color(0xFFC8E6C9),
    graphNegativeStart: Color(0xFFF44336),
    graphNegativeEnd: Color(0xFFFFCDD2),
    graphNeutralStart: Color(0xFF1976D2),
    graphNeutralEnd: Color(0xFFBBDEFB),
    graphBackground: Color(0xFFFAFAFA),
  );

  static const dark = AppColorScheme(
    primary: Color(0xFF7BA5D1),
    primaryVariant: Color(0xFF9DBDD9),
    success: Color(0xFF7EAD7F),
    warning: Color(0xFFD9A566),
    error: Color(0xFFD17E7E),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFE0E0E0),
    onSurfaceVariant: Color(0xFFBDBDBD),
    outline: Color(0xFF424242),
    graphPositiveStart: Color(0xFF81C784),
    graphPositiveEnd: Color(0xFFA5D6A7),
    graphNegativeStart: Color(0xFFE57373),
    graphNegativeEnd: Color(0xFFFFAB91),
    graphNeutralStart: Color(0xFF90CAF9),
    graphNeutralEnd: Color(0xFFE3F2FD),
    graphBackground: Color(0xFF1E1E1E),
  );

  @override
  AppColorScheme copyWith({
    Color? primary,
    Color? primaryVariant,
    Color? success,
    Color? warning,
    Color? error,
    Color? surface,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? graphPositiveStart,
    Color? graphPositiveEnd,
    Color? graphNegativeStart,
    Color? graphNegativeEnd,
    Color? graphNeutralStart,
    Color? graphNeutralEnd,
    Color? graphBackground,
  }) {
    return AppColorScheme(
      primary: primary ?? this.primary,
      primaryVariant: primaryVariant ?? this.primaryVariant,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      graphPositiveStart: graphPositiveStart ?? this.graphPositiveStart,
      graphPositiveEnd: graphPositiveEnd ?? this.graphPositiveEnd,
      graphNegativeStart: graphNegativeStart ?? this.graphNegativeStart,
      graphNegativeEnd: graphNegativeEnd ?? this.graphNegativeEnd,
      graphNeutralStart: graphNeutralStart ?? this.graphNeutralStart,
      graphNeutralEnd: graphNeutralEnd ?? this.graphNeutralEnd,
      graphBackground: graphBackground ?? this.graphBackground,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryVariant: Color.lerp(primaryVariant, other.primaryVariant, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      graphPositiveStart: Color.lerp(graphPositiveStart, other.graphPositiveStart, t)!,
      graphPositiveEnd: Color.lerp(graphPositiveEnd, other.graphPositiveEnd, t)!,
      graphNegativeStart: Color.lerp(graphNegativeStart, other.graphNegativeStart, t)!,
      graphNegativeEnd: Color.lerp(graphNegativeEnd, other.graphNegativeEnd, t)!,
      graphNeutralStart: Color.lerp(graphNeutralStart, other.graphNeutralStart, t)!,
      graphNeutralEnd: Color.lerp(graphNeutralEnd, other.graphNeutralEnd, t)!,
      graphBackground: Color.lerp(graphBackground, other.graphBackground, t)!,
    );
  }
}
