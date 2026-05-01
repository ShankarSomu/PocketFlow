"""
SMS Named Entity Recognition (NER) Model Training
==================================================
Trains a machine learning model to extract entities from financial SMS messages:
- BANK: Bank or financial institution names
- AMOUNT: Transaction amounts
- ACCOUNT: Account/card numbers
- MERCHANT: Merchant/vendor names
- DATE: Transaction dates
- KEYWORD: Transaction type keywords
- REFERENCE: Reference/transaction IDs

Uses TensorFlow/Keras BiLSTM model for Named Entity Recognition.
"""

import json
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.model_selection import train_test_split
import argparse
from datetime import datetime
import pickle
import os
from typing import List, Dict, Tuple
import warnings
warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # Suppress TensorFlow warnings

# Entity types using BIO tagging scheme
ENTITY_TYPES = ['O', 'B-BANK', 'I-BANK', 'B-MERCHANT', 'I-MERCHANT', 
                'B-KEYWORD', 'I-KEYWORD', 'B-AMOUNT', 'I-AMOUNT',
                'B-ACCOUNT', 'I-ACCOUNT', 'B-DATE', 'I-DATE', 
                'B-REFERENCE', 'I-REFERENCE']


def load_training_data(filepath: str) -> List[Dict]:


    """Load the generated training data from JSON file."""
    print(f"\n{'='*80}")
    print(f"Loading training data from {filepath}...")
    print(f"{'='*80}\n")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    metadata = data.get('metadata', {})
    stats = metadata.get('statistics', {})
    
    print(f"Dataset Statistics:")
    print(f"  Total samples: {stats.get('total_samples', 0)}")
    print(f"  Original samples: {stats.get('original_samples', 0)}")
    print(f"  Augmented samples: {stats.get('augmented_samples', 0)}")
    print(f"  With bank entities: {stats.get('with_bank_name', 0)}")
    print(f"  With merchant entities: {stats.get('with_merchant', 0)}")
    print(f"  With keyword entities: {stats.get('with_keyword', 0)}")
    
    entity_types = metadata.get('entity_types', {})
    print(f"\nEntity Type Distribution:")
    for entity_type, count in sorted(entity_types.items()):
        print(f"  {entity_type}: {count}")
    
    return data['training_samples']


