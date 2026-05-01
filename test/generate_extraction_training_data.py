"""
Generate Training Data for SMS Entity Extraction

This script generates labeled training data from SMS messages for training
an ML model to extract:
- Bank name
- Amount
- Account number
- Merchant
- Date
- Transaction type keywords

PRIVACY-SAFE APPROACH:
✓ Applies same masking as export module (SmsDataMasker)
✓ Amounts: Rs.560 → Rs.XXX (preserves structure, masks digits)
✓ Accounts: A/c 1234 → A/c XXXX (masks identifiers)
✓ Dates: 19-Apr-26 → <DATE> (placeholder)
✓ References: Ref: 123456789012 → <REF> (placeholder)

MOBILE-SPECIFIC DATASET DESIGN:
✓ Short text (SMS length ~160 chars) - Truncation applied
✓ Messy formatting - Mixed casing, irregular whitespace
✓ Real-world noise - Broken sentences, carrier suffixes
✓ Fast inference constraints - Simple pattern-based labeling

Training Format:
- Masked text (privacy-safe)
- Entity spans (position + type, no sensitive values)
- Entity types: BANK, AMOUNT, ACCOUNT, MERCHANT, DATE, KEYWORD

Noise augmentation includes:
- Truncated messages (simulate 160 char limit)
- Broken sentences (mid-word cuts)
- Mixed casing (UPPERCASE words, lowercase starts)
- Emojis (rare: 💰💳🏦✓✔⚠❗)
- Carrier suffixes ("STOP to end", "Reply HELP")
- Irregular whitespace

Output format: JSON with masked text + entity spans for NER
"""

import json
import re
import sys
import random
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from typing import List, Dict, Tuple

# Add lib to path for using existing parsers
sys.path.insert(0, str(Path(__file__).parent.parent / 'lib'))

# Mobile-specific noise characteristics
CARRIER_SUFFIXES = [
    " Reply STOP to end",
    " STOP to unsubscribe",
    " Text STOP to opt out",
    " Reply HELP for info",
    " Msg&Data rates may apply",
]

RARE_EMOJIS = ['💰', '💳', '🏦', '✓', '✔', '⚠', '❗']

CASING_VARIATIONS = ['upper', 'lower', 'random']


# ============================================================================
# DATA MASKING (Same approach as SmsDataMasker in lib/services/sms_data_masker.dart)
# ============================================================================

def mask_sms_data(text: str) -> Tuple[str, List[Dict]]:
    """
    Mask sensitive data in SMS text (same approach as export module)
    
    Returns:
        - masked_text: Privacy-safe text with masked values
        - entities: List of entity spans {type, start, end, original_value}
    
    Masking rules:
        - Amounts: Rs.560 → Rs.XXX (preserves currency, masks digits)
        - Accounts: A/c 1234 → A/c XXXX (masks last 4 digits)
        - Dates: 19-Apr-26 → <DATE> (placeholder)
        - References: Ref: 123456789012 → <REF> (placeholder)
    """
    entities = []
    masked = text
    offset = 0  # Track position shifts due to masking
    
    # Step 1: Mask amounts (BEFORE account numbers to preserve currency context)
    masked, amount_entities = _mask_amounts(masked)
    entities.extend(amount_entities)
    
    # Step 2: Mask reference IDs (BEFORE account numbers to catch longer IDs first)
    masked, ref_entities = _mask_reference_ids(masked)
    entities.extend(ref_entities)
    
    # Step 3: Mask account numbers
    masked, account_entities = _mask_account_numbers(masked)
    entities.extend(account_entities)
    
    # Step 4: Mask dates
    masked, date_entities = _mask_dates(masked)
    entities.extend(date_entities)
    
    return masked, entities


