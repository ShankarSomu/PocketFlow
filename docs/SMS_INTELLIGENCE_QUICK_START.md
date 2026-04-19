# 🚀 Quick Start: SMS Intelligence Integration

This guide shows how to integrate the newly implemented SMS Intelligence Engine into your PocketFlow app.

---

## 1. Database Migration

The database migration from v11 to v12 has already been implemented in `lib/db/database.dart`. 

**On next app launch, the migration will automatically run.**

If you want to manually trigger it:
```dart
final db = await AppDatabase.db;
// Migration runs automatically when database version changes
```

---

## 2. Enable SMS Intelligence

### Option A: In Your Settings Screen

Add a toggle to enable/disable SMS Intelligence:

```dart
import 'package:pocket_flow/services/sms_intelligence_integration.dart';

// In your settings widget
SwitchListTile(
  title: Text('SMS Intelligence'),
  subtitle: Text('Automatically process bank SMS'),
  value: _smsIntelligenceEnabled,
  onChanged: (value) async {
    await SmsIntelligenceIntegration.setEnabled(value);
    setState(() => _smsIntelligenceEnabled = value);
    
    if (value) {
      // Run initial scan
      _runSmartScan();
    }
  },
);
```

### Option B: Programmatically Enable

```dart
// Enable SMS Intelligence
await SmsIntelligenceIntegration.setEnabled(true);

// Run smart scan
final result = await SmsIntelligenceIntegration.smartScan(
  sinceDays: 30,  // Look back 30 days
  limit: 1000,     // Process up to 1000 messages
);

print(result.toString());
// Output:
// ✅ Processed: 156 messages
// 📊 Transactions: 89 created
// ⏳ Pending Actions: 12 (need review)
// 🏦 New Accounts: 3 detected
```

---

## 3. Add Pending Actions to Navigation

Add a link to the Pending Actions screen in your app navigation:

```dart
import 'package:pocket_flow/screens/pending_actions_screen.dart';

// In your drawer or bottom navigation
ListTile(
  leading: Icon(Icons.inbox),
  title: Text('Review SMS'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingActionsScreen(),
      ),
    );
  },
);
```

---

## 4. Show Badge for Pending Items

Display a notification badge when there are pending actions:

```dart
import 'package:pocket_flow/services/sms_intelligence_integration.dart';

// Get quick stats
final stats = await SmsIntelligenceIntegration.getQuickStats();
final pendingCount = stats['pending_actions'] as int;
final candidateCount = stats['account_candidates'] as int;

final totalPending = pendingCount + candidateCount;

// Show badge
Badge(
  label: Text('$totalPending'),
  child: Icon(Icons.inbox),
  isLabelVisible: totalPending > 0,
);
```

---

## 5. Background SMS Processing (Optional)

For automatic background processing when new SMS arrive:

```dart
import 'package:pocket_flow/services/sms_intelligence_integration.dart';

// In your app initialization or background service
Timer.periodic(Duration(minutes: 15), (timer) async {
  final enabled = await SmsIntelligenceIntegration.isEnabled();
  if (enabled) {
    // Process only last hour of messages
    await SmsIntelligenceIntegration.smartScan(
      sinceDays: 1,
      limit: 100,
    );
  }
});
```

---

## 6. Manual SMS Processing (For Testing)

Process a single SMS message manually:

```dart
import 'package:pocket_flow/services/sms_intelligence_integration.dart';

final result = await SmsIntelligenceIntegration.processSingleSms(
  sender: 'CHASE',
  body: 'Your card ending in 1234 was charged \$45.67 at AMAZON on 04/18.',
  receivedAt: DateTime.now(),
);

if (result.isTransaction) {
  print('Transaction created: ${result.transactionId}');
  print('Confidence: ${result.confidence}');
} else if (result.isPending) {
  print('Needs review: ${result.message}');
}
```

---

## 7. Testing with Sample SMS

Test the system with various SMS formats:

### US Bank Transaction
```dart
final result = await SmsIntelligenceIntegration.processSingleSms(
  sender: 'CHASE',
  body: 'Chase debit card ending in 1234: \$123.45 purchase at STARBUCKS on 04/18/2024',
);
```

### India Bank Transaction
```dart
final result = await SmsIntelligenceIntegration.processSingleSms(
  sender: 'HDFCBK',
  body: 'Rs.1,234.56 debited from A/c **5678 on 18-Apr-24 at AMAZON using UPI',
);
```

### UPI Transfer (India)
```dart
final result = await SmsIntelligenceIntegration.processSingleSms(
  sender: 'ICICIM',
  body: 'Rs.500 sent to user@paytm via UPI. Ref: 123456789. A/c bal: Rs.12,345.67',
);
```

### Balance Update
```dart
final result = await SmsIntelligenceIntegration.processSingleSms(
  sender: 'BOFA',
  body: 'Your Bank of America checking account ending in 4567 balance is \$5,432.10 as of 04/18.',
);
```

---

## 8. Viewing Results

### Check Statistics
```dart
import 'package:pocket_flow/services/sms_pipeline_executor.dart';

final stats = await SmsPipelineExecutor.getStatistics();
print('SMS Transactions: ${stats['sms_transactions']}');
print('Pending Actions: ${stats['pending_actions']}');
print('Account Candidates: ${stats['account_candidates']}');
```

### View Pending Actions
```dart
import 'package:pocket_flow/services/account_resolution_engine.dart';

// Get account candidates
final candidates = await AccountResolutionEngine.getPendingCandidates();
for (final candidate in candidates) {
  print('${candidate.displayName}: ${candidate.transactionCount} SMS');
}
```

