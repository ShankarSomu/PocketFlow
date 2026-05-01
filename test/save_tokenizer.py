#!/usr/bin/env python3
"""
Extract and save tokenizer config from training dataset
"""

import json
import tensorflow as tf

# Load training data
with open('sms_training_dataset.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

train_texts = [item['text'] for item in data['train']]

# Build tokenizer (same as in training script)
tokenizer = tf.keras.preprocessing.text.Tokenizer(
    num_words=5000,
    oov_token='<OOV>',
    filters='!"#%&()*+,-./:;<=>?@[\\]^_`{|}~\t\n'
)

tokenizer.fit_on_texts(train_texts)

max_len = 100
vocab_size = min(5000, len(tokenizer.word_index) + 1)

# Save tokenizer config
config = {
    'word_index': tokenizer.word_index,
    'max_len': max_len,
    'vocab_size': vocab_size,
}

with open('tokenizer_config.json', 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print(f"✅ Tokenizer config saved: tokenizer_config.json")
print(f"   Vocabulary size: {vocab_size}")
print(f"   Max sequence length: {max_len}")
print(f"   Total words: {len(tokenizer.word_index)}")
