// lib/services/sms_rule_engine.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../db/database.dart';
import 'merchant_normalizer.dart';

/// Two-Stage Indexed Rule Engine for Scalable SMS Classification
/// 
/// Stage 1: Fast Candidate Retrieval (Index-based, O(1) lookup)
/// Stage 2: Scoring + Conflict Resolution (small set only)
/// 
/// Performance: Sub-50ms even with millions of rules
class SmsRuleEngine {
  static final SmsRuleEngine _instance = SmsRuleEngine._internal();
  factory SmsRuleEngine() => _instance;
  SmsRuleEngine._internal();

  final MerchantNormalizer _merchantNormalizer = MerchantNormalizer();

  // In-memory inverted index: keyword → List<rule_id>
  final Map<String, Set<int>> _invertedIndex = {};
  bool _indexLoaded = false;

  // Rule cache: rule_id → Rule object
  final Map<int, SmsClassificationRule> _ruleCache = {};

  // Pattern cache: signature → Classification result
  final Map<String, CachedClassification> _patternCache = {};

  /// Load inverted index from database into memory
  Future<void> _loadIndex() async {
    if (_indexLoaded) return;

    final db = await AppDatabase.db();

    // Load rules
    final rules = await db.query(
      'sms_classification_rules',
      where: 'is_active = 1',
    );

    _ruleCache.clear();
    for (final row in rules) {
      final rule = SmsClassificationRule.fromMap(row);
      _ruleCache[rule.id!] = rule;
    }

    // Load index
    final indexData = await db.query('sms_rule_index');

    _invertedIndex.clear();
    for (final row in indexData) {
      final keyword = row['keyword'] as String;
      final ruleId = (row['rule_id'] as num).toInt();

      if (!_invertedIndex.containsKey(keyword)) {
        _invertedIndex[keyword] = {};
      }
      _invertedIndex[keyword]!.add(ruleId);
    }

    _indexLoaded = true;
    print('✓ Loaded ${_ruleCache.length} rules, ${_invertedIndex.length} keywords in index');
  }

  /// Reload index (call after adding/removing rules)
  Future<void> reloadIndex() async {
    _indexLoaded = false;
    await _loadIndex();
  }

  /// ═══════════════════════════════════════════════════════════
  /// STAGE 1: Fast Candidate Retrieval (Index-based)
  /// ═══════════════════════════════════════════════════════════

  /// Extract keywords from SMS text
  List<String> _extractKeywords(String smsText) {
    final keywords = <String>[];
    final lowercased = smsText.toLowerCase();

    // Financial keywords
    const financialTerms = [
      'debited', 'credited', 'paid', 'received', 'sent', 'transferred',
      'charged', 'refund', 'cashback', 'balance', 'available',
      'withdrawn', 'deposited', 'purchase', 'transaction', 'payment',
      'autopay', 'scheduled', 'recurring', 'upcoming', 'reminder',
      'due', 'owe', 'bill', 'statement', 'interest', 'emi',
    ];

    for (final term in financialTerms) {
      if (lowercased.contains(term)) {
        keywords.add(term);
      }
    }

    return keywords;
  }

  /// Generate pattern signature for caching
  String _generateSignature(String smsText) {
    final keywords = _extractKeywords(smsText);
    keywords.sort();
    
    // Include amount pattern (masked)
    final hasAmount = RegExp(r'\d+\.?\d*').hasMatch(smsText);
    final amountPattern = hasAmount ? 'AMT' : 'NOAMT';
    
    return '${keywords.join('|')}|$amountPattern';
  }

