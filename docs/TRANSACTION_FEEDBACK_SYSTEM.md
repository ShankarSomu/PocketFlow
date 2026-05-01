# Transaction Feedback System - Implementation Plan

**Date**: 2026-04-23  
**Status**: Design Complete - Ready for Implementation  
**Effort**: 6-8 hours

---

## 🎯 Goal

Create a complete user feedback loop that:
1. ✅ Captures user corrections and approvals
2. ✅ Stores feedback in learning database tables
3. ✅ Improves confidence scores over time
4. ✅ Normalizes merchant names automatically
5. ✅ Shows explanation of parsing decisions

---

## 📋 Current State vs. Desired State

### Current SMS Review Screen

```
┌────────────────────────────────────┐
│  Transaction Card                  │
│  --------------------------------  │
│  🔴 42% Confidence                 │
│  $45.82  •  Target                 │
│  Shopping                          │
│                                    │
│  [ Edit ]  [ Approve ]  [ Delete ] │
└────────────────────────────────────┘

ISSUES:
❌ No feedback captured for learning
❌ No explanation of why 42% confidence
❌ No granular feedback (only all-or-nothing)
```

### Enhanced SMS Review Screen (Proposed)

```
┌──────────────────────────────────────────────┐
│  Transaction Card                            │
│  ──────────────────────────────────────────  │
│  🔴 42% Confidence    [ℹ️ Why?]             │
│  $45.82  •  Target                           │
│  Shopping                                    │
│                                              │
│  📊 Parsed From SMS:                         │
│  "Citi Alert: A $45.82 transaction at       │
│   TARGET STORE on card ending 5517"         │
│                                              │
│  ✓ Quick Feedback:                           │
│  Amount correct?    [👍] [👎]                │
│  Merchant correct?  [👍] [👎]                │
│  Category correct?  [👍] [👎]                │
│  Account correct?   [👍] [👎]                │
│                                              │
│  [ 🗑️ Delete ]  [ ✏️ Edit ]  [ ✅ Approve ] │
└──────────────────────────────────────────────┘

IMPROVEMENTS:
✅ Granular feedback per field
✅ Explanation on-demand
✅ Visual SMS source
✅ Captures specific corrections
```

---

## 🗄️ Database Schema Changes

### Step 1: Create Learning Tables

**File**: `lib/db/database.dart` (bump version to 21)

```dart
// In onUpgrade() method, add:
if (oldVersion < 21) {
  // Create user_account_confirmations table
  await db.execute('''
    CREATE TABLE user_account_confirmations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      institution_name TEXT,
      account_identifier TEXT,
      merchant TEXT,
      account_id INTEGER,
      transaction_id INTEGER,
      confirmed INTEGER DEFAULT 0,  -- 0=rejected, 1=confirmed
      confidence_before REAL,
      created_at TEXT,
      FOREIGN KEY (account_id) REFERENCES accounts(id),
      FOREIGN KEY (transaction_id) REFERENCES transactions(id)
    )
  ''');
  
  await db.execute('''
    CREATE INDEX idx_account_confirmations_lookup 
    ON user_account_confirmations(institution_name, account_identifier)
  ''');
  
  // Create user_corrections table
  await db.execute('''
    CREATE TABLE user_corrections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER,
      field_name TEXT,               -- 'merchant', 'category', 'amount', 'account'
      original_value TEXT,
      corrected_value TEXT,
      feedback_type TEXT,            -- 'sms_review', 'manual_edit', 'quick_feedback'
      confidence_before REAL,
      created_at TEXT,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id)
    )
  ''');
  
  await db.execute('''
    CREATE INDEX idx_corrections_merchant 
    ON user_corrections(field_name, original_value)
  ''');
  
  // Create parsing_feedback table (for quick thumbs up/down)
  await db.execute('''
    CREATE TABLE parsing_feedback (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER,
      field_name TEXT,               -- 'amount', 'merchant', 'category', 'account'
      is_correct INTEGER,            -- 1=thumbs up, 0=thumbs down
      sms_source TEXT,
      created_at TEXT,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id)
    )
  ''');
}
```

