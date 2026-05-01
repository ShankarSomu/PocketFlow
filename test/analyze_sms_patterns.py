#!/usr/bin/env python3
"""
SMS Parser Success Rate Analysis
Analyzes exported SMS data to understand message patterns and parser coverage.
"""

import json
import re
from collections import Counter, defaultdict
from typing import Dict, List, Tuple

def load_sms_data(filepath: str) -> Dict:
    """Load SMS training data JSON."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def classify_message_type(text: str) -> str:
    """Classify SMS message into categories."""
    text_lower = text.lower()
    
    # Transaction indicators (debit/charge/purchase)
    if any(word in text_lower for word in ['transaction', 'made at', 'purchase', 'charged']):
        return 'TRANSACTION'
    
    # Credits/deposits
    if any(word in text_lower for word in ['credited', 'deposit', 'refund', 'cashback']):
        return 'CREDIT'
    
    # Payments
    if 'payment' in text_lower and ('posted' in text_lower or 'received' in text_lower):
        return 'PAYMENT'
    
    # Balance notifications
    if any(word in text_lower for word in ['balance', 'bal is', 'available balance']):
        return 'BALANCE'
    
    # Alerts (exceeded limits, etc.)
    if 'exceeded' in text_lower or 'alert' in text_lower.split(':')[0]:
        return 'ALERT'
    
    # Marketing/promotional
    if any(word in text_lower for word in ['free', 'offer', 'promo', 'click here', 'https://']):
        return 'MARKETING'
    
    # Withdrawal/ATM
    if any(word in text_lower for word in ['withdrawn', 'atm', 'cash']):
        return 'WITHDRAWAL'
    
    return 'OTHER'

def extract_sender_pattern(sender: str) -> str:
    """Group senders into banks/services."""
    # Map sender IDs to known services
    sender_map = {
        '692484': 'Citi',
        '227898': 'Capital One',
        '692632': 'Bank of America',
        '58397': 'Flex',
    }
    
    return sender_map.get(sender, f'Unknown ({sender})')

def create_message_template(text: str) -> str:
    """Create a template by replacing masked values with placeholders."""
    # Already masked, so just normalize merchant names and specific text
    template = text
    
    # Replace merchant names with [MERCHANT]
    template = re.sub(r'at [A-Z][A-Z0-9\s\.\-]+(?:on|View|\.|,)', 'at [MERCHANT] ', template)
    
    # Normalize URLs
    template = re.sub(r'https?://[^\s]+', '[URL]', template)
    
    # Normalize account numbers that weren't caught
    template = re.sub(r'\d{4}', 'XXXX', template)
    
    return template.strip()

def analyze_sms_dataset(filepath: str):
    """Main analysis function."""
    print("=" * 80)
    print("SMS PARSER SUCCESS RATE ANALYSIS")
    print("=" * 80)
    print()
    
    # Load data
    data = load_sms_data(filepath)
    messages = data['messages']
    total_count = len(messages)
    
    print(f"📊 Total Messages: {total_count:,}")
    print(f"📅 Export Date: {data['export_info']['export_date']}")
    print(f"🔒 Masked: {data['export_info']['masked']}")
    print()
    
    # Analyze message types
    print("-" * 80)
    print("MESSAGE TYPE DISTRIBUTION")
    print("-" * 80)
    
    type_counter = Counter()
    sender_counter = Counter()
    masking_stats = defaultdict(lambda: {'amounts': 0, 'accounts': 0, 'dates': 0, 'refs': 0})
    
    for msg in messages:
        msg_type = classify_message_type(msg['sms_text'])
        type_counter[msg_type] += 1
        
        sender = extract_sender_pattern(msg['sender'])
        sender_counter[sender] += 1
        
        # Aggregate masking stats
        summary = msg['masking_summary']
        masking_stats[msg_type]['amounts'] += summary['amounts_masked']
        masking_stats[msg_type]['accounts'] += summary['accounts_masked']
        masking_stats[msg_type]['dates'] += summary['dates_masked']
        masking_stats[msg_type]['refs'] += summary['references_masked']
    
    for msg_type, count in type_counter.most_common():
        percentage = (count / total_count) * 100
        print(f"{msg_type:20} {count:6,} ({percentage:5.2f}%)")
    
    print()
    print("-" * 80)
    print("SENDER DISTRIBUTION (Top 10)")
    print("-" * 80)
    
    for sender, count in sender_counter.most_common(10):
        percentage = (count / total_count) * 100
        print(f"{sender:30} {count:6,} ({percentage:5.2f}%)")
    
    print()
    print("-" * 80)
    print("MASKING EFFECTIVENESS BY MESSAGE TYPE")
    print("-" * 80)
    
    for msg_type in type_counter.most_common():
        msg_type_name = msg_type[0]
        stats = masking_stats[msg_type_name]
        count = type_counter[msg_type_name]
        
        avg_amounts = stats['amounts'] / count if count > 0 else 0
        avg_accounts = stats['accounts'] / count if count > 0 else 0
        avg_dates = stats['dates'] / count if count > 0 else 0
        avg_refs = stats['refs'] / count if count > 0 else 0
        
        print(f"\n{msg_type_name}:")
        print(f"  Avg amounts masked:  {avg_amounts:.2f}")
        print(f"  Avg accounts masked: {avg_accounts:.2f}")
        print(f"  Avg dates masked:    {avg_dates:.2f}")
        print(f"  Avg refs masked:     {avg_refs:.2f}")
    
    # Find common message templates
    print()
    print("-" * 80)
    print("COMMON MESSAGE TEMPLATES (Top 20)")
    print("-" * 80)
    
    template_counter = Counter()
    for msg in messages:
        template = create_message_template(msg['sms_text'])
        template_counter[template] += 1
    
    for template, count in template_counter.most_common(20):
        percentage = (count / total_count) * 100
        # Truncate long templates
        display_template = template[:100] + '...' if len(template) > 100 else template
        print(f"\n[{count:4,} msgs, {percentage:5.2f}%]")
        print(f"  {display_template}")
    
    # Parser insights
    print()
    print("=" * 80)
    print("PARSER INSIGHTS & RECOMMENDATIONS")
    print("=" * 80)
    
    transaction_count = type_counter['TRANSACTION']
    credit_count = type_counter['CREDIT']
    balance_count = type_counter['BALANCE']
    payment_count = type_counter['PAYMENT']
    
    print()
    print("✅ TRANSACTION MESSAGES (Should be parsed as transactions):")
    print(f"   {transaction_count:,} messages ({(transaction_count/total_count)*100:.1f}%)")
    print("   These should create transaction records in your app.")
    
    print()
    print("✅ CREDIT MESSAGES (Should be parsed as income):")
    print(f"   {credit_count:,} messages ({(credit_count/total_count)*100:.1f}%)")
    print("   These should create income transaction records.")
    
    print()
    print("❌ BALANCE NOTIFICATIONS (Should NOT create transactions):")
    print(f"   {balance_count:,} messages ({(balance_count/total_count)*100:.1f}%)")
    print("   Your parser should identify and SKIP these.")
    
    print()
    print("✅ PAYMENT MESSAGES (Should be parsed as payments):")
    print(f"   {payment_count:,} messages ({(payment_count/total_count)*100:.1f}%)")
    print("   These should create payment transaction records.")
    
    print()
    print("🎯 RECOMMENDED PARSER TESTS:")
    print(f"   - Test all {len(sender_counter)} unique senders")
    print(f"   - Test all {len(type_counter)} message type classifications")
    print(f"   - Test top 20 message templates (covers ~{sum(c for _, c in template_counter.most_common(20))/total_count*100:.1f}% of messages)")
    
    print()
    print("=" * 80)

if __name__ == '__main__':
    analyze_sms_dataset('SMS Training Data.json')