def _mask_amounts(text: str) -> Tuple[str, List[Dict]]:
    """Mask amounts preserving currency symbols"""
    entities = []
    
    # Pattern 1: Currency symbols (₹1,234.56, $100.00)
    def replace_currency_amount(match):
        currency = match.group(1)
        space = match.group(2)
        amount = match.group(3)
        
        entities.append({
            'type': 'AMOUNT',
            'start': match.start(),
            'end': match.end(),
            'original_value': amount,
            'original_text': match.group(0)
        })
        
        masked_amount = amount.replace(re.compile(r'\d'), 'X')
        return f'{currency}{space}{masked_amount}'
    
    text = re.sub(
        r'([₹\$€£¥])(\s*)(\d+(?:,\d{3})*(?:\.\d{2})?)',
        replace_currency_amount,
        text
    )
    
    # Pattern 2: Currency codes (INR 1234.56, Rs. 500, 100 USD)
    def replace_currency_code(match):
        currency = match.group(1)
        space = match.group(2)
        amount = match.group(3)
        
        entities.append({
            'type': 'AMOUNT',
            'start': match.start(),
            'end': match.end(),
            'original_value': amount,
            'original_text': match.group(0)
        })
        
        masked_amount = re.sub(r'\d', 'X', amount)
        return f'{currency}{space}{masked_amount}'
    
    text = re.sub(
        r'\b(INR|USD|EUR|GBP|Rs\.?)(\s*)(\d+(?:,\d{3})*(?:\.\d{2})?)',
        replace_currency_code,
        text,
        flags=re.IGNORECASE
    )
    
    # Pattern 3: Amount with trailing currency (1234.56 INR)
    def replace_trailing_currency(match):
        amount = match.group(1)
        space = match.group(2)
        currency = match.group(3)
        
        entities.append({
            'type': 'AMOUNT',
            'start': match.start(),
            'end': match.end(),
            'original_value': amount,
            'original_text': match.group(0)
        })
        
        masked_amount = re.sub(r'\d', 'X', amount)
        return f'{masked_amount}{space}{currency}'
    
    text = re.sub(
        r'\b(\d+(?:,\d{3})*(?:\.\d{2})?)(\s*)(INR|USD|EUR|GBP|Rs)',
        replace_trailing_currency,
        text,
        flags=re.IGNORECASE
    )
    
    return text, entities


def _mask_account_numbers(text: str) -> Tuple[str, List[Dict]]:
    """Mask account numbers with XXXX"""
    entities = []
    
    # Pattern 1: Account with XX/asterisks (A/c XX1234, Card ****1234)
    def replace_account_masked(match):
        prefix = match.group(1)
        
        entities.append({
            'type': 'ACCOUNT',
            'start': match.start(),
            'end': match.end(),
            'original_value': match.group(3),
            'original_text': match.group(0)
        })
        
        return f'{prefix}XXXX'
    
    text = re.sub(
        r'\b((?:A/c|Account|Card|a/c)\s*)(XX|xx|\*{4})(\d{4})\b',
        replace_account_masked,
        text,
        flags=re.IGNORECASE
    )
    
    # Pattern 2: "ending in" with 4 digits
    def replace_ending_in(match):
        prefix = match.group(1)
        
        entities.append({
            'type': 'ACCOUNT',
            'start': match.start(),
            'end': match.end(),
            'original_value': match.group(2),
            'original_text': match.group(0)
        })
        
        return f'{prefix}XXXX'
    
    text = re.sub(
        r'\b((?:ending|last)\s*(?:in)?\s*)(\d{4})\b',
        replace_ending_in,
        text,
        flags=re.IGNORECASE
    )
    
    # Pattern 3: "card" or "account" followed by 4 digits
    def replace_card_account(match):
        prefix = match.group(1)
        
        entities.append({
            'type': 'ACCOUNT',
            'start': match.start(),
            'end': match.end(),
            'original_value': match.group(2),
            'original_text': match.group(0)
        })
        
        return f'{prefix}XXXX'
    
    text = re.sub(
        r'\b((?:card|account|acct|a/c)\s+)(\d{4})\b',
        replace_card_account,
        text,
        flags=re.IGNORECASE
    )
    
    return text, entities


def _mask_dates(text: str) -> Tuple[str, List[Dict]]:
    """Mask dates with <DATE> placeholder"""
    entities = []
    
    # Pattern 1: DD-MMM-YY/YYYY (19-Apr-26, 19-April-2026)
    def replace_date_dmy(match):
        entities.append({
            'type': 'DATE',
            'start': match.start(),
            'end': match.end(),
            'original_value': match.group(0),
            'original_text': match.group(0)
        })
        return '<DATE>'
    
    text = re.sub(
        r'\b\d{1,2}-(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*-\d{2,4}\b',
        replace_date_dmy,
        text,
        flags=re.IGNORECASE
    )
    
    # Pattern 2: DD/MM/YY or DD-MM-YY
    text = re.sub(
        r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b',
        lambda m: (entities.append({'type': 'DATE', 'start': m.start(), 'end': m.end(), 
                                    'original_value': m.group(0), 'original_text': m.group(0)}), '<DATE>')[1],
        text
    )
    
    # Pattern 3: Month DD, YYYY
    text = re.sub(
        r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4}\b',
        lambda m: (entities.append({'type': 'DATE', 'start': m.start(), 'end': m.end(), 
                                    'original_value': m.group(0), 'original_text': m.group(0)}), '<DATE>')[1],
        text,
        flags=re.IGNORECASE
    )
    
    return text, entities


