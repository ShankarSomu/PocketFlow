import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter_plus/tflite_flutter_plus.dart';
import 'package:pocket_flow/services/advanced_sms_parser.dart';
import 'sms_correction_service.dart';
import 'package:pocket_flow/models/sms_transaction_result.dart';

/// ML-powered SMS classifier using TensorFlow Lite
/// Works alongside rule-based parser for unknown banks
class MlSmsClassifier {
  late Interpreter _interpreter;
  late Map<String, dynamic> _tokenizerConfig;
  late Map<String, int> _wordIndex;
  int _maxLen = 100;
  
  bool _isInitialized = false;
  
  /// Initialize the ML model
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('ml/sms_classifier.tflite');
      
      // Load tokenizer configuration
      String tokenizerJson;
    try {
      tokenizerJson = await rootBundle.loadString('assets/ml/tokenizer_config.json');
    } catch (e) {
      // Fallback for non‑Flutter environments (e.g., unit tests)
      final file = File('${Directory.current.path}/assets/ml/tokenizer_config.json');
      print('Attempting to load tokenizer config from: ${file.path}');
      print('File exists? ${await file.exists()}');
      if (await file.exists()) {
        tokenizerJson = await file.readAsString();
      } else {
        rethrow;
      }
    }
      _tokenizerConfig = jsonDecode(tokenizerJson);
      _wordIndex = Map<String, int>.from(_tokenizerConfig['word_index']);
      _maxLen = _tokenizerConfig['max_len'] ?? 100;
      
