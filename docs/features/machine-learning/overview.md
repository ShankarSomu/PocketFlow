# Machine Learning Overview

PocketFlow uses on-device machine learning for SMS classification and intelligent transaction categorization.

## Why Machine Learning?

Traditional rule-based systems struggle with:
- **Diverse formats**: Every bank uses different SMS templates
- **Regional variations**: Language, date formats, currency
- **Edge cases**: Ambiguous or complex messages
- **Scalability**: Adding new banks requires manual rules

ML solves this by learning patterns from labeled data.

## ML Architecture

```
SMS Message
    ↓
Preprocessing & Tokenization
    ↓
TFLite Model Inference
    ↓
Classification Result (Type + Confidence)
    ↓
Use in SMS Pipeline
```

## Models in PocketFlow

### 1. SMS Classifier

**Purpose**: Classify SMS message types

**Model**: TensorFlow Lite

**Location**: `assets/ml/sms_classifier.tflite`

**Input**: Tokenized SMS text (sequence of integers)

**Output**: Classification probabilities
- Transaction (debit/credit)
- Transfer
- Balance update
- Payment reminder
- Non-financial

**Accuracy**: 97%+ on test data

### 2. Category Predictor (Future)

**Purpose**: Predict transaction category

**Input**: Merchant name + transaction details

**Output**: Category (Food, Transport, Shopping, etc.)

## Model Files

```
assets/ml/
├── sms_classifier.tflite          # Production model
├── sms_classifier_smoke.tflite    # Lightweight test model
├── tokenizer_config.json          # Tokenizer vocabulary
└── tokenizer_config_smoke.json    # Test tokenizer
```

## Training Data

### Dataset

- **Size**: 100,000+ labeled SMS messages
- **Sources**: 
  - Indian banks (HDFC, ICICI, SBI, Axis, etc.)
  - US banks (Chase, BofA, Wells Fargo, etc.)
  - Payment platforms (UPI, Paytm, Venmo, Zelle)
  
### Labels

```json
{
  "sms": "Your HDFC Card ending 1234 debited by Rs.500 at Amazon",
  "label": "transaction_debit",
  "confidence": 1.0
}
```

### Sample Export

See `/docs/SMS_TRAINING_EXPORT.md` for dataset creation details.

## Using the Model

### 1. Load Model

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class MLClassifier {
  Interpreter? _interpreter;
  Map<String, int>? _vocabulary;
  
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/ml/sms_classifier.tflite');
    _vocabulary = await loadTokenizerConfig();
  }
}
```

### 2. Tokenize Input

```dart
List<int> tokenize(String text, int maxLength = 100) {
  final words = text.toLowerCase().split(' ');
  final tokens = <int>[];
  
  for (final word in words) {
    final token = _vocabulary[word] ?? 0; // 0 = unknown
    tokens.add(token);
  }
  
  // Pad or truncate to maxLength
  if (tokens.length < maxLength) {
    tokens.addAll(List.filled(maxLength - tokens.length, 0));
  } else {
    tokens.removeRange(maxLength, tokens.length);
  }
  
  return tokens;
}
```

### 3. Run Inference

```dart
ClassificationResult classify(String smsText) {
  final tokens = tokenize(smsText);
  
  // Prepare input tensor
  final input = [tokens];
  
  // Prepare output tensor
  final output = List.filled(5, 0.0).reshape([1, 5]);
  
  // Run inference
  _interpreter.run(input, output);
  
  final probabilities = output[0];
  final maxIndex = probabilities.indexOf(probabilities.reduce(max));
  
  return ClassificationResult(
    type: MessageType.values[maxIndex],
    confidence: probabilities[maxIndex],
  );
}
```

## Confidence Thresholds

```dart
class MLConfig {
  static const double highConfidence = 0.90;
  static const double mediumConfidence = 0.70;
  static const double lowConfidence = 0.50;
  
  static bool shouldAccept(double confidence) {
    return confidence >= mediumConfidence;
  }
}
```

## Fallback Strategy

ML classification is combined with rule-based classification:

```dart
ClassificationResult classify(String smsText) {
  // Try ML first
  final mlResult = mlClassifier.classify(smsText);
  
  if (mlResult.confidence >= 0.8) {
    return mlResult;
  }
  
  // Fallback to rule-based
  final ruleResult = ruleClassifier.classify(smsText);
  
  // Return higher confidence result
  return mlResult.confidence > ruleResult.confidence 
    ? mlResult 
    : ruleResult;
}
```

## Continuous Learning

### User Feedback Loop

When users correct classifications:

```dart
void learnFromCorrection(String smsText, MessageType correctType) {
  // Store for future training
  feedbackStore.save(FeedbackSample(
    smsText: smsText,
    predictedType: mlResult.type,
    correctType: correctType,
    timestamp: DateTime.now(),
  ));
}
```

### Retraining (Offline)

Periodically:
1. Collect user feedback
2. Add to training dataset
3. Retrain model
4. Evaluate on test set
5. Deploy new model via app update

See [Continuous Learning](continuous-learning.md) for details.

## Performance

### Inference Speed
- **Average**: 10-20ms per message
- **On-device**: No network required
- **Memory**: ~5MB model size

### Accuracy Metrics
- **Precision**: 97.5%
- **Recall**: 96.8%
- **F1 Score**: 97.1%

### Model Size
- **TFLite**: 4.8 MB
- **Smoke test**: 1.2 MB

## Privacy

All ML inference happens on-device:
- ✅ No data sent to servers
- ✅ No cloud API calls
- ✅ Complete privacy
- ✅ Works offline

## Model Updates

Models are bundled with the app and updated via:
1. App updates (Play Store/App Store)
2. Over-the-air (future feature)

## Testing

```dart
test('Classify transaction SMS', () {
  final sms = "Debited Rs.500 from A/c XX1234 at Amazon";
  final result = classifier.classify(sms);
  
  expect(result.type, MessageType.transaction);
  expect(result.confidence, greaterThan(0.9));
});

test('Reject OTP messages', () {
  final sms = "Your OTP is 123456";
  final result = classifier.classify(sms);
  
  expect(result.type, MessageType.otp);
  expect(result.shouldReject, true);
});
```

## Future Enhancements

### 1. Category Prediction
Automatically categorize transactions by merchant

### 2. Amount Extraction ML
Use ML to extract amounts from complex formats

### 3. Multilingual Support
Support Hindi, Spanish, and other languages

### 4. On-Device Training
Allow model to learn locally without uploading data

## Tools & Frameworks

- **TensorFlow Lite**: On-device inference
- **tflite_flutter**: Flutter plugin for TFLite
- **Python/TensorFlow**: Model training
- **Keras**: Model building

## Next Steps

- [Classifier Guide](classifier-guide.md) - Detailed classifier usage
- [Continuous Learning](continuous-learning.md) - Feedback system
- [Model Deployment](model-deployment.md) - Deployment process

---

*For implementation, see `lib/services/ml/` directory*