---

## 9. User Workflow

### Confirming a New Account

When user sees a new account candidate in Pending Actions screen:

1. **Review**: User sees "HDFC Bank ****5678" with 12 SMS transactions
2. **Edit**: User can customize name (e.g., "HDFC Salary Account")
3. **Confirm**: User taps "Create Account"
4. **Result**: 
   - New account created
   - All 12 transactions automatically linked to the account
   - Confidence scores updated to 0.95

```dart
// Programmatically confirm candidate
final accountId = await AccountResolutionEngine.confirmCandidate(
  candidateId,
  customName: 'HDFC Salary Account',
  customType: 'checking',
);

print('Account created: $accountId');
```

### Merging with Existing Account

If user already manually created the account:

1. **Review**: User sees "Chase ****1234" candidate
2. **Merge**: User selects existing "Chase Credit Card" account
3. **Result**: 
   - Candidate merged into existing account
   - Account keywords updated
   - All transactions relinked

```dart
// Programmatically merge candidate
await AccountResolutionEngine.mergeCandidate(
  candidateId,
  existingAccountId,
);
```

---

## 10. Performance Optimization

### Batch Processing
```dart
// Process 1000 SMS at once
final result = await SmsIntelligenceIntegration.smartScan(
  sinceDays: 180,  // 6 months
  limit: 1000,
);

// Expected performance:
// - 1000 SMS in ~30 seconds
// - ~30ms per SMS on average
```

### Incremental Scanning
```dart
// First run: Process all history
await SmsIntelligenceIntegration.smartScan(sinceDays: 365);

// Subsequent runs: Only new messages
await SmsIntelligenceIntegration.smartScan(sinceDays: 1);
```

---

## 11. Privacy Validation

Test privacy filtering:

```dart
import 'package:pocket_flow/services/privacy_guard.dart';

// These should be BLOCKED
assert(PrivacyGuard.isSensitiveSms('Your OTP is 123456'));
assert(PrivacyGuard.isSensitiveSms('Your password is abc123'));
assert(PrivacyGuard.isSensitiveSms('SSN: 123-45-6789'));
assert(PrivacyGuard.isSensitiveSms('Aadhaar: 1234 5678 9012'));

// These should be ALLOWED
assert(!PrivacyGuard.isSensitiveSms('Your card ****1234 was charged \$50'));
assert(!PrivacyGuard.isSensitiveSms('UPI payment of Rs.100 successful'));
```

---

## 12. Error Handling

```dart
try {
  final result = await SmsIntelligenceIntegration.smartScan();
  
  if (result.hasError) {
    print('Error: ${result.error}');
  } else {
    print('Success: ${result.transactionsCreated} transactions');
  }
  
  if (result.errors > 0) {
    print('${result.errors} messages failed to process');
    for (final error in result.errorMessages) {
      print('  - $error');
    }
  }
} catch (e) {
  print('Fatal error: $e');
}
```

---

## 13. Debugging

Enable detailed logging:

```dart
import 'package:pocket_flow/services/app_logger.dart';

// Check logs for SMS processing
// Logs will show:
// - sms_intelligence_scan_start
// - sms_intelligence_transaction (for each created transaction)
// - sms_intelligence_pending (for pending actions)
// - sms_intelligence_scan_complete
```

---

## 14. Common Integration Patterns

### Pattern 1: Auto-Import on App Launch
```dart
class MyApp extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _autoImportSms();
  }
  
  Future<void> _autoImportSms() async {
    final enabled = await SmsIntelligenceIntegration.isEnabled();
    if (enabled) {
      await SmsIntelligenceIntegration.smartScan(sinceDays: 7);
    }
  }
}
```

### Pattern 2: User-Triggered Scan with Progress
```dart
Future<void> _scanSms() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Processing SMS...'),
        ],
      ),
    ),
  );
  
  final result = await SmsIntelligenceIntegration.smartScan();
  
  Navigator.pop(context); // Close progress dialog
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('SMS Import Complete'),
      content: Text(result.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

### Pattern 3: Quick Actions from Dashboard
```dart
Card(
  child: ListTile(
    title: Text('SMS Transactions'),
    subtitle: Text('$smsTransactionCount imported'),
    trailing: Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PendingActionsScreen(),
        ),
      );
    },
  ),
);
```

---

## 15. Next Steps

After integrating Phase 1:

1. **Test with Real SMS**: Import your actual SMS history
2. **Review Accuracy**: Check how many transactions were correctly extracted
3. **Confirm Accounts**: Review and confirm detected account candidates
4. **Tune Thresholds**: Adjust confidence thresholds if needed
5. **Provide Feedback**: Report issues for Phase 2 improvements

---

## 🎯 Integration Checklist

- [ ] Database migration v12 tested
- [ ] SMS Intelligence enabled in settings
- [ ] Pending Actions screen added to navigation
- [ ] Badge counter implemented
- [ ] Test with sample US SMS
- [ ] Test with sample India SMS
- [ ] Privacy filtering validated
- [ ] Account confirmation workflow tested
- [ ] Statistics dashboard updated
- [ ] Error handling implemented
- [ ] Logging configured
- [ ] User documentation updated

---

## 📞 Support

For issues or questions:
- Check logs in AppLogger
- Review `PHASE_1_COMPLETE_SMS_INTELLIGENCE.md` for detailed documentation
- Test with `processSingleSms()` for debugging
- Verify database migration completed successfully

---

**Phase 1 is ready to use! 🎉**

Start by enabling SMS Intelligence and running a smart scan to see it in action.
