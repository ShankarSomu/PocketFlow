import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_color_scheme.dart';

enum AppAccentColor { emerald, blue, purple, orange, rose, slate }

enum AppThemeMode { system, light, dark }

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  AppAccentColor _accent = AppAccentColor.emerald;
  AppThemeMode _mode = AppThemeMode.light;
  double _contrast = 1.0; // 0.7 – 1.3
  int _textSizeIndex = 1; // 0=small, 1=normal, 2=large
  bool _leftHanded = false;

  AppAccentColor get accent => _accent;
  AppThemeMode get mode => _mode;
  double get contrast => _contrast;
  int get textSizeIndex => _textSizeIndex;
  bool get leftHanded => _leftHanded;

  /// Text scale multiplier for the 3 text size options.
  double get textSizeScale {
    switch (_textSizeIndex) {
      case 0: return 0.85;
      case 2: return 1.2;
      default: return 1.0;
    }
  }

  ThemeMode get flutterThemeMode {
    switch (_mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  // ── Accent color mapping ──────────────────────────────────────────────────

  static const Map<AppAccentColor, Color> accentColors = {
    AppAccentColor.emerald: Color(0xFF059669),
    AppAccentColor.blue: Color(0xFF2563EB),
    AppAccentColor.purple: Color(0xFF7C3AED),
    AppAccentColor.orange: Color(0xFFEA580C),
    AppAccentColor.rose: Color(0xFFBE123C),
    AppAccentColor.slate: Color(0xFF475569),
  };

  static const Map<AppAccentColor, String> accentNames = {
    AppAccentColor.emerald: 'Emerald',
    AppAccentColor.blue: 'Ocean Blue',
    AppAccentColor.purple: 'Violet',
    AppAccentColor.orange: 'Sunset',
    AppAccentColor.rose: 'Rose',
    AppAccentColor.slate: 'Slate',
  };

  /// Raw accent color (not contrast-adjusted).
  Color get baseAccentColor => accentColors[_accent]!;

  /// The primary accent color, adjusted for current contrast (saturation/lightness).
  Color get primaryColor {
    final base = accentColors[_accent]!;
    if ((_contrast - 1.0).abs() < 0.02) return base;
    final hsl = HSLColor.fromColor(base);
    // Contrast > 1: more saturated + slightly darker
    // Contrast < 1: less saturated + slightly lighter
    final s = (hsl.saturation * _contrast).clamp(0.0, 1.0);
    final l = _contrast > 1.0
        ? (hsl.lightness * (2.0 - _contrast)).clamp(0.15, 0.85)
        : (hsl.lightness + (1.0 - _contrast) * 0.2).clamp(0.15, 0.85);
    return hsl.withSaturation(s).withLightness(l).toColor();
  }

  /// A dynamic card gradient using the primary color — replaces AppTheme.cardDarkGradient.
  LinearGradient get cardGradient => LinearGradient(
    colors: [primaryColor, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A dynamic shadow using the primary color — replaces AppTheme.blueShadow.
  List<BoxShadow> get primaryShadow => [
    BoxShadow(color: primaryColor.withValues(alpha: 0.40), blurRadius: 20, offset: const Offset(0, 6)),
    BoxShadow(color: primaryColor.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  /// A darker shade of the primary color (for gradients/shadows).
  Color get primaryDark {
    final c = primaryColor;
    return Color.fromARGB(
      c.alpha,
      (c.red * 0.65).round(),
      (c.green * 0.65).round(),
      (c.blue * 0.65).round(),
    );
  }

  /// Very dark shade for hero card backgrounds.
  Color get primaryDeep {
    final c = primaryColor;
    return Color.fromARGB(
      c.alpha,
      (c.red * 0.25).round(),
      (c.green * 0.25).round(),
      (c.blue * 0.25).round(),
    );
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final accentIdx = prefs.getInt('theme_accent') ?? 0; // default: emerald
    final modeIdx = prefs.getInt('theme_mode') ?? 1; // default: light
    final contrast = prefs.getDouble('theme_contrast') ?? 1.0;
    final textSize = prefs.getInt('theme_text_size') ?? 1; // default: normal
    final leftHanded = prefs.getBool('theme_left_handed') ?? false;
    _accent = AppAccentColor.values[accentIdx.clamp(0, AppAccentColor.values.length - 1)];
    _mode = AppThemeMode.values[modeIdx.clamp(0, AppThemeMode.values.length - 1)];
    _contrast = contrast.clamp(0.7, 1.3);
    _textSizeIndex = textSize.clamp(0, 2);
    _leftHanded = leftHanded;
    notifyListeners();
  }

  Future<void> setAccent(AppAccentColor accent) async {
    _accent = accent;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_accent', accent.index);
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setContrast(double contrast) async {
    _contrast = contrast.clamp(0.7, 1.3);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('theme_contrast', _contrast);
    notifyListeners();
  }

  Future<void> setTextSizeIndex(int index) async {
    _textSizeIndex = index.clamp(0, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_text_size', _textSizeIndex);
    notifyListeners();
  }

  Future<void> setLeftHanded(bool value) async {
    _leftHanded = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_left_handed', _leftHanded);
    notifyListeners();
  }

  // ── Theme Building ────────────────────────────────────────────────────────

  ThemeData buildLightTheme() {
    final seed = primaryColor;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
    ).copyWith(
      primary: seed,
      onPrimary: Colors.white,
      secondary: seed.withValues(alpha: 0.7),
      surface: const Color(0xFFFAFAFA),
      surfaceContainer: const Color(0xFFF5F5F5),
      surfaceContainerHighest: const Color(0xFFEEEEEE),
      onSurface: const Color(0xFF1A1A1A),
      onSurfaceVariant: const Color(0xFF616161),
      error: const Color(0xFFEF4444),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardTheme: CardThemeData(
        color: const Color(0xFFFAFAFA),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFE0E0E0).withValues(alpha: 0.5)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F5F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF424242)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seed,
          side: BorderSide(color: seed.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: seed),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? seed : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? seed.withValues(alpha: 0.4) : null),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0), thickness: 1, space: 1),
      extensions: const <ThemeExtension<dynamic>>[
        AppColorScheme.light,
      ],
    );
  }

  ThemeData buildDarkTheme() {
    final seed = primaryColor;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: seed,
      onPrimary: Colors.white,
      surface: const Color(0xFF1C1C1E),
      surfaceContainer: const Color(0xFF2C2C2E),
      surfaceContainerHighest: const Color(0xFF3A3A3C),
      onSurface: const Color(0xFFE5E5E7),
      onSurfaceVariant: const Color(0xFFAEAEB2),
      error: const Color(0xFFFF453A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF3A3A3C).withValues(alpha: 0.3)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFE5E5E7)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE5E5E7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seed,
          side: BorderSide(color: seed.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: seed),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? seed : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? seed.withValues(alpha: 0.4) : null),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF3A3A3C), thickness: 1, space: 1),
      extensions: const <ThemeExtension<dynamic>>[
        AppColorScheme.dark,
      ],
    );
  }
}

