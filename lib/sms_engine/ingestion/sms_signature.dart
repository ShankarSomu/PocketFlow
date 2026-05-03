/// Structural SMS signature - NO keyword matching.
/// Used for sender-aware similarity scoring.
class SmsSignature {
  const SmsSignature({
    required this.sender,
    required this.patternType,
    required this.lengthBucket,
    required this.hasNumber,
    required this.hasUrl,
  });

  final String sender;       // normalized sender ID or business name fingerprint
  final String patternType;  // otp | alert | transaction | promotion | bill_reminder | marketing | unknown
  final int lengthBucket;    // 0=short(<50), 1=medium(50-150), 2=long(>150)
  final bool hasNumber;
  final bool hasUrl;

  /// Build a signature from raw SMS text and sender.
  /// [sender] should be the actual SMS sender address (phone number or short code).
  /// [mlLabel] is the ML model's classification label if available.
  factory SmsSignature.from(String smsText, String? sender, {String? mlLabel}) {
    final text = smsText.toLowerCase();
    final normalizedSender = _normalizeSender(sender, text);
    // Use ML label as pattern type if provided, otherwise detect from text
    final patternType = mlLabel != null ? _mlLabelToPattern(mlLabel) : _detectPatternType(text);
    return SmsSignature(
      sender: normalizedSender,
      patternType: patternType,
      lengthBucket: smsText.length < 50 ? 0 : smsText.length < 150 ? 1 : 2,
      hasNumber: RegExp(r'\d').hasMatch(smsText),
      hasUrl: text.contains('http') || text.contains('www.') || text.contains('.com'),
    );
  }

  /// Map ML model labels to pattern types.
  static String _mlLabelToPattern(String mlLabel) {
    switch (mlLabel.toLowerCase()) {
      case 'debit':       return 'transaction_debit';
      case 'credit':      return 'transaction_credit';
      case 'transfer':    return 'transfer';
      case 'balance':     return 'alert';
      case 'reminder':    return 'bill_reminder';
      case 'non_financial': return 'non_financial';
      default:            return 'unknown';
    }
  }

  /// Normalize sender: use provided sender, or extract business name from SMS.
  static String _normalizeSender(String? sender, String textLower) {
    if (sender != null && sender.trim().isNotEmpty) {
      return sender.toLowerCase().trim();
    }
    // Extract business name fingerprint from SMS text
    // Look for capitalized words that appear to be business names
    return _extractBusinessFingerprint(textLower);
  }

  /// Extract a business name fingerprint from SMS text.
  /// Looks for patterns like "@BusinessName", "at BusinessName", or repeated capitalized words.
  static String _extractBusinessFingerprint(String textLower) {
    // Look for @mention pattern (e.g. "@PizzaTwist")
    final atMatch = RegExp(r'@(\w+)').firstMatch(textLower);
    if (atMatch != null) return atMatch.group(1)!;

    // Look for "at [Place]" pattern
    final atPlaceMatch = RegExp(r'\bat\s+([a-z][a-z0-9\s]{2,20}?)(?:\s*[,!.]|$)').firstMatch(textLower);
    if (atPlaceMatch != null) return atPlaceMatch.group(1)!.trim();

    // Look for "only at [Place]" or "visit [Place]"
    final visitMatch = RegExp(r'(?:only at|visit|from)\s+([a-z][a-z0-9\s]{2,20}?)(?:\s*[,!.]|$)').firstMatch(textLower);
    if (visitMatch != null) return visitMatch.group(1)!.trim();

    // No business name found - return empty (will rely on patternType only)
    return '';
  }

  static String _detectPatternType(String text) {
    // OTP / verification
    if (text.contains('otp') || text.contains('verification') || text.contains('one-time') ||
        text.contains('passcode') || text.contains('pin:')) {
      return 'otp';
    }
    // Marketing / promotional (check before transaction to avoid false positives)
    if (text.contains('order') || text.contains('pizza') || text.contains('bogo') ||
        text.contains('% off') || text.contains('deal') || text.contains('special') ||
        text.contains('weekend') || text.contains('dinner') || text.contains('lunch') ||
        text.contains('call') && (text.contains('order') || text.contains('visit')) ||
        text.contains('txt stop') || text.contains('text stop') ||
        text.contains('reply stop') || text.contains('opt out')) {
      return 'marketing';
    }
    // Promotional offers
    if (text.contains('offer') || text.contains('promo') || text.contains('discount') ||
        text.contains('sale') || text.contains('coupon') || text.contains('free')) {
      return 'promotion';
    }
    // Balance / account alerts
    if (text.contains('alert') || text.contains('balance') || text.contains('available')) {
      return 'alert';
    }
    // Bill reminders
    if (text.contains('due') || text.contains('bill') || text.contains('payment due') ||
        text.contains('minimum payment')) {
      return 'bill_reminder';
    }
    // Financial transactions
    if (text.contains('debited') || text.contains('credited') || text.contains('paid') ||
        text.contains('charge') || text.contains('deposit') || text.contains('withdrawal') ||
        text.contains('transaction') || text.contains('purchase')) {
      return 'transaction';
    }
    return 'unknown';
  }

  /// Structural similarity score (0.0 - 1.0). NO keyword matching.
  /// Weights: sender=0.6, patternType=0.3, structure=0.1
  /// When sender is empty, patternType carries more weight.
  double similarityTo(SmsSignature other) {
    double score = 0.0;

    if (sender.isNotEmpty && other.sender.isNotEmpty) {
      // Both have sender info - use full weight
      if (sender == other.sender) score += 0.6;
      if (patternType == other.patternType) score += 0.3;
    } else {
      // No sender info - patternType carries more weight
      if (patternType == other.patternType && patternType != 'unknown') score += 0.7;
      else if (patternType == other.patternType) score += 0.3;
    }

    if (lengthBucket == other.lengthBucket) score += 0.05;
    if (hasNumber == other.hasNumber) score += 0.025;
    if (hasUrl == other.hasUrl) score += 0.025;
    return score;
  }

  Map<String, dynamic> toMap() => {
    'sender': sender,
    'pattern_type': patternType,
    'length_bucket': lengthBucket,
    'has_number': hasNumber ? 1 : 0,
    'has_url': hasUrl ? 1 : 0,
  };

  factory SmsSignature.fromMap(Map<String, dynamic> m) => SmsSignature(
    sender: m['sender'] as String,
    patternType: m['pattern_type'] as String,
    lengthBucket: m['length_bucket'] as int,
    hasNumber: (m['has_number'] as int) == 1,
    hasUrl: (m['has_url'] as int) == 1,
  );
}
