import '../db/database.dart';
import '../models/sms_transaction_result.dart';

/// Rule-Based Account Identity Extraction Service
/// 
/// Similar to SMS Intelligence Engine, this service uses a rule-based
/// approach for extracting bank names and account identifiers from SMS text.
/// 
/// Key Features:
/// - Rule-based extraction (not hardcoded regex)
/// - Inverted index for fast keyword matching
/// - Region-aware bank matching
/// - Learning from feedback
/// - Confidence scoring
class AccountExtractionService {
  
  /// Extract account identity from SMS text using rule-based engine
  static Future<AccountIdentity> extractIdentity({
    required String smsText,
    required RegionEnum region,
    String? senderId,
  }) async {
    final lowerText = smsText.toLowerCase();
    final senderLower = senderId?.toLowerCase();
    
    // Extract bank name using rules
    final bank = await _extractBankName(
      smsText: smsText,
      lowerText: lowerText,
      region: region,
      senderLower: senderLower,
    );
    
    // Extract account identifier using rules
    final identifier = await _extractAccountIdentifier(
      smsText: smsText,
      lowerText: lowerText,
    );
    
    // Log extraction results for debugging
    print('[AccountExtraction] Region: ${region.name}, Bank: ${bank?.name} (conf: ${bank?.confidence}), ID: ${identifier?.value} (conf: ${identifier?.confidence})');
    
    return AccountIdentity(
      bank: bank?.name,
      bankConfidence: bank?.confidence ?? 0.0,
      accountIdentifier: identifier?.value,
      identifierConfidence: identifier?.confidence ?? 0.0,
      extractionMethod: 'rule_based',
    );
  }
  