---

## 🔧 Code Changes

### Change 1: Enhanced SMS Review Screen

**File**: `lib/screens/transactions/sms_review_screen.dart`

Add new widget for granular feedback:

```dart
class _ReviewCardEnhanced extends StatelessWidget {
  const _ReviewCardEnhanced({
    required this.transaction,
    required this.fmt,
    required this.onEdit,
    required this.onApprove,
    required this.onDelete,
    required this.onQuickFeedback,  // NEW
    required this.onExplain,        // NEW
  });

  final model.Transaction transaction;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onDelete;
  final Function(String field, bool isCorrect) onQuickFeedback;  // NEW
  final VoidCallback onExplain;  // NEW

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Confidence + Explain button
            Row(
              children: [
                if (transaction.confidenceScore != null)
                  ConfidenceBadge(
                    score: transaction.confidenceScore!,
                    size: BadgeSize.medium,
                  ),
                const SizedBox(width: 8),
                // NEW: Explain button
                TextButton.icon(
                  onPressed: onExplain,
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Why?', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                Text(
                  '${isIncome ? '+' : '-'}${fmt.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Transaction details
            Text(
              transaction.category,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (transaction.merchant != null) ...[
              const SizedBox(height: 4),
              Text(
                '@ ${transaction.merchant}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, y').format(transaction.date),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            
            // NEW: SMS Source Preview
            if (transaction.smsSource != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sms_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Parsed from SMS:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.smsSource!.length > 120
                          ? '${transaction.smsSource!.substring(0, 120)}...'
                          : transaction.smsSource!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // NEW: Quick Feedback Section
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '✓ Quick Feedback:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            
            // Amount feedback
            _buildQuickFeedbackRow(
              context: context,
              label: 'Amount (\$${transaction.amount.toStringAsFixed(2)})',
              onThumbsUp: () => onQuickFeedback('amount', true),
              onThumbsDown: () => onQuickFeedback('amount', false),
            ),
            const SizedBox(height: 6),
            
            // Merchant feedback
            if (transaction.merchant != null)
              _buildQuickFeedbackRow(
                context: context,
                label: 'Merchant (${transaction.merchant})',
                onThumbsUp: () => onQuickFeedback('merchant', true),
                onThumbsDown: () => onQuickFeedback('merchant', false),
              ),
            const SizedBox(height: 6),
            
            // Category feedback
            _buildQuickFeedbackRow(
              context: context,
              label: 'Category (${transaction.category})',
              onThumbsUp: () => onQuickFeedback('category', true),
              onThumbsDown: () => onQuickFeedback('category', false),
            ),
            const SizedBox(height: 6),
            
            // Account feedback
            if (transaction.extractedBank != null || transaction.extractedAccountIdentifier != null)
              _buildQuickFeedbackRow(
                context: context,
                label: 'Account (${transaction.extractedBank ?? 'Unknown'} ${transaction.extractedAccountIdentifier ?? ''})',
                onThumbsUp: () => onQuickFeedback('account', true),
                onThumbsDown: () => onQuickFeedback('account', false),
              ),
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFeedbackRow({
    required BuildContext context,
    required String label,
    required VoidCallback onThumbsUp,
    required VoidCallback onThumbsDown,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        IconButton(
          onPressed: onThumbsUp,
          icon: const Icon(Icons.thumb_up_outlined, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Correct',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onThumbsDown,
          icon: const Icon(Icons.thumb_down_outlined, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Incorrect',
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}
```

---

### Change 2: Feedback Service

**File**: `lib/services/transaction_feedback_service.dart` (NEW)