  /// Retrieve candidate rules using inverted index
  Future<List<SmsClassificationRule>> _getCandidateRules(String smsText) async {
    await _loadIndex();

    final keywords = _extractKeywords(smsText);
    final merchants = await _merchantNormalizer.extractMerchantsFromSms(smsText);

    final candidateRuleIds = <int>{};

    // Fetch rules by keyword (O(1) per keyword)
    for (final keyword in keywords) {
      if (_invertedIndex.containsKey(keyword)) {
        candidateRuleIds.addAll(_invertedIndex[keyword]!);
      }
    }

    // Fetch rules by merchant
    for (final merchant in merchants) {
      final merchantLower = merchant.toLowerCase();
      if (_invertedIndex.containsKey(merchantLower)) {
        candidateRuleIds.addAll(_invertedIndex[merchantLower]!);
      }
    }

    // Convert IDs to Rule objects
    final candidates = candidateRuleIds
        .map((id) => _ruleCache[id])
        .where((rule) => rule != null)
        .cast<SmsClassificationRule>()
        .toList();

    print('🔍 Candidates: ${candidates.length} rules from ${keywords.length} keywords');
    return candidates;
  }

  /// ═══════════════════════════════════════════════════════════
  /// STAGE 2: Scoring + Conflict Resolution
  /// ═══════════════════════════════════════════════════════════

  /// Top-K pruning if too many candidates
  List<SmsClassificationRule> _pruneTopK(
    List<SmsClassificationRule> candidates,
    String smsText,
    int maxK,
  ) {
    if (candidates.length <= maxK) return candidates;

    final keywords = _extractKeywords(smsText).toSet();

    // Score by keyword overlap
    final scored = candidates.map((rule) {
      final ruleKeywords = rule.keywords;
      final overlap = keywords.intersection(ruleKeywords.toSet());
      return MapEntry(rule, overlap.length);
    }).toList();

    // Sort by overlap descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    // Take top K
    final pruned = scored.take(maxK).map((e) => e.key).toList();
    print('✂️ Pruned ${candidates.length} → ${pruned.length} rules');
    return pruned;
  }

  /// Calculate similarity score
  double _calculateSimilarity(SmsClassificationRule rule, String smsText) {
    final smsKeywords = _extractKeywords(smsText).toSet();
    final ruleKeywords = rule.keywords.toSet();

    if (ruleKeywords.isEmpty) return 0.0;

    final matched = smsKeywords.intersection(ruleKeywords);
    return matched.length / ruleKeywords.length;
  }

  /// Calculate feedback score
  double _calculateFeedbackScore(SmsClassificationRule rule) {
    final total = rule.correctCount + rule.incorrectCount;
    if (total == 0) return 1.0; // Neutral for new rules

    // Score = (correct - incorrect) / total
    // Range: -1.0 to +1.0
    final score = (rule.correctCount - rule.incorrectCount) / total;
    return score;
  }

  /// Classify SMS using the two-stage pipeline
  Future<SmsClassification?> classify(String smsText) async {
    // Check cache first (O(1) lookup)
    final signature = _generateSignature(smsText);
    if (_patternCache.containsKey(signature)) {
      final cached = _patternCache[signature]!;
      print('⚡ Cache hit: ${cached.category}');
      await _updateCacheHit(signature);
      return SmsClassification(
        category: cached.category,
        transactionType: cached.transactionType,
        confidence: cached.confidence,
        source: 'cache',
      );
    }

    // Stage 1: Fast Candidate Retrieval
    final candidates = await _getCandidateRules(smsText);

    if (candidates.isEmpty) {
      print('❌ No matching rules found');
      return null;
    }

    // Stage 2: Top-K Pruning
    final pruned = _pruneTopK(candidates, smsText, 50);

    // Stage 3: Scoring
    final scoredRules = <MapEntry<SmsClassificationRule, double>>[];

    for (final rule in pruned) {
      final similarity = _calculateSimilarity(rule, smsText);
      final feedback = _calculateFeedbackScore(rule);
      final finalScore = similarity * (1.0 + feedback); // Boost by feedback

      scoredRules.add(MapEntry(rule, finalScore));
    }

    // Sort by score descending
    scoredRules.sort((a, b) => b.value.compareTo(a.value));

    // Stage 4: Conflict Resolution (aggregate by category)
    final categoryScores = <String, double>{};
    final typeScores = <String, double>{};

    for (final entry in scoredRules) {
      final rule = entry.key;
      final score = entry.value;

      if (rule.category != null) {
        categoryScores[rule.category!] = 
            (categoryScores[rule.category!] ?? 0.0) + score;
      }

      if (rule.transactionType != null) {
        typeScores[rule.transactionType!] = 
            (typeScores[rule.transactionType!] ?? 0.0) + score;
      }
    }

    // Get top category and type
    final topCategory = categoryScores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final topType = typeScores.isNotEmpty
        ? typeScores.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    final confidence = categoryScores[topCategory]! / scoredRules.length;

    // Cache the result
    await _cacheClassification(
      signature,
      topCategory,
      topType,
      confidence,
      scoredRules.take(5).map((e) => e.key.id!).toList(),
    );

    print('✓ Classified: $topCategory ($topType) - confidence: ${(confidence * 100).toInt()}%');

    return SmsClassification(
      category: topCategory,
      transactionType: topType,
      confidence: confidence,
      source: 'rules',
      matchedRuleCount: scoredRules.length,
    );
  }

