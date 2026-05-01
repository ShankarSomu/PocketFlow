// lib/services/merchant_normalizer.dart

import 'package:sqflite/sqflite.dart';
import '../db/database.dart';

/// Merchant Normalization Service
/// Ensures consistent merchant names for better rule matching
/// Example: AMAZON PAY, AMZN, Amazon.in → AMAZON
class MerchantNormalizer {
  // Singleton pattern for cache
  static final MerchantNormalizer _instance = MerchantNormalizer._internal();
  factory MerchantNormalizer() => _instance;
  MerchantNormalizer._internal();

  // In-memory cache for fast lookups
  final Map<String, String> _cache = {};
  bool _cacheLoaded = false;

  /// Common merchant aliases (bootstrap normalization rules)
  static const Map<String, List<String>> _commonAliases = {
    'AMAZON': ['amazon', 'amzn', 'amazon pay', 'amazon.in', 'amazonpay'],
    'SWIGGY': ['swiggy', 'swiggy pay', 'swiggypay'],
    'ZOMATO': ['zomato', 'zomato pay', 'zomatopay'],
    'FLIPKART': ['flipkart', 'flipkart pay', 'fkrt'],
    'PAYTM': ['paytm', 'paytm payments', 'paytm mall'],
    'PHONEPE': ['phonepe', 'phone pe', 'phonepe pvt ltd'],
    'GOOGLEPAY': ['google pay', 'googlepay', 'gpay', 'g pay'],
    'UBER': ['uber', 'uber india', 'uber eats'],
    'OLA': ['ola', 'ola cabs', 'ola electric'],
    'NETFLIX': ['netflix', 'netflix.com', 'netflix india'],
    'SPOTIFY': ['spotify', 'spotify india'],
    'AIRTEL': ['airtel', 'bharti airtel', 'airtel payments'],
    'JIO': ['jio', 'reliance jio', 'jiomoney'],
    'HDFC': ['hdfc', 'hdfc bank', 'hdfcbank'],
    'ICICI': ['icici', 'icici bank', 'icicibank'],
    'SBI': ['sbi', 'state bank', 'state bank of india'],
    'AXIS': ['axis', 'axis bank', 'axisbank'],
    'KOTAK': ['kotak', 'kotak bank', 'kotak mahindra'],
  };

  /// Load normalization cache from database
  Future<void> _loadCache() async {
    if (_cacheLoaded) return;

    final db = await AppDatabase.db();
    final results = await db.query('merchant_normalizations');

    _cache.clear();
    for (final row in results) {
      _cache[row['original_name'] as String] = row['normalized_name'] as String;
    }

    // Add common aliases to cache
    for (final entry in _commonAliases.entries) {
      for (final alias in entry.value) {
        _cache[alias.toLowerCase()] = entry.key;
      }
    }

    _cacheLoaded = true;
    print('✓ Loaded ${_cache.length} merchant normalizations');
  }

  /// Normalize merchant name
  /// Example: "AMAZON PAY" → "AMAZON"
  Future<String> normalize(String merchantName) async {
    await _loadCache();

    // Clean and lowercase
    final cleaned = _cleanMerchantName(merchantName);

    // Check cache first (O(1) lookup)
    if (_cache.containsKey(cleaned)) {
      return _cache[cleaned]!;
    }

    // Try fuzzy matching with known merchants
    final normalized = _fuzzyMatch(cleaned);

    if (normalized != cleaned) {
      // Cache the result (learn new alias)
      await _saveMerchantMapping(cleaned, normalized);
      _cache[cleaned] = normalized;
    }

    return normalized;
  }

  /// Normalize multiple merchant names in batch
  Future<List<String>> normalizeBatch(List<String> merchantNames) async {
    await _loadCache();
    return Future.wait(merchantNames.map((name) => normalize(name)));
  }

