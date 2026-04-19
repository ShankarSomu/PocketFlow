# SMS-First Personal Finance Intelligence Engine
## Technical Design Document v1.0

**Target Regions:** United States & India  
**Primary Data Source:** SMS Messages  
**Design Philosophy:** Privacy-Safe, Auto-Learning, High-Confidence Intelligence  

---

## Executive Summary

This document specifies a comprehensive SMS-first financial intelligence system that automatically processes SMS messages from US and Indian financial institutions, extracts structured financial events, resolves transactions to accounts, detects recurring patterns, identifies transfers, and continuously learns from user feedback.

**Core Capabilities:**
- Automatic account discovery and creation from SMS
- Transaction extraction with confidence scoring
- Transfer detection between accounts (multi-bank support)
- Recurring pattern detection (subscriptions, salaries, EMIs)
- Pending action system for unresolved events
- Privacy-safe processing with zero OTP/password storage
- Continuous learning from user corrections

---

## 1. System Architecture

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       SMS Data Source Layer                      │
│  (Android SMS Inbox - Permission-Gated, Read-Only Access)       │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    1. INGESTION LAYER                            │
│  • SMS Reader Service                                            │
│  • Deduplication (by SMS ID)                                     │
│  • Privacy Filter (OTP/Password Removal)                         │
│  • Metadata Sanitization                                         │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                 2. CLASSIFICATION LAYER                          │
│  • Financial SMS Detector                                        │
│  • Message Type Classifier:                                      │
│    - Transaction (Debit/Credit)                                  │
│    - Transfer                                                    │
│    - Account Update (Balance, Credit Limit)                      │
│    - Payment Reminder                                            │
│    - Unknown Financial Event                                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              3. ENTITY EXTRACTION LAYER                          │
│  • Amount Extractor (Multi-Currency)                             │
│  • Merchant/Sender Extractor                                     │
│  • Account Identifier Extractor                                  │
│  • Institution Name Extractor                                    │
│  • Timestamp Normalizer                                          │
│  • Transaction Type Classifier                                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│           4. ACCOUNT RESOLUTION ENGINE                           │
│  • Priority Matching System:                                     │
│    1. Exact Account Identifier Match                             │
│    2. Institution Name Match                                     │
│    3. SMS Template Pattern Match                                 │
│    4. Historical Transaction Mapping                             │
│  • Confidence Scoring                                            │
│  • Account Candidate Creation                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│         5. TRANSFER DETECTION ENGINE                             │
│  • Debit-Credit Pair Matching                                    │
│  • Cross-Account Amount Correlation                              │
│  • Timestamp Window Analysis                                     │
│  • Sender/Receiver Pattern Matching                              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│       6. RECURRING PATTERN DETECTION ENGINE                      │
│  • Merchant Frequency Analysis                                   │
│  • Amount Pattern Recognition (with tolerance)                   │
│  • Temporal Interval Detection                                   │
│  • Confidence-Based Grouping                                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│            7. PENDING ACTION SYSTEM                              │
│  • Low-Confidence Transaction Queue                              │
│  • Missing Account Resolution Queue                              │
│  • Ambiguous Transfer Resolution Queue                           │
│  • User Review & Correction Interface                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│          8. FINANCIAL INTELLIGENCE LAYER                         │
│  • Spending Trends by Merchant                                   │
│  • Category-wise Analysis                                        │
│  • Subscription Dashboard                                        │
│  • Income vs Expense Analytics                                   │
│  • Behavioral Pattern Insights                                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│           9. LEARNING & FEEDBACK LOOP                            │
│  • User Correction Storage                                       │
│  • Pattern Refinement Engine                                     │
│  • Confidence Score Adjustment                                   │
│  • Template Learning from Corrections                            │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow Sequence

```
SMS Message → Privacy Filter → Classification → Entity Extraction 
  → Account Resolution → Transfer/Recurring Detection → Storage
  → User Review (if low confidence) → Feedback Loop → Intelligence
```

---

## 2. Core Data Models

### 2.1 Enhanced Account Model

```dart
class Account {
  final int? id;
  final String name;                    // User-friendly name
  final String type;                    // 'checking', 'credit', 'savings', etc.
  final double balance;
  
  // SMS Matching & Resolution Fields
  final String? institutionName;        // e.g., "Chase", "HDFC Bank", "ICICI"
  final String? accountIdentifier;      // Primary match key: "****1234", "UPI: user@bank"
  final List<String>? smsKeywords;      // ["HDFCBK", "HDFC BANK", "AD-HDFCBK"]
  final String? accountAlias;           // User-set display name
  final String? last4;                  // Last 4 digits
  
  // Metadata
  final AccountSource source;           // 'manual', 'sms_auto', 'sms_confirmed'
  final double? confidenceScore;        // 0.0-1.0 for auto-created accounts
  final bool requiresConfirmation;      // Flag for user verification
  final DateTime? createdFromSmsDate;   // When SMS first detected this account
  
  // Credit Card Specific
  final int? dueDateDay;
  final double? creditLimit;
  
  final DateTime createdAt;
  final DateTime? deletedAt;
}

enum AccountSource {
  manual,           // User created
  smsAuto,          // Auto-created from SMS (needs review)
  smsConfirmed,     // User confirmed auto-created account
  import,           // Imported from file
}
```

### 2.2 Enhanced Transaction Model

```dart
class Transaction {
  final int? id;
  final String type;                    // 'income', 'expense', 'transfer'
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final int? accountId;
  
  // SMS Intelligence Fields
  final String? smsSource;              // Original SMS text (sanitized)
  final String? smsId;                  // SMS message ID for deduplication
  final String sourceType;              // 'sms', 'manual', 'recurring', 'import'
  final String? merchant;               // Standardized merchant name
  final double? confidenceScore;        // 0.0-1.0 matching confidence
  final bool needsReview;               // Requires user verification
  final String? extractedIdentifier;    // Account identifier from SMS
  final String? extractedInstitution;   // Bank name from SMS
  
  // Transfer Linking
  final int? linkedTransactionId;       // Paired transfer transaction
  final String? transferReference;      // Grouping ID for transfer pairs
  
  // Recurring Pattern
  final int? recurringGroupId;          // Links to recurring pattern
  final bool isRecurringCandidate;      // Flag for potential recurring
  
  // Metadata
  final DateTime createdAt;
  final DateTime? deletedAt;
}
```

### 2.3 New: Pending Action Model

```dart
class PendingAction {
  final int? id;
  final String actionType;              // 'confirm_account', 'confirm_transaction', 
                                         // 'resolve_transfer', 'review_recurring'
  final String priority;                // 'high', 'medium', 'low'
  final DateTime createdAt;
  
  // Associated Data
  final int? transactionId;
  final int? accountCandidateId;
  final String? smsSource;
  final Map<String, dynamic>? metadata; // JSON blob for context
  
  // Resolution
  final String status;                  // 'pending', 'resolved', 'dismissed'
  final DateTime? resolvedAt;
  final String? resolutionAction;       // What user did
  
  // Display
  final String title;                   // "Confirm new account: Chase ****1234"
  final String description;             // Detailed explanation
}
```