      _isInitialized = true;
      print('✅ ML classifier initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize ML classifier: $e');
      rethrow;
    }
  }
  
  /// Classify SMS as transaction or non-transaction
  /// Returns (isTransaction, confidence)
  Future<(bool, double)> classify(String smsText) async {
    if (!_isInitialized) {
      throw Exception('ML classifier not initialized. Call initialize() first.');
    }
    
    // 1. Tokenize text
    final sequence = _tokenize(smsText);
    
    // 2. Pad sequence
    final paddedSequence = _padSequence(sequence, _maxLen);
    
    // 3. Prepare input tensor
    final input = [paddedSequence.map((e) => e.toDouble()).toList()];
    
    // 4. Prepare output tensor
    final output = List.filled(1, 0.0).reshape([1, 1]);
    
    // 5. Run inference
    _interpreter.run(input, output);
    
    // 6. Get prediction
    final confidence = output[0][0] as double;
    final isTransaction = confidence > 0.5;
    
    return (isTransaction, confidence);
  }
  
  /// Tokenize text into sequence of integers
  List<int> _tokenize(String text) {
    final lowerText = text.toLowerCase();
    
    // Split into words (basic tokenization)
    final words = lowerText
        .replaceAll(RegExp(r'[!"#%&()*+,-./:;<=>?@\[\]^_`{|}~\t\n]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    
    // Convert words to indices
    final sequence = <int>[];
    for (final word in words) {
      if (_wordIndex.containsKey(word)) {
        sequence.add(_wordIndex[word]!);
      } else {
        sequence.add(1); // OOV token
      }
    }
    
    return sequence;
  }
  
  /// Pad sequence to fixed length
  List<int> _padSequence(List<int> sequence, int maxLen) {
    if (sequence.length >= maxLen) {
      return sequence.sublist(0, maxLen); // Truncate
    } else {
      return [...sequence, ...List.filled(maxLen - sequence.length, 0)]; // Pad with zeros
    }
  }
  
  /// Clean up resources
  void dispose() {
    _interpreter.close();
    _isInitialized = false;
  }
}

/// Hybrid SMS parser combining rules + ML
class HybridSmsParser {
  final MlSmsClassifier _mlClassifier = MlSmsClassifier();
  
  // Known banks from training data (100% accuracy with rules)
  static const _knownBanks = [
    'CITI', 'CITIBANK',
    'BOFA', 'BANKOFAMERICA',
    'CAPITALONE', 'CAPONE',
  ];
  
  /// Initialize hybrid parser
  Future<void> initialize() async {
    await _mlClassifier.initialize();
  }
  
  /// Parse SMS with hybrid approach
  Future<SmsTransactionResult> parse(String smsText, {String? senderId}) async {
    try {
      // Step 1: Check if it's a known bank
      final isKnownBank = senderId != null && 
          _knownBanks.any((bank) => senderId.toUpperCase().contains(bank));
      
      if (isKnownBank) {
        // Use rule-based parser (100% accuracy for known banks)
        return AdvancedSmsParser.parse(smsText, senderId: senderId);
      }
      
      // Step 2: Unknown bank → Use ML model (with fallback)
      if (!_mlClassifier._isInitialized) {
        // ML not available → Fall back to rules
        return AdvancedSmsParser.parse(smsText, senderId: senderId);
      }
      
      final (isTransaction, mlConfidence) = await _mlClassifier.classify(smsText);
      
      if (mlConfidence >= 0.85) {
        // High ML confidence → Trust it, but parse with lower confidence
        final ruleResult = AdvancedSmsParser.parse(smsText, senderId: senderId);
        
        // Return new instance with modified confidence and suggestions
        return SmsTransactionResult(
          isTransaction: isTransaction,
          transactionType: ruleResult.transactionType,
          amount: ruleResult.amount,
          currency: ruleResult.currency,
          merchant: ruleResult.merchant,
          accountIdentifier: ruleResult.accountIdentifier,
          bank: ruleResult.bank,
          region: ruleResult.region,
          confidenceScore: mlConfidence * 0.9, // Slightly lower than rule-based
          reasoning: '${ruleResult.reasoning} (ML-classified)',
          improvementSuggestions: [
            ...ruleResult.improvementSuggestions,
            'Classification based on ML model (unknown bank)',
            'Please review for accuracy',
          ],
        );
      }
      
      // Step 3: Low ML confidence → Mark for manual review
      return SmsTransactionResult(
        isTransaction: false,
        transactionType: TransactionTypeEnum.unknown,
        confidenceScore: mlConfidence,
        reasoning: 'Unknown bank with low ML confidence',
        improvementSuggestions: [
          'Unknown bank pattern detected',
          'ML confidence: ${(mlConfidence * 100).toStringAsFixed(1)}%',
          'Manual review recommended',
          'Your feedback will improve the parser',
        ],
      );
    } catch (e) {
      // If anything fails, fall back to rule-based parser
      return AdvancedSmsParser.parse(smsText, senderId: senderId);
    }
  }
  
  /// Record user correction for active learning
  Future<void> recordCorrection({
    required String smsText,
    required String? senderId,
    required bool isTransaction,
    Map<String, dynamic>? parsedData,
  }) async {
    // Store correction for analytics
    // Note: SmsCorrectionService now uses transactionId-based methods
    // This method is deprecated - use markAsDisputed/recordEdit instead
    print('⚠️ recordCorrectionFromUser is deprecated. Use SmsCorrectionService.markAsDisputed instead.');
    
    // For backward compatibility, just log it
    final smsPreview = smsText.length > 50 ? smsText.substring(0, 50) : smsText;
    print('📝 User correction logged: $smsPreview (isTransaction: $isTransaction)');
  }
  
  /// Clean up resources
  void dispose() {
    _mlClassifier.dispose();
  }
}

/// Example usage in SMS import service
class SmsImportServiceWithML {
  final HybridSmsParser _hybridParser = HybridSmsParser();
  
  Future<void> initialize() async {
    await _hybridParser.initialize();
  }
  
  Future<void> importSms(String smsText, String senderId) async {
    // Parse with hybrid approach
    final result = await _hybridParser.parse(smsText, senderId: senderId);
    
    if (result.isTransaction) {
      if (result.confidenceScore >= 0.9) {
        // High confidence → Auto-import
        await _saveTransaction(result);
      } else if (result.confidenceScore >= 0.7) {
        // Medium confidence → Import with review flag
        await _saveTransaction(result, needsReview: true);
        
        // Show notification to user
        _showReviewNotification(result);
      } else {
        // Low confidence → Skip, ask user
        _promptUserReview(smsText, senderId, result);
      }
    }
  }
  
  Future<void> _saveTransaction(SmsTransactionResult result, {bool needsReview = false}) async {
    // Save to database with review flag
    print('💾 Transaction saved (review: $needsReview): ${result.amount}');
  }
  
  void _showReviewNotification(SmsTransactionResult result) {
    print('🔔 Transaction needs review: ${result.amount}');
  }
  
  void _promptUserReview(String smsText, String senderId, SmsTransactionResult result) {
    print('❓ User review required for: ${smsText.substring(0, 50)}');
    // Show dialog asking user to confirm/correct
  }
}

// Add to pubspec.yaml:
// dependencies:
//   tflite_flutter: ^0.10.4

// Add to android/app/build.gradle:
// android {
//   aaptOptions {
//     noCompress 'tflite'
//   }
// }