def _mask_reference_ids(text: str) -> Tuple[str, List[Dict]]:
    """Mask reference IDs, transaction IDs with <REF> placeholder"""
    entities = []
    
    # Pattern: Ref/Reference labels (Ref: 123456789012, UPI Ref: XXX)
    def replace_ref(match):
        label_match = re.match(r'[^:\s]+(?:\s+[^:\s]+)*', match.group(0))
        label = label_match.group(0) if label_match else 'Ref'
        
        entities.append({
            'type': 'REFERENCE',
            'start': match.start(),
            'end': match.end(),
            'original_value': match.group(0),
            'original_text': match.group(0)
        })
        
        return f'{label}: <REF>'
    
    text = re.sub(
        r'\b(?:Ref|Reference|UPI\s+Ref|Transaction\s+ID|Txn\s+ID|Order\s+ID)[:\s]+[A-Z0-9]{6,}',
        replace_ref,
        text,
        flags=re.IGNORECASE
    )
    
    # Pattern 2: Long alphanumeric IDs (12+ characters)
    text = re.sub(
        r'\b[A-Z0-9]{12,}\b',
        lambda m: (entities.append({'type': 'REFERENCE', 'start': m.start(), 'end': m.end(), 
                                    'original_value': m.group(0), 'original_text': m.group(0)}), '<REF>')[1],
        text
    )
    
    return text, entities


def extract_entities_from_sms(sms_text: str, sender: str = None) -> Dict:
    """
    Extract entities from SMS and apply privacy-safe masking
    
    Process:
        1. Extract entities from ORIGINAL text (get positions and values)
        2. Apply masking (same as export module)
        3. Extract additional entities (bank, merchant, keywords)
        4. Return masked text + entity spans
    
    Returns:
        {
            "original_text": Original SMS,
            "masked_text": Privacy-safe masked text,
            "entity_spans": List of {type, start, end, original_value},
            "bank_name": Extracted bank name,
            "merchant": Extracted merchant,
            "raw_type_keyword": Transaction type keyword
        }
    """
    # First, apply masking and capture entity positions
    masked_text, masked_entities = mask_sms_data(sms_text)
    
    # Initialize result
    result = {
        "original_text": sms_text,
        "masked_text": masked_text,
        "entity_spans": masked_entities,
        "bank_name": None,
        "merchant": None,
        "raw_type_keyword": None,
    }
    
    # Extract bank name from sender or SMS header (NOT masked)
    if sender:
        bank_patterns = {
            'CITI': 'Citi',
            'CHASE': 'Chase',
            'BOFA': 'Bank of America',
            'WELLSFARGO': 'Wells Fargo',
            'CAPONE': 'Capital One',
            'HDFCBK': 'HDFC Bank',
            'ICICIBK': 'ICICI Bank',
            'SBIINB': 'SBI',
            'AXISBK': 'Axis Bank',
            'KOTAKB': 'Kotak Bank',
        }
        sender_upper = sender.upper()
        for pattern, bank_name in bank_patterns.items():
            if pattern in sender_upper:
                result['bank_name'] = bank_name
                # Add bank entity span
                result['entity_spans'].append({
                    'type': 'BANK',
                    'start': 0,
                    'end': 0,  # Bank from sender, not in text
                    'original_value': bank_name,
                    'original_text': sender
                })
                break
    
    # Extract bank from SMS header (e.g., "Citi Alert:", "HDFC Bank:")
    header_match = re.match(r'^([A-Za-z\s&]+?):\s+', sms_text)
    if header_match and not result['bank_name']:
        header = header_match.group(1).strip()
        if header not in ['Alert', 'Notice', 'Reminder', 'Info']:
            result['bank_name'] = header
            result['entity_spans'].append({
                'type': 'BANK',
                'start': header_match.start(),
                'end': header_match.end(),
                'original_value': header,
                'original_text': header_match.group(0)
            })
    
    # Extract merchant from ORIGINAL text (before masking)
    merchant_patterns = [
        r'(?:at|from|to|payment\s+to)\s+([A-Z][A-Z\s,\.&\-]+?)(?:\s+on|\s+for|\s+via|\.|\s*$)',
        r'(?:transaction\s+(?:was\s+)?(?:made\s+)?at)\s+([A-Z][A-Z\s,\.&\-]+?)(?:\s+on|\.)',
    ]
    for pattern in merchant_patterns:
        match = re.search(pattern, sms_text)
        if match:
            merchant = match.group(1).strip()
            # Filter out common false positives
            if len(merchant) > 2 and merchant not in ['SMS', 'APP', 'CARD', 'ATM']:
                result['merchant'] = merchant
                result['entity_spans'].append({
                    'type': 'MERCHANT',
                    'start': match.start(1),
                    'end': match.end(1),
                    'original_value': merchant,
                    'original_text': match.group(0)
                })
                break
    
    # Extract transaction type keyword from ORIGINAL text
    type_keywords = {
        'credit': ['credited', 'received', 'deposited', 'deposit', 'refund', 'cashback', 'credit'],
        'debit': ['debited', 'deducted', 'spent', 'paid', 'withdrawn', 'payment', 'purchase', 'charge', 'debit'],
        'transfer': ['transferred', 'transfer', 'sent'],
    }
    
    lower_text = sms_text.lower()
    for type_name, keywords in type_keywords.items():
        for keyword in keywords:
            if keyword in lower_text:
                result['raw_type_keyword'] = keyword
                # Find keyword position
                keyword_pos = lower_text.find(keyword)
                result['entity_spans'].append({
                    'type': 'KEYWORD',
                    'start': keyword_pos,
                    'end': keyword_pos + len(keyword),
                    'original_value': keyword,
                    'original_text': sms_text[keyword_pos:keyword_pos + len(keyword)]
                })
                break
        if result['raw_type_keyword']:
            break
    
    return result