### 2.4 New: Account Candidate Model

```dart
class AccountCandidate {
  final int? id;
  final String? institutionName;        // Extracted from SMS
  final String? accountIdentifier;      // "****1234", "UPI: xyz@bank"
  final List<String> smsKeywords;       // All sender IDs seen
  final String suggestedType;           // Best guess: 'checking', 'credit'
  final double confidenceScore;         // How sure we are
  
  final int transactionCount;           // # of SMS linked to this candidate
  final DateTime firstSeenDate;         // First SMS date
  final DateTime lastSeenDate;          // Most recent SMS
  
  final String status;                  // 'pending', 'confirmed', 'merged', 'rejected'
  final int? mergedIntoAccountId;       // If merged
  final DateTime createdAt;
}
```

### 2.5 New: Recurring Pattern Model

```dart
class RecurringPattern {
  final int? id;
  final String? merchant;               // Identified merchant
  final String category;                // Spending category
  final String type;                    // 'income' or 'expense'
  
  // Pattern Characteristics
  final double averageAmount;
  final double amountVariance;          // Standard deviation
  final String frequency;               // 'weekly', 'monthly', 'yearly'
  final int intervalDays;               // Average days between occurrences
  
  // Confidence & Validation
  final int occurrenceCount;            // How many times detected
  final double confidenceScore;         // 0.0-1.0
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;
  final DateTime? nextExpectedDate;     // Prediction
  
  // Linking
  final List<int> transactionIds;       // All member transactions
  final int? accountId;                 // Primary account
  
  final String status;                  // 'candidate', 'confirmed', 'inactive'
  final DateTime createdAt;
}
```

### 2.6 New: SMS Template Model (Learning System)

```dart
class SmsTemplate {
  final int? id;
  final String institutionName;         // "Chase", "HDFC Bank"
  final List<String> senderPatterns;    // Regex patterns for sender IDs
  final String messagePattern;          // Regex for message body
  
  // Extraction Rules
  final String? amountPattern;          // Amount extraction regex
  final String? merchantPattern;        // Merchant extraction regex
  final String? accountIdPattern;       // Account identifier pattern
  final String? balancePattern;         // Balance extraction
  
  // Classification
  final String transactionType;         // 'debit', 'credit', 'balance', 'transfer'
  
  // Learning Metadata
  final int matchCount;                 // Times this template matched
  final int userConfirmations;          // User validated matches
  final int userRejections;             // User rejected matches
  final double accuracy;                // confirmations / (confirmations + rejections)
  
  final bool isUserCreated;             // User-defined template
  final DateTime createdAt;
  final DateTime lastUsed;
}
```

### 2.7 New: Transfer Pair Model

```dart
class TransferPair {
  final int? id;
  final int debitTransactionId;         // Source transaction
  final int creditTransactionId;        // Destination transaction
  final double amount;
  final DateTime timestamp;
  
  final int sourceAccountId;
  final int destinationAccountId;
  
  final double confidenceScore;         // Match confidence
  final String detectionMethod;         // 'amount_time', 'reference_id', 'user_confirmed'
  
  final String status;                  // 'detected', 'confirmed', 'rejected'
  final DateTime createdAt;
}
```

---

## 3. SMS Processing Pipeline Implementation

### 3.1 Layer 1: Ingestion

**Responsibilities:**
- Read SMS from Android inbox
- Assign unique SMS IDs
- Privacy filtering (OTP/password removal)
- Deduplication

**Implementation:**

```dart
class SmsIngestionService {
  /// Privacy-safe SMS filters
  static final _otpPatterns = [
    RegExp(r'\b\d{4,6}\b.*?(OTP|code|verification|pin)', caseSensitive: false),
    RegExp(r'(OTP|code|verification|pin).*?\b\d{4,6}\b', caseSensitive: false),
    RegExp(r'one.?time.?password', caseSensitive: false),
  ];
  
  static final _passwordPatterns = [
    RegExp(r'password is \w+', caseSensitive: false),
    RegExp(r'pin is \d+', caseSensitive: false),
  ];
  
  /// Ingest SMS messages with privacy filtering
  static Future<List<RawSmsMessage>> ingestMessages({
    DateTime? since,
    int? limit,
  }) async {
    final query = SmsQuery();
    final messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      start: since?.millisecondsSinceEpoch,
      count: limit,
    );
    
    final processed = <RawSmsMessage>[];
    
    for (final sms in messages) {
      // Privacy check - skip OTP/password messages
      if (_isOtpOrPassword(sms.body ?? '')) {
        AppLogger.info('sms_ingest', 'Skipped OTP/password message');
        continue;
      }
      
      // Check if already processed
      if (await _isAlreadyProcessed(sms.id)) continue;
      
      processed.add(RawSmsMessage(
        id: sms.id!,
        sender: sms.sender ?? '',
        body: sms.body ?? '',
        timestamp: sms.date ?? DateTime.now(),
      ));
    }
    
    return processed;
  }
  
  static bool _isOtpOrPassword(String body) {
    for (final pattern in [..._otpPatterns, ..._passwordPatterns]) {
      if (pattern.hasMatch(body)) return true;
    }
    return false;
  }
}
```

### 3.2 Layer 2: Classification

**Message Types:**
1. **Transaction (Debit/Credit)** - Money movement
2. **Transfer** - Inter-account transfer indicators
3. **Account Update** - Balance, credit limit changes
4. **Payment Reminder** - Due date notifications
5. **Unknown Financial** - Has financial keywords but unclear type

**Implementation:**

```dart
class SmsClassificationService {
  static SmsClassification classify(RawSmsMessage sms) {
    final body = sms.body.toLowerCase();
    final sender = sms.sender.toLowerCase();
    
    // Priority 1: Must be from financial institution
    if (!_isFinancialSender(sender, body)) {
      return SmsClassification(type: SmsType.nonFinancial);
    }
    
    // Priority 2: Detect transaction type
    final hasAmount = _amountPattern.hasMatch(body);
    final hasDebit = _containsAny(body, _debitKeywords);
    final hasCredit = _containsAny(body, _creditKeywords);
    final hasTransfer = _containsAny(body, _transferKeywords);
    final hasBalance = _containsAny(body, _balanceKeywords);
    
    // Transfer detection (specific patterns)
    if (hasTransfer && hasAmount) {
      return SmsClassification(
        type: SmsType.transfer,
        confidence: 0.85,
      );
    }
    
    // Transaction (debit)
    if (hasDebit && hasAmount) {
      return SmsClassification(
        type: SmsType.transactionDebit,
        confidence: 0.9,
      );
    }
    
    // Transaction (credit)
    if (hasCredit && hasAmount) {
      return SmsClassification(
        type: SmsType.transactionCredit,
        confidence: 0.9,
      );
    }
    
    // Balance update
    if (hasBalance && hasAmount) {
      return SmsClassification(
        type: SmsType.accountUpdate,
        confidence: 0.8,
      );
    }
    
    // Unknown but financial
    if (hasAmount) {
      return SmsClassification(
        type: SmsType.unknownFinancial,
        confidence: 0.5,
      );
    }
    
    return SmsClassification(type: SmsType.nonFinancial);
  }
  
  static final _debitKeywords = [
    'debited', 'deducted', 'spent', 'paid', 'withdrawn', 
    'charged', 'purchase', 'payment of', 'txn of',
  ];
  
  static final _creditKeywords = [
    'credited', 'received', 'deposited', 'refund', 
    'cashback', 'salary', 'amount credited',
  ];
  
  static final _transferKeywords = [
    'transferred to', 'transfer from', 'sent to', 
    'upi transfer', 'imps transfer', 'neft transfer',
  ];
  
  static final _balanceKeywords = [
    'available balance', 'total balance', 'current balance',
    'avl bal', 'total bal', 'closing balance',
  ];
}
```

