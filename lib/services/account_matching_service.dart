import '../db/database.dart';
import '../models/account.dart';
import 'app_logger.dart';

/// Result of account matching operation
class AccountMatchResult {

  AccountMatchResult({
    required this.confidence, required this.matchReason, this.account,
    this.alternatives = const [],
    this.requiresConfirmation = false,
  });
  final Account? account;
  final double confidence; // 0.0 to 1.0
  final List<Account> alternatives; // Alternative matches if ambiguous
  final String matchReason; // Explanation of why this account was matched
  final bool requiresConfirmation;

  bool get hasMatch => account != null;
  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.5 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.5;
  bool get hasMultipleMatches => alternatives.length > 1;
}

/// Unified Account Matching Engine
/// 
/// Provides intelligent account matching for both SMS-parsed and manually-entered transactions.
/// Uses a priority-based matching system with confidence scoring.
class AccountMatchingService {
  // Confidence score thresholds
  static const double _confidenceThresholdHigh = 0.8;
  static const double _confidenceThresholdMedium = 0.5;

  /// Match account for SMS transaction
  /// 
  /// Priority order:
  /// 1. Exact match on accountIdentifier
  /// 2. Match on institutionName + last4
  /// 3. Fuzzy match on SMS keywords
  /// 4. No match (returns null)
  static Future<AccountMatchResult> matchForSms({
    required String smsBody,
    String? detectedLast4,
    String? detectedInstitution,
  }) async {
    AppLogger.log(
      LogLevel.info,
      LogCategory.system,
      'account_match_sms',
      detail: 'institution=$detectedInstitution, last4=$detectedLast4',
    );

    final accounts = await AppDatabase.getAccounts();
    final scores = <Account, double>{};
    final reasons = <Account, String>{};

    for (final account in accounts) {
      double score = 0.0;
      final matchReasons = <String>[];

      // Priority 1: Exact account identifier match (highest confidence)
      if (detectedLast4 != null && account.accountIdentifier != null) {
        if (account.accountIdentifier!.contains(detectedLast4)) {
          score += 0.5;
          matchReasons.add('Account identifier match');
        }
      }

      // Priority 2: Institution name match
      if (detectedInstitution != null && account.institutionName != null) {
        if (_fuzzyMatch(detectedInstitution, account.institutionName!)) {
          score += 0.3;
          matchReasons.add('Institution match');
        }
      }

      // Priority 3: Last 4 digits match
      if (detectedLast4 != null && account.last4 != null) {
        if (account.last4 == detectedLast4) {
          score += 0.3;
          matchReasons.add('Last 4 digits match');
        }
      }

      // Priority 4: SMS keyword matching (fallback)
      if (account.smsKeywords != null && account.smsKeywords!.isNotEmpty) {
        for (final keyword in account.smsKeywords!) {
          if (smsBody.toUpperCase().contains(keyword.toUpperCase())) {
            score += 0.2;
            matchReasons.add('SMS keyword: $keyword');
            break; // Only count once per account
          }
        }
      }

      if (score > 0) {
        scores[account] = score;
        reasons[account] = matchReasons.join(', ');
      }
    }

    // Sort by score descending
    final sortedAccounts = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    if (sortedAccounts.isEmpty) {
      AppLogger.warn('account_match_sms_no_match', detail: 'No account matched');
      return AccountMatchResult(
        confidence: 0.0,
        matchReason: 'No matching account found',
        requiresConfirmation: true,
      );
    }

    final topAccount = sortedAccounts.first;
    final topScore = scores[topAccount]!;
    final alternatives = sortedAccounts.skip(1).take(3).toList();

    // Check for ambiguous matches (multiple accounts with similar scores)
    final requiresConfirmation = alternatives.isNotEmpty &&
        (scores[alternatives.first]! - topScore).abs() < 0.1;

    AppLogger.log(
      LogLevel.info,
      LogCategory.system,
      'account_match_sms_result',
      detail: 'account=${topAccount.name}, confidence=$topScore, reason=${reasons[topAccount]}',
    );

    return AccountMatchResult(
      account: topAccount,
      confidence: topScore,
      alternatives: requiresConfirmation ? alternatives : [],
      matchReason: reasons[topAccount] ?? 'Unknown',
      requiresConfirmation: requiresConfirmation || topScore < _confidenceThresholdMedium,
    );
  }