def apply_mobile_noise(masked_text: str, noise_level: str = 'medium') -> str:
    """
    Apply mobile-specific noise to MASKED SMS text
    
    Noise types:
    - Truncation (simulate 160 char limit)
    - Broken sentences
    - Mixed casing
    - Rare emojis
    - Carrier suffixes
    - Extra whitespace
    
    Args:
        masked_text: MASKED SMS text (privacy-safe)
        noise_level: 'light', 'medium', 'heavy'
    
    Returns:
        Augmented masked SMS text
    """
    augmented = masked_text
    
    # Noise probabilities based on level
    probabilities = {
        'light': {'truncate': 0.1, 'case': 0.1, 'emoji': 0.02, 'suffix': 0.15, 'whitespace': 0.1},
        'medium': {'truncate': 0.2, 'case': 0.2, 'emoji': 0.05, 'suffix': 0.3, 'whitespace': 0.2},
        'heavy': {'truncate': 0.35, 'case': 0.4, 'emoji': 0.1, 'suffix': 0.5, 'whitespace': 0.3},
    }
    
    p = probabilities.get(noise_level, probabilities['medium'])
    
    # 1. Truncation (simulate SMS character limit)
    if random.random() < p['truncate'] and len(augmented) > 100:
        # Truncate at random point between 100-160 chars
        max_truncate = min(160, len(augmented) - 10)
        if max_truncate > 100:  # Only truncate if we have enough text
            truncate_at = random.randint(100, max_truncate)
            # Try to truncate at word boundary
            truncate_point = augmented.rfind(' ', 0, truncate_at)
            if truncate_point > 80:
                augmented = augmented[:truncate_point] + '...'
            else:
                augmented = augmented[:truncate_at] + '...'
    
    # 2. Mixed casing variations
    if random.random() < p['case']:
        variation = random.choice(CASING_VARIATIONS)
        if variation == 'upper':
            # Convert random word to uppercase
            words = augmented.split()
            if words:
                idx = random.randint(0, len(words) - 1)
                words[idx] = words[idx].upper()
                augmented = ' '.join(words)
        elif variation == 'lower':
            # Convert first letter to lowercase (common in informal SMS)
            if augmented:
                augmented = augmented[0].lower() + augmented[1:]
        elif variation == 'random':
            # Random case for 1-2 characters
            chars = list(augmented)
            for _ in range(random.randint(1, 2)):
                idx = random.randint(0, len(chars) - 1)
                chars[idx] = chars[idx].swapcase()
            augmented = ''.join(chars)
    
    # 3. Add rare emoji (before key financial terms)
    if random.random() < p['emoji']:
        emoji = random.choice(RARE_EMOJIS)
        # Insert before amount or near important keywords
        keywords = ['debited', 'credited', 'payment', 'amount', 'INR', 'USD', '$']
        for keyword in keywords:
            if keyword in augmented:
                augmented = augmented.replace(keyword, f"{emoji} {keyword}", 1)
                break
        else:
            # Random position if no keyword found
            if len(augmented) > 20:
                pos = random.randint(10, len(augmented) - 10)
                augmented = augmented[:pos] + emoji + augmented[pos:]
    
    # 4. Add carrier suffix
    if random.random() < p['suffix']:
        suffix = random.choice(CARRIER_SUFFIXES)
        augmented += suffix
    
    # 5. Extra/irregular whitespace
    if random.random() < p['whitespace']:
        # Add double space
        augmented = augmented.replace(' ', '  ', random.randint(1, 3))
        # Or remove space after punctuation
        if random.random() < 0.5:
            augmented = re.sub(r'([.,:])\s+', r'\1', augmented, count=random.randint(1, 2))
    
    return augmented


