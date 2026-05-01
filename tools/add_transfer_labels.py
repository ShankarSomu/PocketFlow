"""Add transfer labels (label=2) to existing training data.

This script identifies credit card payment SMS in your training data
and relabels them from label=1 (transaction) to label=2 (transfer).

Usage:
    python tools/add_transfer_labels.py

Input: train.jsonl, dev.jsonl, test.jsonl
Output: train_3class.jsonl, dev_3class.jsonl, test_3class.jsonl
"""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent.parent
TRAIN_IN = ROOT / 'train.jsonl'
DEV_IN = ROOT / 'dev.jsonl'
TEST_IN = ROOT / 'test.jsonl'

TRAIN_OUT = ROOT / 'train_3class.jsonl'
DEV_OUT = ROOT / 'dev_3class.jsonl'
TEST_OUT = ROOT / 'test_3class.jsonl'

# Transfer detection patterns (data-driven approach)
TRANSFER_PATTERNS = [
    # Credit card payment patterns
    re.compile(r'payment\s+(posted|applied|received|processed|credited)\s+(to|on|for)\s+(acct|account|card)', re.IGNORECASE),
    re.compile(r'payment\s+of\s+.*\s+(posted|applied|received|processed|credited)', re.IGNORECASE),
    re.compile(r'(autopay|auto-pay|automatic\s+payment)\s+(posted|processed|completed)', re.IGNORECASE),
    
    # Bill payment patterns
    re.compile(r'bill\s+payment\s+(of|for)', re.IGNORECASE),
    re.compile(r'credit\s+card\s+bill\s+payment', re.IGNORECASE),
    re.compile(r'your\s+payment\s+(has\s+been|was)\s+(posted|received|processed|applied)', re.IGNORECASE),
    
    # Thank you patterns
    re.compile(r'thank\s+you\s+for\s+(your\s+)?payment', re.IGNORECASE),
    re.compile(r'payment\s+confirmation', re.IGNORECASE),
    re.compile(r'we\s+(received|have\s+received)\s+your\s+payment', re.IGNORECASE),
    
    # Money transfer (between own accounts)
    re.compile(r'money\s+transfer\s+of', re.IGNORECASE),
    re.compile(r'transferred\s+(from|to)\s+your\s+account', re.IGNORECASE),
]

# OTP/Non-transaction patterns (should stay label=0)
NON_TRANSACTION_PATTERNS = [
    re.compile(r'\botp\b', re.IGNORECASE),
    re.compile(r'one.time.password', re.IGNORECASE),
    re.compile(r'verification code', re.IGNORECASE),
    re.compile(r'do not share', re.IGNORECASE),
    re.compile(r'valid for \d+ (minutes|mins)', re.IGNORECASE),
]


def is_transfer(text):
    """Check if SMS text matches transfer patterns."""
    for pattern in TRANSFER_PATTERNS:
        if pattern.search(text):
            return True
    return False


def is_non_transaction(text):
    """Check if SMS text matches non-transaction patterns."""
    for pattern in NON_TRANSACTION_PATTERNS:
        if pattern.search(text):
            return True
    return False


def relabel_record(rec):
    """Relabel record to 3-class system."""
    text = rec.get('text', '')
    original_label = rec.get('label', 0)
    
    # Non-transactions stay 0
    if is_non_transaction(text):
        rec['label'] = 0
        rec['class_name'] = 'non_transaction'
        return rec, 'non_transaction'
    
    # Transfers become 2
    if is_transfer(text):
        rec['label'] = 2
        rec['class_name'] = 'transfer'
        return rec, 'transfer' if original_label != 2 else 'unchanged'
    
    # Regular transactions
    if rec.get('amount') or rec.get('raw_type_keyword'):
        rec['label'] = 1
        rec['class_name'] = 'transaction'
        return rec, 'transaction'
    
    # Default to non-transaction
    rec['label'] = 0
    rec['class_name'] = 'non_transaction'
    return rec, 'non_transaction'


def process_file(input_path, output_path):
    """Process a training file and relabel records."""
    if not input_path.exists():
        print(f"⚠️  {input_path} not found, skipping")
        return None
    
    records = []
    with input_path.open('r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                records.append(json.loads(line))
    
    stats = {
        'total': len(records),
        'non_transaction': 0,
        'transaction': 0,
        'transfer': 0,
        'relabeled': 0,
    }
    
    relabeled_records = []
    for rec in records:
        original_label = rec.get('label', 0)
        new_rec, class_result = relabel_record(rec)
        
        # Track statistics
        stats[new_rec['class_name']] += 1
        if class_result == 'transfer' and original_label != 2:
            stats['relabeled'] += 1
        
        relabeled_records.append(new_rec)
    
    # Write output
    with output_path.open('w', encoding='utf-8') as f:
        for rec in relabeled_records:
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
    
    return stats


def main():
    """Process all training files."""
    print("🔄 Relabeling training data with 3-class system...\n")
    
    files = [
        (TRAIN_IN, TRAIN_OUT, 'Training'),
        (DEV_IN, DEV_OUT, 'Validation'),
        (TEST_IN, TEST_OUT, 'Test'),
    ]
    
    total_stats = {
        'total': 0,
        'non_transaction': 0,
        'transaction': 0,
        'transfer': 0,
        'relabeled': 0,
    }
    
    for input_path, output_path, label in files:
        stats = process_file(input_path, output_path)
        
        if stats:
            print(f"✅ {label} set: {output_path.name}")
            print(f"   Total: {stats['total']}")
            print(f"   Non-transactions (0): {stats['non_transaction']} ({stats['non_transaction']/stats['total']*100:.1f}%)")
            print(f"   Transactions (1): {stats['transaction']} ({stats['transaction']/stats['total']*100:.1f}%)")
            print(f"   Transfers (2): {stats['transfer']} ({stats['transfer']/stats['total']*100:.1f}%)")
            print(f"   Relabeled: {stats['relabeled']}\n")
            
            for key in total_stats:
                total_stats[key] += stats[key]
    
    print("=" * 60)
    print("📊 Overall Statistics:")
    print(f"   Total records: {total_stats['total']}")
    print(f"   Non-transactions: {total_stats['non_transaction']} ({total_stats['non_transaction']/total_stats['total']*100:.1f}%)")
    print(f"   Transactions: {total_stats['transaction']} ({total_stats['transaction']/total_stats['total']*100:.1f}%)")
    print(f"   Transfers: {total_stats['transfer']} ({total_stats['transfer']/total_stats['total']*100:.1f}%)")
    print(f"   Total relabeled: {total_stats['relabeled']}")
    print("=" * 60)
    
    print("\n📝 Next steps:")
    print("   1. Review *_3class.jsonl files to verify labeling")
    print("   2. Update test/train_sms_classifier.py to use 3-class model")
    print("   3. Run: python test/train_sms_classifier.py")
    print("   4. Convert to TFLite: python test/convert_to_tflite.py")
    print("   5. Update ml_sms_classifier.dart to handle 3 classes")


if __name__ == '__main__':
    main()