### 3.3 Layer 3: Entity Extraction

**Extracted Entities:**
- Amount (with currency)
- Merchant/Sender
- Account Identifier (last 4 digits, UPI ID, etc.)
- Institution Name
- Balance (if present)
- Reference Number
- Timestamp

**Implementation:**

```dart
class EntityExtractionService {
  /// Extract all financial entities from SMS
  static ExtractedEntities extract(RawSmsMessage sms, SmsClassification classification) {
    final body = sms.body;
    final sender = sms.sender;
    
    return ExtractedEntities(
      amount: _extractAmount(body),
      merchant: _extractMerchant(body, classification.type),
      accountIdentifier: _extractAccountIdentifier(body),
      institutionName: _extractInstitution(sender, body),
      balance: _extractBalance(body),
      referenceNumber: _extractReference(body),
      transactionType: classification.type,
      timestamp: sms.timestamp,
      confidenceScore: _calculateConfidence(/* extracted data */),
    );
  }
  
  /// Multi-currency amount extraction
  static double? _extractAmount(String body) {
    // Patterns: $1,234.56 | USD 1234 | Rs.1,000 | INR 500 | ₹500 | RM 25
    final patterns = [
      RegExp(r'(?:USD|INR|Rs\.?|₹|RM|AED|EUR|GBP)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'\$\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:USD|INR|Rs|₹)', caseSensitive: false),
      RegExp(r'amt.*?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];
    
    double? maxAmount;
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(body);
      for (final match in matches) {
        final raw = match.group(1)?.replaceAll(',', '');
        final value = double.tryParse(raw ?? '');
        if (value != null && value > 0 && value < 10000000) {
          if (maxAmount == null || value > maxAmount) {
            maxAmount = value;
          }
        }
      }
    }
    
    return maxAmount;
  }
  
  /// Extract account identifier (last 4, UPI ID, card number)
  static String? _extractAccountIdentifier(String body) {
    // Patterns:
    // A/c ****1234
    // Card ending 5678
    // UPI ID: user@okicici
    // XX1234 (common format)
    
    final patterns = [
      RegExp(r'(?:a/c|account|card).*?[xX*]{4}(\d{4})', caseSensitive: false),
      RegExp(r'ending\s+(\d{4})', caseSensitive: false),
      RegExp(r'[xX]{2}(\d{4})\b'),
      RegExp(r'UPI\s*(?:ID)?:\s*(\S+@\S+)', caseSensitive: false),
      RegExp(r'VPA:\s*(\S+@\S+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final extracted = match.group(1);
        if (extracted != null && extracted.isNotEmpty) {
          // Standardize format
          if (extracted.contains('@')) {
            return 'UPI:$extracted'; // UPI ID
          } else {
            return '****$extracted'; // Last 4 digits
          }
        }
      }
    }
    
    return null;
  }
  
  /// Extract institution name from sender/body
  static String? _extractInstitution(String sender, String body) {
    // US Banks
    final usInstitutions = {
      'chase': 'Chase Bank',
      'bofa': 'Bank of America',
      'wellsfargo': 'Wells Fargo',
      'citi': 'Citibank',
      'capitalone': 'Capital One',
      'amex': 'American Express',
      'discover': 'Discover',
      'usbank': 'US Bank',
    };
    
    // Indian Banks
    final indianInstitutions = {
      'hdfcbk': 'HDFC Bank',
      'icicibk': 'ICICI Bank',
      'sbiinb': 'State Bank of India',
      'axisbk': 'Axis Bank',
      'kotakb': 'Kotak Mahindra Bank',
      'pnbsms': 'Punjab National Bank',
      'bobimt': 'Bank of Baroda',
      'yesbnk': 'Yes Bank',
      'idfcbk': 'IDFC First Bank',
    };
    
    final allInstitutions = {...usInstitutions, ...indianInstitutions};
    final searchText = '${sender.toLowerCase()} ${body.toLowerCase()}';
    
    for (final entry in allInstitutions.entries) {
      if (searchText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Extract merchant name using multiple strategies
  static String? _extractMerchant(String body, SmsType type) {
    if (type != SmsType.transactionDebit && type != SmsType.transactionCredit) {
      return null;
    }
    
    // Patterns: "at MERCHANT", "to MERCHANT", "on MERCHANT"
    final patterns = [
      RegExp(r'\bat\s+([A-Za-z0-9 &\-\'\.]{3,40})', caseSensitive: false),
      RegExp(r'\bto\s+([A-Za-z0-9 &\-\'\.]{3,40})', caseSensitive: false),
      RegExp(r'\bon\s+([A-Za-z0-9 &\-\'\.]{3,40})', caseSensitive: false),
      RegExp(r'\bfor\s+([A-Za-z0-9 &\-\'\.]{3,40})', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length >= 3) {
          // Clean up
          return merchant
              .replaceAll(RegExp(r'[.\s]+$'), '')
              .trim();
        }
      }
    }
    
    return null;
  }
}
```

---

## 4. Account Resolution Engine

**Priority Matching Algorithm:**

```
1. Exact Account Identifier Match (confidence: 0.95)
   ↓ (if no match)
2. Institution + Partial Identifier (confidence: 0.80)
   ↓ (if no match)
3. SMS Template Pattern Match (confidence: 0.70)
   ↓ (if no match)
4. Historical Transaction Mapping (confidence: 0.60)
   ↓ (if no match)
5. Create Account Candidate (confidence: 0.50)
```

**Implementation:**