```dart
import '../db/database.dart';
import '../models/transaction.dart';

class TransactionFeedbackService {
  /// Record quick feedback (thumbs up/down)
  static Future<void> recordQuickFeedback({
    required Transaction transaction,
    required String fieldName,
    required bool isCorrect,
  }) async {
    final db = await AppDatabase.db();
    
    await db.insert('parsing_feedback', {
      'transaction_id': transaction.id,
      'field_name': fieldName,
      'is_correct': isCorrect ? 1 : 0,
      'sms_source': transaction.smsSource,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // Update system confidence based on feedback
    if (isCorrect) {
      await _boostConfidence(transaction, fieldName);
    } else {
      await _lowerConfidence(transaction, fieldName);
    }
  }
  
  /// Record user correction (edit)
  static Future<void> recordCorrection({
    required Transaction transaction,
    required String fieldName,
    required String originalValue,
    required String correctedValue,
    String feedbackType = 'sms_review',
  }) async {
    final db = await AppDatabase.db();
    
    await db.insert('user_corrections', {
      'transaction_id': transaction.id,
      'field_name': fieldName,
      'original_value': originalValue,
      'corrected_value': correctedValue,
      'feedback_type': feedbackType,
      'confidence_before': transaction.confidenceScore,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // Learn from correction for future imports
    await _learnFromCorrection(fieldName, originalValue, correctedValue);
  }
  
  /// Record account confirmation (approve/reject)
  static Future<void> recordAccountConfirmation({
    required Transaction transaction,
    required bool confirmed,
  }) async {
    final db = await AppDatabase.db();
    
    await db.insert('user_account_confirmations', {
      'institution_name': transaction.extractedBank,
      'account_identifier': transaction.extractedAccountIdentifier,
      'merchant': transaction.merchant,
      'account_id': transaction.accountId,
      'transaction_id': transaction.id,
      'confirmed': confirmed ? 1 : 0,
      'confidence_before': transaction.confidenceScore,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Get confidence explanation
  static Future<String> getConfidenceExplanation(Transaction transaction) async {
    if (transaction.confidenceScore == null) {
      return 'No confidence score available';
    }
    
    final score = transaction.confidenceScore!;
    final parts = <String>[];
    
    // Base explanation
    if (score >= 0.80) {
      parts.add('✅ High confidence (${ (score * 100).toStringAsFixed(0)}%)');
    } else if (score >= 0.60) {
      parts.add('🟡 Medium confidence (${(score * 100).toStringAsFixed(0)}%)');
    } else {
      parts.add('⚠️ Low confidence (${(score * 100).toStringAsFixed(0)}%)');
    }
    
    // Check factors
    final db = await AppDatabase.db();
    
    // Factor 1: Sender match
    if (transaction.extractedBank != null) {
      parts.add('• Bank identified: ${transaction.extractedBank}');
    } else {
      parts.add('• Bank unknown (lower confidence)');
    }
    
    // Factor 2: Account match
    if (transaction.accountId != null && transaction.extractedAccountIdentifier != null) {
      parts.add('• Account matched: ${transaction.extractedAccountIdentifier}');
    } else {
      parts.add('• Account ambiguous (needs verification)');
    }
    
    // Factor 3: Merchant history
    if (transaction.merchant != null) {
      final historyResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM transactions 
        WHERE merchant = ? AND account_id = ?
      ''', [transaction.merchant, transaction.accountId]);
      
      final count = historyResult.first['count'] as int;
      if (count > 5) {
        parts.add('• Frequent merchant ($count previous transactions)');
      } else if (count > 0) {
        parts.add('• Seen before ($count previous)');
      } else {
        parts.add('• New merchant (first time)');
      }
    }
    
    // Factor 4: User confirmations
    if (transaction.extractedBank != null && transaction.merchant != null) {
      final confirmResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM user_account_confirmations 
        WHERE institution_name = ? 
          AND merchant = ? 
          AND confirmed = 1
      ''', [transaction.extractedBank, transaction.merchant]);
      
      final confirmCount = confirmResult.first['count'] as int;
      if (confirmCount > 0) {
        parts.add('• You confirmed this pattern before ($confirmCount times)');
      }
    }
    
    return parts.join('\\n');
  }
  
  /// Boost confidence for similar future transactions
  static Future<void> _boostConfidence(Transaction transaction, String fieldName) async {
    // Implementation: Update pattern weights in learning system
    // This would integrate with account_resolution_engine.dart
    print('📈 Boosting confidence for $fieldName match');
  }
  
  /// Lower confidence for similar future transactions
  static Future<void> _lowerConfidence(Transaction transaction, String fieldName) async {
    // Implementation: Reduce pattern weights in learning system
    print('📉 Lowering confidence for $fieldName match');
  }
  
  /// Learn from user correction for future imports
  static Future<void> _learnFromCorrection(
    String fieldName, 
    String originalValue, 
    String correctedValue,
  ) async {
    // Implementation: Create normalization rule
    // E.g., "AMZN MKTPLACE" → "Amazon"
    print('🎓 Learned: $fieldName "$originalValue" → "$correctedValue"');
  }
}
```