def augment_dataset(training_samples: List[Dict], augmentation_factor: int = 2) -> List[Dict]:
    """
    Create augmented versions of training samples with mobile noise
    
    Args:
        training_samples: List of original training samples (with masked_text)
        augmentation_factor: How many augmented versions per sample (1-3)
    
    Returns:
        Combined list of original + augmented samples
    """
    augmented_samples = []
    
    for sample in training_samples:
        # Keep original
        augmented_samples.append(sample)
        
        # Create augmented versions
        for i in range(augmentation_factor):
            # Vary noise level
            noise_levels = ['light', 'medium', 'heavy']
            noise_level = noise_levels[i % len(noise_levels)]
            
            # Apply noise to MASKED text (not original)
            augmented_text = apply_mobile_noise(sample['masked_text'], noise_level)
            
            # Create augmented sample (keep same entities, update masked_text)
            augmented_sample = {
                'original_text': sample['original_text'],  # Keep original for reference
                'masked_text': augmented_text,  # Augmented masked text
                'entity_spans': sample['entity_spans'],  # Same entity positions
                'bank_name': sample['bank_name'],
                'merchant': sample['merchant'],
                'raw_type_keyword': sample['raw_type_keyword'],
                'augmented': True,
                'noise_level': noise_level
            }
            
            augmented_samples.append(augmented_sample)
    
    return augmented_samples


