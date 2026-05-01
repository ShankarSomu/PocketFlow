#!/usr/bin/env python3
"""
Parser Validation Script
Tests real SMS messages against expected classification to identify parser weaknesses.
"""

import json
import re
from collections import defaultdict
from typing import Dict, List, Tuple

def load_sms_data(filepath: str) -> List[Dict]:
    """Load SMS training data JSON."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
        return data['messages']

def expected_classification(text: str) -> Tuple[str, str]:
    """
    Determine what the parser SHOULD do with this message.
    Returns: (classification, reason)
    """
    text_lower = text.lower()
    
    # REJECT - Balance notifications
    balance_indicators = [
        'available balance',
        'balance is',
        'bal is',
        'current balance',
        'has a balance of',
    ]
    for indicator in balance_indicators:
        if indicator in text_lower:
            return ('REJECT', f'Balance notification: "{indicator}"')
    
    # Special case: "your balance" in marketing footer vs primary message
    # If message has transaction verbs AND "your balance", it's likely a transaction with marketing footer
    if 'your balance' in text_lower:
        # Check if this is a transaction notification with marketing footer
        transaction_indicators = [
            'payment posted',
            'transaction was made',
            'electronic draft',
            'direct deposit',
        ]
        has_transaction = any(ind in text_lower for ind in transaction_indicators)
        if not has_transaction:
            return ('REJECT', 'Balance notification: "your balance"')
    
    # REJECT - Future obligations (not actual transactions)
    if 'payment is due' in text_lower or 'due by' in text_lower or 'due on' in text_lower:
        return ('REJECT', 'Future obligation/due date')
    
    # REJECT - Alerts about limits (not transactions)
    if 'exceeded' in text_lower and 'amount set in' in text_lower:
        return ('REJECT', 'Exceeded limit alert')
    
    # REJECT - Statement ready notifications
    if 'statement' in text_lower and any(x in text_lower for x in ['ready', 'available', 'new statement']):
        return ('REJECT', 'Statement notification')
    
    # REJECT - Marketing/promotional
    if any(x in text_lower for x in ['click here', 'free up', 'offer', 'check it out']):
        return ('REJECT', 'Marketing/promotional')
    
    # ACCEPT - Direct indicators of actual transactions
    transaction_verbs = [
        'debited',
        'credited', 
        'withdrawn',
        'transaction was made',
        'purchase',
        'charged',
        'payment posted',
        'direct deposit',
        'refund',
        'electronic draft',
    ]
    
    for verb in transaction_verbs:
        if verb in text_lower:
            # But check for negative context
            if 'available' in text_lower or 'current balance' in text_lower:
                return ('REJECT', 'Transaction verb in balance context')
            return ('ACCEPT', f'Transaction verb: "{verb}"')
    
    # Default to uncertain
    return ('UNCERTAIN', 'No clear indicators')

def simulate_parser_step3(text: str) -> Tuple[str, str]:
    """
    Simulate the parser's Step 3 rule-based evaluation.
    This matches the logic in advanced_sms_parser.dart (UPDATED with phrase detection)
    """
    text_lower = text.lower()
    
    # Debit transaction phrases (matches updated Dart code)
    debit_phrases = [
        'transaction was made',
        'transaction at',
        'electronic draft',
        'payment posted',
        'purchase at',
        'charged at',
        'was deducted',
        'has been deducted',
    ]
    
    # Credit transaction phrases (matches updated Dart code)
    credit_phrases = [
        'direct deposit',
        'payment received',
        'deposit of',
        'credit of',
        'refund of',
    ]
    
    # Check debit phrases first (most specific)
    for phrase in debit_phrases:
        if phrase in text_lower:
            return ('ACCEPT', f'Debit phrase: "{phrase}"')
    
    # Check credit phrases
    for phrase in credit_phrases:
        if phrase in text_lower:
            return ('ACCEPT', f'Credit phrase: "{phrase}"')
    
    # Priority 1: Check for transaction action verbs (high confidence)
    transaction_verbs = [
        'debited', 'credited', 'spent', 'paid', 'withdrawn', 
        'deposited', 'transferred', 'received', 'charged',
        'purchase', 'refund', 'cashback'
    ]
    
    has_transaction_verb = any(verb in text_lower for verb in transaction_verbs)
    
    # Priority 2: Check for negative context (should reject)
    negative_context = [
        'available balance', 'current balance', 'balance is',
        'statement ready', 'statement available', 'payment is due',
        'due by', 'due on', 'statement for', 'minimum payment',
        'exceeded', 'limit'
    ]
    
    has_negative_context = any(ctx in text_lower for ctx in negative_context)
    
    # Decision logic (matching Step 3)
    if has_transaction_verb and not has_negative_context:
        return ('ACCEPT', 'Transaction verb without negative context')
    
    if has_negative_context:
        return ('REJECT', 'Negative context detected')
    
    # Check for amount patterns (weak indicator)
    amount_pattern = r'[\$₹€£¥]\s*\d+(?:,\d{3})*(?:\.\d{2})?'
    has_amount = re.search(amount_pattern, text) is not None
    
    if has_amount and not has_negative_context:
        return ('UNCERTAIN', 'Has amount but no clear transaction verb')
    
    return ('REJECT', 'No transaction indicators')

def analyze_parser_accuracy():
    """Main validation function."""
    print("=" * 80)
    print("PARSER VALIDATION REPORT")
    print("=" * 80)
    print()
    
    messages = load_sms_data('SMS Training Data.json')
    
    # Sample analysis (first 1000 messages for speed)
    sample_size = min(1000, len(messages))
    sample = messages[:sample_size]
    
    print(f"📊 Analyzing {sample_size:,} messages (sample from {len(messages):,} total)")
    print()
    
    results = {
        'correct_accept': [],
        'correct_reject': [],
        'false_positive': [],  # Parser accepts, should reject
        'false_negative': [],  # Parser rejects, should accept
        'uncertain': [],
    }
    
    for msg in sample:
        text = msg['sms_text']
        expected, expected_reason = expected_classification(text)
        parser_result, parser_reason = simulate_parser_step3(text)
        
        if expected == 'UNCERTAIN':
            results['uncertain'].append({
                'text': text[:100],
                'parser': parser_result,
            })
            continue
        
        if expected == 'ACCEPT' and parser_result == 'ACCEPT':
            results['correct_accept'].append(text[:100])
        elif expected == 'REJECT' and parser_result == 'REJECT':
            results['correct_reject'].append(text[:100])
        elif expected == 'REJECT' and parser_result == 'ACCEPT':
            results['false_positive'].append({
                'text': text[:100],
                'reason': expected_reason,
            })
        elif expected == 'ACCEPT' and parser_result == 'REJECT':
            results['false_negative'].append({
                'text': text[:100],
                'reason': expected_reason,
            })
    
    # Calculate accuracy
    total_classified = sample_size - len(results['uncertain'])
    correct = len(results['correct_accept']) + len(results['correct_reject'])
    incorrect = len(results['false_positive']) + len(results['false_negative'])
    
    accuracy = (correct / total_classified * 100) if total_classified > 0 else 0
    
    print("-" * 80)
    print("OVERALL ACCURACY")
    print("-" * 80)
    print(f"✅ Correct classifications: {correct:,} ({accuracy:.1f}%)")
    print(f"❌ Incorrect classifications: {incorrect:,} ({100-accuracy:.1f}%)")
    print(f"❓ Uncertain: {len(results['uncertain']):,}")
    print()
    
    print("-" * 80)
    print("BREAKDOWN")
    print("-" * 80)
    print(f"✅ Correct ACCEPT (true positives):  {len(results['correct_accept']):,}")
    print(f"✅ Correct REJECT (true negatives):  {len(results['correct_reject']):,}")
    print(f"❌ FALSE POSITIVES (accepted but should reject): {len(results['false_positive']):,}")
    print(f"❌ FALSE NEGATIVES (rejected but should accept): {len(results['false_negative']):,}")
    print()
    
    # Show examples of errors
    if results['false_positive']:
        print("-" * 80)
        print("🚨 FALSE POSITIVES (Parser incorrectly ACCEPTS these)")
        print("-" * 80)
        for i, item in enumerate(results['false_positive'][:10], 1):
            print(f"\n{i}. {item['text']}")
            print(f"   Reason should reject: {item['reason']}")
    
    if results['false_negative']:
        print()
        print("-" * 80)
        print("🚨 FALSE NEGATIVES (Parser incorrectly REJECTS these)")
        print("-" * 80)
        for i, item in enumerate(results['false_negative'][:10], 1):
            print(f"\n{i}. {item['text']}")
            print(f"   Reason should accept: {item['reason']}")
    
    print()
    print("=" * 80)
    print("RECOMMENDATIONS FOR PARSER IMPROVEMENTS")
    print("=" * 80)
    
    # Analyze false positives for patterns
    if results['false_positive']:
        print("\n🔧 Add these to NEGATIVE CONTEXT detection:")
        negative_patterns = defaultdict(int)
        for item in results['false_positive']:
            text_lower = item['text'].lower()
            if 'balance' in text_lower:
                negative_patterns['balance notifications'] += 1
            if 'exceeded' in text_lower:
                negative_patterns['exceeded alerts'] += 1
            if 'statement' in text_lower:
                negative_patterns['statement notifications'] += 1
        
        for pattern, count in sorted(negative_patterns.items(), key=lambda x: -x[1]):
            print(f"   - {pattern}: {count} cases")
    
    # Analyze false negatives for patterns
    if results['false_negative']:
        print("\n🔧 Add these to TRANSACTION VERB detection:")
        verb_patterns = defaultdict(int)
        for item in results['false_negative']:
            text_lower = item['text'].lower()
            if 'posted' in text_lower:
                verb_patterns['payment posted'] += 1
            if 'deposit' in text_lower:
                verb_patterns['deposit'] += 1
            if 'draft' in text_lower:
                verb_patterns['electronic draft'] += 1
        
        for pattern, count in sorted(verb_patterns.items(), key=lambda x: -x[1]):
            print(f"   - {pattern}: {count} cases")
    
    print()
    print("=" * 80)

if __name__ == '__main__':
    analyze_parser_accuracy()
