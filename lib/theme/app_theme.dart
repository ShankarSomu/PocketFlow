import 'package:flutter/material.dart';

class AppTheme {
  // ── Color Palette ──────────────────────────────────────────────────────────
  
  // Primary colors
  static const emerald = Color(0xFF10B981); // emerald-500
  static const emeraldLight = Color(0xFFD1FAE5); // emerald-100
  static const emeraldDark = Color(0xFF047857); // emerald-700
  
  static const blue = Color(0xFF3B82F6); // blue-500
  static const blueLight = Color(0xFFDEEBFF); // blue-50
  
  static const indigo = Color(0xFF6C63FF); // Custom indigo
  static const indigoLight = Color(0xFFEEEDFF);
  
  // Semantic colors
  static const success = emerald;
  static const error = Color(0xFFEF4444); // red-500
  static const warning = Color(0xFFF59E0B); // amber-500
  static const info = blue;
  
  // Neutral colors
  static const slate900 = Color(0xFF0F172A);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);
  
  // Background colors
  static const background = Color(0xFFFAFAFA);
  static const surface = Colors.white;
  static const surfaceVariant = slate50;
  
  // ── Gradients ──────────────────────────────────────────────────────────────
  
  static const emeraldGradient = LinearGradient(
    colors: [emerald, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const blueGradient = LinearGradient(
    colors: [blue, Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const indigoGradient = LinearGradient(
    colors: [indigo, Color(0xFF5B52E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const slateGradient = LinearGradient(
    colors: [slate900, slate700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const emeraldBlueGradient = LinearGradient(
    colors: [emerald, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ── Shadows ────────────────────────────────────────────────────────────────
  
  static const cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];
  
  static const cardShadowHover = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
  
  static const emeraldShadow = [
    BoxShadow(
      color: Color(0x1A10B981),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  // ── Border Radius ──────────────────────────────────────────────────────────
  
  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusLarge = 16.0;
  static const radiusXLarge = 20.0;
  
  // ── Icon Sizes ─────────────────────────────────────────────────────────────
  
  static const iconSmall = 16.0;
  static const iconMedium = 24.0;
  static const iconLarge = 32.0;
  static const iconXLarge = 40.0;
  
  // ── Icon Helpers ───────────────────────────────────────────────────────────
  
  /// Creates an icon with circular colored background
  static Widget circularIcon({
    required IconData icon,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    double size = iconLarge,
    double iconSize = iconMedium,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
  
  /// Creates an icon with gradient circular background
  static Widget gradientCircularIcon({
    required IconData icon,
    required Gradient gradient,
    Color iconColor = Colors.white,
    double size = iconLarge,
    double iconSize = iconMedium,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
  
  /// Creates an icon with rounded square background
  static Widget squareIcon({
    required IconData icon,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    double size = iconLarge,
    double iconSize = iconMedium,
    double radius = radiusSmall,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
  
  // ── Theme Data ─────────────────────────────────────────────────────────────
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: indigo,
        onPrimary: Colors.white,
        secondary: emerald,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: slate900,
        surfaceContainerHighest: surfaceVariant,
      ),
      scaffoldBackgroundColor: background,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        iconTheme: IconThemeData(color: slate900),
      ),
      
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
          side: BorderSide(color: slate200),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate900,
          side: const BorderSide(color: slate300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: indigo,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: slate300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: slate300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: indigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: slate400),
        labelStyle: const TextStyle(color: slate600),
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: indigo,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: indigo,
        unselectedItemColor: slate400,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      dividerTheme: const DividerThemeData(
        color: slate200,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
