import '../db/database.dart';

/// Merchant Normalization Service
/// Standardizes merchant names across transactions for better grouping and analysis
class MerchantNormalizationService {
  // Common merchant name variations
  static final Map<String, String> _merchantAliases = {
    // Amazon variations
    'amazon': 'Amazon',
    'amzn': 'Amazon',
    'amazon.com': 'Amazon',
    'amazon prime': 'Amazon Prime',
    'amzn mktp': 'Amazon',
    
    // Starbucks variations
    'starbucks': 'Starbucks',
    'sbux': 'Starbucks',
    'starbuck': 'Starbucks',
    
    // Netflix variations
    'netflix': 'Netflix',
    'netflix.com': 'Netflix',
    
    // Walmart variations
    'walmart': 'Walmart',
    'wal-mart': 'Walmart',
    'wmart': 'Walmart',
    
    // Target variations
    'target': 'Target',
    'tgt': 'Target',
    
    // McDonald's variations
    'mcdonalds': 'McDonald\'s',
    'mcdonald\'s': 'McDonald\'s',
    'mcd': 'McDonald\'s',
    
    // Uber variations
    'uber': 'Uber',
    'uber trip': 'Uber',
    'uber eats': 'Uber Eats',
    
    // Spotify variations
    'spotify': 'Spotify',
    'spotify usa': 'Spotify',
    
    // Google variations
    'google': 'Google',
    'google pay': 'Google Pay',
    'google storage': 'Google Storage',
    'google one': 'Google One',
    
    // Apple variations
    'apple': 'Apple',
    'apple.com': 'Apple',
    'itunes': 'Apple iTunes',
    'app store': 'App Store',
    
    // Indian merchants
    'paytm': 'Paytm',
    'phonepe': 'PhonePe',
    'swiggy': 'Swiggy',
    'zomato': 'Zomato',
    'flipkart': 'Flipkart',
    'bigbasket': 'BigBasket',
    'big basket': 'BigBasket',
    'dunzo': 'Dunzo',
    'grofers': 'Grofers',
    'blinkit': 'Blinkit',
    'zepto': 'Zepto',
    
    // Gas stations
    'shell': 'Shell',
    'chevron': 'Chevron',
    'exxon': 'ExxonMobil',
    'bp': 'BP',
    '76': '76 Gas',
    
    // Grocery
    'whole foods': 'Whole Foods',
    'safeway': 'Safeway',
    'kroger': 'Kroger',
    'trader joe': 'Trader Joe\'s',
    'trader joes': 'Trader Joe\'s',
    
    // Restaurants
    'chipotle': 'Chipotle',
    'panera': 'Panera Bread',
    'subway': 'Subway',
    'dominos': 'Domino\'s',
    'domino\'s': 'Domino\'s',
    'pizza hut': 'Pizza Hut',
  };