---

### Change 3: Update SMS Review Screen to Use New Service

**File**: `lib/screens/transactions/sms_review_screen.dart`

```dart
import '../../services/transaction_feedback_service.dart';

// In _SmsReviewScreenState class:

Future<void> _handleQuickFeedback(
  model.Transaction transaction,
  String fieldName,
  bool isCorrect,
) async {
  try {
    await TransactionFeedbackService.recordQuickFeedback(
      transaction: transaction,
      fieldName: fieldName,
      isCorrect: isCorrect,
    );
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect 
              ? '✓ Thanks! System will learn from this.' 
              : '✗ Noted. System will avoid this pattern.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to record feedback: $e')),
    );
  }
}

Future<void> _showExplanation(model.Transaction transaction) async {
  final explanation = await TransactionFeedbackService.getConfidenceExplanation(transaction);
  
  if (!mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, size: 24),
          SizedBox(width: 8),
          Text('Confidence Breakdown'),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          explanation,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

// Update _approveTransaction to record feedback:
Future<void> _approveTransaction(model.Transaction transaction) async {
  try {
    // Record account confirmation
    await TransactionFeedbackService.recordAccountConfirmation(
      transaction: transaction,
      confirmed: true,
    );
    
    // Update transaction
    await AppDatabase.updateTransaction(model.Transaction(
      id: transaction.id,
      type: transaction.type,
      amount: transaction.amount,
      category: transaction.category,
      note: transaction.note,
      date: transaction.date,
      accountId: transaction.accountId,
      sourceType: transaction.sourceType,
      merchant: transaction.merchant,
      smsSource: transaction.smsSource,
      confidenceScore: transaction.confidenceScore,
      needsReview: false,
    ));

    notifyDataChanged();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Transaction approved & feedback recorded')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to approve: $e')),
    );
  }
}

// Update _deleteTransaction to record rejection:
Future<void> _deleteTransaction(model.Transaction transaction) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Transaction?'),
      content: Text('Delete ${transaction.category} - ${_fmt.format(transaction.amount)}?\\n\\nThis will help the system avoid similar patterns in the future.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    // Record rejection feedback
    await TransactionFeedbackService.recordAccountConfirmation(
      transaction: transaction,
      confirmed: false,
    );
    
    await AppDatabase.deleteTransaction(transaction.id!);
    notifyDataChanged();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted & feedback recorded')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to delete: $e')),
    );
  }
}

// Update ListView.builder to use new widget:
ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: _reviewTransactions.length,
  itemBuilder: (context, index) {
    final transaction = _reviewTransactions[index];
    return _ReviewCardEnhanced(  // Changed from _ReviewCard
      transaction: transaction,
      fmt: _fmt,
      onEdit: () => _editTransaction(transaction),
      onApprove: () => _approveTransaction(transaction),
      onDelete: () => _deleteTransaction(transaction),
      onQuickFeedback: (field, isCorrect) => 
          _handleQuickFeedback(transaction, field, isCorrect),
      onExplain: () => _showExplanation(transaction),
    );
  },
)
```

---

## 📊 Testing the Feedback System

### Test Case 1: Quick Thumbs Up

```
1. User opens SMS Review screen
2. Sees transaction: $45.82 at Target (42% confidence)
3. Clicks thumbs up (👍) on "Amount"
4. Clicks thumbs up (👍) on "Merchant"
5. Clicks thumbs down (👎) on "Category" (should be "Groceries" not "Shopping")
6. System records:
   - parsing_feedback: amount=correct, merchant=correct, category=incorrect
   - Future Target transactions get higher confidence
   - System flags category for improvement
```