```dart
class AccountResolutionEngine {
  /// Resolve SMS to an existing account or create candidate
  static Future<AccountResolution> resolve(ExtractedEntities entities) async {
    final db = await AppDatabase.db;
    
    // Strategy 1: Exact identifier match
    if (entities.accountIdentifier != null) {
      final exactMatch = await db.query(
        'accounts',
        where: 'account_identifier = ? AND deleted_at IS NULL',
        whereArgs: [entities.accountIdentifier],
      );
      
      if (exactMatch.isNotEmpty) {
        return AccountResolution(
          accountId: exactMatch.first['id'] as int,
          confidence: 0.95,
          method: 'exact_identifier',
        );
      }
    }
    
    // Strategy 2: Institution + partial match
    if (entities.institutionName != null && entities.accountIdentifier != null) {
      final partialMatch = await db.query(
        'accounts',
        where: 'institution_name = ? AND account_identifier LIKE ? AND deleted_at IS NULL',
        whereArgs: [entities.institutionName, '%${entities.accountIdentifier!.takeLast(4)}'],
      );
      
      if (partialMatch.isNotEmpty) {
        return AccountResolution(
          accountId: partialMatch.first['id'] as int,
          confidence: 0.80,
          method: 'institution_partial',
        );
      }
    }
    
    // Strategy 3: SMS keyword match
    if (entities.institutionName != null) {
      final keywordMatch = await db.rawQuery('''
        SELECT id FROM accounts 
        WHERE deleted_at IS NULL 
        AND (institution_name = ? OR sms_keywords LIKE ?)
        LIMIT 1
      ''', [entities.institutionName, '%${entities.institutionName}%']);
      
      if (keywordMatch.isNotEmpty) {
        return AccountResolution(
          accountId: keywordMatch.first['id'] as int,
          confidence: 0.70,
          method: 'sms_keyword',
        );
      }
    }
    
    // Strategy 4: Historical transaction pattern
    final historicalMatch = await _findHistoricalMatch(entities);
    if (historicalMatch != null) {
      return AccountResolution(
        accountId: historicalMatch,
        confidence: 0.60,
        method: 'historical_pattern',
      );
    }
    
    // Strategy 5: Create account candidate
    final candidateId = await _createAccountCandidate(entities);
    return AccountResolution(
      accountCandidateId: candidateId,
      confidence: 0.50,
      method: 'new_candidate',
      requiresUserConfirmation: true,
    );
  }
  
  /// Create a pending account candidate
  static Future<int> _createAccountCandidate(ExtractedEntities entities) async {
    final db = await AppDatabase.db;
    
    final candidate = {
      'institution_name': entities.institutionName,
      'account_identifier': entities.accountIdentifier,
      'suggested_type': _guessAccountType(entities),
      'confidence_score': 0.50,
      'transaction_count': 1,
      'first_seen_date': entities.timestamp.toIso8601String(),
      'last_seen_date': entities.timestamp.toIso8601String(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };
    
    return await db.insert('account_candidates', candidate);
  }
  
  static String _guessAccountType(ExtractedEntities entities) {
    final keywords = entities.institutionName?.toLowerCase() ?? '';
    if (keywords.contains('credit') || keywords.contains('amex') || 
        keywords.contains('visa') || keywords.contains('mastercard')) {
      return 'credit';
    }
    return 'checking';
  }
}
```

---

## 5. Transfer Detection Engine

**Detection Strategies:**

1. **Amount-Time Correlation**
   - Match debit/credit pairs with same amount
   - Within time window (±2 hours)
   - Different accounts

2. **Reference Number Matching**
   - UPI/IMPS/NEFT reference IDs
   - Bank transfer confirmation numbers

3. **UPI Transfer Patterns**
   - Explicit UPI transfer keywords
   - VPA matching

**Implementation:**

```dart
class TransferDetectionEngine {
  /// Detect potential transfers between accounts
  static Future<List<TransferPair>> detectTransfers({
    DateTime? since,
  }) async {
    final db = await AppDatabase.db;
    
    // Get all recent debit/credit transactions
    final cutoff = since ?? DateTime.now().subtract(const Duration(days: 7));
    
    final debits = await db.query(
      'transactions',
      where: "type = 'expense' AND date >= ? AND deleted_at IS NULL AND source_type = 'sms'",
      whereArgs: [cutoff.toIso8601String()],
    );
    
    final credits = await db.query(
      'transactions',
      where: "type = 'income' AND date >= ? AND deleted_at IS NULL AND source_type = 'sms'",
      whereArgs: [cutoff.toIso8601String()],
    );
    
    final pairs = <TransferPair>[];
    
    for (final debit in debits) {
      for (final credit in credits) {
        final match = _evaluateTransferMatch(debit, credit);
        if (match != null && match.confidenceScore >= 0.70) {
          pairs.add(match);
        }
      }
    }
    
    return pairs;
  }
  
  static TransferPair? _evaluateTransferMatch(
    Map<String, dynamic> debit,
    Map<String, dynamic> credit,
  ) {
    final debitAmount = debit['amount'] as double;
    final creditAmount = credit['amount'] as double;
    final debitDate = DateTime.parse(debit['date'] as String);
    final creditDate = DateTime.parse(credit['date'] as String);
    
    // Amount match (exact or within 1%)
    final amountDiff = (debitAmount - creditAmount).abs();
    final amountTolerance = debitAmount * 0.01;
    if (amountDiff > amountTolerance) return null;
    
    // Time window (within 2 hours)
    final timeDiff = debitDate.difference(creditDate).abs();
    if (timeDiff.inHours > 2) return null;
    
    // Different accounts
    if (debit['account_id'] == credit['account_id']) return null;
    
    // Calculate confidence
    double confidence = 0.70;
    
    // Boost: Exact amount match
    if (amountDiff == 0) confidence += 0.10;
    
    // Boost: Close time match (< 5 minutes)
    if (timeDiff.inMinutes < 5) confidence += 0.10;
    
    // Boost: Transfer keywords in SMS
    final debitSms = debit['sms_source'] as String?;
    final creditSms = credit['sms_source'] as String?;
    if (debitSms != null && creditSms != null) {
      if (_hasTransferKeywords(debitSms) || _hasTransferKeywords(creditSms)) {
        confidence += 0.10;
      }
    }
    
    return TransferPair(
      debitTransactionId: debit['id'] as int,
      creditTransactionId: credit['id'] as int,
      amount: debitAmount,
      timestamp: debitDate,
      sourceAccountId: debit['account_id'] as int,
      destinationAccountId: credit['account_id'] as int,
      confidenceScore: confidence,
      detectionMethod: 'amount_time',
      status: confidence >= 0.90 ? 'confirmed' : 'detected',
      createdAt: DateTime.now(),
    );
  }
  
  static bool _hasTransferKeywords(String sms) {
    final keywords = ['transfer', 'upi', 'imps', 'neft', 'rtgs', 'sent to', 'received from'];
    final lower = sms.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }
}
```

---

## 6. Recurring Pattern Detection Engine

**Detection Algorithm:**

```
For each merchant/category:
1. Group transactions by merchant
2. Calculate time intervals between occurrences
3. Detect regular patterns (weekly, monthly, yearly)
4. Analyze amount consistency
5. Assign confidence score based on:
   - Number of occurrences (≥3 required)
   - Time regularity (coefficient of variation < 0.15)
   - Amount consistency (CV < 0.20)
```

**Implementation:**