  /// Normalize a merchant name
  static String normalize(String? merchant) {
    if (merchant == null || merchant.isEmpty) return '';
    
    String normalized = merchant.trim();
    
    // Remove SMS prefix
    normalized = normalized.replaceAll(RegExp(r'^(sms:|📱\s*)'), '');
    
    // Remove common prefixes/suffixes
    normalized = _removeCommonPatterns(normalized);
    
    // Convert to lowercase for matching
    final lowerMerchant = normalized.toLowerCase();
    
    // Check exact aliases first
    if (_merchantAliases.containsKey(lowerMerchant)) {
      return _merchantAliases[lowerMerchant]!;
    }
    
    // Check partial matches
    for (final entry in _merchantAliases.entries) {
      if (lowerMerchant.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Apply generic normalization
    normalized = _applyGenericNormalization(normalized);
    
    return _capitalize(normalized);
  }

  /// Remove common patterns from merchant names
  static String _removeCommonPatterns(String merchant) {
    String cleaned = merchant;
    
    // Remove location codes (e.g., "#1234", "Store #56")
    cleaned = cleaned.replaceAll(RegExp(r'#\d+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'store\s*#?\s*\d+', caseSensitive: false), '');
    
    // Remove dates
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}[/-]\d{1,2}[/-]?\d{0,4}'), '');
    
    // Remove times
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false), '');
    
    // Remove transaction codes (e.g., "TXN123456")
    cleaned = cleaned.replaceAll(RegExp(r'txn\s*\d+', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'ref\s*:?\s*\w+', caseSensitive: false), '');
    
    // Remove city/state suffixes
    cleaned = cleaned.replaceAll(RegExp(r',?\s*[A-Z]{2}$'), ''); // ", CA" or " TX"
    
    // Remove asterisks and underscores
    cleaned = cleaned.replaceAll(RegExp('[*_]+'), ' ');
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  /// Apply generic normalization rules
  static String _applyGenericNormalization(String merchant) {
    String normalized = merchant;
    
    // Remove URL prefixes
    normalized = normalized.replaceAll(RegExp(r'^(https?://)?(www\.)?'), '');
    
    // Remove .com, .net, etc.
    normalized = normalized.replaceAll(RegExp(r'\.(com|net|org|in|co\.in)$', caseSensitive: false), '');
    
    // Remove common words
    final wordsToRemove = ['inc', 'llc', 'ltd', 'corp', 'corporation', 'the'];
    for (final word in wordsToRemove) {
      normalized = normalized.replaceAll(RegExp(r'\b' + word + r'\b', caseSensitive: false), '');
    }
    
    // Clean up
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return normalized;
  }

  /// Capitalize properly
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    
    // Split into words
    final words = text.split(' ');
    
    // Capitalize first letter of each word
    final capitalized = words.map((word) {
      if (word.isEmpty) return word;
      
      // Keep acronyms uppercase if they're already uppercase
      if (word.toUpperCase() == word && word.length <= 4) {
        return word;
      }
      
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();
    
    return capitalized.join(' ');
  }

  /// Check if two merchant names are similar
  static bool areSimilar(String merchant1, String merchant2) {
    final norm1 = normalize(merchant1).toLowerCase();
    final norm2 = normalize(merchant2).toLowerCase();
    
    // Exact match
    if (norm1 == norm2) return true;
    
    // One contains the other
    if (norm1.contains(norm2) || norm2.contains(norm1)) return true;
    
    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(norm1, norm2);
    final maxLength = norm1.length > norm2.length ? norm1.length : norm2.length;
    
    // Similar if distance is less than 20% of max length
    return distance < (maxLength * 0.2);
  }

  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final len1 = s1.length;
    final len2 = s2.length;
    
    List<int> prev = List.generate(len2 + 1, (i) => i);
    
    for (int i = 0; i < len1; i++) {
      final List<int> curr = [i + 1];
      
      for (int j = 0; j < len2; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        curr.add([
          curr[j] + 1,        // deletion
          prev[j + 1] + 1,    // insertion
          prev[j] + cost,     // substitution
        ].reduce((a, b) => a < b ? a : b));
      }
      
      prev = curr;
    }
    
    return prev[len2];
  }

  /// Group transactions by normalized merchant
  static Future<Map<String, List<int>>> groupTransactionsByMerchant() async {
    final db = await AppDatabase.db();
    
    final results = await db.query(
      'transactions',
      columns: ['id', 'merchant', 'note'],
      where: 'deleted_at IS NULL',
    );
    
    final groups = <String, List<int>>{};
    
    for (final row in results) {
      final txnId = row['id']! as int;
      final merchant = row['merchant'] as String?;
      final note = row['note'] as String?;
      
      final merchantName = merchant ?? note ?? 'Unknown';
      final normalized = normalize(merchantName);
      
      if (normalized.isEmpty) continue;
      
      groups.putIfAbsent(normalized, () => []);
      groups[normalized]!.add(txnId);
    }
    
    return groups;
  }

  /// Get merchant statistics
  static Future<List<Map<String, dynamic>>> getMerchantStatistics({
    int? limit,
    DateTime? since,
  }) async {
    final groups = await groupTransactionsByMerchant();
    
    final db = await AppDatabase.db();
    final stats = <Map<String, dynamic>>[];
    
    for (final entry in groups.entries) {
      final merchant = entry.key;
      final txnIds = entry.value;
      
      if (txnIds.isEmpty) continue;
      
      // Get transaction details
      final txnResults = await db.query(
        'transactions',
        where: 'id IN (${txnIds.map((_) => '?').join(',')}) AND deleted_at IS NULL',
        whereArgs: txnIds,
      );
      
      if (txnResults.isEmpty) continue;
      
      double totalAmount = 0;
      int count = 0;
      DateTime? firstDate;
      DateTime? lastDate;
      
      for (final row in txnResults) {
        final amount = row['amount']! as double;
        final dateStr = row['date']! as String;
        final date = DateTime.parse(dateStr);
        
        // Apply date filter if specified
        if (since != null && date.isBefore(since)) continue;
        
        totalAmount += amount;
        count++;
        
        if (firstDate == null || date.isBefore(firstDate)) {
          firstDate = date;
        }
        if (lastDate == null || date.isAfter(lastDate)) {
          lastDate = date;
        }
      }
      
      if (count > 0) {
        stats.add({
          'merchant': merchant,
          'total_amount': totalAmount,
          'transaction_count': count,
          'average_amount': totalAmount / count,
          'first_transaction': firstDate,
          'last_transaction': lastDate,
        });
      }
    }
    
    // Sort by total amount descending
    stats.sort((a, b) => (b['total_amount'] as double).compareTo(a['total_amount'] as double));
    
    if (limit != null && stats.length > limit) {
      return stats.sublist(0, limit);
    }
    
    return stats;
  }

  /// Update transaction merchants with normalized names
  static Future<int> normalizeAllTransactions() async {
    final db = await AppDatabase.db();
    
    final results = await db.query(
      'transactions',
      columns: ['id', 'merchant', 'note'],
      where: 'deleted_at IS NULL',
    );
    
    int updated = 0;
    
    for (final row in results) {
      final txnId = row['id']! as int;
      final merchant = row['merchant'] as String?;
      
      if (merchant == null || merchant.isEmpty) continue;
      
      final normalized = normalize(merchant);
      
      if (normalized != merchant && normalized.isNotEmpty) {
        await db.update(
          'transactions',
          {'merchant': normalized},
          where: 'id = ?',
          whereArgs: [txnId],
        );
        updated++;
      }
    }
    
    return updated;
  }

  /// Add custom merchant alias
  static void addAlias(String variant, String canonical) {
    _merchantAliases[variant.toLowerCase()] = canonical;
  }

  /// Get all known merchant aliases
  static Map<String, String> getAllAliases() {
    return Map.from(_merchantAliases);
  }

  /// Find duplicate merchants (for merging)
  static Future<List<List<String>>> findDuplicates() async {
    final groups = await groupTransactionsByMerchant();
    final merchants = groups.keys.toList();
    
    final duplicates = <List<String>>[];
    final processed = <String>{};
    
    for (int i = 0; i < merchants.length; i++) {
      if (processed.contains(merchants[i])) continue;
      
      final similar = <String>[merchants[i]];
      
      for (int j = i + 1; j < merchants.length; j++) {
        if (processed.contains(merchants[j])) continue;
        
        if (areSimilar(merchants[i], merchants[j])) {
          similar.add(merchants[j]);
          processed.add(merchants[j]);
        }
      }
      
      if (similar.length > 1) {
        duplicates.add(similar);
      }
      
      processed.add(merchants[i]);
    }
    
    return duplicates;
  }
}
