/// Input sanitization to prevent injection attacks and clean user input
library;

import 'sanitization_rules.dart';

/// Base class for sanitizing different types of input
abstract class Sanitizer<T> {
  /// Sanitize the input value
  T sanitize(T value);
  
  /// Check if value needs sanitization
  bool needsSanitization(T value);
}

/// Sanitizes text input by removing dangerous patterns and trimming
class TextSanitizer implements Sanitizer<String> {
  final int? maxLength;
  final bool trimWhitespace;
  final bool removeHtml;
  final bool preventSqlInjection;
  final bool preventXss;
  
  const TextSanitizer({
    this.maxLength,
    this.trimWhitespace = true,
    this.removeHtml = true,
    this.preventSqlInjection = true,
    this.preventXss = true,
  });
  
  @override
  String sanitize(String value) {
    var result = value;
    
    // Trim whitespace
    if (trimWhitespace) {
      result = result.trim();
    }
    
    // Remove HTML tags
    if (removeHtml) {
      result = _stripHtml(result);
    }
    
    // Prevent SQL injection
    if (preventSqlInjection) {
      result = _preventSqlInjection(result);
    }
    
    // Prevent XSS
    if (preventXss) {
      result = _preventXss(result);
    }
    
    // Enforce max length
    if (maxLength != null && result.length > maxLength!) {
      result = result.substring(0, maxLength);
    }
    
    return result;
  }
  
  @override
  bool needsSanitization(String value) {
    if (trimWhitespace && value != value.trim()) return true;
    if (removeHtml && _containsHtml(value)) return true;
    if (preventSqlInjection && _containsSqlPatterns(value)) return true;
    if (preventXss && _containsXssPatterns(value)) return true;
    if (maxLength != null && value.length > maxLength!) return true;
    return false;
  }
  
  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
  
  bool _containsHtml(String input) {
    return RegExp(r'<[^>]*>').hasMatch(input);
  }
  
  String _preventSqlInjection(String input) {
    // Remove or escape common SQL injection patterns
    return input
        .replaceAll("'", "''") // Escape single quotes
        .replaceAll(';--', '') // Remove comment patterns
        .replaceAll('/*', '')
        .replaceAll('*/', '')
        .replaceAll('xp_', '') // Remove SQL Server extended procedures
        .replaceAll('sp_', ''); // Remove SQL Server stored procedures
  }
  
  bool _containsSqlPatterns(String input) {
    final sqlPatterns = [
      RegExp(r'\bSELECT\b', caseSensitive: false),
      RegExp(r'\bINSERT\b', caseSensitive: false),
      RegExp(r'\bUPDATE\b', caseSensitive: false),
      RegExp(r'\bDELETE\b', caseSensitive: false),
      RegExp(r'\bDROP\b', caseSensitive: false),
      RegExp(r'\bUNION\b', caseSensitive: false),
      RegExp(r';--'),
      RegExp(r'/\*.*\*/'),
    ];
    return sqlPatterns.any((pattern) => pattern.hasMatch(input));
  }
  
  String _preventXss(String input) {
    return input
        .replaceAll('<script', '&lt;script')
        .replaceAll('</script>', '&lt;/script&gt;')
        .replaceAll('javascript:', '')
        .replaceAll('onerror=', '')
        .replaceAll('onload=', '')
        .replaceAll('onclick=', '');
  }
  
  bool _containsXssPatterns(String input) {
    final xssPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'onerror\s*=', caseSensitive: false),
      RegExp(r'onload\s*=', caseSensitive: false),
      RegExp(r'onclick\s*=', caseSensitive: false),
    ];
    return xssPatterns.any((pattern) => pattern.hasMatch(input));
  }
}

/// Sanitizes numeric input to ensure valid numbers
class NumberSanitizer implements Sanitizer<String> {
  final double? min;
  final double? max;
  final int? decimalPlaces;
  final bool allowNegative;
  
  const NumberSanitizer({
    this.min,
    this.max,
    this.decimalPlaces,
    this.allowNegative = true,
  });
  