  /// Match account for manual transaction entry
  /// 
  /// Uses typeahead-style matching based on user input (merchant, description, etc.)
  static Future<List<AccountMatchResult>> suggestForManual({
    String? merchantName,
    String? description,
    String? accountHint,
  }) async {
    AppLogger.log(
      LogLevel.debug,
      LogCategory.userAction,
      'account_suggest_manual',
      detail: 'merchant=$merchantName, hint=$accountHint',
    );

    final accounts = await AppDatabase.getAccounts();
    final suggestions = <AccountMatchResult>[];

    for (final account in accounts) {
      double score = 0.0;
      final matchReasons = <String>[];

      // Match on account name/alias
      if (accountHint != null && accountHint.isNotEmpty) {
        if (_fuzzyMatch(accountHint, account.name)) {
          score += 0.5;
          matchReasons.add('Name match');
        }
        if (account.accountAlias != null && _fuzzyMatch(accountHint, account.accountAlias!)) {
          score += 0.5;
          matchReasons.add('Alias match');
        }
        if (account.institutionName != null && _fuzzyMatch(accountHint, account.institutionName!)) {
          score += 0.4;
          matchReasons.add('Institution match');
        }
      }

      // Historical usage patterns (simple frequency-based suggestion)
      // This would be enhanced with actual transaction history in production
      if (merchantName != null && merchantName.isNotEmpty) {
        final merchantScore = await _getHistoricalAccountScore(account.id!, merchantName);
        if (merchantScore > 0) {
          score += merchantScore * 0.3;
          matchReasons.add('Historical usage');
        }
      }

      if (score > 0) {
        suggestions.add(AccountMatchResult(
          account: account,
          confidence: score.clamp(0.0, 1.0),
          matchReason: matchReasons.join(', '),
        ));
      }
    }

    // Sort by confidence descending
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    AppLogger.log(
      LogLevel.debug,
      LogCategory.userAction,
      'account_suggest_manual_result',
      detail: 'Found ${suggestions.length} suggestions',
    );

    return suggestions.take(5).toList(); // Return top 5 suggestions
  }

  /// Get historical account usage score for a merchant
  /// 
  /// Returns 0.0-1.0 based on how often this account was used with this merchant
  static Future<double> _getHistoricalAccountScore(int accountId, String merchantName) async {
    try {
      final db = await AppDatabase.db();
      
      // Get transactions with this merchant for this account
      final accountTxns = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM transactions 
        WHERE deleted_at IS NULL 
          AND account_id = ? 
          AND (merchant LIKE ? OR note LIKE ?)
        LIMIT 10
      ''', [accountId, '%$merchantName%', '%$merchantName%']);

      final count = (accountTxns.first['count'] as int?) ?? 0;
      
      // Normalize to 0.0-1.0 (max at 5 transactions)
      return (count / 5.0).clamp(0.0, 1.0);
    } catch (e) {
      AppLogger.err('get_historical_account_score', e);
      return 0.0;
    }
  }

  /// Fuzzy string matching helper
  /// 
  /// Returns true if strings match (case-insensitive, partial match allowed)
  static bool _fuzzyMatch(String input, String target) {
    final inputLower = input.toLowerCase().trim();
    final targetLower = target.toLowerCase().trim();

    // Exact match
    if (inputLower == targetLower) return true;

    // Contains match
    if (targetLower.contains(inputLower) || inputLower.contains(targetLower)) {
      return true;
    }

    // Word-boundary match (e.g., "chase" matches "Chase Bank")
    final inputWords = inputLower.split(RegExp(r'\\s+'));
    final targetWords = targetLower.split(RegExp(r'\\s+'));

    for (final inputWord in inputWords) {
      for (final targetWord in targetWords) {
        if (inputWord == targetWord || 
            inputWord.startsWith(targetWord) || 
            targetWord.startsWith(inputWord)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Validate account assignment before saving transaction
  /// 
  /// Returns true if account assignment is valid, false otherwise
  static Future<bool> validateAccountAssignment({
    required int? accountId,
    required String sourceType,
    required bool needsReview,
  }) async {
    // Manual transactions must have an account
    if (sourceType == 'manual' && accountId == null) {
      AppLogger.warn('validate_account', detail: 'Manual transaction missing account');
      return false;
    }

    // SMS transactions can be unassigned if they need review
    if (sourceType == 'sms' && accountId == null) {
      return needsReview; // Only allowed if flagged for review
    }

    // Verify account exists and is not deleted
    if (accountId != null) {
      final account = await _getAccountById(accountId);
      if (account == null || account.deletedAt != null) {
        AppLogger.warn('validate_account', detail: 'Account not found or deleted: $accountId');
        return false;
      }
    }

    return true;
  }

  /// Get account by ID (helper method)
  static Future<Account?> _getAccountById(int id) async {
    try {
      final accounts = await AppDatabase.getAccounts();
      return accounts.where((a) => a.id == id).firstOrNull;
    } catch (e) {
      AppLogger.err('get_account_by_id', e);
      return null;
    }
  }
}