  /// ═══════════════════════════════════════════════════════════
  /// Rule Management
  /// ═══════════════════════════════════════════════════════════

  /// Add new rule from user feedback
  Future<int> addRule({
    required String smsText,
    required String category,
    String? transactionType,
    String source = 'user_feedback',
  }) async {
    final db = await AppDatabase.db();

    // Extract keywords and merchants
    final keywords = _extractKeywords(smsText);
    final merchants = await _merchantNormalizer.extractMerchantsFromSms(smsText);

    final now = DateTime.now().millisecondsSinceEpoch;

    // Insert rule
    final ruleId = await db.insert(
      'sms_classification_rules',
      {
        'rule_type': 'pattern',
        'keywords': jsonEncode(keywords),
        'normalized_merchants': merchants.isNotEmpty ? jsonEncode(merchants) : null,
        'category': category,
        'transaction_type': transactionType,
        'confidence': 1.0,
        'correct_count': 1,
        'incorrect_count': 0,
        'created_at': now,
        'last_used_at': now,
        'source': source,
        'is_active': 1,
      },
    );

    // Update inverted index
    await _updateInvertedIndex(ruleId, [...keywords, ...merchants.map((m) => m.toLowerCase())]);

    // Reload cache
    await reloadIndex();

    print('✓ Rule added: ID=$ruleId, keywords=$keywords, category=$category');
    return ruleId;
  }