  @override
  String sanitize(String value) {
    // Remove non-numeric characters (except decimal point and minus)
    var cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    
    // Handle negative numbers
    if (!allowNegative) {
      cleaned = cleaned.replaceAll('-', '');
    } else {
      // Ensure only one minus sign at the start
      if (cleaned.startsWith('-')) {
        cleaned = '-${cleaned.substring(1).replaceAll('-', '')}';
      } else {
        cleaned = cleaned.replaceAll('-', '');
      }
    }
    
    // Ensure only one decimal point
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
    }
    
    // Parse and validate range
    final number = double.tryParse(cleaned);
    if (number != null) {
      var result = number;
      if (min != null && result < min!) result = min!;
      if (max != null && result > max!) result = max!;
      
      // Format with decimal places
      if (decimalPlaces != null) {
        return result.toStringAsFixed(decimalPlaces!);
      }
      return result.toString();
    }
    
    return cleaned;
  }
  
  @override
  bool needsSanitization(String value) {
    return RegExp(r'[^\d.-]').hasMatch(value) ||
           value.split('.').length > 2 ||
           (!allowNegative && value.contains('-'));
  }
}

/// Sanitizes currency amount input
class AmountSanitizer implements Sanitizer<String> {
  final double? maxAmount;
  final bool allowNegative;
  
  const AmountSanitizer({
    this.maxAmount,
    this.allowNegative = false,
  });
  
  @override
  String sanitize(String value) {
    // Remove currency symbols and whitespace
    var cleaned = value
        .replaceAll(RegExp(r'[$₹€£¥₹]'), '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    
    // Use NumberSanitizer for the rest
    final numberSanitizer = NumberSanitizer(
      min: allowNegative ? null : 0.0,
      max: maxAmount,
      decimalPlaces: 2,
      allowNegative: allowNegative,
    );
    
    return numberSanitizer.sanitize(cleaned);
  }
  
  @override
  bool needsSanitization(String value) {
    return RegExp(r'[$₹€£¥,\s]').hasMatch(value);
  }
}

/// Sanitizes date input strings
class DateSanitizer implements Sanitizer<String> {
  @override
  String sanitize(String value) {
    // Remove any non-date characters
    var cleaned = value.replaceAll(RegExp(r'[^\d/\-: ]'), '');
    
    // Normalize date separators to hyphens
    cleaned = cleaned
        .replaceAll('/', '-')
        .trim();
    
    return cleaned;
  }
  
  @override
  bool needsSanitization(String value) {
    return RegExp(r'[^\d/\-: ]').hasMatch(value);
  }
}

/// Sanitizes category names
class CategorySanitizer implements Sanitizer<String> {
  static const maxLength = 50;
  
  const CategorySanitizer();
  
  @override
  String sanitize(String value) {
    final textSanitizer = TextSanitizer(
      maxLength: maxLength,
      trimWhitespace: true,
      removeHtml: true,
      preventSqlInjection: true,
      preventXss: true,
    );
    
    var cleaned = textSanitizer.sanitize(value);
    
    // Remove special characters that might cause issues
    cleaned = cleaned.replaceAll(RegExp(r'[<>"|\\]'), '');
    
    // Collapse multiple spaces into one
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned;
  }
  
  @override
  bool needsSanitization(String value) {
    return value != sanitize(value);
  }
}

/// Pre-configured sanitizers for common use cases
class InputSanitizers {
  static const transaction = TextSanitizer(maxLength: 500);
  static const transactionNote = TextSanitizer(maxLength: 1000);
  static const accountName = TextSanitizer(maxLength: 100);
  static const budgetName = TextSanitizer(maxLength: 100);
  static const goalName = TextSanitizer(maxLength: 100);
  static const category = CategorySanitizer();
  static const amount = AmountSanitizer();
  static const chatMessage = TextSanitizer(maxLength: 5000);
  
  /// Sanitize transaction amount
  static String sanitizeAmount(String value) => amount.sanitize(value);
  
  /// Sanitize transaction note
  static String sanitizeNote(String value) => transactionNote.sanitize(value);
  
  /// Sanitize category name
  static String sanitizeCategory(String value) => category.sanitize(value);
  
  /// Sanitize account name
  static String sanitizeAccountName(String value) => accountName.sanitize(value);
  
  /// Sanitize chat message
  static String sanitizeChatMessage(String value) => chatMessage.sanitize(value);
}