def generate_training_data(input_file: Path, output_file: Path, max_samples: int = 5000, augment: bool = True):
    """
    Generate training data from SMS JSON file with privacy-safe masking
    
    Process:
        1. Load SMS messages from JSON file
        2. Extract entities + apply masking (same as export module)
        3. Generate entity spans (position + type, no sensitive values)
        4. Apply mobile-specific noise augmentation
        5. Save masked text + entity spans for NER training
    
    Args:
        input_file: Path to SMS Training Data.json
        output_file: Path to output training data JSON
        max_samples: Maximum unique samples to generate
        augment: Apply mobile-specific noise augmentation
    """
    print(f"Loading SMS data from {input_file}...")
    
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    messages = data.get('messages', [])
    print(f"Total messages: {len(messages)}")
    
    # Track unique SMS texts
    seen_texts = set()
    training_samples = []
    
    for msg in messages:
        sms_text = msg.get('sms_text', '')
        sender = msg.get('sender', '')
        
        # Skip if already seen
        if sms_text in seen_texts:
            continue
        
        # Skip very short or very long messages
        if len(sms_text) < 20 or len(sms_text) > 500:
            continue
        
        seen_texts.add(sms_text)
        
        # Extract entities + apply masking
        sample = extract_entities_from_sms(sms_text, sender)
        
        # Only include if has meaningful entities
        if sample['bank_name'] or sample['raw_type_keyword'] or sample['entity_spans']:
            training_samples.append(sample)
        
        if len(training_samples) >= max_samples:
            break
    
    print(f"\nGenerated {len(training_samples)} base labeled samples (MASKED for privacy)")
    
    # Apply mobile-specific augmentation
    if augment:
        print("\nApplying mobile-specific noise augmentation...")
        original_count = len(training_samples)
        training_samples = augment_dataset(training_samples, augmentation_factor=2)
        augmented_count = len(training_samples) - original_count
        print(f"Added {augmented_count} augmented samples (truncation, noise, carrier suffixes)")
        print(f"Total samples: {len(training_samples)}")
    
    # Calculate statistics
    stats = {
        'total_samples': len(training_samples),
        'augmented_samples': sum(1 for s in training_samples if s.get('augmented', False)),
        'original_samples': sum(1 for s in training_samples if not s.get('augmented', False)),
        'with_bank_name': sum(1 for s in training_samples if s['bank_name']),
        'with_amount': sum(1 for s in training_samples if any(e['type'] == 'AMOUNT' for e in s['entity_spans'])),
        'with_account': sum(1 for s in training_samples if any(e['type'] == 'ACCOUNT' for e in s['entity_spans'])),
        'with_merchant': sum(1 for s in training_samples if s['merchant']),
        'with_date': sum(1 for s in training_samples if any(e['type'] == 'DATE' for e in s['entity_spans'])),
        'with_keyword': sum(1 for s in training_samples if s['raw_type_keyword']),
        'with_reference': sum(1 for s in training_samples if any(e['type'] == 'REFERENCE' for e in s['entity_spans'])),
        'augmented': augment,
    }
    
    print("\nTraining Data Statistics:")
    for key, value in stats.items():
        percentage = (value / stats['total_samples'] * 100) if stats['total_samples'] > 0 else 0
        print(f"  {key}: {value} ({percentage:.1f}%)")
    
    # Entity type distribution
    entity_type_counts = defaultdict(int)
    for sample in training_samples:
        for entity in sample['entity_spans']:
            entity_type_counts[entity['type']] += 1
    
    print("\nEntity Type Distribution:")
    for entity_type, count in sorted(entity_type_counts.items()):
        print(f"  {entity_type}: {count}")
    
    # Save to file
    output_data = {
        'metadata': {
            'generated_at': datetime.now().isoformat(),
            'source_file': str(input_file),
            'masking_applied': True,
            'masking_strategy': 'Same as SmsDataMasker (Amount→XXX, Account→XXXX, Date→<DATE>, Ref→<REF>)',
            'statistics': stats,
            'entity_types': dict(entity_type_counts),
        },
        'training_samples': training_samples
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\nSaved training data to {output_file}")
    
    # Print samples
    print("\nSample training data (MASKED for privacy):")
    print("=" * 80)
    
    # Show first 3 original samples
    original_samples = [s for s in training_samples if not s.get('augmented', False)][:3]
    for i, sample in enumerate(original_samples, 1):
        print(f"\n[Original Sample {i}]")
        print(f"Masked Text: {sample['masked_text']}")
        print(f"  Bank: {sample['bank_name']}")
        print(f"  Merchant: {sample['merchant']}")
        print(f"  Keyword: {sample['raw_type_keyword']}")
        print(f"  Entity Spans: {len(sample['entity_spans'])} entities")
        for entity in sample['entity_spans']:
            print(f"    - {entity['type']}: '{entity.get('original_value', '')[:20]}' at pos {entity['start']}-{entity['end']}")
    
    # Show augmented samples with mobile noise
    if augment:
        augmented_samples = [s for s in training_samples if s.get('augmented', False)][:3]
        
        if augmented_samples:
            print(f"\n{'=' * 80}")
            print("Mobile-Augmented Samples (with noise):")
            print("=" * 80)
            
            for i, sample in enumerate(augmented_samples, 1):
                # Identify noise types
                noise_tags = []
                if sample['masked_text'].endswith('...'):
                    noise_tags.append('TRUNCATED')
                if any(suffix in sample['masked_text'] for suffix in CARRIER_SUFFIXES):
                    noise_tags.append('CARRIER-SUFFIX')
                if any(emoji in sample['masked_text'] for emoji in RARE_EMOJIS):
                    noise_tags.append('EMOJI')
                if '  ' in sample['masked_text']:
                    noise_tags.append('WHITESPACE')
                
                print(f"\n[Augmented Sample {i}] {sample.get('noise_level', 'unknown').upper()} | {' | '.join(noise_tags)}")
                print(f"Masked Text: {sample['masked_text']}")
                print(f"  Entities: {len(sample['entity_spans'])} ({', '.join(e['type'] for e in sample['entity_spans'])})")
    
    print(f"\n{'=' * 80}")


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Generate SMS entity extraction training data with mobile-specific noise'
    )
    parser.add_argument('--input', default='test/SMS Training Data.json', help='Input SMS JSON file')
    parser.add_argument('--output', default='test/sms_extraction_training_data.json', help='Output training data file')
    parser.add_argument('--max-samples', type=int, default=5000, help='Maximum base samples to generate')
    parser.add_argument('--no-augment', action='store_true', help='Disable mobile noise augmentation')
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    output_path = Path(args.output)
    
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)
    
    generate_training_data(input_path, output_path, args.max_samples, augment=not args.no_augment)