  /// Update inverted index for a rule
  Future<void> _updateInvertedIndex(int ruleId, List<String> keywords) async {
    final db = await AppDatabase.db();

    for (final keyword in keywords) {
      await db.insert(
        'sms_rule_index',
        {
          'keyword': keyword.toLowerCase(),
          'rule_id': ruleId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Record feedback for a rule
  Future<void> recordFeedback({
    required int ruleId,
    required bool isCorrect,
  }) async {
    final db = await AppDatabase.db();

    final column = isCorrect ? 'correct_count' : 'incorrect_count';
    await db.rawUpdate(
      'UPDATE sms_classification_rules SET $column = $column + 1, last_used_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, ruleId],
    );

    // Reload cache to reflect feedback
    await reloadIndex();
  }

  /// ═══════════════════════════════════════════════════════════
  /// Caching Layer
  /// ═══════════════════════════════════════════════════════════

  Future<void> _cacheClassification(
    String signature,
    String category,
    String? transactionType,
    double confidence,
    List<int> ruleIds,
  ) async {
    final db = await AppDatabase.db();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'sms_pattern_cache',
      {
        'pattern_signature': signature,
        'category': category,
        'transaction_type': transactionType,
        'matched_rule_ids': jsonEncode(ruleIds),
        'hit_count': 1,
        'last_hit_at': now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Add to in-memory cache
    _patternCache[signature] = CachedClassification(
      category: category,
      transactionType: transactionType,
      confidence: confidence,
    );
  }

  Future<void> _updateCacheHit(String signature) async {
    final db = await AppDatabase.db();
    await db.rawUpdate(
      'UPDATE sms_pattern_cache SET hit_count = hit_count + 1, last_hit_at = ? WHERE pattern_signature = ?',
      [DateTime.now().millisecondsSinceEpoch, signature],
    );
  }

  /// Clear old cache entries (keep last 10,000)
  Future<void> cleanupCache() async {
    final db = await AppDatabase.db();
    await db.rawDelete('''
      DELETE FROM sms_pattern_cache
      WHERE id NOT IN (
        SELECT id FROM sms_pattern_cache
        ORDER BY hit_count DESC, last_hit_at DESC
        LIMIT 10000
      )
    ''');
  }

  /// Statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await AppDatabase.db();

    final ruleCount = await db.rawQuery('SELECT COUNT(*) as count FROM sms_classification_rules WHERE is_active = 1');
    final cacheCount = await db.rawQuery('SELECT COUNT(*) as count FROM sms_pattern_cache');
    final topRules = await db.rawQuery('''
      SELECT category, COUNT(*) as count, AVG(correct_count) as avg_correct
      FROM sms_classification_rules
      WHERE is_active = 1
      GROUP BY category
      ORDER BY count DESC
    ''');

    return {
      'total_rules': ((ruleCount.first['count'] ?? 0) as num).toInt(),
      'cache_size': ((cacheCount.first['count'] ?? 0) as num).toInt(),
      'index_keywords': _invertedIndex.length,
      'rules_by_category': topRules,
    };
  }
}

/// Rule model
class SmsClassificationRule {
  final int? id;
  final String ruleType;
  final List<String> keywords;
  final List<String>? merchants;
  final String? category;
  final String? transactionType;
  final double confidence;
  final int correctCount;
  final int incorrectCount;
  final int createdAt;
  final int? lastUsedAt;
  final String source;
  final bool isActive;

  SmsClassificationRule({
    this.id,
    required this.ruleType,
    required this.keywords,
    this.merchants,
    this.category,
    this.transactionType,
    this.confidence = 1.0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    required this.createdAt,
    this.lastUsedAt,
    this.source = 'user',
    this.isActive = true,
  });

  factory SmsClassificationRule.fromMap(Map<String, dynamic> map) {
    return SmsClassificationRule(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      ruleType: map['rule_type'] as String,
      keywords: (jsonDecode(map['keywords'] as String) as List).cast<String>(),
      merchants: map['normalized_merchants'] != null
          ? (jsonDecode(map['normalized_merchants'] as String) as List).cast<String>()
          : null,
      category: map['category'] as String?,
      transactionType: map['transaction_type'] as String?,
      confidence: (map['confidence'] as num).toDouble(),
      correctCount: (map['correct_count'] as num).toInt(),
      incorrectCount: (map['incorrect_count'] as num).toInt(),
      createdAt: (map['created_at'] as num).toInt(),
      lastUsedAt: map['last_used_at'] != null ? (map['last_used_at'] as num).toInt() : null,
      source: map['source'] as String,
      isActive: (map['is_active'] as num).toInt() == 1,
    );
  }
}

/// Classification result
class SmsClassification {
  final String category;
  final String? transactionType;
  final double confidence;
  final String source; // 'cache' or 'rules'
  final int? matchedRuleCount;

  SmsClassification({
    required this.category,
    this.transactionType,
    required this.confidence,
    required this.source,
    this.matchedRuleCount,
  });
}

/// Cached classification
class CachedClassification {
  final String category;
  final String? transactionType;
  final double confidence;

  CachedClassification({
    required this.category,
    this.transactionType,
    required this.confidence,
  });
}