```dart
class RecurringPatternEngine {
  /// Detect recurring patterns from transaction history
  static Future<List<RecurringPattern>> detectPatterns({
    int minOccurrences = 3,
    double minConfidence = 0.70,
  }) async {
    final db = await AppDatabase.db;
    
    // Group transactions by merchant
    final merchants = await db.rawQuery('''
      SELECT merchant, category, type, account_id
      FROM transactions
      WHERE deleted_at IS NULL 
        AND merchant IS NOT NULL
        AND source_type = 'sms'
      GROUP BY merchant, category, type
      HAVING COUNT(*) >= ?
    ''', [minOccurrences]);
    
    final patterns = <RecurringPattern>[];
    
    for (final merchantGroup in merchants) {
      final merchant = merchantGroup['merchant'] as String;
      final category = merchantGroup['category'] as String;
      final type = merchantGroup['type'] as String;
      
      // Get all transactions for this merchant
      final transactions = await db.query(
        'transactions',
        where: 'merchant = ? AND category = ? AND type = ? AND deleted_at IS NULL',
        whereArgs: [merchant, category, type],
        orderBy: 'date ASC',
      );
      
      if (transactions.length < minOccurrences) continue;
      
      // Analyze pattern
      final pattern = _analyzePattern(transactions, merchant, category, type);
      
      if (pattern != null && pattern.confidenceScore >= minConfidence) {
        patterns.add(pattern);
      }
    }
    
    return patterns;
  }
  
  static RecurringPattern? _analyzePattern(
    List<Map<String, dynamic>> transactions,
    String merchant,
    String category,
    String type,
  ) {
    if (transactions.length < 3) return null;
    
    // Extract amounts and dates
    final amounts = transactions.map((t) => t['amount'] as double).toList();
    final dates = transactions.map((t) => DateTime.parse(t['date'] as String)).toList();
    final ids = transactions.map((t) => t['id'] as int).toList();
    
    // Calculate amount statistics
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    final amountVariance = _calculateStdDev(amounts);
    final amountCV = amountVariance / avgAmount;
    
    // Calculate time intervals
    final intervals = <int>[];
    for (int i = 1; i < dates.length; i++) {
      intervals.add(dates[i].difference(dates[i - 1]).inDays);
    }
    
    final avgInterval = intervals.reduce((a, b) => a + b) ~/ intervals.length;
    final intervalStdDev = _calculateStdDev(intervals.map((i) => i.toDouble()).toList());
    final intervalCV = intervalStdDev / avgInterval;
    
    // Determine frequency
    final frequency = _determineFrequency(avgInterval);
    
    // Calculate confidence
    double confidence = 0.50;
    
    // Boost: Number of occurrences
    if (transactions.length >= 5) confidence += 0.10;
    if (transactions.length >= 10) confidence += 0.10;
    
    // Boost: Amount consistency
    if (amountCV < 0.10) confidence += 0.15;
    else if (amountCV < 0.20) confidence += 0.10;
    
    // Boost: Time regularity
    if (intervalCV < 0.10) confidence += 0.15;
    else if (intervalCV < 0.15) confidence += 0.10;
    
    // Predict next occurrence
    final lastDate = dates.last;
    final nextExpected = lastDate.add(Duration(days: avgInterval));
    
    return RecurringPattern(
      merchant: merchant,
      category: category,
      type: type,
      averageAmount: avgAmount,
      amountVariance: amountVariance,
      frequency: frequency,
      intervalDays: avgInterval,
      occurrenceCount: transactions.length,
      confidenceScore: confidence,
      firstOccurrence: dates.first,
      lastOccurrence: dates.last,
      nextExpectedDate: nextExpected,
      transactionIds: ids,
      accountId: transactions.first['account_id'] as int?,
      status: confidence >= 0.80 ? 'confirmed' : 'candidate',
      createdAt: DateTime.now(),
    );
  }
  
  static String _determineFrequency(int avgDays) {
    if (avgDays <= 8) return 'weekly';
    if (avgDays <= 17) return 'biweekly';
    if (avgDays <= 35) return 'monthly';
    if (avgDays <= 100) return 'quarterly';
    if (avgDays <= 200) return 'semi-annual';
    return 'yearly';
  }
  
  static double _calculateStdDev(List<double> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }
}
```

---

## 7. Pending Action System

**Action Types:**
1. **Confirm Account** - Review auto-created account candidates
2. **Confirm Transaction** - Review low-confidence transactions
3. **Resolve Transfer** - Link detected transfer pairs
4. **Review Recurring** - Confirm recurring pattern detection

**Implementation:**

```dart
class PendingActionService {
  /// Create pending action for user review
  static Future<int> createAction({
    required String actionType,
    required String priority,
    required String title,
    required String description,
    int? transactionId,
    int? accountCandidateId,
    String? smsSource,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await AppDatabase.db;
    
    final action = {
      'action_type': actionType,
      'priority': priority,
      'created_at': DateTime.now().toIso8601String(),
      'transaction_id': transactionId,
      'account_candidate_id': accountCandidateId,
      'sms_source': smsSource,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'status': 'pending',
      'title': title,
      'description': description,
    };
    
    return await db.insert('pending_actions', action);
  }
  
  /// Get all pending actions
  static Future<List<PendingAction>> getPendingActions() async {
    final db = await AppDatabase.db;
    
    final results = await db.query(
      'pending_actions',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: '''
        CASE priority
          WHEN 'high' THEN 1
          WHEN 'medium' THEN 2
          WHEN 'low' THEN 3
        END,
        created_at DESC
      ''',
    );
    
    return results.map((r) => PendingAction.fromMap(r)).toList();
  }
  
  /// Resolve action with user feedback
  static Future<void> resolveAction({
    required int actionId,
    required String resolutionAction,
    Map<String, dynamic>? feedback,
  }) async {
    final db = await AppDatabase.db;
    
    await db.update(
      'pending_actions',
      {
        'status': 'resolved',
        'resolved_at': DateTime.now().toIso8601String(),
        'resolution_action': resolutionAction,
        'metadata': feedback != null ? jsonEncode(feedback) : null,
      },
      where: 'id = ?',
      whereArgs: [actionId],
    );
    
    // Learn from resolution
    await _learnFromResolution(actionId, resolutionAction, feedback);
  }
  
  /// Learn patterns from user corrections
  static Future<void> _learnFromResolution(
    int actionId,
    String action,
    Map<String, dynamic>? feedback,
  ) async {
    // Update confidence scores, template patterns, etc.
    // This feeds into the learning system
    
    // Example: User confirmed an account candidate
    if (action == 'confirm_account' && feedback != null) {
      final candidateId = feedback['candidate_id'] as int?;
      if (candidateId != null) {
        // Boost confidence for this institution/pattern
        await _boostInstitutionConfidence(candidateId);
      }
    }
    
    // Example: User corrected merchant name
    if (action == 'correct_merchant' && feedback != null) {
      final wrongName = feedback['wrong_name'] as String?;
      final correctName = feedback['correct_name'] as String?;
      if (wrongName != null && correctName != null) {
        await _learnMerchantMapping(wrongName, correctName);
      }
    }
  }
}
```

