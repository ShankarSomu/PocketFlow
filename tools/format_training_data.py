#!/usr/bin/env python3
"""
SMS Parser LLM Training Data Formatter

Converts PocketFlow JSONL training data into format suitable for:
1. Text classification (transaction vs non-transaction)
2. Named Entity Recognition (NER) for field extraction
3. Multi-task learning (all fields at once)

Input Format (train.jsonl):
{
  "text": "Citi Alert: A $8.00 transaction was made at WASH LAUNDRY...",
  "bank_name": "Citi",
  "amount": "8.00",
  "account_number": "3530",
  "merchant": "WASH LAUNDRY WAVERID",
  "date": "2026-04-17",
  "raw_type_keyword": "made"
}

Output Format (for training):
{
  "input_text": "[SMS] Citi Alert: A $8.00 transaction was made at WASH LAUNDRY... [SENDER] Citi",
  "output_json": {
    "is_transaction": true,
    "type": "debit",
    "amount": "8.00",
    "currency": "$",
    "bank_name": "Citi",
    "account_id": "3530",
    "merchant": "WASH LAUNDRY WAVERID",
    "date": "2026-04-17",
    "region": "US",
    "confidence": 1.0,
    "reasoning": "Transaction keyword 'made' indicates debit transaction"
  }
}
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime


class SmsTrainingDataFormatter:
    """Format SMS data for LLM training"""
    
    # Transaction type keywords mapping
    TYPE_KEYWORDS = {
        'debit': [
            'debited', 'debit', 'withdrawn', 'withdrawal', 'charged',
            'purchase', 'made', 'spent', 'paid', 'payment', 'used',
            'posted to', 'electronic draft', 'ach debit', 'autopay'
        ],
        'credit': [
            'credited', 'credit', 'deposited', 'deposit', 'received',
            'refund', 'cashback', 'reward', 'direct deposit'
        ],
    }
    
    # Non-transaction patterns (balance alerts, reminders, etc.)
    NON_TRANSACTION_PATTERNS = [
        r'balance\s+(?:is|:)',
        r'available\s+balance',
        r'current\s+balance',
        r'exceeded\s+amount\s+set',
        r'due\s+date',
        r'payment\s+due',
        r'statement\s+available',
        r'reminder',
        r'alert\s+preference',
    ]
    
    def __init__(self, input_jsonl: str, output_jsonl: str):
        self.input_path = Path(input_jsonl)
        self.output_path = Path(output_jsonl)
        
    def format_all(self) -> Dict[str, int]:
        """Format all records in the input file"""
        stats = {
            'total': 0,
            'transactions': 0,
            'non_transactions': 0,
            'debit': 0,
            'credit': 0,
            'unknown_type': 0,
        }
        
        with open(self.input_path, 'r', encoding='utf-8') as infile, \
             open(self.output_path, 'w', encoding='utf-8') as outfile:
            
            for line_num, line in enumerate(infile, 1):
                try:
                    record = json.loads(line.strip())
                    formatted = self.format_record(record)
                    
                    # Write formatted record
                    outfile.write(json.dumps(formatted, ensure_ascii=False) + '\n')
                    
                    # Update stats
                    stats['total'] += 1
                    if formatted['output_json']['is_transaction']:
                        stats['transactions'] += 1
                        trans_type = formatted['output_json']['type']
                        if trans_type in stats:
                            stats[trans_type] += 1
                    else:
                        stats['non_transactions'] += 1
                        
                except Exception as e:
                    print(f"Error on line {line_num}: {e}")
                    continue
        
        return stats
    
    def format_record(self, record: Dict) -> Dict:
        """Format a single record"""
        text = record.get('text', '')
        sender = self._extract_sender(text)
        
        # Determine if this is a transaction
        is_transaction = self._is_transaction(record)
        
        if not is_transaction:
            # Non-transaction (balance alert, reminder, etc.)
            return {
                'input_text': f"[SMS] {text} [SENDER] {sender}",
                'output_json': {
                    'is_transaction': False,
                    'type': 'unknown',
                    'amount': None,
                    'currency': None,
                    'bank_name': record.get('bank_name'),
                    'account_id': None,
                    'merchant': None,
                    'date': None,
                    'region': self._detect_region(text),
                    'confidence': 1.0,
                    'reasoning': 'Balance alert or notification',
                }
            }
        
        # Extract all fields
        transaction_type = self._determine_type(record)
        amount = self._normalize_amount(record.get('amount'))
        currency = self._detect_currency(text)
        region = self._detect_region(text)
        
        # Generate reasoning
        reasoning = self._generate_reasoning(record, transaction_type)
        
        return {
            'input_text': f"[SMS] {text} [SENDER] {sender}",
            'output_json': {
                'is_transaction': True,
                'type': transaction_type,
                'amount': amount,
                'currency': currency,
                'bank_name': record.get('bank_name'),
                'account_id': record.get('account_number'),
                'merchant': record.get('merchant'),
                'date': record.get('date'),
                'region': region,
                'confidence': 1.0,  # Training data is ground truth
                'reasoning': reasoning,
            }
        }
    
    def _is_transaction(self, record: Dict) -> bool:
        """Determine if record is a transaction"""
        text = record.get('text', '').lower()
        
        # Check for non-transaction patterns
        for pattern in self.NON_TRANSACTION_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                # But if it also has an amount and merchant, it might be a transaction
                if record.get('amount') and record.get('merchant'):
                    continue
                return False
        
        # Must have amount to be a transaction
        if not record.get('amount'):
            return False
        
        return True
    
    def _determine_type(self, record: Dict) -> str:
        """Determine transaction type"""
        text = record.get('text', '').lower()
        keyword = record.get('raw_type_keyword', '').lower()
        
        # Check keyword first
        for trans_type, keywords in self.TYPE_KEYWORDS.items():
            if keyword in keywords or any(kw in text for kw in keywords):
                return trans_type
        
        # Special cases
        if 'payment posted to' in text or 'electronic draft' in text:
            return 'debit'  # Credit card payment or bill payment
        
        if 'direct deposit' in text:
            return 'credit'  # Incoming money
        
        return 'unknown'
    
    def _normalize_amount(self, amount: Optional[str]) -> Optional[str]:
        """Normalize amount to decimal format"""
        if not amount:
            return None
        
        # Remove currency symbols and commas
        amount_str = str(amount).replace(',', '').replace('$', '').replace('₹', '')
        
        try:
            # Convert to float and format to 2 decimals
            amount_float = float(amount_str)
            return f"{amount_float:.2f}"
        except ValueError:
            return amount_str
    
    def _detect_currency(self, text: str) -> str:
        """Detect currency from text"""
        if '₹' in text or 'INR' in text.upper() or 'RS.' in text.upper():
            return '₹'
        elif '$' in text or 'USD' in text.upper():
            return '$'
        elif '€' in text or 'EUR' in text.upper():
            return '€'
        elif '£' in text or 'GBP' in text.upper():
            return '£'
        else:
            return '$'  # Default to USD
    
    def _detect_region(self, text: str) -> str:
        """Detect region from SMS content"""
        text_lower = text.lower()
        
        # India indicators
        india_indicators = ['₹', 'inr', 'upi', 'neft', 'imps', 'rtgs', 'paytm', 
                           'phonepe', 'gpay', 'hdfc', 'icici', 'sbi', 'axis']
        if any(ind in text_lower for ind in india_indicators):
            return 'INDIA'
        
        # US indicators
        us_indicators = ['$', 'usd', 'ach', 'check', 'routing', 'chase', 
                        'bofa', 'wells fargo', 'citi', 'capital one']
        if any(ind in text_lower for ind in us_indicators):
            return 'US'
        
        return 'UNKNOWN'
    
    def _extract_sender(self, text: str) -> str:
        """Extract sender from SMS header or assume from bank name"""
        # Check for header pattern "Bank: message"
        header_match = re.match(r'^([A-Za-z\s&]+?):\s+', text)
        if header_match:
            return header_match.group(1).strip()
        
        # Look for common bank names
        banks = ['Citi', 'BofA', 'Chase', 'Capital One', 'Wells Fargo', 
                'HDFC', 'ICICI', 'SBI', 'Axis', 'American Express']
        for bank in banks:
            if bank.lower() in text.lower():
                return bank
        
        return 'UNKNOWN'
    
    def _generate_reasoning(self, record: Dict, trans_type: str) -> str:
        """Generate explanation for the classification"""
        keyword = record.get('raw_type_keyword', '')
        
        if trans_type == 'debit':
            if 'payment posted to' in record.get('text', '').lower():
                return f"'payment posted to' indicates credit card bill payment (debit)"
            elif keyword in ['made', 'charged', 'used']:
                return f"Keyword '{keyword}' indicates money spent (debit transaction)"
            elif keyword in ['debited', 'withdrawn']:
                return f"Keyword '{keyword}' directly indicates debit transaction"
            else:
                return "Transaction involves money leaving the account (debit)"
        
        elif trans_type == 'credit':
            if keyword in ['credited', 'deposited']:
                return f"Keyword '{keyword}' directly indicates credit transaction"
            elif 'direct deposit' in record.get('text', '').lower():
                return "Direct deposit indicates incoming money (credit)"
            else:
                return "Transaction involves money entering the account (credit)"
        
        else:
            return f"Transaction type unclear, keyword: '{keyword}'"


def main():
    """Process all training files"""
    files_to_process = [
        ('train.jsonl', 'train_formatted.jsonl'),
        ('dev.jsonl', 'dev_formatted.jsonl'),
        ('test.jsonl', 'test_formatted.jsonl'),
    ]
    
    total_stats = {
        'total': 0,
        'transactions': 0,
        'non_transactions': 0,
        'debit': 0,
        'credit': 0,
    }
    
    for input_file, output_file in files_to_process:
        input_path = Path(input_file)
        if not input_path.exists():
            print(f"⏭️  Skipping {input_file} (not found)")
            continue
        
        print(f"\n📄 Processing {input_file}...")
        formatter = SmsTrainingDataFormatter(input_file, output_file)
        stats = formatter.format_all()
        
        print(f"✅ {output_file}:")
        print(f"   Total: {stats['total']}")
        print(f"   Transactions: {stats['transactions']} ({stats['transactions']/stats['total']*100:.1f}%)")
        print(f"   - Debit: {stats['debit']}")
        print(f"   - Credit: {stats['credit']}")
        print(f"   - Unknown: {stats['unknown_type']}")
        print(f"   Non-transactions: {stats['non_transactions']}")
        
        # Add to totals
        for key in total_stats:
            total_stats[key] += stats.get(key, 0)
    
    print(f"\n" + "="*50)
    print(f"📊 TOTAL STATISTICS:")
    print(f"   Total records: {total_stats['total']}")
    print(f"   Transactions: {total_stats['transactions']} ({total_stats['transactions']/total_stats['total']*100:.1f}%)")
    print(f"   - Debit: {total_stats['debit']}")
    print(f"   - Credit: {total_stats['credit']}")
    print(f"   Non-transactions: {total_stats['non_transactions']}")
    print("="*50)


if __name__ == '__main__':
    main()