class SMSNERModel:
    """BiLSTM-based Named Entity Recognition model for SMS text."""
    
    def __init__(self, vocab_size=5000, embedding_dim=128, lstm_units=64, max_length=50):
        self.vocab_size = vocab_size
        self.embedding_dim = embedding_dim
        self.lstm_units = lstm_units
        self.max_length = max_length  # Max SMS length in words
        
        self.tokenizer = None
        self.label_encoder = {label: idx for idx, label in enumerate(ENTITY_TYPES)}
        self.label_decoder = {idx: label for label, idx in self.label_encoder.items()}
        self.num_labels = len(ENTITY_TYPES)
        
        self.model = None
    
    def build_model(self):
        """Build BiLSTM model for NER"""
        print(f"\nBuilding BiLSTM NER model...")
        print(f"  Vocab size: {self.vocab_size}")
        print(f"  Embedding dim: {self.embedding_dim}")
        print(f"  LSTM units: {self.lstm_units}")
        print(f"  Max length: {self.max_length}")
        print(f"  Num labels: {self.num_labels}")
        
        # Input layer
        input_ids = layers.Input(shape=(self.max_length,), dtype=tf.int32, name='input_ids')
        
        # Embedding layer
        embeddings = layers.Embedding(
            input_dim=self.vocab_size,
            output_dim=self.embedding_dim,
            mask_zero=True,
            name='embeddings'
        )(input_ids)
        
        # Bidirectional LSTM layers
        lstm1 = layers.Bidirectional(
            layers.LSTM(self.lstm_units, return_sequences=True, dropout=0.3),
            name='bilstm_1'
        )(embeddings)
        
        lstm2 = layers.Bidirectional(
            layers.LSTM(self.lstm_units // 2, return_sequences=True, dropout=0.3),
            name='bilstm_2'
        )(lstm1)
        
        # Dense layers
        dense = layers.Dense(64, activation='relu', name='dense')(lstm2)
        dropout = layers.Dropout(0.3)(dense)
        
        # Output layer (entity labels)
        output = layers.Dense(self.num_labels, activation='softmax', name='output')(dropout)
        
        # Build model
        self.model = keras.Model(inputs=input_ids, outputs=output)
        
        # Compile
        self.model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy']
        )
        
        return self.model
    
    def prepare_data(self, training_data: List[Dict]) -> Tuple:
        """Convert training data to model format using BIO tagging."""
        
        texts = []
        entity_sequences = []
        
        print(f"\nPreparing {len(training_data)} samples...")
        
        for sample in training_data:
            text = sample['masked_text']
            spans = sample.get('entity_spans', [])
            
            # Tokenize text (split by whitespace)
            words = text.split()
            texts.append(text)
            
            # Create BIO labels for each word
            labels = ['O'] * len(words)
            
            # Assign entity labels using character positions
            for span in spans:
                entity_type = span['type']
                start_char = span['start']
                end_char = span['end']
                
                # Find which words overlap with this entity span
                current_pos = 0
                first_word = True
                
                for word_idx, word in enumerate(words):
                    word_start = current_pos
                    word_end = current_pos + len(word)
                    
                    # Check if word overlaps with entity span
                    if word_end > start_char and word_start < end_char:
                        if first_word and labels[word_idx] == 'O':
                            labels[word_idx] = f'B-{entity_type}'
                            first_word = False
                        elif labels[word_idx] == 'O':
                            labels[word_idx] = f'I-{entity_type}'
                    
                    current_pos = word_end + 1  # +1 for space
            
            entity_sequences.append(labels)
        
        # Create tokenizer if not exists
        if self.tokenizer is None:
            print("Creating tokenizer...")
            self.tokenizer = keras.preprocessing.text.Tokenizer(
                num_words=self.vocab_size,
                oov_token='<UNK>',
                lower=False  # Keep case for better bank/merchant recognition
            )
            self.tokenizer.fit_on_texts(texts)
        
        # Convert texts to sequences
        sequences = self.tokenizer.texts_to_sequences(texts)
        
        # Pad sequences
        X = keras.preprocessing.sequence.pad_sequences(
            sequences,
            maxlen=self.max_length,
            padding='post',
            truncating='post'
        )
        
        # Convert labels to indices and pad
        y = []
        for seq_labels in entity_sequences:
            label_ids = [self.label_encoder.get(label, 0) for label in seq_labels]
            # Pad to max_length
            padded = label_ids + [0] * (self.max_length - len(label_ids))
            padded = padded[:self.max_length]
            y.append(padded)
        
        y = np.array(y)
        
        print(f"X shape: {X.shape}, y shape: {y.shape}")
        print(f"Actual vocabulary size: {min(len(self.tokenizer.word_index) + 1, self.vocab_size)}")
        
        return X, y
    
    def train(self, X_train, y_train, X_val, y_val, epochs=30, batch_size=32):
        """Train the model"""
        
        if self.model is None:
            self.build_model()
        
        print("\n" + "="*80)
        print("MODEL ARCHITECTURE:")
        print("="*80)
        self.model.summary()
        
        # Create models directory
        os.makedirs('test/models', exist_ok=True)
        
        # Callbacks
        callbacks = [
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=5,
                restore_best_weights=True,
                verbose=1
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=3,
                min_lr=0.00001,
                verbose=1
            ),
            keras.callbacks.ModelCheckpoint(
                'test/models/sms_ner_best.h5',
                monitor='val_loss',
                save_best_only=True,
                verbose=1
            )
        ]
        
        print("\n" + "="*80)
        print("TRAINING STARTED:")
        print("="*80)
        
        # Train
        history = self.model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            epochs=epochs,
            batch_size=batch_size,
            callbacks=callbacks,
            verbose=1
        )
        
        return history
    
    def predict(self, texts: List[str]) -> List[List[Tuple[str, str]]]:
        """Predict entities in texts"""
        
        sequences = self.tokenizer.texts_to_sequences(texts)
        X = keras.preprocessing.sequence.pad_sequences(
            sequences,
            maxlen=self.max_length,
            padding='post'
        )
        
        predictions = self.model.predict(X, verbose=0)
        
        results = []
        for text, pred in zip(texts, predictions):
            words = text.split()
            pred_labels = [self.label_decoder[np.argmax(p)] for p in pred[:len(words)]]
            
            # Combine words and labels
            word_labels = list(zip(words, pred_labels))
            results.append(word_labels)
        
        return results
    
    def save(self, path='test/models/sms_ner_model'):
        """Save model and tokenizer"""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        
        # Save model
        self.model.save(f'{path}.h5')
        
        # Save tokenizer and config
        with open(f'{path}_config.pkl', 'wb') as f:
            pickle.dump({
                'tokenizer': self.tokenizer,
                'label_encoder': self.label_encoder,
                'label_decoder': self.label_decoder,
                'max_length': self.max_length,
                'vocab_size': self.vocab_size,
                'embedding_dim': self.embedding_dim,
                'lstm_units': self.lstm_units
            }, f)
        
        print(f"\n✓ Model saved to {path}")
    
    def load(self, path='test/models/sms_ner_model'):
        """Load saved model"""
        
        # Load model
        self.model = keras.models.load_model(f'{path}.h5')
        
        # Load tokenizer and config
        with open(f'{path}_config.pkl', 'rb') as f:
            data = pickle.load(f)
            self.tokenizer = data['tokenizer']
            self.label_encoder = data['label_encoder']
            self.label_decoder = data['label_decoder']
            self.max_length = data['max_length']
            self.vocab_size = data['vocab_size']
            self.embedding_dim = data['embedding_dim']
            self.lstm_units = data['lstm_units']
        
        print(f"✓ Model loaded from {path}")