---

## 8. Financial Intelligence Layer

**Analytics & Insights:**

```dart
class FinancialIntelligenceService {
  /// Generate spending trends by merchant
  static Future<List<MerchantTrend>> getMerchantTrends({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await AppDatabase.db;
    
    final results = await db.rawQuery('''
      SELECT 
        merchant,
        category,
        COUNT(*) as transaction_count,
        SUM(amount) as total_spent,
        AVG(amount) as average_amount,
        MIN(date) as first_transaction,
        MAX(date) as last_transaction
      FROM transactions
      WHERE type = 'expense'
        AND merchant IS NOT NULL
        AND date >= ?
        AND date <= ?
        AND deleted_at IS NULL
      GROUP BY merchant, category
      ORDER BY total_spent DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    
    return results.map((r) => MerchantTrend.fromMap(r)).toList();
  }
  
  /// Detect subscription services
  static Future<List<Subscription>> detectSubscriptions() async {
    // Get high-confidence recurring patterns that look like subscriptions
    final patterns = await RecurringPatternEngine.detectPatterns(
      minOccurrences: 3,
      minConfidence: 0.75,
    );
    
    return patterns
        .where((p) => p.type == 'expense' && _isSubscriptionLike(p))
        .map((p) => Subscription.fromPattern(p))
        .toList();
  }
  
  static bool _isSubscriptionLike(RecurringPattern pattern) {
    // Monthly frequency
    if (pattern.frequency != 'monthly') return false;
    
    // Consistent amount (low variance)
    if (pattern.amountVariance / pattern.averageAmount > 0.10) return false;
    
    // Known subscription merchants
    final subscriptionKeywords = [
      'netflix', 'spotify', 'youtube', 'prime', 'hulu',
      'disney', 'apple', 'microsoft', 'amazon', 'google',
    ];
    
    final merchant = pattern.merchant?.toLowerCase() ?? '';
    return subscriptionKeywords.any((k) => merchant.contains(k));
  }
  
  /// Income vs Expense analysis
  static Future<IncomeExpenseAnalysis> getIncomeExpenseAnalysis({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await AppDatabase.db;
    
    final income = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'income'
        AND date >= ?
        AND date <= ?
        AND deleted_at IS NULL
        AND category != 'transfer'
    ''', [start.toIso8601String(), end.toIso8601String()]);
    
    final expense = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'expense'
        AND date >= ?
        AND date <= ?
        AND deleted_at IS NULL
        AND category != 'transfer'
    ''', [start.toIso8601String(), end.toIso8601String()]);
    
    final totalIncome = (income.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpense = (expense.first['total'] as num?)?.toDouble() ?? 0.0;
    
    return IncomeExpenseAnalysis(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: totalIncome - totalExpense,
      savingsRate: totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome : 0.0,
      period: DateTimeRange(start: start, end: end),
    );
  }
}
```

---

## 9. Learning & Feedback System

**Learning Mechanisms:**

1. **Template Learning**
   - Extract patterns from confirmed SMS
   - Build institution-specific templates
   - Improve extraction accuracy

2. **Confidence Adjustment**
   - Boost patterns that user confirms
   - Reduce confidence for rejected patterns

3. **Merchant Mapping**
   - Learn merchant name variations
   - Build merchant alias database

**Implementation:**

```dart
class LearningEngine {
  /// Learn from user confirmation of account candidate
  static Future<void> learnAccountPattern(AccountCandidate candidate, int confirmedAccountId) async {
    final db = await AppDatabase.db;
    
    // Update all transactions linked to this candidate
    await db.rawUpdate('''
      UPDATE transactions
      SET account_id = ?, confidence_score = 0.95, needs_review = 0
      WHERE merchant LIKE ? OR sms_source LIKE ?
    ''', [
      confirmedAccountId,
      '%${candidate.institutionName}%',
      '%${candidate.institutionName}%',
    ]);
    
    // Create or update SMS template
    await _createOrUpdateTemplate(
      institutionName: candidate.institutionName!,
      senderPatterns: candidate.smsKeywords,
      accountId: confirmedAccountId,
    );
  }
  
  /// Learn merchant name variations
  static Future<void> learnMerchantMapping(String extractedName, String correctName) async {
    final db = await AppDatabase.db;
    
    // Store mapping
    await db.insert('merchant_mappings', {
      'extracted_name': extractedName,
      'correct_name': correctName,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Update existing transactions
    await db.rawUpdate('''
      UPDATE transactions
      SET merchant = ?
      WHERE merchant = ? AND deleted_at IS NULL
    ''', [correctName, extractedName]);
  }
  
  /// Adjust confidence based on user feedback
  static Future<void> adjustConfidence({
    required String institutionName,
    required bool wasCorrect,
  }) async {
    final db = await AppDatabase.db;
    
    // Find template
    final templates = await db.query(
      'sms_templates',
      where: 'institution_name = ?',
      whereArgs: [institutionName],
    );
    
    if (templates.isEmpty) return;
    
    final template = templates.first;
    final currentConfirmations = template['user_confirmations'] as int;
    final currentRejections = template['user_rejections'] as int;
    
    await db.update(
      'sms_templates',
      {
        'user_confirmations': wasCorrect ? currentConfirmations + 1 : currentConfirmations,
        'user_rejections': wasCorrect ? currentRejections : currentRejections + 1,
        'accuracy': wasCorrect
            ? (currentConfirmations + 1) / (currentConfirmations + currentRejections + 1)
            : currentConfirmations / (currentConfirmations + currentRejections + 1),
        'last_used': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [template['id']],
    );
  }
}
```

---

## 10. Privacy & Security Implementation

**Privacy Rules:**

```dart
class PrivacyGuard {
  /// Patterns to detect and skip
  static final _sensitivePatterns = [
    // OTP patterns
    RegExp(r'\b\d{4,6}\b.*?(OTP|code|verification|pin|password)', caseSensitive: false),
    RegExp(r'(OTP|code|verification|pin).*?\b\d{4,6}\b', caseSensitive: false),
    
    // Password/PIN reveals
    RegExp(r'(?:password|pin|cvv|security code) is \w+', caseSensitive: false),
    
    // SSN/Aadhaar
    RegExp(r'\b\d{9}\b'),    // SSN
    RegExp(r'\b\d{12}\b'),   // Aadhaar
    
    // Full card numbers
    RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b'),
  ];
  
  /// Check if SMS contains sensitive information
  static bool isSensitive(String smsBody) {
    for (final pattern in _sensitivePatterns) {
      if (pattern.hasMatch(smsBody)) return true;
    }
    return false;
  }
  
  /// Sanitize SMS before storage
  static String sanitize(String smsBody) {
    String sanitized = smsBody;
    
    // Remove full card numbers (keep last 4)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(\d{4})\s?(\d{4})\s?(\d{4})\s?(\d{4})\b'),
      (match) => '****-****-****-${match.group(4)}',
    );
    
    // Remove potential SSN/Aadhaar
    sanitized = sanitized.replaceAll(RegExp(r'\b\d{9,12}\b'), '***REDACTED***');
    
    return sanitized;
  }
  
  /// Data retention policy
  static Future<void> enforceRetentionPolicy() async {
    final db = await AppDatabase.db;
    
    // Delete SMS source older than 1 year
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    await db.rawUpdate('''
      UPDATE transactions
      SET sms_source = NULL
      WHERE date < ?
    ''', [cutoff.toIso8601String()]);
    
    // Delete resolved pending actions older than 90 days
    final actionCutoff = DateTime.now().subtract(const Duration(days: 90));
    await db.delete(
      'pending_actions',
      where: 'status = ? AND resolved_at < ?',
      whereArgs: ['resolved', actionCutoff.toIso8601String()],
    );
  }
}
```

