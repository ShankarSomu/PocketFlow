# SMS Engine Testing Guide

This test suite validates the complete SMS Intelligence Engine using the 10,000 sample training dataset.

## What It Tests

### 📊 Test Coverage

1. **Rule Engine Performance** - Cold start speed test
2. **ML Classifier Accuracy** - Precision, recall, F1-score, confusion matrix
3. **Complete Pipeline** - Rule Engine → ML → Parser fallback with learning
4. **Merchant Normalization** - AMAZON PAY → AMAZON
5. **Performance Benchmark** - 1000 SMS throughput test
6. **Edge Cases** - Empty strings, spam, OTPs, long messages

### 🎯 Success Criteria

- ✅ Rule Engine: < 50ms per SMS
- ✅ ML Accuracy: > 80%
- ✅ Pipeline: Rules learned from feedback
- ✅ Merchant: > 80% normalization accuracy
- ✅ Throughput: > 10 SMS/second
- ✅ Edge cases: All handled gracefully

## Running the Test

### Option 1: Run All Tests

```powershell
flutter test test/sms_engine_comprehensive_test.dart
```

### Option 2: Run Individual Test Groups

```powershell
# Test 1: Rule Engine Performance
flutter test test/sms_engine_comprehensive_test.dart --name "Rule Engine"

# Test 2: ML Accuracy
flutter test test/sms_engine_comprehensive_test.dart --name "ML Classifier"

# Test 3: Complete Pipeline
flutter test test/sms_engine_comprehensive_test.dart --name "Complete Pipeline"

# Test 4: Merchant Normalization
flutter test test/sms_engine_comprehensive_test.dart --name "Merchant"

# Test 5: Performance Benchmark
flutter test test/sms_engine_comprehensive_test.dart --name "Performance"

# Test 6: Edge Cases
flutter test test/sms_engine_comprehensive_test.dart --name "Edge Cases"
```

### Option 3: Verbose Output

```powershell
flutter test test/sms_engine_comprehensive_test.dart --reporter expanded
```

## Expected Output

```
📊 Dataset loaded:
   Total samples: 10000
   Train samples: 8000
   Val samples: 1000
   Test samples: 1000
   Positive (transactions): 8000
   Negative (non-transactions): 2000

🧪 TEST 1: Rule Engine Cold Start Performance
   ✅ Results:
      Classified: 0 / 100
      Skipped (no rules): 100 / 100
      Average time: 2.45 ms/SMS
      Total time: 245 ms

🧪 TEST 2: ML Classifier Accuracy Test
   ✅ Results:
      Accuracy: 95.23%
      Precision: 96.12%
      Recall: 94.87%
      F1-Score: 95.49%

      Confusion Matrix:
      ┌─────────────────┬──────────┬──────────┐
      │                 │ Predicted│ Predicted│
      │                 │ YES      │ NO       │
      ├─────────────────┼──────────┼──────────┤
      │ Actual YES      │ 76       │ 4        │
      │ Actual NO       │ 3        │ 17       │
      └─────────────────┴──────────┴──────────┘

      Average time: 15.67 ms/SMS
      Total time: 1567 ms

🧪 TEST 3: Complete Pipeline + Feedback Learning
   📚 Phase 1: Learning from user corrections...
      ✅ Created 50 rules from training data

   🧪 Phase 2: Testing complete pipeline...
      ✅ Results:
         Stage Distribution:
         ├─ Rule Engine: 45 (45.0%)
         ├─ ML Classifier: 52 (52.0%)
         └─ Parser: 3 (3.0%)

         Average time: 8.23 ms/SMS
         Total time: 823 ms

🧪 TEST 4: Merchant Normalization Test
   ✅ AMAZON PAY → AMAZON
   ✅ SWIGGY FOODS → SWIGGY
   ✅ WALMART SUPERCENTER → WALMART
   ✅ McDonald's → MCDONALDS
   ✅ STARBUCKS COFFEE → STARBUCKS

   ✅ Results: 5 / 5 passed

🧪 TEST 5: Performance Benchmark (1000 SMS)
   ✅ Results:
      Processed: 1000 SMS
      Total time: 12345 ms
      Average time: 12.35 ms/SMS
      Throughput: 81 SMS/second

🧪 TEST 6: Edge Cases & Error Handling
   ✅ Handled: ""
   ✅ Handled: "x"
   ✅ Handled: "This is not a financial SMS at all"
   ✅ Handled: "Rs Rs Rs Rs Rs Rs Rs Rs Rs Rs Rs R..."
   ✅ Handled: "$$$ FREE MONEY $$$"
   ✅ Handled: "Your OTP is 123456"

   ✅ Results: 6 / 6 handled gracefully

All tests passed! ✅
```

## Dataset Structure

The test uses `test/sms_training_dataset.json`:

```json
{
  "metadata": {
    "total_samples": 10000,
    "train_samples": 8000,
    "val_samples": 1000,
    "test_samples": 1000
  },
  "train": [
    {
      "text": "BofA: Electronic draft of $123.45...",
      "label": 1,
      "source": "real",
      "category": "real_transactions"
    }
  ],
  "test": [...]
}
```

- **label**: 1 = transaction, 0 = non-transaction
- **source**: real, augmented, unknown
- **category**: Transaction category or type

## Troubleshooting

### Test fails with "File not found"

Make sure you're running from the project root:

```powershell
cd c:\Users\shank\projects\github\PocketFlow
flutter test test/sms_engine_comprehensive_test.dart
```

### Database errors

The test uses sqflite_ffi for desktop testing. Make sure dependencies are installed:

```powershell
flutter pub get
```

### ML Model not found

If ML classifier fails, ensure `assets/models/sms_classifier.tflite` exists and is in pubspec.yaml:

```yaml
flutter:
  assets:
    - assets/models/sms_classifier.tflite
    - assets/models/tokenizer_config.json
```

## What's Next?

After running tests:

1. **Review Results** - Check accuracy, speed metrics
2. **Add More Rules** - Based on misclassifications
3. **Train ML Model** - If accuracy < 90%
4. **Optimize Performance** - If speed > 20ms/SMS
5. **Add Custom Tests** - For specific SMS formats

## Integration with CI/CD

Add to `.github/workflows/test.yml`:

```yaml
- name: Run SMS Engine Tests
  run: flutter test test/sms_engine_comprehensive_test.dart --reporter expanded
```

---

**Created**: 2025-01-XX  
**Dataset**: sms_training_dataset.json (10,000 samples)  
**Coverage**: Rule Engine, ML Classifier, Pipeline, Normalization, Performance
