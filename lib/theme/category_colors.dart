import 'package:flutter/material.dart';

/// Vibrant color palette for expense categories in charts and widgets
class CategoryColors {
  CategoryColors._();

  /// Get a vibrant, distinct color for any category
  static Color getColor(String category, {bool isDark = false}) {
    final key = category.toLowerCase().trim();
    
    // Predefined colors for common categories
    final Map<String, Color> lightColors = {
      'food': const Color(0xFFFF6B6B),           // Red
      'groceries': const Color(0xFF4ECDC4),      // Teal
      'transport': const Color(0xFF45B7D1),      // Sky Blue
      'shopping': const Color(0xFFFF8B94),       // Pink
      'entertainment': const Color(0xFF9B59B6),  // Purple
      'utilities': const Color(0xFFF39C12),      // Orange
      'healthcare': const Color(0xFF26DE81),     // Green
      'education': const Color(0xFF574B90),      // Indigo
      'housing': const Color(0xFFE67E22),        // Dark Orange
      'insurance': const Color(0xFF3498DB),      // Blue
      'personal': const Color(0xFFE74C3C),       // Crimson
      'savings': const Color(0xFF27AE60),        // Emerald
      'investments': const Color(0xFF8E44AD),    // Violet
      'gifts': const Color(0xFFEC407A),          // Pink
      'travel': const Color(0xFF00BCD4),         // Cyan
      'dining': const Color(0xFFFF5722),         // Deep Orange
      'subscriptions': const Color(0xFF9C27B0),  // Purple
      'fitness': const Color(0xFF4CAF50),        // Green
      'pets': const Color(0xFFFFAB00),           // Amber
      'income': const Color(0xFF4CAF50),         // Green
      'salary': const Color(0xFF66BB6A),         // Light Green
      'others': const Color(0xFF78909C),         // Blue Grey
      'other': const Color(0xFF78909C),          // Blue Grey
    };

    final Map<String, Color> darkColors = {
      'food': const Color(0xFFFF8787),           
      'groceries': const Color(0xFF6FE7DD),      
      'transport': const Color(0xFF67C9E4),      
      'shopping': const Color(0xFFFFA5AC),       
      'entertainment': const Color(0xFFB57EDC),  
      'utilities': const Color(0xFFF5B041),      
      'healthcare': const Color(0xFF4EEC9A),     
      'education': const Color(0xFF7268A8),      
      'housing': const Color(0xFFFF9549),        
      'insurance': const Color(0xFF5FAEE3),      
      'personal': const Color(0xFFFF6B6B),       
      'savings': const Color(0xFF52C77A),        
      'investments': const Color(0xFFA862C8),    
      'gifts': const Color(0xFFFF6090),          
      'travel': const Color(0xFF4DD0E1),         
      'dining': const Color(0xFFFF7043),         
      'subscriptions': const Color(0xFFBA68C8),  
      'fitness': const Color(0xFF66BB6A),        
      'pets': const Color(0xFFFFCA28),           
      'income': const Color(0xFF66BB6A),         
      'salary': const Color(0xFF81C784),         
      'others': const Color(0xFF90A4AE),         
      'other': const Color(0xFF90A4AE),          
    };

    final colorMap = isDark ? darkColors : lightColors;
    
    // Try exact match first
    if (colorMap.containsKey(key)) {
      return colorMap[key]!;
    }
    
    // Try partial match
    for (final entry in colorMap.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    
    // Fallback: Generate color from hash
    return _generateColorFromString(category);
  }

  /// Generate a vibrant color from string hash
  static Color _generateColorFromString(String text) {
    final hash = text.hashCode.abs();
    final hue = (hash % 360).toDouble();
    
    // Use high saturation and medium lightness for vibrant colors
    return HSLColor.fromAHSL(1.0, hue, 0.65, 0.55).toColor();
  }

  /// Get a list of distinct colors for a chart (for InteractiveDonut)
  static List<Color> getChartPalette({bool isDark = false}) {
    if (isDark) {
      return const [
        Color(0xFFFF8787),  // Red
        Color(0xFF6FE7DD),  // Teal
        Color(0xFF67C9E4),  // Sky Blue
        Color(0xFFFFA5AC),  // Pink
        Color(0xFFB57EDC),  // Purple
        Color(0xFFF5B041),  // Orange
        Color(0xFF4EEC9A),  // Green
        Color(0xFF7268A8),  // Indigo
        Color(0xFFFF9549),  // Dark Orange
        Color(0xFFBA68C8),  // Violet
      ];
    }
    
    return const [
      Color(0xFFFF6B6B),  // Red
      Color(0xFF4ECDC4),  // Teal
      Color(0xFF45B7D1),  // Sky Blue
      Color(0xFFFF8B94),  // Pink
      Color(0xFF9B59B6),  // Purple
      Color(0xFFF39C12),  // Orange
      Color(0xFF26DE81),  // Green
      Color(0xFF574B90),  // Indigo
      Color(0xFFE67E22),  // Dark Orange
      Color(0xFF8E44AD),  // Violet
    ];
  }
}