def evaluate_model(model, X_test, y_test):
    """Evaluate model performance"""
    
    print(f"\n{'='*80}")
    print("EVALUATING MODEL...")
    print(f"{'='*80}\n")
    
    predictions = model.model.predict(X_test, verbose=0)
    pred_labels = np.argmax(predictions, axis=-1)
    
    # Calculate metrics
    total_correct = 0
    total_tokens = 0
    entity_correct = 0
    entity_total = 0
    
    # Per-entity metrics
    entity_stats = {label: {'correct': 0, 'total': 0, 'predicted': 0} 
                    for label in ENTITY_TYPES if label != 'O'}
    
    for true_seq, pred_seq in zip(y_test, pred_labels):
        for true_label_idx, pred_label_idx in zip(true_seq, pred_seq):
            if true_label_idx != 0:  # Ignore padding
                total_tokens += 1
                true_label = model.label_decoder[true_label_idx]
                pred_label = model.label_decoder[pred_label_idx]
                
                if true_label_idx == pred_label_idx:
                    total_correct += 1
                
                # Count entity tokens (not 'O')
                if true_label != 'O':
                    entity_total += 1
                    if true_label_idx == pred_label_idx:
                        entity_correct += 1
                    
                    # Track per-entity stats
                    if true_label in entity_stats:
                        entity_stats[true_label]['total'] += 1
                        if true_label == pred_label:
                            entity_stats[true_label]['correct'] += 1
                
                if pred_label != 'O' and pred_label in entity_stats:
                    entity_stats[pred_label]['predicted'] += 1
    
    overall_acc = total_correct / total_tokens if total_tokens > 0 else 0
    entity_acc = entity_correct / entity_total if entity_total > 0 else 0
    
    print(f"Overall Metrics:")
    print(f"  Token Accuracy: {overall_acc:.4f} ({total_correct}/{total_tokens})")
    print(f"  Entity Token Accuracy: {entity_acc:.4f} ({entity_correct}/{entity_total})")
    
    print(f"\nPer-Entity Performance:")
    for label, stats in sorted(entity_stats.items()):
        if stats['total'] > 0:
            acc = stats['correct'] / stats['total']
            precision = stats['correct'] / stats['predicted'] if stats['predicted'] > 0 else 0
            print(f"  {label:15s}: Acc={acc:.3f} Prec={precision:.3f} ({stats['correct']}/{stats['total']})")
    
    return overall_acc, entity_acc


def test_predictions(model, num_samples=5):
    """Test model predictions on sample messages"""
    
    test_texts = [
        "BofA: Direct deposit of $500.00 credited 01/06/2026 to account - 3456. STOP to end account texts",
        "Citi Alert: A $10.00 transaction was made at GITHUB, INC. on card ending in 3453",
        "Capital One Alert: Your Quicksilver Credit Card bal is $71.61 as of March 20",
        "Discover Card Alert: A transaction of $5.74 at Walmart on August 05, 2025. No Action needed.",
        "PG&E: Recurring payment for account 4564-8 for $58.32 paid with card 3453 approved",
        "DCU Alert: A deposit of $500.00 was credited to your account ending in 1234 on 04/20/2026",
    ]
    
    print(f"\n{'='*80}")
    print("TEST PREDICTIONS ON SAMPLE SMS:")
    print(f"{'='*80}\n")
    
    predictions = model.predict(test_texts[:num_samples])
    
    for idx, (text, word_labels) in enumerate(zip(test_texts[:num_samples], predictions), 1):
        print(f"[Sample {idx}]")
        print(f"Text: {text}\n")
        
        # Extract entities from BIO tags
        entities_found = {}
        current_entity_type = None
        current_entity_words = []
        
        for word, label in word_labels:
            if label.startswith('B-'):
                # Save previous entity if exists
                if current_entity_type and current_entity_words:
                    entity_text = ' '.join(current_entity_words)
                    if current_entity_type not in entities_found:
                        entities_found[current_entity_type] = []
                    entities_found[current_entity_type].append(entity_text)
                
                # Start new entity
                current_entity_type = label[2:]  # Remove 'B-'
                current_entity_words = [word]
                
            elif label.startswith('I-') and current_entity_type:
                # Continue current entity
                current_entity_words.append(word)
                
            else:
                # End of entity
                if current_entity_type and current_entity_words:
                    entity_text = ' '.join(current_entity_words)
                    if current_entity_type not in entities_found:
                        entities_found[current_entity_type] = []
                    entities_found[current_entity_type].append(entity_text)
                current_entity_type = None
                current_entity_words = []
        
        # Save last entity
        if current_entity_type and current_entity_words:
            entity_text = ' '.join(current_entity_words)
            if current_entity_type not in entities_found:
                entities_found[current_entity_type] = []
            entities_found[current_entity_type].append(entity_text)
        
        # Print extracted entities
        if entities_found:
            print("Extracted Entities:")
            for entity_type, values in sorted(entities_found.items()):
                for value in values:
                    print(f"  {entity_type:12s}: {value}")
        else:
            print("  No entities found")
        
        print("\n" + "-"*80 + "\n")