### Test Case 2: Edit with Correction

```
1. User clicks "Edit" button
2. Changes merchant from "AMZN MKTPLACE" to "Amazon"
3. Changes category from "Online Shopping" to "Shopping"
4. Clicks "Save & Approve"
5. System records:
   - user_corrections: merchant correction recorded
   - user_corrections: category correction recorded
   - Future "AMZN MKTPLACE" SMS → auto-normalize to "Amazon"
```

### Test Case 3: Check Explanation

```
1. User clicks "Why?" button
2. Dialog shows:
   "🟡 Medium confidence (42%)
    • Bank unknown (lower confidence)
    • Account ambiguous (needs verification)
    • New merchant (first time)
    • No previous confirmations"
    
3. User understands why low confidence
4. User provides feedback to improve
```

---

## ✅ Implementation Checklist

- [ ] **Database Migration** (30 min)
  - [ ] Add `user_account_confirmations` table
  - [ ] Add `user_corrections` table
  - [ ] Add `parsing_feedback` table
  - [ ] Test migration with existing data

- [ ] **Create Feedback Service** (1.5 hours)
  - [ ] Create `transaction_feedback_service.dart`
  - [ ] Implement `recordQuickFeedback()`
  - [ ] Implement `recordCorrection()`
  - [ ] Implement `recordAccountConfirmation()`
  - [ ] Implement `getConfidenceExplanation()`

- [ ] **Update SMS Review Screen** (2 hours)
  - [ ] Create `_ReviewCardEnhanced` widget
  - [ ] Add quick feedback buttons (thumbs up/down)
  - [ ] Add "Why?" explanation button
  - [ ] Integrate with feedback service
  - [ ] Update approve/delete to record feedback

- [ ] **Update Edit Flow** (1 hour)
  - [ ] Track original values before edit
  - [ ] Record corrections on save
  - [ ] Show "System will learn" confirmation

- [ ] **Learning Integration** (2 hours)
  - [ ] Update confidence scoring to use feedback data
  - [ ] Implement merchant normalization from corrections
  - [ ] Boost/lower confidence based on feedback
  - [ ] Test feedback loop (approve → rescan → see improvement)

- [ ] **Testing** (1 hour)
  - [ ] Test quick feedback recording
  - [ ] Test explanation generation
  - [ ] Test correction learning
  - [ ] Verify database inserts
  - [ ] Test with 20+ transactions

---

## 📈 Expected Results

### Before Feedback System:
```
First scan: 2,000 transactions imported
- 200 high confidence (auto-approved)
- 1,600 need review
- 200 pending

Second scan: Same patterns repeat
- Still 1,600 need review
- No improvement
```

### After Feedback System:
```
First scan: 2,000 transactions imported
- 200 high confidence (auto-approved)
- 1,600 need review

User reviews 50 transactions with feedback

Second scan: 500 new transactions
- 420 auto-approved (84%) ✅
- 70 need review (14%)
- 10 pending (2%)

50% reduction in review burden! 🎉
```

---

## 🎯 Success Metrics

1. **Feedback Capture Rate**: 80%+ of reviews include feedback
2. **Confidence Improvement**: +15% average after 20 feedbacks
3. **Review Burden Reduction**: 50%+ fewer reviews after 1 week
4. **User Satisfaction**: Clear explanations reduce confusion

---

## 📚 Related Files

- Current: [sms_review_screen.dart](../lib/screens/transactions/sms_review_screen.dart)
- New: [transaction_feedback_service.dart](../lib/services/transaction_feedback_service.dart) (to create)
- Update: [database.dart](../lib/db/database.dart) (add v21 migration)
- Related: [account_resolution_engine.dart](../lib/services/account_resolution_engine.dart) (integrate feedback)

---

**Status**: Ready for implementation  
**Estimated time**: 6-8 hours  
**Priority**: HIGH - Essential for learning system
