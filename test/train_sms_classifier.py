"""
train_sms_classifier.py

Trains a 6-way SMS classifier and exports:
  assets/ml/sms_classifier.tflite   — TFLite model for on-device inference
  assets/ml/tokenizer_config.json   — word index + max_len for the Flutter app

Labels:
  0 debit | 1 credit | 2 transfer | 3 balance | 4 reminder | 5 non_financial

Usage:
    .venv\\Scripts\\python.exe test/train_sms_classifier.py
"""

import os
import json
import csv
import re
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
os.environ["TF_CPP_MIN_LOG_LEVEL"]  = "2"

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT        = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAIN_CSV   = os.path.join(ROOT, "test", "sms_training_balanced.csv")
TFLITE_OUT  = os.path.join(ROOT, "assets", "ml", "sms_classifier.tflite")
TOKENIZER_OUT = os.path.join(ROOT, "assets", "ml", "tokenizer_config.json")

# ── Hyperparameters ────────────────────────────────────────────────────────────
VOCAB_SIZE  = 4000
MAX_LEN     = 64
EMBED_DIM   = 32
EPOCHS      = 20
BATCH_SIZE  = 64
VAL_SPLIT   = 0.15
TEST_SPLIT  = 0.10

LABEL_MAP = {
    "debit":         0,
    "credit":        1,
    "transfer":      2,
    "balance":       3,
    "reminder":      4,
    "non_financial": 5,
}
IDX_TO_LABEL = {v: k for k, v in LABEL_MAP.items()}
NUM_CLASSES  = len(LABEL_MAP)

# ── Text cleaning ──────────────────────────────────────────────────────────────

def clean(text: str) -> str:
    text = text.lower()
    # Normalise dollar amounts → token "$amount"
    text = re.sub(r'\$[\d,]+(?:\.\d{1,2})?', '$amount', text)
    # Normalise account last-4 → token "acct1234"
    text = re.sub(r'\b\d{4}\b', 'acct1234', text)
    # Normalise dates
    text = re.sub(r'\d{1,2}/\d{1,2}/\d{2,4}', 'date', text)
    text = re.sub(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+\d{1,2}(,\s*\d{4})?', 'date', text)
    # Remove URLs
    text = re.sub(r'https?://\S+', '', text)
    # Remove punctuation except $ (already normalised)
    text = re.sub(r'[^a-z0-9\s]', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

# ── Load data ──────────────────────────────────────────────────────────────────

print("Loading training data ...")
texts, labels = [], []
with open(TRAIN_CSV, encoding="utf-8") as f:
    for row in csv.DictReader(f):
        t = (row.get("text") or "").strip()
        l = (row.get("label") or "").strip()
        if t and l in LABEL_MAP:
            texts.append(clean(t))
            labels.append(LABEL_MAP[l])

print(f"  {len(texts)} samples loaded")
from collections import Counter
dist = Counter(IDX_TO_LABEL[l] for l in labels)
for lbl, cnt in dist.most_common():
    print(f"    {lbl:<16} {cnt:>5}  ({cnt/len(labels)*100:.1f}%)")

# ── Tokenizer ─────────────────────────────────────────────────────────────────

print("\nBuilding tokenizer ...")
tokenizer = keras.preprocessing.text.Tokenizer(
    num_words=VOCAB_SIZE,
    oov_token="<OOV>",
)
tokenizer.fit_on_texts(texts)

sequences = tokenizer.texts_to_sequences(texts)
padded    = keras.preprocessing.sequence.pad_sequences(
    sequences, maxlen=MAX_LEN, padding="post", truncating="post"
)
labels_arr = np.array(labels)

# ── Train / val / test split ───────────────────────────────────────────────────

X_temp, X_test, y_temp, y_test = train_test_split(
    padded, labels_arr, test_size=TEST_SPLIT, random_state=42, stratify=labels_arr
)
X_train, X_val, y_train, y_val = train_test_split(
    X_temp, y_temp, test_size=VAL_SPLIT / (1 - TEST_SPLIT), random_state=42, stratify=y_temp
)
print(f"  Train: {len(X_train)} | Val: {len(X_val)} | Test: {len(X_test)}")

# ── Model ──────────────────────────────────────────────────────────────────────

print("\nBuilding model ...")
model = keras.Sequential([
    layers.Embedding(VOCAB_SIZE, EMBED_DIM, input_length=MAX_LEN),
    layers.GlobalAveragePooling1D(),
    layers.Dense(64, activation="relu"),
    layers.Dropout(0.3),
    layers.Dense(32, activation="relu"),
    layers.Dropout(0.2),
    layers.Dense(NUM_CLASSES, activation="softmax"),
])

model.compile(
    optimizer="adam",
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
model.summary()

# ── Training ───────────────────────────────────────────────────────────────────

print("\nTraining ...")
callbacks = [
    keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=4, restore_best_weights=True, verbose=1
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss", factor=0.5, patience=2, verbose=1
    ),
]

history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=callbacks,
    verbose=1,
)

# ── Evaluation ─────────────────────────────────────────────────────────────────

print("\nEvaluating on test set ...")
test_loss, test_acc = model.evaluate(X_test, y_test, verbose=0)
print(f"  Test accuracy: {test_acc:.4f}  |  Test loss: {test_loss:.4f}")

y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
print("\nClassification report:")
print(classification_report(
    y_test, y_pred,
    target_names=[IDX_TO_LABEL[i] for i in range(NUM_CLASSES)]
))

# ── Export TFLite ──────────────────────────────────────────────────────────────

print("Exporting TFLite model ...")

# Save as SavedModel first (concrete function approach for max compatibility)
import tempfile, os
saved_model_dir = os.path.join(tempfile.mkdtemp(), 'saved_model')
model.export(saved_model_dir)

# Convert using the legacy path which produces a flatbuffer compatible with older runtimes
converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
# No quantization, no experimental flags — produces the most compatible flatbuffer
tflite_model = converter.convert()

os.makedirs(os.path.dirname(TFLITE_OUT), exist_ok=True)
with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)
print(f"  Saved: {TFLITE_OUT}  ({len(tflite_model)/1024:.1f} KB)")

# ── Export tokenizer ──────────────────────────────────────────────────────────

print("Exporting tokenizer config ...")
# Only export words that made it into the vocabulary (index < VOCAB_SIZE)
word_index = {
    word: idx
    for word, idx in tokenizer.word_index.items()
    if idx < VOCAB_SIZE
}
tokenizer_config = {
    "word_index": word_index,
    "max_len":    MAX_LEN,
    "vocab_size": VOCAB_SIZE,
    "label_map":  LABEL_MAP,
}
with open(TOKENIZER_OUT, "w", encoding="utf-8") as f:
    json.dump(tokenizer_config, f, indent=2)
print(f"  Saved: {TOKENIZER_OUT}  ({len(word_index)} tokens)")

print("\nDone.")