  /// Extract bank name using pattern-based + fallback keyword matching
  static Future<_BankMatch?> _extractBankName({
    required String smsText,
    required String lowerText,
    required RegionEnum region,
    String? senderLower,
  }) async {
    // ═══════════════════════════════════════════════════════════════
    // PATTERN-BASED EXTRACTION (Priority 1)
    // Auto-detect banks from structural patterns
    // ═══════════════════════════════════════════════════════════════
    
    _BankMatch? patternMatch;
    
    // Pattern 1: Sender ID extraction (highest confidence)
    if (senderLower != null) {
      patternMatch = await _extractFromSenderId(senderLower);
      if (patternMatch != null) {
        print('[AccountExtraction] Pattern match from sender: ${patternMatch.name} (confidence: ${patternMatch.confidence})');
        return patternMatch;
      }
    }
    
    // Pattern 2: SMS header extraction (e.g., "Chase: Purchase of...")
    patternMatch = _extractFromSmsHeader(smsText);
    if (patternMatch != null) {
      print('[AccountExtraction] Pattern match from header: ${patternMatch.name} (confidence: ${patternMatch.confidence})');
      return patternMatch;
    }
    
    // Pattern 3: URL/Domain extraction (e.g., "chase.com")
    patternMatch = _extractFromDomain(lowerText);
    if (patternMatch != null) {
      print('[AccountExtraction] Pattern match from domain: ${patternMatch.name} (confidence: ${patternMatch.confidence})');
      return patternMatch;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // KEYWORD-BASED EXTRACTION (Fallback)
    // Use database rules for less structured SMS
    // ═══════════════════════════════════════════════════════════════
    
    final db = await AppDatabase.db();
    
    // Step 1: Find candidate rules using inverted index
    final words = _tokenize(lowerText);
    final candidateRuleIds = <int>{};
    
    for (final word in words) {
      final rows = await db.query(
        'account_extraction_index',
        where: 'keyword = ?',
        whereArgs: [word],
      );
      
      for (final row in rows) {
        candidateRuleIds.add(row['rule_id'] as int);
      }
    }
    
    // Also check sender ID if provided
    if (senderLower != null) {
      final senderWords = _tokenize(senderLower);
      for (final word in senderWords) {
        final rows = await db.query(
          'account_extraction_index',
          where: 'keyword = ?',
          whereArgs: [word],
        );
        
        for (final row in rows) {
          candidateRuleIds.add(row['rule_id'] as int);
        }
      }
    }
    
    if (candidateRuleIds.isEmpty) {
      return null;
    }
    
    // Step 2: Load rules and filter by region
    // CRITICAL: Only match banks from the detected region
    // - If region is US: Only US banks + global banks (region IS NULL)
    // - If region is INDIA: Only Indian banks + global banks (region IS NULL)
    // - If region is unknown: All banks (fallback)
    final String regionFilter;
    final List<dynamic> whereArgs;
    
    if (region == RegionEnum.unknown) {
      // Unknown region: check all banks
      regionFilter = 'rule_type = ? AND is_active = 1 AND id IN (${candidateRuleIds.join(',')})';
      whereArgs = ['bank_name'];
    } else {
      // Known region: ONLY match banks from this region OR global banks (NULL region)
      // Exclude banks from other regions
      regionFilter = 'rule_type = ? AND is_active = 1 AND (region = ? OR region IS NULL) AND id IN (${candidateRuleIds.join(',')})';
      whereArgs = ['bank_name', region.name];
    }
    
    final rules = await db.query(
      'account_extraction_rules',
      where: regionFilter,
      whereArgs: whereArgs,
      orderBy: 'priority DESC, confidence DESC',
    );
    
    print('[AccountExtraction] Region filter: $regionFilter, Args: $whereArgs');
    print('[AccountExtraction] Found ${rules.length} candidate rules after region filtering');
    
    // Step 3: Apply rules and find best match
    _BankMatch? bestMatch;
    
    for (final rule in rules) {
      final keywords = (rule['keywords'] as String).split(',');
      bool matched = false;
      String? matchedKeyword;
      
      // Check if any keyword matches
      for (final keyword in keywords) {
        final kw = keyword.trim().toLowerCase();
        if (lowerText.contains(kw) || (senderLower?.contains(kw) ?? false)) {
          matched = true;
          matchedKeyword = kw;
          break;
        }
      }
      
      if (matched) {
        print('[AccountExtraction] Matched rule: ${rule['output_value']} (region: ${rule['region']}, keyword: $matchedKeyword)');
        final confidence = (rule['confidence'] as num).toDouble();
        final priority = (rule['priority'] as num).toInt();
        
        // Prefer higher confidence and priority
        if (bestMatch == null || 
            priority > bestMatch.priority ||
            (priority == bestMatch.priority && confidence > bestMatch.confidence)) {
          bestMatch = _BankMatch(
            name: rule['output_value'] as String,
            confidence: confidence,
            ruleId: rule['id'] as int,
            priority: priority,
          );
        }
      }
    }
    
    // Step 4: Update rule usage stats
    if (bestMatch != null) {
      await db.update(
        'account_extraction_rules',
        {
          'last_used_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [bestMatch.ruleId],
      );
    }
    
    return bestMatch;
  }
  
  /// Extract account identifier using rule-based pattern matching
  static Future<_IdentifierMatch?> _extractAccountIdentifier({
    required String smsText,
    required String lowerText,
  }) async {
    // ═══════════════════════════════════════════════════════════════
    // STRUCTURAL ACCOUNT IDENTIFIER EXTRACTION
    // Uses mask strength, position, and context instead of keyword-based matching
    // ═══════════════════════════════════════════════════════════════
    
    // Find all masked 4-digit candidates
    final candidates = <_IdentifierCandidate>[];
    
    // Pattern 1: Asterisk-masked digits (e.g., ************3453, ****1234)
    final asteriskPattern = RegExp(r'(\*{4,})(\d{4})', caseSensitive: false);
    for (final match in asteriskPattern.allMatches(smsText)) {
      final maskLength = match.group(1)!.length;
      final digits = match.group(2)!;
      final position = match.start;
      
      candidates.add(_IdentifierCandidate(
        value: digits,
        position: position,
        maskLength: maskLength,
        fullMatch: match.group(0)!,
        hasHyphenSuffix: false,
      ));
    }
    
    // Pattern 2: X-masked digits (e.g., XXXX1234, XX1234)
    final xPattern = RegExp(r'([xX]{2,})(\d{4,6})', caseSensitive: false);
    for (final match in xPattern.allMatches(smsText)) {
      final maskLength = match.group(1)!.length;
      final digits = match.group(2)!;
      final position = match.start;
      
      // Check if part of a hyphenated sequence (service account reference)
      final hasHyphen = smsText.indexOf('-', match.end) == match.end;
      
      candidates.add(_IdentifierCandidate(
        value: digits.substring(digits.length - 4), // Last 4 digits
        position: position,
        maskLength: maskLength,
        fullMatch: match.group(0)!,
        hasHyphenSuffix: hasHyphen,
      ));
    }
    
    // Pattern 3: "ending in" or "last" patterns
    final endingPattern = RegExp(r'(?:ending|last)\s+(?:in\s+)?(\d{4})', caseSensitive: false);
    final endingMatch = endingPattern.firstMatch(lowerText);
    if (endingMatch != null) {
      candidates.add(_IdentifierCandidate(
        value: endingMatch.group(1)!,
        position: endingMatch.start,
        maskLength: 0, // No mask, but explicit indicator
        fullMatch: endingMatch.group(0)!,
        hasHyphenSuffix: false,
        explicitIndicator: true,
      ));
    }
    
    if (candidates.isEmpty) {
      return null;
    }
    
    // Score each candidate using structural features
    for (final candidate in candidates) {
      double score = 0.0;
      
      // A. MASK STRENGTH - longer mask = higher confidence payment instrument
      if (candidate.maskLength >= 10) {
        score += 3.0;
      } else if (candidate.maskLength >= 6) {
        score += 2.0;
      } else if (candidate.maskLength >= 4) {
        score += 1.0;
      }
      
      // B. POSITION IN MESSAGE - later = more likely payment instrument
      final messageLength = smsText.length;
      final relativePosition = candidate.position / messageLength;
      if (relativePosition > 0.7) {
        score += 3.0; // Last third
      } else if (relativePosition > 0.4) {
        score += 1.0; // Middle third
      }
      
      // C. EXPLICIT INDICATOR - "ending in" is very strong signal
      if (candidate.explicitIndicator) {
        score += 5.0;
      }
      
      // D. STRUCTURAL TYPE - hyphenated suffix indicates service account reference
      if (candidate.hasHyphenSuffix) {
        score -= 3.0; // e.g., ******4564-8 is PG&E account, not payment card
      }
      
      // E. PROXIMITY TO AMOUNT - within 20 chars of amount
      final amountPattern = RegExp(r'\$\$?[\d,]+\.?\d*');
      for (final amountMatch in amountPattern.allMatches(smsText)) {
        final distance = (candidate.position - amountMatch.end).abs();
        if (distance < 20) {
          score += 1.0;
        }
      }
      
      candidate.score = score;
    }
    
    // Select highest scoring candidate
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    
    // Calculate confidence (0.0-1.0)
    final confidence = (best.score / 10.0).clamp(0.0, 1.0);
    
    print('[AccountExtraction] Identifier candidates: ${candidates.length}, Best: ${best.value} (score: ${best.score.toStringAsFixed(1)}, mask: ${best.maskLength}, pos: ${best.position})');
    
    return _IdentifierMatch(
      value: best.value,
      confidence: confidence,
      ruleId: 0, // Structural extraction, not rule-based
    );
  }
  
  // ═══════════════════════════════════════════════════════════════
  // PATTERN-BASED BANK EXTRACTION METHODS
  // These auto-detect banks without requiring database entries
  // ═══════════════════════════════════════════════════════════════
  
  /// Extract bank from sender ID using normalization table
  static Future<_BankMatch?> _extractFromSenderId(String senderId) async {
    final db = await AppDatabase.db();
    
    // Check normalization table for sender ID variations
    final results = await db.query(
      'bank_normalizations',
      where: 'LOWER(original_name) = ?',
      whereArgs: [senderId.toLowerCase()],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return _BankMatch(
        name: results.first['normalized_name'] as String,
        confidence: 0.95, // High confidence from sender ID
        ruleId: 0,
        priority: 100,
      );
    }
    
    // Pattern-based sender ID parsing (e.g., HDFCBK → HDFC, ICICIBK → ICICI)
    if (senderId.length >= 4) {
      // Common bank sender ID patterns
      final patterns = {
        'hdfcbk': 'HDFC Bank',
        'icicibk': 'ICICI Bank',
        'sbiinb': 'State Bank of India',
        'axisbk': 'Axis Bank',
        'kotakb': 'Kotak Mahindra Bank',
        'bofa': 'Bank of America',
        'citi': 'Citi',
        'chase': 'Chase',
        'wellsfargo': 'Wells Fargo',
        'capone': 'Capital One',
        'amex': 'American Express',
      };
      
      for (final entry in patterns.entries) {
        if (senderId.toLowerCase().contains(entry.key)) {
          return _BankMatch(
            name: entry.value,
            confidence: 0.90,
            ruleId: 0,
            priority: 100,
          );
        }
      }
    }
    
    return null;
  }
  
  /// Extract bank from SMS header (first line before colon)
  static _BankMatch? _extractFromSmsHeader(String smsText) {
    // Pattern: "Bank Name: Message content"
    final headerPattern = RegExp(r'^([A-Za-z\s&]+?):\s+', multiLine: false);
    final match = headerPattern.firstMatch(smsText);
    
    if (match != null) {
      final bankName = match.group(1)!.trim();
      
      // Filter out common false positives
      final stopWords = {'alert', 'notice', 'reminder', 'message', 'notification', 'info', 'update'};
      if (stopWords.contains(bankName.toLowerCase())) {
        return null;
      }
      
      // Valid bank name from header
      if (bankName.length >= 3 && bankName.length <= 30) {
        return _BankMatch(
          name: bankName,
          confidence: 0.85,
          ruleId: 0,
          priority: 90,
        );
      }
    }
    
    return null;
  }
  
  /// Extract bank from domain name in SMS
  static _BankMatch? _extractFromDomain(String lowerText) {
    // Common bank domain patterns
    final domainPattern = RegExp(r'([a-z]+)\.com|www\.([a-z]+)\.com');
    final matches = domainPattern.allMatches(lowerText);
    
    for (final match in matches) {
      final domain = match.group(1) ?? match.group(2);
      if (domain == null) continue;
      
      // Known bank domains
      final bankDomains = {
        'chase': 'Chase',
        'citi': 'Citi',
        'wellsfargo': 'Wells Fargo',
        'capitalone': 'Capital One',
        'bankofamerica': 'Bank of America',
        'usbank': 'US Bank',
        'discover': 'Discover',
        'americanexpress': 'American Express',
        'paypal': 'PayPal',
        'venmo': 'Venmo',
        'chime': 'Chime',
        'sofi': 'SoFi',
      };
      
      if (bankDomains.containsKey(domain)) {
        return _BankMatch(
          name: bankDomains[domain]!,
          confidence: 0.80,
          ruleId: 0,
          priority: 80,
        );
      }
    }
    
    return null;
  }
  
  /// Tokenize text into searchable keywords
  static List<String> _tokenize(String text) {
    // Remove special characters and split
    final cleaned = text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .toLowerCase()
        .split(RegExp(r'\s+'));
    
    // Filter out short words and common stop words
    return cleaned
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();
  }
  
  static const _stopWords = {
    'the', 'and', 'for', 'you', 'was', 'are', 'your', 'from', 'has', 
    'been', 'this', 'that', 'with', 'have', 'not', 'can', 'will',
  };
  
  /// Record feedback for improving extraction accuracy
  static Future<void> recordFeedback({
    required String smsText,
    String? extractedBank,
    String? extractedIdentifier,
    String? correctBank,
    String? correctIdentifier,
    required String feedbackType,
  }) async {
    final db = await AppDatabase.db();
    
    await db.insert('account_extraction_feedback', {
      'sms_text': smsText,
      'extracted_bank': extractedBank,
      'extracted_identifier': extractedIdentifier,
      'correct_bank': correctBank,
      'correct_identifier': correctIdentifier,
      'feedback_type': feedbackType,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    
    // TODO: Implement learning logic to adjust rule confidence
    // based on feedback (similar to SMS Intelligence Engine)
  }
  
  /// Add new extraction rule
  static Future<int> addRule({
    required String ruleType,
    required String extractionType,
    required String pattern,
    required String keywords,
    String? region,
    String? outputValue,
    double confidence = 1.0,
  }) async {
    final db = await AppDatabase.db();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Insert rule
    final ruleId = await db.insert('account_extraction_rules', {
      'rule_type': ruleType,
      'extraction_type': extractionType,
      'pattern': pattern,
      'keywords': keywords,
      'region': region,
      'output_value': outputValue,
      'confidence': confidence,
      'created_at': now,
      'source': 'user',
      'is_active': 1,
      'priority': 5, // User rules have medium priority
    });
    
    // Create inverted index
    final keywordList = keywords.split(',');
    for (final keyword in keywordList) {
      final kw = keyword.trim().toLowerCase();
      if (kw.isNotEmpty) {
        await db.insert('account_extraction_index', {
          'keyword': kw,
          'rule_id': ruleId,
        });
      }
    }
    
    return ruleId;
  }
}

/// Result of account identity extraction
class AccountIdentity {
  final String? bank;
  final double bankConfidence;
  final String? accountIdentifier;
  final double identifierConfidence;
  final String extractionMethod;
  
  AccountIdentity({
    this.bank,
    this.bankConfidence = 0.0,
    this.accountIdentifier,
    this.identifierConfidence = 0.0,
    required this.extractionMethod,
  });
  
  bool get hasBank => bank != null && bank!.isNotEmpty;
  bool get hasIdentifier => accountIdentifier != null && accountIdentifier!.isNotEmpty;
  bool get isComplete => hasBank && hasIdentifier;
  
  @override
  String toString() => 'Identity(bank: $bank [$bankConfidence], id: $accountIdentifier [$identifierConfidence])';
}

/// Internal class for bank matching results
class _BankMatch {
  final String name;
  final double confidence;
  final int ruleId;
  final int priority;
  
  _BankMatch({
    required this.name,
    required this.confidence,
    required this.ruleId,
    required this.priority,
  });
}

/// Internal class for identifier matching results
class _IdentifierMatch {
  final String value;
  final double confidence;
  final int ruleId;
  
  _IdentifierMatch({
    required this.value,
    required this.confidence,
    required this.ruleId,
  });
}

/// Internal class for identifier candidate scoring
class _IdentifierCandidate {
  final String value;
  final int position;
  final int maskLength;
  final String fullMatch;
  final bool hasHyphenSuffix;
  final bool explicitIndicator;
  double score = 0.0;
  
  _IdentifierCandidate({
    required this.value,
    required this.position,
    required this.maskLength,
    required this.fullMatch,
    required this.hasHyphenSuffix,
    this.explicitIndicator = false,
  });
}
