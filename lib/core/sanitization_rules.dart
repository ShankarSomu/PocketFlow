/// Validation rules for input sanitization
library;

/// Base class for sanitization rules
abstract class SanitizationRule {
  /// Check if the value passes this rule
  bool validate(String value);
  
  /// Get error message if validation fails
  String get errorMessage;
}

/// Rule for maximum length validation
class MaxLengthRule implements SanitizationRule {
  final int maxLength;
  
  const MaxLengthRule(this.maxLength);
  
  @override
  bool validate(String value) => value.length <= maxLength;
  
  @override
  String get errorMessage => 'Maximum length is $maxLength characters';
}

/// Rule for minimum length validation
class MinLengthRule implements SanitizationRule {
  final int minLength;
  
  const MinLengthRule(this.minLength);
  
  @override
  bool validate(String value) => value.length >= minLength;
  
  @override
  String get errorMessage => 'Minimum length is $minLength characters';
}

/// Rule for allowed characters
class AllowedCharactersRule implements SanitizationRule {
  final String pattern;
  final String description;
  
  const AllowedCharactersRule(this.pattern, {required this.description});
  
  @override
  bool validate(String value) {
    final regex = RegExp(pattern);
    return regex.hasMatch(value);
  }
  
  @override
  String get errorMessage => 'Only $description are allowed';
}

/// Rule for disallowed patterns (security)
class DisallowedPatternRule implements SanitizationRule {
  final List<RegExp> patterns;
  final String description;
  
  const DisallowedPatternRule(this.patterns, {required this.description});
  
  @override
  bool validate(String value) {
    return !patterns.any((pattern) => pattern.hasMatch(value));
  }
  
  @override
  String get errorMessage => '$description are not allowed';
}

/// Pre-defined disallowed patterns for security
class SecurityPatterns {
  /// SQL injection patterns
  static final sqlInjection = DisallowedPatternRule(
    [
      RegExp(r'\bSELECT\b', caseSensitive: false),
      RegExp(r'\bINSERT\b', caseSensitive: false),
      RegExp(r'\bUPDATE\b', caseSensitive: false),
      RegExp(r'\bDELETE\b', caseSensitive: false),
      RegExp(r'\bDROP\b', caseSensitive: false),
      RegExp(r'\bUNION\b', caseSensitive: false),
      RegExp(r'\bEXEC\b', caseSensitive: false),
      RegExp(r';--'),
      RegExp(r'/\*.*\*/'),
      RegExp(r'\bxp_\w+', caseSensitive: false),
      RegExp(r'\bsp_\w+', caseSensitive: false),
    ],
    description: 'SQL commands',
  );
  
  /// XSS (Cross-Site Scripting) patterns
  static final xss = DisallowedPatternRule(
    [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'</script>', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'onerror\s*=', caseSensitive: false),
      RegExp(r'onload\s*=', caseSensitive: false),
      RegExp(r'onclick\s*=', caseSensitive: false),
      RegExp(r'onmouseover\s*=', caseSensitive: false),
      RegExp(r'onfocus\s*=', caseSensitive: false),
      RegExp(r'<iframe', caseSensitive: false),
      RegExp(r'<embed', caseSensitive: false),
      RegExp(r'<object', caseSensitive: false),
    ],
    description: 'Script tags and event handlers',
  );
  
  /// HTML injection patterns
  static final htmlInjection = DisallowedPatternRule(
    [
      RegExp(r'<[^>]+>'),
    ],
    description: 'HTML tags',
  );
  
  /// Path traversal patterns
  static final pathTraversal = DisallowedPatternRule(
    [
      RegExp(r'\.\./'),
      RegExp(r'\.\.\\'),
    ],
    description: 'Path traversal patterns',
  );
}

/// Common sanitization rule sets
class RuleSets {
  /// Rules for transaction notes
  static const transactionNote = [
    MaxLengthRule(1000),
    MinLengthRule(1),
  ];
  
  /// Rules for account names
  static const accountName = [
    MaxLengthRule(100),
    MinLengthRule(1),
    AllowedCharactersRule(
      r"^[\w\s\-']+$",
      description: 'letters, numbers, spaces, hyphens, and apostrophes',
    ),
  ];
  
  /// Rules for category names
  static const categoryName = [
    MaxLengthRule(50),
    MinLengthRule(1),
    AllowedCharactersRule(
      r'^[\w\s\-&]+$',
      description: 'letters, numbers, spaces, hyphens, and ampersands',
    ),
  ];
  
  /// Rules for budget/goal names
  static const budgetName = [
    MaxLengthRule(100),
    MinLengthRule(1),
  ];
  
  /// Security rules (always apply these)
  static List<SanitizationRule> get security => [
    SecurityPatterns.sqlInjection,
    SecurityPatterns.xss,
  ];
}

/// Validator that checks multiple rules
class RuleValidator {
  final List<SanitizationRule> rules;
  
  const RuleValidator(this.rules);
  
  /// Validate value against all rules
  /// Returns null if valid, otherwise returns error message
  String? validate(String value) {
    for (final rule in rules) {
      if (!rule.validate(value)) {
        return rule.errorMessage;
      }
    }
    return null;
  }
  
  /// Check if value is valid
  bool isValid(String value) => validate(value) == null;
  
  /// Get all validation errors
  List<String> getAllErrors(String value) {
    return rules
        .where((rule) => !rule.validate(value))
        .map((rule) => rule.errorMessage)
        .toList();
  }
}
