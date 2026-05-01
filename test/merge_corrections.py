#!/usr/bin/env python3
'''
Merge User Corrections with Training Data

This combines:
1. Original training dataset
2. Exported user corrections (real SMS from users)
3. Extracted keywords from parser

Into an enhanced training dataset.
'''

import json
from pathlib import Path
from datetime import datetime


def merge_training_data():
    # Load original training data
    with open('test/sms_training_dataset.json', 'r') as f:
        original_data = json.load(f)
    
    # Load user corrections (exported from app)
    corrections_file = Path('test/user_corrections.json')
    if corrections_file.exists():
        with open(corrections_file, 'r') as f:
            corrections = json.load(f)
        
        print(f"Loaded {len(corrections)} user corrections")
        
        # Convert corrections to training format
        correction_samples = []
        for corr in corrections:
            correction_samples.append({
                'text': corr['sms_text'],
                'label': 1 if corr['user_corrected_transaction'] else 0,
                'source': 'user_correction',
                'metadata': {
                    'sender_id': corr.get('sender_id'),
                    'was_misclassified': corr.get('was_misclassified', 0),
                }
            })
        
        # Add to training set (prioritize real data)
        print(f"Adding {len(correction_samples)} real user SMS to training...")
        original_data['train'].extend(correction_samples)
    
    # Load keyword-enhanced data
    keyword_file = Path('test/sms_training_dataset_enhanced.json')
    if keyword_file.exists():
        with open(keyword_file, 'r') as f:
            keyword_data = json.load(f)
        
        print(f"Merging keyword-enhanced dataset...")
        original_data['train'].extend(keyword_data['train'][:1000])  # Add subset
    
    # Save merged dataset
    output_file = 'test/sms_training_dataset_merged.json'
    with open(output_file, 'w') as f:
        json.dump(original_data, f, indent=2)
    
    print(f"\n✓ Merged training data saved: {output_file}")
    print(f"  Total training samples: {len(original_data['train'])}")
    print(f"\nNext: python test/train_sms_classifier.py")


if __name__ == '__main__':
    merge_training_data()
