#!/usr/bin/env python3
"""
Test the saved TFLite model to verify it works correctly
"""

import json
import numpy as np
import tensorflow as tf

def test_saved_model():
    """Test the saved TFLite model"""
    
    print("="*70)
    print("TESTING SAVED TFLITE MODEL")
    print("="*70)
    
    # Load TFLite model
    try:
        interpreter = tf.lite.Interpreter(model_path='sms_classifier.tflite')
        interpreter.allocate_tensors()
        print("✅ Model loaded successfully")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return
    
    # Get model details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"\nModel Input Shape: {input_details[0]['shape']}")
    print(f"Model Output Shape: {output_details[0]['shape']}")
    
    # Load tokenizer
    with open('tokenizer_config.json', 'r') as f:
        tokenizer_config = json.load(f)
        word_index = tokenizer_config['word_index']
        max_len = tokenizer_config['max_len']
    
    print(f"Vocabulary size: {len(word_index)}")
    print(f"Max sequence length: {max_len}")
    
    # Test messages
    test_messages = [
        ("Citi Alert: A $89.45 transaction was made at GITHUB, INC.", True),
        ("BofA: Electronic draft of $125.00 for NETFLIX.COM was deducted", True),
        ("Chase: $50 charged at STARBUCKS on card ending 1234", True),
        ("Wells Fargo: Your available balance is $1,234.56", False),
        ("Capital One: Payment of $1,250.00 is due by 05/01/2026", False),
        ("Your OTP for login is 123456. Valid for 10 minutes.", False),
    ]
    
    print(f"\n{'='*70}")
    print("TEST PREDICTIONS")
    print(f"{'='*70}\n")
    
    batch_size = input_details[0]['shape'][0]
    
    correct = 0
    total = len(test_messages)
    
    for i, (message, expected) in enumerate(test_messages):
        # Tokenize
        words = message.lower().split()
        sequence = [word_index.get(word, 1) for word in words]
        
        # Pad
        if len(sequence) > max_len:
            sequence = sequence[:max_len]
        else:
            sequence = sequence + [0] * (max_len - len(sequence))
        
        # Create batch (repeat sequence to fill batch)
        batch = np.array([sequence] * batch_size, dtype=np.float32)
        
        # Run inference
        interpreter.set_tensor(input_details[0]['index'], batch)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])
        
        # Get prediction (first item in batch)
        confidence = output[0][0]
        predicted = confidence > 0.5
        
        # Check correctness
        is_correct = (predicted == expected)
        correct += is_correct
        
        # Display result
        status = "✅" if is_correct else "❌"
        label = "TRANSACTION" if predicted else "NON-TRANS"
        expected_label = "TRANSACTION" if expected else "NON-TRANS"
        
        print(f"{status} [{confidence:.3f}] {label} (expected: {expected_label})")
        print(f"   {message[:65]}")
        print()
    
    accuracy = correct / total * 100
    print(f"{'='*70}")
    print(f"Accuracy: {correct}/{total} = {accuracy:.1f}%")
    print(f"{'='*70}\n")
    
    if accuracy >= 80:
        print("✅ Model is working correctly!")
        print("\n📦 Files ready for deployment:")
        print("   - sms_classifier.tflite (0.82 MB)")
        print("   - tokenizer_config.json")
        print("\n📲 Next steps:")
        print("   1. Create assets/ml/ folder in your Flutter project")
        print("   2. Copy both files to assets/ml/")
        print("   3. Add to pubspec.yaml under flutter: assets:")
        print("   4. Use HybridSmsParser from ml_sms_classifier.dart")
    else:
        print("⚠️ Model accuracy is lower than expected")
        print("Consider retraining with different parameters")

if __name__ == '__main__':
    test_saved_model()
