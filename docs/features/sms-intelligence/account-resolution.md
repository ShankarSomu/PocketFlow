# Account Resolution

Account resolution matches extracted transaction data from SMS messages to existing accounts in the system, or creates new accounts when needed.

## The Challenge

An SMS says:
```
"Your HDFC Card ending 1234 debited by Rs.500 at Amazon"
```

Which account is this?
- Do we have an account for "HDFC Card ending 1234"?
- Should we create a new account?
- How confident are we in the match?

## Resolution Process

```
Extracted Entities
    ↓
Search Existing Accounts
    ├→ Exact Match Found → Use Account (confidence: 1.0)
    ├→ Partial Match → Use Best Match (confidence: 0.7-0.9)
    ├→ No Match →  Create Candidate or Request User Input
    └→ Multiple Matches → Rank by confidence
```

## Matching Strategies

### 1. Account Identifier Match (Highest Priority)

Match extracted identifier with account's `accountIdentifier` field.

```dart
// SMS: "Card ending 1234 debited Rs.500"
// Extracted: accountIdentifier = "1234"

// Check accounts:
Account? findByIdentifier(String identifier) {
  return accounts.firstWhere(
    (a) => a.accountIdentifier == identifier ||
           a.accountIdentifier?.endsWith(identifier) == true,
    orElse: () => null,
  );
}
```

**Examples**:
```
SMS: "XX1234" → Matches account with identifier "1234" or "****1234"
SMS: "ending 5678" → Matches account with identifier "5678"
```

**Confidence**: 0.95 - 1.0

### 2. Institution Name Match

If no identifier match, match by institution name.

```dart
// SMS: "HDFC Bank debited Rs.500"
// Extracted: institution = "HDFC"

Account? findByInstitution(String institution) {
  return accounts.where(
    (a) => a.institutionName?.contains(institution) == true
  ).toList();
}
```

**Confidence**: 0.7 - 0.85 (multiple accounts from same bank may exist)

### 3. SMS Sender Pattern Match

Match using SMS sender ID patterns stored in account.

```dart
// SMS sender: "HDFCBK"
// Account.smsKeywords: ["HDFCBK", "HDFC BANK", "AD-HDFCBK"]

Account? findBySenderPattern(String sender) {
  return accounts.firstWhere(
    (a) => a.smsKeywords?.any((k) => sender.contains(k)) == true,
    orElse: () => null,
  );
}
```

**Confidence**: 0.8 - 0.9

### 4. Historical Transaction Mapping

Learn from past user confirmations.

```dart
// User previously confirmed:
// SMS "HDFCBK: XX1234 debited..." → Account "HDFC Credit Card"

// Store this mapping
class SMSAccountMapping {
  final String smsPattern;        // "HDFCBK + XX1234"
  final int accountId;
  final int confirmationCount;    // How many times confirmed
}
```

**Confidence**: Based on confirmation count (0.7 - 0.95)

## Resolution Algorithm

```dart
class AccountResolver {
  Future<AccountResolution> resolve(ExtractedEntities entities, String sender) {
    List<AccountMatch> candidates = [];
    
    // Strategy 1: Exact identifier match
    if (entities.accountIdentifier != null) {
      final account = findByIdentifier(entities.accountIdentifier!);
      if (account != null) {
        return AccountResolution(
          account: account,
          confidence: 0.95,
          strategy: 'identifier_match',
        );
      }
    }
    
    // Strategy 2: SMS sender pattern match
    final senderMatches = findBySenderPattern(sender);
    candidates.addAll(senderMatches);
    
    // Strategy 3: Institution match
    if (entities.institution != null) {
      final institutionMatches = findByInstitution(entities.institution!);
      candidates.addAll(institutionMatches);
    }
    
    // Strategy 4: Historical mapping
    final historicalMatch = findByHistoricalMapping(
      entities.accountIdentifier,
      entities.institution,
      sender,
    );
    if (historicalMatch != null) {
      candidates.add(historicalMatch);
    }
    
    // Rank candidates by confidence
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    if (candidates.isEmpty) {
      return AccountResolution.noMatch(
        suggestion: createAccountCandidate(entities, sender),
      );
    }
    
    return AccountResolution(
      account: candidates.first.account,
      confidence: candidates.first.confidence,
      strategy: candidates.first.strategy,
      alternatives: candidates.skip(1).toList(),
    );
  }
}
```

## Creating Account Candidates

When no match found, create a candidate for user review.

```dart
class AccountCandidate {
  final String suggestedName;         // "HDFC Card ending 1234"
  final String? institutionName;      // "HDFC"
  final String? accountIdentifier;    // "1234"
  final String suggestedType;         // "credit_card"
  final List<String> smsKeywords;     // ["HDFCBK"]
  final int transactionCount;         // How many SMS match this
  final double confidenceScore;       // 0.0 - 1.0
}

AccountCandidate createCandidate(ExtractedEntities entities, String sender) {
  return AccountCandidate(
    suggestedName: buildName(entities),
    institutionName: entities.institution,
    accountIdentifier: entities.accountIdentifier,
    suggestedType: guessAccountType(entities),
    smsKeywords: [normalizeSender(sender)],
    transactionCount: 1,
    confidenceScore: 0.7,
  );
}

String buildName(ExtractedEntities entities) {
  // "HDFC Card ending 1234"
  final parts = <String>[];
  if (entities.institution != null) parts.add(entities.institution!);
  if (entities.accountType != null) parts.add(entities.accountType!.name);
  if (entities.accountIdentifier != null) {
    parts.add('ending ${entities.accountIdentifier}');
  }
  return parts.join(' ').trim();
}
```

## Auto-Creating Accounts

For high-confidence candidates, auto-create accounts.