---

## 11. Error Handling & Resilience

**Principles:**

1. **Never fail on malformed SMS** - Always classify as unknown
2. **Graceful degradation** - Partial extraction is better than none
3. **Confidence scoring** - Low confidence → pending action
4. **User escape hatch** - Always allow manual override

**Implementation:**

```dart
class SmsPipelineExecutor {
  /// Execute full pipeline with error handling
  static Future<SmsProcessingResult> process(RawSmsMessage sms) async {
    try {
      // Step 1: Privacy check
      if (PrivacyGuard.isSensitive(sms.body)) {
        return SmsProcessingResult(
          status: 'skipped',
          reason: 'privacy_filter',
        );
      }
      
      // Step 2: Classification
      final classification = SmsClassificationService.classify(sms);
      if (classification.type == SmsType.nonFinancial) {
        return SmsProcessingResult(
          status: 'skipped',
          reason: 'non_financial',
        );
      }
      
      // Step 3: Entity extraction (always returns partial results)
      final entities = EntityExtractionService.extract(sms, classification);
      
      // Step 4: Account resolution
      final accountResolution = await AccountResolutionEngine.resolve(entities);
      
      // Step 5: Create transaction
      final transaction = await _createTransaction(
        entities: entities,
        accountResolution: accountResolution,
        smsId: sms.id,
      );
      
      // Step 6: Create pending action if needed
      if (accountResolution.requiresUserConfirmation || entities.confidenceScore < 0.70) {
        await PendingActionService.createAction(
          actionType: accountResolution.requiresUserConfirmation 
              ? 'confirm_account' 
              : 'confirm_transaction',
          priority: 'medium',
          title: 'Review SMS transaction',
          description: 'Please verify this transaction from ${entities.institutionName ?? 'Unknown'}',
          transactionId: transaction.id,
          smsSource: sms.body,
        );
      }
      
      return SmsProcessingResult(
        status: 'success',
        transactionId: transaction.id,
        confidence: entities.confidenceScore,
      );
      
    } catch (e, stackTrace) {
      // Never fail - log and create unknown event
      AppLogger.err('sms_processing', e, stackTrace);
      
      // Create pending action for manual review
      await PendingActionService.createAction(
        actionType: 'review_failed',
        priority: 'low',
        title: 'SMS processing failed',
        description: 'Could not automatically process this SMS',
        smsSource: sms.body,
      );
      
      return SmsProcessingResult(
        status: 'error',
        reason: e.toString(),
      );
    }
  }
}
```

---

## 12. Database Schema

### Complete Schema

```sql
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Accounts (Enhanced)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  balance REAL NOT NULL DEFAULT 0,
  
  -- SMS Matching Fields
  institution_name TEXT,
  account_identifier TEXT,  -- Primary matching key
  sms_keywords TEXT,         -- Comma-separated
  account_alias TEXT,
  last4 TEXT,
  
  -- Metadata
  source TEXT NOT NULL DEFAULT 'manual',  -- 'manual', 'sms_auto', 'sms_confirmed'
  confidence_score REAL,
  requires_confirmation INTEGER DEFAULT 0,
  created_from_sms_date TEXT,
  
  -- Credit Card
  due_date_day INTEGER,
  credit_limit REAL,
  
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at INTEGER
);

CREATE INDEX idx_accounts_institution ON accounts(institution_name);
CREATE INDEX idx_accounts_identifier ON accounts(account_identifier);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Transactions (Enhanced)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  category TEXT NOT NULL,
  note TEXT,
  date TEXT NOT NULL,
  account_id INTEGER REFERENCES accounts(id),
  recurring_id INTEGER REFERENCES recurring_transactions(id),
  
  -- SMS Intelligence
  sms_source TEXT,           -- Sanitized original SMS
  sms_id TEXT,               -- SMS message ID (deduplication)
  source_type TEXT NOT NULL DEFAULT 'manual',
  merchant TEXT,
  confidence_score REAL,
  needs_review INTEGER DEFAULT 0,
  extracted_identifier TEXT,
  extracted_institution TEXT,
  
  -- Transfer Linking
  linked_transaction_id INTEGER REFERENCES transactions(id),
  transfer_reference TEXT,
  
  -- Recurring Detection
  recurring_group_id INTEGER REFERENCES recurring_patterns(id),
  is_recurring_candidate INTEGER DEFAULT 0,
  
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at INTEGER
);

CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_date ON transactions(date);
CREATE INDEX idx_transactions_merchant ON transactions(merchant);
CREATE INDEX idx_transactions_needs_review ON transactions(needs_review);
CREATE INDEX idx_transactions_source_type ON transactions(source_type);
CREATE INDEX idx_transactions_sms_id ON transactions(sms_id);
CREATE INDEX idx_transactions_deleted ON transactions(deleted_at);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Account Candidates (NEW)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE account_candidates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  institution_name TEXT,
  account_identifier TEXT,
  sms_keywords TEXT,
  suggested_type TEXT NOT NULL DEFAULT 'checking',
  confidence_score REAL NOT NULL DEFAULT 0.5,
  
  transaction_count INTEGER NOT NULL DEFAULT 1,
  first_seen_date TEXT NOT NULL,
  last_seen_date TEXT NOT NULL,
  
  status TEXT NOT NULL DEFAULT 'pending',  -- 'pending', 'confirmed', 'merged', 'rejected'
  merged_into_account_id INTEGER REFERENCES accounts(id),
  
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_account_candidates_status ON account_candidates(status);
CREATE INDEX idx_account_candidates_institution ON account_candidates(institution_name);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Pending Actions (NEW)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE pending_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action_type TEXT NOT NULL,  -- 'confirm_account', 'confirm_transaction', etc.
  priority TEXT NOT NULL DEFAULT 'medium',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  transaction_id INTEGER REFERENCES transactions(id),
  account_candidate_id INTEGER REFERENCES account_candidates(id),
  sms_source TEXT,
  metadata TEXT,  -- JSON
  
  status TEXT NOT NULL DEFAULT 'pending',  -- 'pending', 'resolved', 'dismissed'
  resolved_at TEXT,
  resolution_action TEXT,
  
  title TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE INDEX idx_pending_actions_status ON pending_actions(status);
CREATE INDEX idx_pending_actions_priority ON pending_actions(priority);
CREATE INDEX idx_pending_actions_type ON pending_actions(action_type);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Recurring Patterns (NEW)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE recurring_patterns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant TEXT,
  category TEXT NOT NULL,
  type TEXT NOT NULL,
  
  average_amount REAL NOT NULL,
  amount_variance REAL NOT NULL,
  frequency TEXT NOT NULL,
  interval_days INTEGER NOT NULL,
  
  occurrence_count INTEGER NOT NULL,
  confidence_score REAL NOT NULL,
  first_occurrence TEXT NOT NULL,
  last_occurrence TEXT NOT NULL,
  next_expected_date TEXT,
  
  transaction_ids TEXT NOT NULL,  -- JSON array
  account_id INTEGER REFERENCES accounts(id),
  
  status TEXT NOT NULL DEFAULT 'candidate',  -- 'candidate', 'confirmed', 'inactive'
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_recurring_patterns_merchant ON recurring_patterns(merchant);
CREATE INDEX idx_recurring_patterns_status ON recurring_patterns(status);
CREATE INDEX idx_recurring_patterns_next_date ON recurring_patterns(next_expected_date);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SMS Templates (NEW - Learning System)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE sms_templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  institution_name TEXT NOT NULL,
  sender_patterns TEXT NOT NULL,  -- JSON array of regex patterns
  message_pattern TEXT NOT NULL,
  
  amount_pattern TEXT,
  merchant_pattern TEXT,
  account_id_pattern TEXT,
  balance_pattern TEXT,
  
  transaction_type TEXT NOT NULL,  -- 'debit', 'credit', 'balance', 'transfer'
  
  match_count INTEGER NOT NULL DEFAULT 0,
  user_confirmations INTEGER NOT NULL DEFAULT 0,
  user_rejections INTEGER NOT NULL DEFAULT 0,
  accuracy REAL NOT NULL DEFAULT 0.5,
  
  is_user_created INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used TEXT
);

CREATE INDEX idx_sms_templates_institution ON sms_templates(institution_name);
CREATE INDEX idx_sms_templates_accuracy ON sms_templates(accuracy);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Transfer Pairs (NEW)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE transfer_pairs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  debit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
  credit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
  amount REAL NOT NULL,
  timestamp TEXT NOT NULL,
  
  source_account_id INTEGER NOT NULL REFERENCES accounts(id),
  destination_account_id INTEGER NOT NULL REFERENCES accounts(id),
  
  confidence_score REAL NOT NULL,
  detection_method TEXT NOT NULL,
  
  status TEXT NOT NULL DEFAULT 'detected',  -- 'detected', 'confirmed', 'rejected'
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transfer_pairs_status ON transfer_pairs(status);
CREATE INDEX idx_transfer_pairs_debit ON transfer_pairs(debit_transaction_id);
CREATE INDEX idx_transfer_pairs_credit ON transfer_pairs(credit_transaction_id);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Merchant Mappings (NEW - Learning System)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE merchant_mappings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  extracted_name TEXT NOT NULL,
  correct_name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(extracted_name, correct_name)
);

CREATE INDEX idx_merchant_mappings_extracted ON merchant_mappings(extracted_name);
```

