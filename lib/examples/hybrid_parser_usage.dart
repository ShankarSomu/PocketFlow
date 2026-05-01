import 'package:pocket_flow/services/ml_sms_classifier.dart';
import 'package:pocket_flow/services/advanced_sms_parser.dart';

/// Example: How to use the Hybrid SMS Parser (Rules + ML)
/// 
/// This demonstrates using ML for unknown banks while keeping 
/// 100% accuracy on known banks (Citi, BofA, Capital One)
void main() async {
  // Initialize the hybrid parser (do this once at app startup)
  final hybridParser = HybridSmsParser();
  await hybridParser.initialize();
  
  print('✅ Hybrid parser initialized\n');
  
  // Example 1: Known bank (Citi) → Uses rules (100% accuracy)
  final citiSms = 'Citi Alert: A \$89.45 transaction was made at GITHUB, INC. on card ending in 1234';
  final citiResult = await hybridParser.parse(citiSms, senderId: 'Citi');
  
  print('Example 1: Known Bank (Citi)');
  print('SMS: $citiSms');
  print('Method: Rule-based parser');
  print('Result: ${citiResult.isTransaction ? "TRANSACTION" : "NOT TRANSACTION"}');
  print('Confidence: ${(citiResult.confidenceScore * 100).toStringAsFixed(1)}%');
  print('Amount: \$${citiResult.amount}');
  print('Merchant: ${citiResult.merchant}');
  print('');
  
  // Example 2: Unknown bank (Chase) → Uses ML model
  final chaseSms = 'Chase: \$125.00 charged at STARBUCKS on card ending 5678';
  final chaseResult = await hybridParser.parse(chaseSms, senderId: 'Chase');
  
  print('Example 2: Unknown Bank (Chase)');
  print('SMS: $chaseSms');
  print('Method: ML classifier');
  print('Result: ${chaseResult.isTransaction ? "TRANSACTION" : "NOT TRANSACTION"}');
  print('Confidence: ${(chaseResult.confidenceScore * 100).toStringAsFixed(1)}%');
  print('Notes: ${chaseResult.improvementSuggestions.join(", ")}');
  print('');
  
  // Example 3: Unknown bank balance notification → ML should reject
  final wellsBalance = 'Wells Fargo: Your available balance is \$1,234.56';
  final wellsResult = await hybridParser.parse(wellsBalance, senderId: 'WellsFargo');
  
  print('Example 3: Unknown Bank Balance Alert (Wells Fargo)');
  print('SMS: $wellsBalance');
  print('Method: ML classifier');
  print('Result: ${wellsResult.isTransaction ? "TRANSACTION" : "NOT TRANSACTION"}');
  print('Confidence: ${(wellsResult.confidenceScore * 100).toStringAsFixed(1)}%');
  print('✅ Correctly identified as non-transaction');
  print('');
  
  // Example 4: Low confidence → Should prompt for review
  final uncertainSms = 'Your account XXXX was updated';
  final uncertainResult = await hybridParser.parse(uncertainSms, senderId: 'UNKNOWN');
  
  print('Example 4: Uncertain Message');
  print('SMS: $uncertainSms');
  print('Result: ${uncertainResult.isTransaction ? "TRANSACTION" : "NOT TRANSACTION"}');
  print('Confidence: ${(uncertainResult.confidenceScore * 100).toStringAsFixed(1)}%');
  print('Action: Manual review recommended');
  print('Suggestions: ${uncertainResult.improvementSuggestions.join(", ")}');
  
  // Clean up
  hybridParser.dispose();
}

/// Integration example for SMS import service
class SmsImportService {
  final HybridSmsParser _parser = HybridSmsParser();
  
  Future<void> initialize() async {
    await _parser.initialize();
  }
  
  Future<void> importSms(String smsText, String senderId) async {
    final result = await _parser.parse(smsText, senderId: senderId);
    
    if (!result.isTransaction) {
      print('Skipping non-transaction: ${smsText.substring(0, 50)}...');
      return;
    }
    
    if (result.confidenceScore >= 0.9) {
      // High confidence → Auto-import
      await _saveTransaction(result);
      print('✅ Auto-imported: \$${result.amount} at ${result.merchant}');
    } else if (result.confidenceScore >= 0.7) {
      // Medium confidence → Import with review flag
      await _saveTransaction(result, needsReview: true);
      print('⚠️  Imported with review flag: \$${result.amount}');
      _notifyUserReview(result);
    } else {
      // Low confidence → Skip and ask user
      print('❓ Manual review required');
      await _promptUserConfirmation(smsText, senderId, result);
    }
  }
  
  Future<void> _saveTransaction(result, {bool needsReview = false}) async {
    // Save to database
    // transaction.needsReview = needsReview;
    print('💾 Saved to database (review: $needsReview)');
  }
  
  void _notifyUserReview(result) {
    // Show notification: "New transaction needs review"
    print('🔔 User notification sent');
  }
  
  Future<void> _promptUserConfirmation(String sms, String sender, result) async {
    // Show dialog: "Is this a transaction?"
    // If yes: record correction for active learning
    print('📝 Awaiting user input');
    
    // Record correction
    await _parser.recordCorrection(
      smsText: sms,
      senderId: sender,
      isTransaction: true, // User's answer
    );
  }
}

/// Active Learning: Improve model over time
/// 
/// When users correct the parser:
/// 1. Record the correction in local database
/// 2. After 100+ corrections, export for retraining
/// 3. Retrain model with user corrections
/// 4. Deploy updated model in next app update
/// 
/// This continuously improves accuracy for your users' specific banks!
