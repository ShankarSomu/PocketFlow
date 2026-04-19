/// Privacy Guard - Ensures sensitive information is never stored
/// Filters OTP, passwords, PIN codes, SSN, Aadhaar, and other sensitive data
class PrivacyGuard {
  // ── OTP/Password Detection Patterns ─────────────────────────────────────────
  
  static final _otpPatterns = [
    // OTP with code nearby
    RegExp(r'\b\d{4,6}\b.{0,20}(?:OTP|code|verification|pin|password)', caseSensitive: false),
    RegExp(r'(?:OTP|code|verification|pin|password).{0,20}\b\d{4,6}\b', caseSensitive: false),
    
    // One-time password/pin variations
    RegExp('one.?time.?(?:password|pin|code)', caseSensitive: false),
    RegExp('(?:verification|security).?code', caseSensitive: false),
    
    // Password/PIN reveals
    RegExp(r'(?:password|pin|cvv|security code) is \w+', caseSensitive: false),
    RegExp(r'your (?:password|pin) (?:is|:)\s*\w+', caseSensitive: false),
    
    // Common OTP message patterns
    RegExp('do not share this (?:OTP|code|pin)', caseSensitive: false),
    RegExp('(?:OTP|code) to (?:verify|authenticate|confirm)', caseSensitive: false),
  ];

  // ── Personal Identification Numbers ─────────────────────────────────────────
  
  static final _sensitiveNumberPatterns = [
    // SSN (US) - 9 digits
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    RegExp(r'\b\d{9}\b'),
    
    // Aadhaar (India) - 12 digits
    RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b'),
    RegExp(r'\b\d{12}\b'),
    
    // Full credit card numbers (16 digits)
    RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
  ];

  // ── Account Credentials ─────────────────────────────────────────────────────
  
  static final _credentialPatterns = [
    RegExp(r'username.{0,10}[:=]\s*\w+', caseSensitive: false),
    RegExp(r'user\s*id.{0,10}[:=]\s*\w+', caseSensitive: false),
    RegExp(r'password.{0,10}[:=]\s*\w+', caseSensitive: false),
    RegExp(r'(?:cvv|cvc).{0,5}[:=]?\s*\d{3,4}', caseSensitive: false),
  ];

  // ── Public Methods ──────────────────────────────────────────────────────────

  /// Check if SMS contains sensitive information (OTP, password, SSN, etc.)
  /// Returns true if message should be completely skipped
  static bool isSensitive(String smsBody) {
    final body = smsBody.toLowerCase();
    
    // Check OTP patterns
    for (final pattern in _otpPatterns) {
      if (pattern.hasMatch(body)) return true;
    }
    
    // Check sensitive numbers
    for (final pattern in _sensitiveNumberPatterns) {
      if (pattern.hasMatch(smsBody)) return true; // Case-sensitive for numbers
    }
    
    // Check credential patterns
    for (final pattern in _credentialPatterns) {
      if (pattern.hasMatch(body)) return true;
    }
    
    return false;
  }

  /// Sanitize SMS before storage (remove/mask sensitive data)
  /// Returns cleaned SMS or null if entirely sensitive
  static String? sanitize(String smsBody) {
    // If entire message is sensitive, return null
    if (isSensitive(smsBody)) return null;
    
    String sanitized = smsBody;
    
    // Mask full card numbers (keep last 4)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(\d{4})[\s-]?(\d{4})[\s-]?(\d{4})[\s-]?(\d{4})\b'),
      (match) => '****-****-****-${match.group(4)}',
    );
    
    // Mask SSN/Aadhaar completely
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
      '***-**-****',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b'),
      '**** **** ****',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{9,12}\b'),
      '***REDACTED***',
    );
    
    // Remove CVV/CVC codes
    sanitized = sanitized.replaceAll(
      RegExp(r'(?:cvv|cvc).{0,5}[:=]?\s*\d{3,4}', caseSensitive: false),
      'CVV: ***',
    );
    
    return sanitized;
  }

  /// Check if message is a financial SMS (not OTP/personal)
  /// This is more permissive - allows transaction messages
  static bool isFinancialNotSensitive(String smsBody) {
    // First, reject if sensitive
    if (isSensitive(smsBody)) return false;
    
    // Then check if it contains financial keywords
    final body = smsBody.toLowerCase();
    
    final financialKeywords = [
      'debited', 'credited', 'transaction', 'payment', 'purchase',
      'balance', 'account', 'transfer', 'spent', 'received',
      'withdrawn', 'deposited', 'charged', 'refund', 'cashback',
    ];
    
    for (final keyword in financialKeywords) {
      if (body.contains(keyword)) return true;
    }
    
    return false;
  }

  /// Get reason why SMS was flagged as sensitive (for logging)
  static String? getSensitiveReason(String smsBody) {
    final body = smsBody.toLowerCase();
    
    // Check each pattern category
    for (final pattern in _otpPatterns) {
      if (pattern.hasMatch(body)) return 'Contains OTP/verification code';
    }
    
    for (final pattern in _sensitiveNumberPatterns) {
      if (pattern.hasMatch(smsBody)) return 'Contains SSN/Aadhaar/Card number';
    }
    
    for (final pattern in _credentialPatterns) {
      if (pattern.hasMatch(body)) return 'Contains login credentials';
    }
    
    return null;
  }

  /// Validate that stored data doesn't contain sensitive information
  /// Use this as a final safety check before database insert
  static bool validateStorageSafe(String? data) {
    if (data == null) return true;
    return !isSensitive(data);
  }
}