---

## 13. Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Enhanced database schema migration
- [ ] Privacy guard implementation
- [ ] SMS ingestion service
- [ ] Classification layer
- [ ] Entity extraction layer

### Phase 2: Core Intelligence (Week 3-4)
- [ ] Account resolution engine
- [ ] Pending action system
- [ ] Account candidate management
- [ ] Confidence scoring system
- [ ] Basic UI for pending actions

### Phase 3: Advanced Detection (Week 5-6)
- [ ] Transfer detection engine
- [ ] Recurring pattern detection
- [ ] Transfer pair management UI
- [ ] Recurring pattern confirmation UI

### Phase 4: Learning  System (Week 7-8)
- [ ] SMS template learning
- [ ] Merchant mapping database
- [ ] Confidence adjustment algorithms
- [ ] Pattern refinement from user feedback

### Phase 5: Intelligence Layer (Week 9-10)
- [ ] Financial analytics dashboard
- [ ] Subscription detection
- [ ] Spending trends visualization
- [ ] Income vs expense analysis
- [ ] Behavioral insights

### Phase 6: Region-Specific Enhancements (Week 11-12)
- [ ] US bank templates (Chase, BoA, Wells Fargo, etc.)
- [ ] India bank templates (HDFC, ICICI, SBI, etc.)
- [ ] UPI transaction parsing
- [ ] Multi-currency support
- [ ] Region-specific merchant mapping

---

## 14. Success Metrics

**Accuracy Metrics:**
- Transaction extraction accuracy > 95%
- Account resolution accuracy > 90%
- Transfer detection accuracy > 85%
- Recurring pattern detection accuracy > 80%

**Performance Metrics:**
- SMS processing < 500ms per message
- Bulk import: 1000 SMS in < 30 seconds
- Zero crashes on malformed SMS

**User Experience Metrics:**
- Pending action resolution rate > 80%
- False positive rate < 5%
- User confirmation required < 10% of transactions

---

## 15. Testing Strategy

### Unit Tests
```dart
// Test entity extraction
test('Extract amount from US bank SMS', () {
  final sms = 'Chase: $124.50 spent at Amazon on 04/15';
  final amount = EntityExtractionService._extractAmount(sms);
  expect(amount, 124.50);
});

// Test account resolution
test('Resolve account by identifier', () async {
  final resolution = await AccountResolutionEngine.resolve(entities);
  expect(resolution.confidence, greaterThan(0.90));
});
```

### Integration Tests
```dart
// Test full SMS pipeline
test('Process debit transaction SMS', () async {
  final result = await SmsPipelineExecutor.process(sampleSms);
  expect(result.status, 'success');
  expect(result.transactionId, isNotNull);
});
```

### Real-World SMS Testing
- Collect anonymized SMS samples from 10+ US banks
- Collect anonymized SMS samples from 10+ Indian banks
- Test against 1000+ real SMS messages
- Validate accuracy against manual classification

---

## 16. Conclusion

This design provides a comprehensive, production-ready SMS-first personal finance intelligence engine with:

✅ **Privacy-safe** processing (zero OTP/password storage)  
✅ **Auto-learning** from user feedback  
✅ **High confidence** scoring system  
✅ **Comprehensive** error handling  
✅ **Extensible** for new banks and regions  
✅ **User-centric** with pending action system  
✅ **Intelligent** transfer and recurring detection  

The system transforms raw SMS messages into actionable financial intelligence while maintaining user privacy and continuously improving accuracy.

---

**Document Version:** 1.0  
**Last Updated:** April 18, 2026  
**Status:** Ready for Implementation  

