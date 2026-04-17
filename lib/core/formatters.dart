import 'package:intl/intl.dart';

/// Centralized currency formatting utilities
/// Eliminates duplication of NumberFormat instances across the app
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Standard currency format with symbol and 2 decimal places
  /// Example: $1,234.56
  static final standard = NumberFormat.currency(symbol: '\$');

  /// Compact currency format for large numbers
  /// Example: $1.2K, $1.2M
  static final compact = NumberFormat.compactCurrency(symbol: r'$');

  /// Currency format with no decimal places
  /// Example: $1,234
  static final noDecimals = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  /// Simple currency format (used in some contexts)
  static final simple = NumberFormat.simpleCurrency();

  /// Format amount with standard currency format
  /// 
  /// [amount] - The amount to format
  /// [compact] - Use compact format for large numbers (default: false)
  /// [decimals] - Number of decimal places (default: 2, use 0 for none)
  static String format(num amount, {bool compact = false, int? decimals}) {
    if (compact) return CurrencyFormatter.compact.format(amount);
    if (decimals == 0) return noDecimals.format(amount);
    if (decimals != null) {
      return NumberFormat.currency(symbol: '\$', decimalDigits: decimals).format(amount);
    }
    return standard.format(amount);
  }

  /// Format amount as compact currency (e.g., $1.2K, $45M)
  static String formatCompact(num amount) => compact.format(amount);

  /// Format amount without decimal places (e.g., $1,234)
  static String formatNoDecimals(num amount) => noDecimals.format(amount);
}

/// Centralized date formatting utilities
/// Provides consistent date formatting patterns across the app
class DateFormatter {
  DateFormatter._();

  // Common format patterns as constants
  static const String shortDatePattern = 'MMM d';
  static const String mediumDatePattern = 'MMM d, yyyy';
  static const String dateTimePattern = 'd MMM, h:mm a';
  static const String fullDateTimePattern = 'MMM d, yyyy h:mm a';
  static const String timeOnlyPattern = 'h:mm a';
  static const String yearMonthPattern = 'MMMM yyyy';
  static const String dayMonthYearPattern = 'MMM d, yyyy';
  static const String csvDatePattern = 'yyyy-MM-dd';
  static const String filenameDatePattern = 'yyyyMMdd_HHmm';

  /// Format date with short format
  /// Example: "Jan 5", "Dec 31"
  static String short(DateTime date) => DateFormat(shortDatePattern).format(date);

  /// Format date with medium format
  /// Example: "Jan 5, 2024", "Dec 31, 2023"
  static String medium(DateTime date) => DateFormat(mediumDatePattern).format(date);

  /// Format date with time
  /// Example: "5 Jan, 3:45 PM"
  static String dateTime(DateTime date) => DateFormat(dateTimePattern).format(date);

  /// Format date with full date and time
  /// Example: "Jan 5, 2024 3:45 PM"
  static String full(DateTime date) => DateFormat(fullDateTimePattern).format(date);

  /// Format time only
  /// Example: "3:45 PM"
  static String timeOnly(DateTime date) => DateFormat(timeOnlyPattern).format(date);

  /// Format as year and month
  /// Example: "January 2024"
  static String yearMonth(DateTime date) => DateFormat(yearMonthPattern).format(date);

  /// Format for CSV export
  /// Example: "2024-01-05"
  static String csv(DateTime date) => DateFormat(csvDatePattern).format(date);

  /// Format for filenames
  /// Example: "20240105_1545"
  static String filename(DateTime date) => DateFormat(filenameDatePattern).format(date);

  /// Format with custom pattern
  /// 
  /// [date] - The date to format
  /// [pattern] - Custom DateFormat pattern
  static String custom(DateTime date, String pattern) {
    return DateFormat(pattern).format(date);
  }

  /// Format date relative to now
  /// Example: "Today", "Yesterday", "Jan 5"
  static String relative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) return 'Today';
    if (dateDay == yesterday) return 'Yesterday';
    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    }
    return short(date);
  }
}

/// Number formatting utilities
class NumberFormatter {
  NumberFormatter._();

  /// Format as percentage with specified decimal places
  /// Example: 45.6%, 100%
  static String percentage(num value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Format as compact number (K, M, B suffixes)
  /// Example: 1.2K, 45M, 1.2B
  static String compact(num value) {
    return NumberFormat.compact().format(value);
  }

  /// Format with thousands separator
  /// Example: 1,234,567
  static String withSeparator(num value) {
    return NumberFormat('#,###').format(value);
  }

  /// Format decimal with fixed places
  static String decimal(num value, int places) {
    return value.toStringAsFixed(places);
  }
}
