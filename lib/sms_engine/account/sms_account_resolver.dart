import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/models/account_candidate.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_entity_extractor.dart';

/// Account resolution result
class AccountResolution {

  AccountResolution({
    required this.confidence, required this.method, this.accountId,
    this.accountCandidateId,
    this.requiresUserConfirmation = false,
    this.reason,
  });
  final int? accountId;             // Matched account ID
  final int? accountCandidateId;    // Created candidate ID
  final double confidence;          // Match confidence 0.0-1.0
  final String method;              // How it was matched
  final bool requiresUserConfirmation;
  final String? reason;

  bool get hasMatch => accountId != null;
  bool get isCandidate => accountCandidateId != null;
  bool get isHighConfidence => confidence >= 0.80;
  bool get needsReview => confidence < 0.70 || requiresUserConfirmation;
}

/// Account Resolution Engine
/// Matches SMS to existing accounts or creates candidates
class AccountResolutionEngine {
  /// Resolve SMS entities to an existing account or create candidate
  /// 
  /// Priority matching:
  /// 1. Exact account identifier match (0.95)
  /// 2. Institution + partial identifier match (0.80)
  /// 3. SMS keyword match (0.70)
  /// 4. Historical transaction mapping (0.60)
  /// 5. Create account candidate (0.50)
  static Future<AccountResolution> resolve(ExtractedEntities entities) async {
    final db = await AppDatabase.db();
    
    // Strategy 1: Exact identifier match
    if (entities.accountIdentifier != null) {
      final exactMatch = await db.query(
        'accounts',
        where: 'account_identifier = ? AND deleted_at IS NULL',
        whereArgs: [entities.accountIdentifier],
        limit: 1,
      );
      
      if (exactMatch.isNotEmpty) {
        return AccountResolution(
          accountId: exactMatch.first['id']! as int,
          confidence: 0.95,
          method: 'exact_identifier',
          reason: 'Exact match on account identifier',
        );
      }
    }
    
    // Strategy 2: Institution + partial identifier match
    if (entities.institutionName != null && entities.accountIdentifier != null) {
      // Extract last 4 digits from identifier
      final last4 = _extractLast4(entities.accountIdentifier!);
      
      if (last4 != null) {
        final partialMatch = await db.query(
          'accounts',
          where: 'institution_name = ? AND (account_identifier LIKE ? OR last4 = ?) AND deleted_at IS NULL',
          whereArgs: [
            entities.institutionName,
            '%$last4',
            last4,
          ],
          limit: 1,
        );
        
        if (partialMatch.isNotEmpty) {
          return AccountResolution(
            accountId: partialMatch.first['id']! as int,
            confidence: 0.80,
            method: 'institution_partial',
            reason: 'Matched institution and last 4 digits',
          );
        }
      }
    }
    
    // Strategy 3: SMS keyword match
    if (entities.institutionName != null) {
      final keywordMatch = await db.rawQuery('''
        SELECT id, institution_name, sms_keywords 
        FROM accounts 
        WHERE deleted_at IS NULL 
        AND (institution_name = ? OR sms_keywords LIKE ?)
        LIMIT 1
      ''', [
        entities.institutionName,
        '%${entities.institutionName}%',
      ]);
      
      if (keywordMatch.isNotEmpty) {
        return AccountResolution(
          accountId: keywordMatch.first['id']! as int,
          confidence: 0.70,
          method: 'sms_keyword',
          reason: 'Matched SMS keywords',
        );
      }
    }
    
    // Strategy 4: Historical transaction pattern match
    if (entities.merchant != null && entities.institutionName != null) {
      final historicalMatch = await _findHistoricalMatch(
        entities.merchant!,
        entities.institutionName!,
      );
      
      if (historicalMatch != null) {
        return AccountResolution(
          accountId: historicalMatch,
          confidence: 0.60,
          method: 'historical_pattern',
          reason: 'Matched based on transaction history',
        );
      }
    }
    
    // Strategy 5: Create account candidate
    final candidateId = await _createAccountCandidate(entities);
    return AccountResolution(
      accountCandidateId: candidateId,
      confidence: 0.50,
      method: 'new_candidate',
      requiresUserConfirmation: true,
      reason: 'New account detected, needs confirmation',
    );
  }

  /// Find account based on historical merchant+institution pattern
  static Future<int?> _findHistoricalMatch(
    String merchant,
    String institution,
  ) async {
    final db = await AppDatabase.db();
    
    // Find account that has transactions with this merchant
    // and matches the institution
    final results = await db.rawQuery('''
      SELECT t.account_id, COUNT(*) as count
      FROM transactions t
      INNER JOIN accounts a ON t.account_id = a.id
      WHERE t.merchant = ?
        AND a.institution_name = ?
        AND t.deleted_at IS NULL
        AND a.deleted_at IS NULL
      GROUP BY t.account_id
      ORDER BY count DESC
      LIMIT 1
    ''', [merchant, institution]);
    
    if (results.isNotEmpty && (results.first['count']! as int) >= 2) {
      return results.first['account_id']! as int;
    }
    
    return null;
  }

