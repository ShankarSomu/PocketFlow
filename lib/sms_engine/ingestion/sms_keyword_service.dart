/// SMS Keyword Service - Manages keywords and merchant categories from database
/// 
/// This service caches all keywords in memory for fast lookups during SMS parsing.
/// Call initialize() on app startup to preload the cache.

import 'package:pocket_flow/db/database.dart';

class SmsKeywordService {
  // Cache keywords grouped by type and region
  static final Map<String, List<String>> _keywordCache = {};
  static RegExp? _senderPatternRegex;
  static bool _initialized = false;

  /// Initialize keyword cache on app startup
  /// This preloads all keywords into memory for fast access
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final db = await AppDatabase.db();

      // Check if table exists (might not exist in older database versions)
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'sms_keywords'],
      );

      if (tables.isEmpty) {
        print('[SmsKeywordService] sms_keywords table not found, skipping initialization');
        _initialized = true;
        return;
      }

      // Load all active keywords from database
      final results = await db.query(
        'sms_keywords',
        where: 'is_active = 1',
        orderBy: 'priority DESC, confidence DESC',
      );

      // Collect sender patterns separately
      final senderPatterns = <String>[];

      // Group keywords by type + region for efficient lookup
      for (final row in results) {
        final type = row['type'] as String;
        final region = row['region'] as String?;
        final keyword = row['keyword'] as String;

        if (type == 'sender_pattern') {
          // Collect sender patterns to build regex
          senderPatterns.add(keyword);
        } else {
          // Create cache key: "debit_INDIA", "credit_US", "financial_global"
          final cacheKey = '${type}_${region ?? 'global'}';
          _keywordCache[cacheKey] ??= [];
          _keywordCache[cacheKey]!.add(keyword.toLowerCase());
        }
      }

      // Build sender pattern regex from all sender IDs
      if (senderPatterns.isNotEmpty) {
        // Add optional prefixes commonly used by banks
        final prefix = r'^(?:AD-|BZ-|VK-|AX-|JD-|HD-|SB-|IC-|KO-|UN-|CX-|AM-)?';
        final patterns = senderPatterns.join('|');
        _senderPatternRegex = RegExp('$prefix(?:$patterns)', caseSensitive: false);
      }

      _initialized = true;
      print('[SmsKeywordService] Initialized with ${results.length} keywords (${senderPatterns.length} sender patterns)');
    } catch (e) {
      print('[SmsKeywordService] Error during initialization: $e');
      _initialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Get keywords for specific type and region
  /// Returns both region-specific and global keywords
  static List<String> getKeywords({
    required String type,
    String? region,
  }) {
    final keywords = <String>{};

    // Add region-specific keywords
    if (region != null) {
      final regionKey = '${type}_$region';
      if (_keywordCache.containsKey(regionKey)) {
        keywords.addAll(_keywordCache[regionKey]!);
      }
    }

    // Add global keywords (fallback)
    final globalKey = '${type}_global';
    if (_keywordCache.containsKey(globalKey)) {
      keywords.addAll(_keywordCache[globalKey]!);
    }

    return keywords.toList();
  }

  /// Check if SMS body contains any keywords of a specific type
  static bool containsKeyword({
    required String text,
    required String type,
    String? region,
  }) {
    final lowerText = text.toLowerCase();
    final keywords = getKeywords(type: type, region: region);

    for (final keyword in keywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Check if sender ID matches known bank/payment app patterns
  /// Uses dynamically built regex from database sender patterns
  static bool isBankSender(String sender) {
    if (_senderPatternRegex == null) return false;
    return _senderPatternRegex!.hasMatch(sender);
  }

  /// Get merchant category from database
  /// Returns category name if merchant pattern matches
  static Future<String?> getCategoryForMerchant(
    String merchant,
    String? region,
  ) async {
    if (merchant.isEmpty) return null;

    final db = await AppDatabase.db();
    final lowerMerchant = merchant.toLowerCase();

    // Try region-specific match first
    if (region != null) {
      final regionResult = await db.query(
        'merchant_categories',
        where: 'LOWER(merchant_pattern) = ? AND region = ? AND is_active = 1',
        whereArgs: [lowerMerchant, region],
        orderBy: 'priority DESC',
        limit: 1,
      );

      if (regionResult.isNotEmpty) {
        // Increment match counter for analytics
        await _incrementMatchCount(db, regionResult.first['id'] as int);
        return regionResult.first['category'] as String;
      }
    }

    // Fallback to global merchant match
    final globalResult = await db.query(
      'merchant_categories',
      where: 'LOWER(merchant_pattern) = ? AND region IS NULL AND is_active = 1',
      whereArgs: [lowerMerchant],
      orderBy: 'priority DESC',
      limit: 1,
    );

    if (globalResult.isNotEmpty) {
      await _incrementMatchCount(db, globalResult.first['id'] as int);
      return globalResult.first['category'] as String;
    }

    // Also try partial match (merchant name contains pattern)
    final partialResult = await db.rawQuery('''
      SELECT * FROM merchant_categories 
      WHERE ? LIKE '%' || LOWER(merchant_pattern) || '%' 
        AND (region = ? OR region IS NULL)
        AND is_active = 1
      ORDER BY 
        CASE WHEN region = ? THEN 0 ELSE 1 END,
        priority DESC,
        LENGTH(merchant_pattern) DESC
      LIMIT 1
    ''', [lowerMerchant, region, region]);

    if (partialResult.isNotEmpty) {
      await _incrementMatchCount(db, partialResult.first['id'] as int);
      return partialResult.first['category'] as String;
    }

    return null; // No match found
  }

  /// Increment match counter for analytics
  static Future<void> _incrementMatchCount(dynamic db, int id) async {
    await db.rawUpdate('''
      UPDATE merchant_categories 
      SET match_count = match_count + 1 
      WHERE id = ?
    ''', [id]);
  }

  /// Reload cache from database (useful after keyword updates)
  static Future<void> reload() async {
    _initialized = false;
    _keywordCache.clear();
    await initialize();
  }

  /// Get keyword statistics (for debugging/analytics)
  static Map<String, int> getCacheStats() {
    return _keywordCache.map((key, value) => MapEntry(key, value.length));
  }
}
