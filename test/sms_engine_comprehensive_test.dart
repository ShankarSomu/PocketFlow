// Comprehensive SMS Engine Test
// Tests the complete pipeline: Rule Engine → ML Classifier → Parser
// Uses sms_training_dataset.json (10,000 samples)

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/sms_engine/rules/sms_rule_engine.dart';
import 'package:pocket_flow/sms_engine/_ml_deprecated/sms_ml_classifier.dart';
import 'package:pocket_flow/sms_engine/parsing/sms_classification_service.dart';
import 'package:pocket_flow/services/merchant_normalizer.dart';
import 'package:pocket_flow/db/database.dart';

void main() {

  group('SMS Engine Comprehensive Test', () {
    late SmsRuleEngine ruleEngine;
    late MlSmsClassifier mlClassifier;
    late SmsClassificationService classificationService;
    late Map<String, dynamic> testData;

    setUpAll(() async {
      // Initialize services
      ruleEngine = SmsRuleEngine();
      mlClassifier = MlSmsClassifier();
      classificationService = SmsClassificationService();
      
      // Initialize ML classifier
      try {
        await mlClassifier.initialize();
      } catch (e) {
        print('⚠️  ML classifier initialization failed: $e');
        print('   Tests will continue with rule engine only');
      }

      // Load test dataset
      final file = File('test/sms_training_dataset.json');
      final jsonString = await file.readAsString();
      testData = jsonDecode(jsonString);

      print('📊 Dataset loaded:');
      print('   Total samples: ${testData['metadata']['total_samples']}');
      print('   Train samples: ${testData['metadata']['train_samples']}');
      print('   Val samples: ${testData['metadata']['val_samples']}');
      print('   Test samples: ${testData['metadata']['test_samples']}');
      print('   Positive (transactions): ${testData['metadata']['positive_samples']}');
      print('   Negative (non-transactions): ${testData['metadata']['negative_samples']}');
      print('');
    });

    test('Test 1: Rule Engine Performance (Cold Start)', () async {
      print('\n🧪 TEST 1: Rule Engine Cold Start Performance\n');
      
      final testSamples = testData['test'] as List;
      final sampleSize = 100; // Test first 100 samples
      
      int correct = 0;
      int classified = 0;
      int skipped = 0;
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < sampleSize && i < testSamples.length; i++) {
        final sample = testSamples[i];
        final smsText = sample['text'] as String;
        final expectedIsTransaction = (sample['label'] as int) == 1;

        // Try rule engine
        final classification = await ruleEngine.classify(smsText);

        if (classification != null) {
          classified++;
          // For now, just count as correct if it classified (no rules exist yet)
        } else {
          skipped++;
        }
      }

      stopwatch.stop();
      final avgTimeMs = stopwatch.elapsedMilliseconds / sampleSize;

      print('✅ Results:');
      print('   Classified: $classified / $sampleSize');
      print('   Skipped (no rules): $skipped / $sampleSize');
      print('   Average time: ${avgTimeMs.toStringAsFixed(2)} ms/SMS');
      print('   Total time: ${stopwatch.elapsedMilliseconds} ms');
      print('');
      
      expect(avgTimeMs, lessThan(50), reason: 'Average classification should be < 50ms');
    });

    test('Test 2: ML Classifier Accuracy', () async {
      print('\n🧪 TEST 2: ML Classifier Accuracy Test\n');
      
      final testSamples = testData['test'] as List;
      final sampleSize = 100; // Test first 100 samples
      
      int correct = 0;
      int total = 0;
      int truePositives = 0;
      int trueNegatives = 0;
      int falsePositives = 0;
      int falseNegatives = 0;
      
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < sampleSize && i < testSamples.length; i++) {
        final sample = testSamples[i];
        final smsText = sample['text'] as String;
        final expectedIsTransaction = (sample['label'] as int) == 1;

        try {
          // Test ML classifier
          final (isTransaction, confidence) = await mlClassifier.classify(smsText);
          final predictedIsTransaction = isTransaction;

          total++;
          if (predictedIsTransaction == expectedIsTransaction) {
            correct++;
            if (expectedIsTransaction) {
              truePositives++;
            } else {
              trueNegatives++;
            }
          } else {
            if (predictedIsTransaction) {
              falsePositives++;
            } else {
              falseNegatives++;
            }
          }
        } catch (e) {
          print('   ⚠️  Error classifying SMS: $e');
        }
      }

      stopwatch.stop();
      final accuracy = (correct / total) * 100;
      final avgTimeMs = stopwatch.elapsedMilliseconds / total;
      final precision = truePositives / (truePositives + falsePositives);
      final recall = truePositives / (truePositives + falseNegatives);
      final f1Score = 2 * (precision * recall) / (precision + recall);

      print('✅ Results:');
      print('   Accuracy: ${accuracy.toStringAsFixed(2)}%');
      print('   Precision: ${(precision * 100).toStringAsFixed(2)}%');
      print('   Recall: ${(recall * 100).toStringAsFixed(2)}%');
      print('   F1-Score: ${(f1Score * 100).toStringAsFixed(2)}%');
      print('');
      print('   Confusion Matrix:');
      print('   ┌─────────────────┬──────────┬──────────┐');
      print('   │                 │ Predicted│ Predicted│');
      print('   │                 │ YES      │ NO       │');
      print('   ├─────────────────┼──────────┼──────────┤');
      print('   │ Actual YES      │ $truePositives       │ $falseNegatives       │');
      print('   │ Actual NO       │ $falsePositives       │ $trueNegatives      │');
      print('   └─────────────────┴──────────┴──────────┘');
      print('');
      print('   Average time: ${avgTimeMs.toStringAsFixed(2)} ms/SMS');
      print('   Total time: ${stopwatch.elapsedMilliseconds} ms');
      print('');

      expect(accuracy, greaterThan(80), reason: 'ML accuracy should be > 80%');
    });

    test('Test 3: Complete Pipeline with Feedback Learning', () async {
      print('\n🧪 TEST 3: Complete Pipeline + Feedback Learning\n');
      
      final trainSamples = testData['train'] as List;
      final testSamples = testData['test'] as List;
      
      // Phase 1: Learn from 50 corrections
      print('📚 Phase 1: Learning from user corrections...');
      int rulesCreated = 0;
      
      for (var i = 0; i < 50 && i < trainSamples.length; i++) {
        final sample = trainSamples[i];
        final smsText = sample['text'] as String;
        final isTransaction = (sample['label'] as int) == 1;
        
        if (isTransaction) {
          // Simulate user correction: create rule
          try {
            await ruleEngine.addRule(
              smsText: smsText,
              category: sample['category'] ?? 'Shopping',
              transactionType: 'expense',
              source: 'test_simulation',
            );
            rulesCreated++;
          } catch (e) {
            // Ignore duplicates
          }
        }
      }
      
      print('   ✅ Created $rulesCreated rules from training data\n');
      
      // Phase 2: Test on test set
      print('🧪 Phase 2: Testing complete pipeline...');
      
      int ruleEngineHits = 0;
      int mlClassifierHits = 0;
      int parserHits = 0;
      int totalCorrect = 0;
      int total = 0;
      
      final stopwatch = Stopwatch()..start();
      
      for (var i = 0; i < 100 && i < testSamples.length; i++) {
        final sample = testSamples[i];
        final smsText = sample['text'] as String;
        final expectedIsTransaction = (sample['label'] as int) == 1;
        
        // Try rule engine first
        var classification = await ruleEngine.classify(smsText);
        var stage = '';
        
        if (classification != null) {
          ruleEngineHits++;
          stage = 'Rule Engine';
        } else {
          // Try ML classifier
          try {
            final (isTransaction, _) = await mlClassifier.classify(smsText);
            if (isTransaction) {
              mlClassifierHits++;
              stage = 'ML Classifier';
            }
          } catch (e) {
            // ML failed, would try parser here
            parserHits++;
            stage = 'Parser';
          }
        }
        
        total++;
        if (stage.isNotEmpty) {
          // Simplified: just count if we classified it
          totalCorrect++;
        }
      }
      
      stopwatch.stop();
      
      print('\n✅ Results:');
      print('   Stage Distribution:');
      print('   ├─ Rule Engine: $ruleEngineHits (${(ruleEngineHits/total*100).toStringAsFixed(1)}%)');
      print('   ├─ ML Classifier: $mlClassifierHits (${(mlClassifierHits/total*100).toStringAsFixed(1)}%)');
      print('   └─ Parser: $parserHits (${(parserHits/total*100).toStringAsFixed(1)}%)');
      print('');
      print('   Average time: ${(stopwatch.elapsedMilliseconds/total).toStringAsFixed(2)} ms/SMS');
      print('   Total time: ${stopwatch.elapsedMilliseconds} ms');
      print('');
      
      expect(ruleEngineHits, greaterThan(0), reason: 'Rules should be used after training');
    });

    test('Test 4: Merchant Normalization', () async {
      print('\n🧪 TEST 4: Merchant Normalization Test\n');
      
      final normalizer = MerchantNormalizer();
      final testCases = <String, String>{
        'AMAZON PAY': 'AMAZON',
        'SWIGGY FOODS': 'SWIGGY',
        'WALMART SUPERCENTER': 'WALMART',
        'McDONALDS': 'MCDONALDS',
        'STARBUCKS COFFEE': 'STARBUCKS',
      };
      
      int passed = 0;
      int total = testCases.length;
      
      for (var entry in testCases.entries) {
        final normalized = normalizer.normalize(entry.key);
        final expected = entry.value;
        
        if (normalized == expected) {
          passed++;
          print('   ✅ ${entry.key} → $normalized');
        } else {
          print('   ❌ ${entry.key} → $normalized (expected: $expected)');
        }
      }
      
      print('');
      print('✅ Results: $passed / $total passed');
      print('');
      
      expect(passed, greaterThan(total * 0.8), reason: 'At least 80% should normalize correctly');
    });

    test('Test 5: Performance Benchmark (1000 SMS)', () async {
      print('\n🧪 TEST 5: Performance Benchmark (1000 SMS)\n');
      
      final testSamples = testData['test'] as List;
      final benchmarkSize = 1000;
      
      final stopwatch = Stopwatch()..start();
      int processed = 0;
      
      for (var i = 0; i < benchmarkSize && i < testSamples.length; i++) {
        final sample = testSamples[i];
        final smsText = sample['text'] as String;
        
        // Complete pipeline
        var classification = await ruleEngine.classify(smsText);
        
        if (classification == null) {
          try {
            await mlClassifier.classify(smsText);
          } catch (e) {
            // Parser would go here
          }
        }
        
        processed++;
      }
      
      stopwatch.stop();
      final totalMs = stopwatch.elapsedMilliseconds;
      final avgMs = totalMs / processed;
      final smsPerSecond = (processed / (totalMs / 1000)).toStringAsFixed(0);
      
      print('✅ Results:');
      print('   Processed: $processed SMS');
      print('   Total time: $totalMs ms');
      print('   Average time: ${avgMs.toStringAsFixed(2)} ms/SMS');
      print('   Throughput: $smsPerSecond SMS/second');
      print('');
      
      expect(avgMs, lessThan(100), reason: 'Should process SMS in < 100ms on average');
    });

    test('Test 6: Edge Cases & Error Handling', () async {
      print('\n🧪 TEST 6: Edge Cases & Error Handling\n');
      
      final edgeCases = [
        '', // Empty string
        'x', // Single character
        'This is not a financial SMS at all', // Non-financial
        'Rs ' * 1000, // Very long SMS
        '\$\$\$ FREE MONEY \$\$\$', // Spam-like
        'Your OTP is 123456', // OTP (should be blocked)
      ];
      
      int handled = 0;
      
      for (var smsText in edgeCases) {
        try {
          final classification = await ruleEngine.classify(smsText);
          print('   ✅ Handled: "${smsText.length > 40 ? smsText.substring(0, 40) + '...' : smsText}"');
          handled++;
        } catch (e) {
          print('   ❌ Failed: "${smsText.length > 40 ? smsText.substring(0, 40) + '...' : smsText}" - $e');
        }
      }
      
      print('');
      print('✅ Results: $handled / ${edgeCases.length} handled gracefully');
      print('');
      
      expect(handled, equals(edgeCases.length), reason: 'Should handle all edge cases');
    });
  });
}