  /// Create a new account candidate for user review
  static Future<int> _createAccountCandidate(ExtractedEntities entities) async {
    final db = await AppDatabase.db();
    
    // Check if candidate already exists
    final existingCandidate = await db.query(
      'account_candidates',
      where: 'institution_name = ? AND account_identifier = ? AND status = ?',
      whereArgs: [
        entities.institutionName,
        entities.accountIdentifier,
        'pending',
      ],
      limit: 1,
    );
    
    if (existingCandidate.isNotEmpty) {
      // Update existing candidate
      final existingId = existingCandidate.first['id']! as int;
      final existingCount = existingCandidate.first['transaction_count']! as int;
      
      await db.update(
        'account_candidates',
        {
          'transaction_count': existingCount + 1,
          'last_seen_date': entities.timestamp.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
      
      return existingId;
    }
    
    // Create new candidate
    final candidate = AccountCandidate(
      institutionName: entities.institutionName,
      accountIdentifier: entities.accountIdentifier,
      smsKeywords: entities.institutionName != null ? [entities.institutionName!] : [],
      suggestedType: _guessAccountType(entities),
      firstSeenDate: entities.timestamp,
      lastSeenDate: entities.timestamp,
      createdAt: DateTime.now(),
    );
    
    return db.insert('account_candidates', candidate.toMap());
  }

  /// Guess account type from SMS content
  static String _guessAccountType(ExtractedEntities entities) {
    final institution = entities.institutionName?.toLowerCase() ?? '';
    final identifier = entities.accountIdentifier?.toLowerCase() ?? '';
    
    // Credit card indicators
    if (institution.contains('amex') ||
        institution.contains('visa') ||
        institution.contains('mastercard') ||
        institution.contains('credit')) {
      return 'credit';
    }
    
    // UPI/Wallet indicators
    if (identifier.contains('upi') ||
        institution.contains('paytm') ||
        institution.contains('phonepe') ||
        institution.contains('google pay')) {
      return 'other'; // wallet
    }
    
    // Default to checking for banks
    return 'checking';
  }

  /// Extract last 4 digits from account identifier
  static String? _extractLast4(String identifier) {
    // Extract from patterns like "****1234" or "UPI:user@bank"
    final match = RegExp(r'\d{4}$').firstMatch(identifier);
    return match?.group(0);
  }

  /// Get pending account candidates
  static Future<List<AccountCandidate>> getPendingCandidates() async {
    final db = await AppDatabase.db();
    
    final results = await db.query(
      'account_candidates',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'transaction_count DESC, created_at DESC',
    );
    
    return results.map(AccountCandidate.fromMap).toList();
  }

  /// Confirm account candidate and create real account
  static Future<int> confirmCandidate(
    int candidateId, {
    String? customName,
    String? customType,
  }) async {
    final db = await AppDatabase.db();
    
    // Get candidate
    final candidateMap = await db.query(
      'account_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    
    if (candidateMap.isEmpty) {
      throw Exception('Account candidate not found');
    }
    
    final candidate = AccountCandidate.fromMap(candidateMap.first);
    
    // Create account
    final account = Account(
      name: customName ?? candidate.displayName,
      type: customType ?? candidate.suggestedType,
      balance: 0,
      institutionName: candidate.institutionName,
      accountIdentifier: candidate.accountIdentifier,
      smsKeywords: candidate.smsKeywords,
    );
    
    final accountId = await AppDatabase.insertAccount(account);
    
    // Update candidate status
    await db.update(
      'account_candidates',
      {
        'status': 'confirmed',
        'merged_into_account_id': accountId,
      },
      where: 'id = ?',
      whereArgs: [candidateId],
    );
    
    // Update all transactions linked to this candidate
    await db.rawUpdate('''
      UPDATE transactions
      SET account_id = ?, needs_review = 0, confidence_score = 0.95
      WHERE extracted_institution = ? AND extracted_identifier = ?
    ''', [
      accountId,
      candidate.institutionName,
      candidate.accountIdentifier,
    ]);
    
    return accountId;
  }

  /// Reject account candidate
  static Future<void> rejectCandidate(int candidateId) async {
    final db = await AppDatabase.db();
    
    await db.update(
      'account_candidates',
      {'status': 'rejected'},
      where: 'id = ?',
      whereArgs: [candidateId],
    );
  }

  /// Merge candidate into existing account
  static Future<void> mergeCandidate(int candidateId, int existingAccountId) async {
    final db = await AppDatabase.db();
    
    // Get candidate
    final candidateMap = await db.query(
      'account_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    
    if (candidateMap.isEmpty) return;
    
    final candidate = AccountCandidate.fromMap(candidateMap.first);
    
    // Update candidate status
    await db.update(
      'account_candidates',
      {
        'status': 'merged',
        'merged_into_account_id': existingAccountId,
      },
      where: 'id = ?',
      whereArgs: [candidateId],
    );
    
    // Update transactions
    await db.rawUpdate('''
      UPDATE transactions
      SET account_id = ?, needs_review = 0, confidence_score = 0.90
      WHERE extracted_institution = ? AND extracted_identifier = ?
    ''', [
      existingAccountId,
      candidate.institutionName,
      candidate.accountIdentifier,
    ]);
    
    // Update account keywords if needed
    final accountRows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [existingAccountId],
      limit: 1,
    );
    
    if (accountRows.isNotEmpty && candidate.smsKeywords.isNotEmpty) {
      final account = Account.fromMap(accountRows.first);
      final existingKeywords = account.smsKeywords ?? [];
      final mergedKeywords = {...existingKeywords, ...candidate.smsKeywords}.toList();
      
      await db.update(
        'accounts',
        {'sms_keywords': mergedKeywords.join(',')},
        where: 'id = ?',
        whereArgs: [existingAccountId],
      );
    }
  }
}
