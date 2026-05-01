"""
Convert trained SMS NER model to TensorFlow Lite for mobile deployment.
"""

import tensorflow as tf
import pickle
import os

def convert_to_tflite(model_path='test/models/sms_ner_best.h5', 
                     output_path='test/models/sms_ner_model.tflite'):
    """
    Convert Keras model to TensorFlow Lite format for Flutter deployment.
    
    TFLite optimizations:
    - Reduced model size (quantization)
    - Faster inference on mobile devices
    - Compatible with tflite_flutter package
    """
    
    print("="*80)
    print("CONVERTING TO TENSORFLOW LITE FOR MOBILE")
    print("="*80)
    
    # Load the trained model (with custom objects if needed)
    print(f"\nLoading model from {model_path}...")
    try:
        model = tf.keras.models.load_model(model_path)
    except ValueError:
        # Try with compile=False for models with custom layers
        print("  Loading without compilation...")
        model = tf.keras.models.load_model(model_path, compile=False)
    
    print("\nModel Summary:")
    model.summary()
    
    # Convert to TensorFlow Lite
    print("\nConverting to TFLite format...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Optimization options
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Optional: Dynamic range quantization (reduces size, maintains accuracy)
    # Uncomment for smaller model (may reduce accuracy slightly)
    # converter.optimizations = [tf.lite.Optimize.DEFAULT]
    # converter.target_spec.supported_types = [tf.float16]
    
    # Convert
    tflite_model = converter.convert()
    
    # Save the model
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    # Get file sizes
    original_size = os.path.getsize(model_path) / (1024 * 1024)
    tflite_size = os.path.getsize(output_path) / (1024 * 1024)
    
    print(f"\n✓ Conversion complete!")
    print(f"  Original model: {original_size:.2f} MB")
    print(f"  TFLite model: {tflite_size:.2f} MB")
    print(f"  Compression: {(1 - tflite_size/original_size)*100:.1f}%")
    print(f"  Saved to: {output_path}")
    
    # Also copy the tokenizer config for mobile use
    config_path = 'test/models/sms_ner_model_config.pkl'
    if os.path.exists(config_path):
        print(f"\n⚠ Remember to port tokenizer logic to Dart!")
        print(f"  Config file: {config_path}")
        
        with open(config_path, 'rb') as f:
            config = pickle.load(f)
            print(f"  Vocab size: {len(config['tokenizer'].word_index)}")
            print(f"  Max length: {config['max_length']}")
    
    print("\n" + "="*80)
    print("NEXT STEPS FOR FLUTTER INTEGRATION:")
    print("="*80)
    print("""
1. Add to pubspec.yaml:
   dependencies:
     tflite_flutter: ^0.10.4

2. Copy model to Flutter assets:
   - Create folder: assets/models/
   - Copy: sms_ner_model.tflite to assets/models/
   - Update pubspec.yaml:
     flutter:
       assets:
         - assets/models/sms_ner_model.tflite

3. Create Dart NER service:
   - Load TFLite model using tflite_flutter
   - Implement tokenizer in Dart (word_index mapping)
   - Run inference on SMS text
   - Parse BIO tags to extract entities

4. Integration:
   - Call NER service from AccountExtractionService
   - Compare with pattern-based extraction
   - Use ML predictions when confidence > 0.8
    """)


def create_dart_example():
    """Generate example Dart code for using the TFLite model."""
    
    dart_code = '''
// lib/services/sms_ner_service.dart
import 'package:tflite_flutter/tflite_flutter.dart';

class SmsNERService {
  static Interpreter? _interpreter;
  static Map<String, int>? _wordIndex;
  static const int _maxLength = 50;
  static const int _vocabSize = 5000;
  
  // Entity labels (same as Python training)
  static const List<String> _labels = [
    'O', 'B-BANK', 'I-BANK', 'B-MERCHANT', 'I-MERCHANT',
    'B-KEYWORD', 'I-KEYWORD', 'B-AMOUNT', 'I-AMOUNT',
    'B-ACCOUNT', 'I-ACCOUNT', 'B-DATE', 'I-DATE',
    'B-REFERENCE', 'I-REFERENCE'
  ];
  
  static Future<void> initialize() async {
    // Load TFLite model
    _interpreter = await Interpreter.fromAsset('assets/models/sms_ner_model.tflite');
    
    // Load word index (you need to convert Python tokenizer to JSON)
    // _wordIndex = await _loadWordIndex();
    
    print('SMS NER model loaded successfully');
  }
  
  static Future<Map<String, List<String>>> extractEntities(String smsText) async {
    if (_interpreter == null) {
      await initialize();
    }
    
    // 1. Tokenize text
    final words = smsText.split(' ');
    final inputIds = _tokenize(words);
    
    // 2. Run inference
    final input = [inputIds];
    final output = List.filled(1, List.filled(_maxLength, List.filled(_labels.length, 0.0)));
    
    _interpreter!.run(input, output);
    
    // 3. Parse predictions (BIO tags)
    final entities = _parseBIOTags(words, output[0]);
    
    return entities;
  }
  
  static List<int> _tokenize(List<String> words) {
    final tokens = <int>[];
    for (final word in words) {
      final wordLower = word.toLowerCase();
      final tokenId = _wordIndex?[wordLower] ?? 1; // 1 = <UNK>
      tokens.add(tokenId);
    }
    
    // Pad to max_length
    while (tokens.length < _maxLength) {
      tokens.add(0);
    }
    
    return tokens.take(_maxLength).toList();
  }
  
  static Map<String, List<String>> _parseBIOTags(
    List<String> words, 
    List<List<double>> predictions
  ) {
    final entities = <String, List<String>>{};
    String? currentEntityType;
    List<String> currentWords = [];
    
    for (int i = 0; i < words.length && i < predictions.length; i++) {
      final labelIdx = _argmax(predictions[i]);
      final label = _labels[labelIdx];
      
      if (label.startsWith('B-')) {
        // Save previous entity
        if (currentEntityType != null && currentWords.isNotEmpty) {
          entities.putIfAbsent(currentEntityType, () => [])
              .add(currentWords.join(' '));
        }
        // Start new entity
        currentEntityType = label.substring(2); // Remove 'B-'
        currentWords = [words[i]];
      } else if (label.startsWith('I-') && currentEntityType != null) {
        currentWords.add(words[i]);
      } else {
        // End entity
        if (currentEntityType != null && currentWords.isNotEmpty) {
          entities.putIfAbsent(currentEntityType, () => [])
              .add(currentWords.join(' '));
        }
        currentEntityType = null;
        currentWords = [];
      }
    }
    
    // Save last entity
    if (currentEntityType != null && currentWords.isNotEmpty) {
      entities.putIfAbsent(currentEntityType, () => [])
          .add(currentWords.join(' '));
    }
    
    return entities;
  }
  
  static int _argmax(List<double> probabilities) {
    int maxIdx = 0;
    double maxVal = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxVal) {
        maxVal = probabilities[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }
  
  static void dispose() {
    _interpreter?.close();
  }
}
'''.trim()
    
    # Save example Dart code
    with open('test/models/sms_ner_service_example.dart', 'w') as f:
        f.write(dart_code)
    
    print(f"\n✓ Example Dart code saved to: test/models/sms_ner_service_example.dart")


if __name__ == '__main__':
    convert_to_tflite()
    create_dart_example()