  /// Clean merchant name (remove special chars, extra spaces)
  String _cleanMerchantName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ')          // Normalize spaces
        .trim();
  }

  /// Fuzzy match against known merchants
  String _fuzzyMatch(String cleaned) {
    // Check if cleaned contains any known merchant name
    for (final normalized in _commonAliases.keys) {
      final normalizedLower = normalized.toLowerCase();
      
      // Exact match
      if (cleaned == normalizedLower) {
        return normalized;
      }

      // Contains match (e.g., "amazon pay" contains "amazon")
      if (cleaned.contains(normalizedLower)) {
        return normalized;
      }

      // Reverse contains (e.g., "amazon" is in "amazon pay")
      if (normalizedLower.contains(cleaned) && cleaned.length >= 4) {
        return normalized;
      }

      // Check aliases
      for (final alias in _commonAliases[normalized]!) {
        if (cleaned == alias || cleaned.contains(alias)) {
          return normalized;
        }
      }
    }

    // No match found, return uppercase version
    return cleaned.toUpperCase().replaceAll(' ', '_');
  }

  /// Save merchant mapping to database
  Future<void> _saveMerchantMapping(String original, String normalized) async {
    try {
      final db = await AppDatabase.db();
      await db.insert(
        'merchant_normalizations',
        {
          'original_name': original,
          'normalized_name': normalized,
          'frequency': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Ignore duplicate errors
      print('Merchant mapping save failed: $e');
    }
  }

  /// Update frequency for existing mapping
  Future<void> incrementFrequency(String original) async {
    final db = await AppDatabase.db();
    await db.rawUpdate(
      'UPDATE merchant_normalizations SET frequency = frequency + 1 WHERE original_name = ?',
      [original],
    );
  }

  /// Get all merchant mappings (for debugging)
  Future<Map<String, String>> getAllMappings() async {
    await _loadCache();
    return Map.from(_cache);
  }

  /// Clear cache and reload from database
  Future<void> reloadCache() async {
    _cacheLoaded = false;
    await _loadCache();
  }

  /// Add custom merchant alias
  Future<void> addCustomAlias(String original, String normalized) async {
    final cleaned = _cleanMerchantName(original);
    await _saveMerchantMapping(cleaned, normalized.toUpperCase());
    _cache[cleaned] = normalized.toUpperCase();
  }

  /// Extract merchant from SMS text
  /// Example: "Rs 500 debited at AMAZON via HDFC" → "AMAZON"
  Future<List<String>> extractMerchantsFromSms(String smsText) async {
    final merchants = <String>[];
    final lowercased = smsText.toLowerCase();

    // Look for known merchants in SMS
    for (final normalized in _commonAliases.keys) {
      for (final alias in _commonAliases[normalized]!) {
        if (lowercased.contains(alias)) {
          merchants.add(normalized);
          break; // Found this merchant, move to next
        }
      }
    }

    // Look for merchant patterns
    // Pattern: "at <merchant>" or "from <merchant>" or "<merchant> charged"
    final patterns = [
      RegExp(r'at\s+([a-z0-9\s]+?)(?:\s+via|\s+on|\s+for|$)', caseSensitive: false),
      RegExp(r'from\s+([a-z0-9\s]+?)(?:\s+via|\s+on|\s+for|$)', caseSensitive: false),
      RegExp(r'to\s+([a-z0-9\s]+?)(?:\s+via|\s+on|\s+for|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(smsText);
      for (final match in matches) {
        final merchantCandidate = match.group(1)?.trim();
        if (merchantCandidate != null && merchantCandidate.length >= 3) {
          final normalized = await normalize(merchantCandidate);
          if (!merchants.contains(normalized)) {
            merchants.add(normalized);
          }
        }
      }
    }

    return merchants;
  }

  /// Statistics for learning patterns
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await AppDatabase.db();

    final totalCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM merchant_normalizations'
    );

    final topMerchants = await db.rawQuery('''
      SELECT normalized_name, COUNT(*) as count, SUM(frequency) as total_frequency
      FROM merchant_normalizations
      GROUP BY normalized_name
      ORDER BY total_frequency DESC
      LIMIT 20
    ''');

    return {
      'total_mappings': ((totalCount.first['count'] ?? 0) as num).toInt(),
      'cache_size': _cache.length,
      'top_merchants': topMerchants,
    };
  }
}