```dart
bool shouldAutoCreate(AccountCandidate candidate) {
  return candidate.confidenceScore >= 0.85 &&
         candidate.accountIdentifier != null &&
         candidate.institutionName != null;
}

Account autoCreateAccount(AccountCandidate candidate) {
  return Account(
    name: candidate.suggestedName,
    type: candidate.suggestedType,
    institutionName: candidate.institutionName,
    accountIdentifier: candidate.accountIdentifier,
    smsKeywords: candidate.smsKeywords,
    source: 'sms_auto',
    confidenceScore: candidate.confidenceScore,
    requiresConfirmation: true,  // User should review
  );
}
```

## Handling Edge Cases

### Multiple Accounts from Same Bank

```
User has:
- "HDFC Credit Card ending 1234"
- "HDFC Savings Account ending 5678"

SMS: "HDFC Bank debited Rs.500"
(no identifier in SMS)

Resolution:
1. Cannot auto-resolve
2. Show both options to user
3. Learn from user choice for future
```

### Transfer Between Accounts

```
SMS: "Rs.1000 transferred from XX1234 to XX5678"

Extracted:
- fromAccountIdentifier: "1234"
- toAccountIdentifier: "5678"

Resolution:
1. Resolve both accounts separately
2. Create transfer transaction
3. Link both transactions
```

### Account Type Mismatches

```
SMS says "Card" but existing account is type "Savings"

Options:
1. Trust SMS → Update account type
2. Trust existing → Use account anyway
3. Ask user to resolve

Default: Use existing account but flag for review
```

## Confidence Thresholds

```dart
class ResolutionConfidence {
  static const double autoAccept = 0.9;      // Auto-use this account
  static const double medium = 0.7;          // Use but flag for review
  static const double requiresReview = 0.5;  // User must confirm
  
  static bool shouldAutoAccept(double confidence) {
    return confidence >= autoAccept;
  }
  
  static bool needsUserReview(double confidence) {
    return confidence < requiresReview;
  }
}
```

## Learning from User Corrections

When user corrects account assignment:

```dart
void learnFromCorrection(
  ExtractedEntities entities,
  String sender,
  int correctAccountId,
) {
  // Store SMS pattern → Account mapping
  final mapping = SMSAccountMapping(
    smsPattern: buildPattern(entities, sender),
    accountId: correctAccountId,
    confirmationCount: 1,
  );
  
  mappingRepository.save(mapping);
  
  // Update account keywords if needed
  final account = getAccount(correctAccountId);
  if (!account.smsKeywords.contains(sender)) {
    account.smsKeywords.add(normalizeSender(sender));
    accountRepository.update(account);
  }
}
```

## Multi-Account Support

### Handling Multiple Matches

```dart
class AccountResolution {
  final Account? account;              // Primary match
  final double confidence;
  final String strategy;
  final List<AccountMatch> alternatives; // Other possibilities
  
  bool get hasMultipleOptions => alternatives.isNotEmpty;
  bool get requiresUserChoice => confidence < 0.9 && hasMultipleOptions;
}
```

### User Selection UI

When multiple accounts match:
```
┌─────────────────────────────────────┐
│ Which account for this transaction? │
├─────────────────────────────────────┤
│ ○ HDFC Credit Card ending 1234      │
│   (Confidence: 85%)                 │
│                                     │
│ ○ HDFC Savings ending 5678          │
│   (Confidence: 70%)                 │
│                                     │
│ ○ Create new account                │
├─────────────────────────────────────┤
│ [ ] Remember this choice            │
│ [Cancel] [Confirm]                  │
└─────────────────────────────────────┘
```

## Performance Optimization

### Caching

```dart
class AccountResolverCache {
  // Cache recent resolutions
  final Map<String, AccountResolution> _cache = {};
  
  AccountResolution? getCached(String cacheKey) {
    return _cache[cacheKey];
  }
  
  void cache(String key, AccountResolution resolution) {
    _cache[key] = resolution;
    // Limit cache size
    if (_cache.length > 100) {
      _cache.remove(_cache.keys.first);
    }
  }
}
```

### Indexing

Database indexes for fast lookups:
```sql
CREATE INDEX idx_accounts_identifier ON accounts(account_identifier);
CREATE INDEX idx_accounts_institution ON accounts(institution_name);
CREATE INDEX idx_sms_mappings_pattern ON sms_account_mappings(sms_pattern);
```

## Testing

```dart
test('Resolve by exact identifier match', () {
  final account = Account(
    name: 'HDFC Credit Card',
    accountIdentifier: '1234',
  );
  
  final entities = ExtractedEntities(
    accountIdentifier: '1234',
  );
  
  final resolution = resolver.resolve(entities, 'HDFCBK');
  
  expect(resolution.account, account);
  expect(resolution.confidence, greaterThan(0.9));
});

test('Create candidate when no match', () {
  final entities = ExtractedEntities(
    institution: 'NewBank',
    accountIdentifier: '9999',
  );
  
  final resolution = resolver.resolve(entities, 'NEWBANK');
  
  expect(resolution.account, isNull);
  expect(resolution.candidate, isNotNull);
  expect(resolution.candidate.suggestedName, contains('NewBank'));
});
```

## Metrics

Track resolution performance:
- **Auto-resolution rate**: % resolved without user input
- **Accuracy**: % correct when auto-resolved
- **User correction rate**: How often users change the match
- **Candidate creation rate**: How often new accounts suggested

Target metrics:
- Auto-resolution: > 90%
- Accuracy: > 95%
- User corrections: < 5%

## Next Steps

After resolution:
- [Transfer Detection](transfer-detection.md) - Check if transaction is a transfer
- [Entity Extraction](entity-extraction.md) - Review extraction process

---

*For implementation, see `lib/services/account_resolver.dart`*