def main():
    parser = argparse.ArgumentParser(description='Train SMS NER Model using TensorFlow/Keras')
    parser.add_argument('--data', type=str, default='test/sms_extraction_training_data.json',
                        help='Path to training data JSON file')
    parser.add_argument('--epochs', type=int, default=30,
                        help='Number of training epochs')
    parser.add_argument('--batch-size', type=int, default=32,
                        help='Batch size for training')
    parser.add_argument('--test-split', type=float, default=0.15,
                        help='Test set split ratio')
    parser.add_argument('--val-split', type=float, default=0.15,
                        help='Validation set split ratio')
    parser.add_argument('--vocab-size', type=int, default=5000,
                        help='Vocabulary size')
    parser.add_argument('--embedding-dim', type=int, default=128,
                        help='Embedding dimension')
    parser.add_argument('--lstm-units', type=int, default=64,
                        help='LSTM units')
    parser.add_argument('--max-length', type=int, default=50,
                        help='Maximum sequence length (words)')
    
    args = parser.parse_args()
    
    print("="*80)
    print("SMS NAMED ENTITY RECOGNITION MODEL TRAINING")
    print("Using TensorFlow/Keras BiLSTM")
    print("="*80)
    print(f"\nConfiguration:")
    print(f"  Data: {args.data}")
    print(f"  Epochs: {args.epochs}")
    print(f"  Batch Size: {args.batch_size}")
    print(f"  Vocab Size: {args.vocab_size}")
    print(f"  Embedding Dim: {args.embedding_dim}")
    print(f"  LSTM Units: {args.lstm_units}")
    print(f"  Max Length: {args.max_length} words")
    
    # Load data
    training_data = load_training_data(args.data)
    
    # Create model
    model = SMSNERModel(
        vocab_size=args.vocab_size,
        embedding_dim=args.embedding_dim,
        lstm_units=args.lstm_units,
        max_length=args.max_length
    )
    
    # Prepare data
    X, y = model.prepare_data(training_data)
    
    # Split data
    # First split: separate test set
    X_temp, X_test, y_temp, y_test = train_test_split(
        X, y, test_size=args.test_split, random_state=42
    )
    
    # Second split: separate train and validation
    X_train, X_val, y_train, y_val = train_test_split(
        X_temp, y_temp, 
        test_size=args.val_split / (1 - args.test_split),
        random_state=42
    )
    
    print(f"\nData Split:")
    print(f"  Training: {len(X_train)} samples")
    print(f"  Validation: {len(X_val)} samples")
    print(f"  Test: {len(X_test)} samples")
    
    # Train model
    history = model.train(
        X_train, y_train,
        X_val, y_val,
        epochs=args.epochs,
        batch_size=args.batch_size
    )
    
    # Evaluate
    evaluate_model(model, X_test, y_test)
    
    # Test predictions
    test_predictions(model, num_samples=6)
    
    # Save model
    model.save('test/models/sms_ner_model')
    
    print(f"\n{'='*80}")
    print("✓ TRAINING COMPLETE!")
    print(f"{'='*80}")
    print(f"Model saved to: test/models/sms_ner_model.h5")
    print(f"Config saved to: test/models/sms_ner_model_config.pkl")
    print(f"Finished at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")


if __name__ == '__main__':
    main()
