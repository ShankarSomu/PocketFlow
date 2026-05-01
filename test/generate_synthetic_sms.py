#!/usr/bin/env python3
"""
Synthetic SMS Data Generator
Expands 400 real transaction messages into 10,000+ training examples
"""

import json
import random
import re
from typing import List, Dict, Tuple
from collections import defaultdict

class SyntheticSmsGenerator:
    def __init__(self, input_file: str):
        """Load real SMS data and extract patterns"""
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            self.messages = data['messages']
        
        # Filter for actual transactions only
        from validate_parser import expected_classification
        self.transactions = []
        self.non_transactions = []
        
        for msg in self.messages:
            classification, _ = expected_classification(msg['sms_text'])
            if classification == 'ACCEPT':
                self.transactions.append(msg['sms_text'])
            else:
                self.non_transactions.append(msg['sms_text'])
        
        print(f"Loaded {len(self.transactions)} transactions, {len(self.non_transactions)} non-transactions")
        
        # Augmentation resources
        self.init_augmentation_resources()
    
    def init_augmentation_resources(self):
        """Initialize synonym dictionaries and variations"""
        
        # Transaction verbs (maintain meaning)
        self.verb_synonyms = {
            'debited': ['debited', 'deducted', 'withdrawn', 'charged', 'debit of'],
            'credited': ['credited', 'deposited', 'added', 'credit of', 'received'],
            'spent': ['spent', 'paid', 'used'],
            'transaction was made': ['transaction was made', 'transaction at', 'purchase at', 'charge at'],
            'electronic draft': ['electronic draft', 'e-draft', 'draft payment'],
            'payment posted': ['payment posted', 'payment processed', 'payment of'],
            'direct deposit': ['direct deposit', 'deposit', 'DD'],
            'purchase': ['purchase', 'transaction', 'payment'],
            'withdrawal': ['withdrawal', 'cash withdrawal', 'ATM withdrawal'],
        }
        
        # Bank name variations
        self.bank_variants = {
            'citi': ['Citi', 'CITI', 'Citibank', 'CITIBANK', 'Citi Bank'],
            'bofa': ['BofA', 'BOFA', 'Bank of America', 'BankAmericard'],
            'capitalone': ['Capital One', 'CapitalOne', 'CAPITAL ONE', 'Cap1', 'CapOne'],
            'chase': ['Chase', 'CHASE', 'Chase Bank', 'JP Morgan Chase'],
            'wells': ['Wells Fargo', 'WellsFargo', 'WELLS FARGO', 'Wells'],
            'discover': ['Discover', 'DISCOVER', 'Discover Card'],
            'amex': ['AmEx', 'AMEX', 'American Express', 'Amex'],
            'usbank': ['US Bank', 'U.S. Bank', 'USBANK', 'US BANK'],
        }
        
        # Currency variations
        self.currency_formats = {
            'usd': ['$XX.XX', '$X,XXX.XX', 'USD XX.XX', 'XX.XX USD', '$XX'],
            'inr': ['Rs.XX.XX', 'Rs.X,XXX.XX', 'INR XX.XX', 'XX.XX INR', 'Rs XX'],
        }
        
        # Account patterns
        self.account_patterns = [
            'ending in XXXX',
            'ending XXXX',
            'ending with XXXX',
            'acct XXXX',
            'account XXXX',
            'a/c XXXX',
            'card XXXX',
            'XXXX',
        ]
        
        # Date patterns
        self.date_patterns = [
            'MM/DD/YYYY',
            'DD/MM/YYYY',
            'DD-MM-YYYY',
            'on MM/DD/YYYY',
            'MM-DD-YYYY',
        ]
        
        # Merchant names (generic, realistic)
        self.merchants = [
            'AMAZON', 'AMAZON.COM', 'WALMART', 'TARGET', 'COSTCO',
            'STARBUCKS', 'MCDONALDS', 'UBER', 'UBER EATS', 'DOORDASH',
            'NETFLIX', 'SPOTIFY', 'APPLE.COM', 'GOOGLE', 'MICROSOFT',
            'SHELL', 'CHEVRON', 'BP', '7-ELEVEN', 'CVS',
            'WHOLE FOODS', 'TRADER JOE', 'SAFEWAY', 'KROGER',
            'HOME DEPOT', 'LOWES', 'BEST BUY', 'EBAY',
            'ATT', 'VERIZON', 'T-MOBILE', 'COMCAST',
            'MARRIOTT', 'HILTON', 'DELTA', 'UNITED',
        ]
        
        # Message structure templates (extracted from real messages)
        self.templates = {
            'citi_transaction': [
                "Citi Alert: A {amount} transaction was made at {merchant} on card ending in {account}",
                "Citi Alert: A {amount} transaction was made at {merchant} on {date}",
                "{bank}: A {amount} purchase at {merchant} on card {account}",
            ],
            'bofa_draft': [
                "BofA: Electronic draft of {amount} for {merchant} was deducted on {date}",
                "{bank}: E-draft {amount} for {merchant} on {date}",
                "BofA alerts: Draft payment {amount} to {merchant} processed",
            ],
            'payment_posted': [
                "Citi Alert: A {amount} payment posted to acct ending in {account} on {date}",
                "{bank}: Payment of {amount} posted on {date}",
                "{bank}: {amount} payment processed to account {account}",
            ],
            'direct_deposit': [
                "BofA: Direct deposit of {amount} credited to account ending in {account} on {date}",
                "{bank}: DD {amount} credited on {date}",
                "{bank}: Deposit {amount} received to acct {account}",
            ],
            'debit_simple': [
                "{amount} debited from A/c {account} at {merchant}. {bank}",
                "{bank}: {amount} debited from card {account} at {merchant}",
                "Your account {account} was debited {amount} for {merchant}. {bank}",
            ],
            'credit_simple': [
                "{amount} credited to A/c {account}. {bank}",
                "{bank}: {amount} credited to account {account}",
                "Your account {account} credited {amount} on {date}",
            ],
            'purchase': [
                "Purchase of {amount} at {merchant} using card {account}",
                "{bank}: Your card {account} was charged {amount} at {merchant}",
                "{amount} spent on {bank} card {account} at {merchant} on {date}",
            ],
        }
    
    def augment_transaction(self, sms_text: str) -> List[str]:
        """Generate variations of a single transaction SMS"""
        variations = [sms_text]  # Include original
        
        # Technique 1: Synonym replacement
        variations.extend(self._synonym_replacement(sms_text, num_variations=3))
        
        # Technique 2: Bank name variation
        variations.extend(self._bank_variation(sms_text, num_variations=2))
        
        # Technique 3: Format variation (amounts, dates, accounts)
        variations.extend(self._format_variation(sms_text, num_variations=2))
        
        # Technique 4: Word order permutation
        variations.extend(self._word_order_variation(sms_text, num_variations=2))
        
        # Technique 5: Optional word deletion/insertion
        variations.extend(self._optional_words_variation(sms_text, num_variations=2))
        
        # Remove duplicates
        return list(set(variations))
    
    def _synonym_replacement(self, text: str, num_variations: int = 3) -> List[str]:
        """Replace verbs with synonyms"""
        variations = []
        lower_text = text.lower()
        
        for _ in range(num_variations):
            new_text = text
            for original, synonyms in self.verb_synonyms.items():
                if original in lower_text:
                    synonym = random.choice(synonyms)
                    # Preserve case
                    if original.upper() in text:
                        synonym = synonym.upper()
                    elif original.capitalize() in text:
                        synonym = synonym.capitalize()
                    
                    new_text = re.sub(
                        re.escape(original), 
                        synonym, 
                        new_text, 
                        count=1, 
                        flags=re.IGNORECASE
                    )
            
            if new_text != text:
                variations.append(new_text)
        
        return variations
    
    def _bank_variation(self, text: str, num_variations: int = 2) -> List[str]:
        """Replace bank names with variants"""
        variations = []
        lower_text = text.lower()
        
        for _ in range(num_variations):
            new_text = text
            for bank_key, variants in self.bank_variants.items():
                for variant in variants:
                    if variant.lower() in lower_text:
                        new_variant = random.choice([v for v in variants if v != variant])
                        new_text = new_text.replace(variant, new_variant)
                        break
            
            if new_text != text:
                variations.append(new_text)
        
        return variations
    
    def _format_variation(self, text: str, num_variations: int = 2) -> List[str]:
        """Vary formatting of amounts, dates, accounts"""
        variations = []
        
        for _ in range(num_variations):
            new_text = text
            
            # Vary amount format: $XX.XX → $XX or XX.XX USD
            if '$X' in new_text:
                if random.random() > 0.5:
                    new_text = new_text.replace('$X,XXX.XX', '$X,XXX')
                    new_text = new_text.replace('$XX.XX', '$XX')
            
            # Vary account format
            account_patterns = ['ending in XXXX', 'ending XXXX', 'acct XXXX', 'card XXXX']
            for i, pattern in enumerate(account_patterns):
                if pattern in new_text and random.random() > 0.5:
                    new_pattern = account_patterns[(i + 1) % len(account_patterns)]
                    new_text = new_text.replace(pattern, new_pattern)
            
            # Vary date format
            if 'MM/DD/YYYY' in new_text and random.random() > 0.5:
                new_text = new_text.replace('MM/DD/YYYY', 'DD/MM/YYYY')
            
            if new_text != text:
                variations.append(new_text)
        
        return variations
    
    def _word_order_variation(self, text: str, num_variations: int = 2) -> List[str]:
        """Reorder sentence components"""
        variations = []
        
        # Pattern: "A $XX.XX transaction was made at MERCHANT on card XXXX"
        # → "$XX.XX charged at MERCHANT on card XXXX"
        # → "Card XXXX charged $XX.XX at MERCHANT"
        
        match = re.search(r'(\$[X,\.]+)\s+transaction was made at ([A-Z\s,\.]+?)\s+on card ending in (X+)', text)
        if match:
            amount, merchant, account = match.groups()
            variations.extend([
                f"{amount} charged at {merchant.strip()} on card ending in {account}",
                f"Card ending in {account} charged {amount} at {merchant.strip()}",
            ][:num_variations])
        
        return variations
    
    def _optional_words_variation(self, text: str, num_variations: int = 2) -> List[str]:
        """Add or remove optional words"""
        variations = []
        
        optional_removals = [
            ('Alert: ', ''),
            ('alerts: ', ''),
            ('Your ', ''),
            (' Please note.', ''),
            (' View your balance.*', ''),
        ]
        
        optional_additions = [
            ('debited', 'was debited'),
            ('credited', 'has been credited'),
            ('charged', 'was charged'),
        ]
        
        for _ in range(num_variations):
            new_text = text
            
            # 50% chance to remove optional words
            if random.random() > 0.5:
                for old, new in optional_removals:
                    new_text = re.sub(old, new, new_text)
            
            # 50% chance to add optional words
            if random.random() > 0.5:
                for old, new in optional_additions:
                    if old in new_text.lower():
                        new_text = re.sub(re.escape(old), new, new_text, count=1, flags=re.IGNORECASE)
            
            if new_text != text:
                variations.append(new_text)
        
        return variations
    
    def generate_from_template(self, num_samples: int = 1000) -> List[Dict]:
        """Generate completely synthetic messages from templates"""
        synthetic = []
        
        for _ in range(num_samples):
            # Choose random template category
            category = random.choice(list(self.templates.keys()))
            template = random.choice(self.templates[category])
            
            # Fill in placeholders
            amount = random.choice(['$X.XX', '$XX.XX', '$XXX.XX', '$X,XXX.XX'])
            merchant = random.choice(self.merchants)
            account = 'XXXX'
            date = 'MM/DD/YYYY'
            bank = random.choice(['Citi', 'BofA', 'Capital One', 'Chase', 'Wells Fargo'])
            
            message = template.format(
                amount=amount,
                merchant=merchant,
                account=account,
                date=date,
                bank=bank
            )
            
            synthetic.append({
                'sms_text': message,
                'sender': bank.replace(' ', '').upper()[:6],
                'category': category,
                'is_transaction': True,
                'synthetic': True,
            })
        
        return synthetic
    
    def generate_dataset(self, target_size: int = 10000) -> Dict:
        """Generate complete synthetic dataset"""
        
        print(f"\n{'='*70}")
        print(f"SYNTHETIC DATA GENERATION")
        print(f"{'='*70}\n")
        
        dataset = {
            'real_transactions': [],
            'augmented_transactions': [],
            'synthetic_transactions': [],
            'real_non_transactions': [],
        }
        
        # 1. Include all real transactions
        print(f"Step 1: Including {len(self.transactions)} real transaction messages...")
        dataset['real_transactions'] = [
            {'sms_text': msg, 'source': 'real', 'is_transaction': True}
            for msg in self.transactions
        ]
        
        # 2. Augment real transactions (multiply by ~10-15x)
        print(f"Step 2: Augmenting real transactions...")
        augmentation_target = min(4000, target_size // 2)
        
        augmented = []
        while len(augmented) < augmentation_target:
            for transaction in self.transactions:
                variations = self.augment_transaction(transaction)
                for var in variations[:15]:  # Max 15 variations per message
                    augmented.append({
                        'sms_text': var,
                        'source': 'augmented',
                        'is_transaction': True,
                    })
                    if len(augmented) >= augmentation_target:
                        break
                if len(augmented) >= augmentation_target:
                    break
        
        dataset['augmented_transactions'] = augmented
        print(f"   Generated {len(augmented)} augmented variations")
        
        # 3. Generate fully synthetic from templates
        print(f"Step 3: Generating synthetic messages from templates...")
        synthetic_target = target_size - len(dataset['real_transactions']) - len(augmented) - len(self.non_transactions[:2000])
        synthetic = self.generate_from_template(num_samples=synthetic_target)
        dataset['synthetic_transactions'] = synthetic
        print(f"   Generated {len(synthetic)} synthetic messages")
        
        # 4. Include non-transactions for balanced dataset
        print(f"Step 4: Including non-transaction examples...")
        dataset['real_non_transactions'] = [
            {'sms_text': msg, 'source': 'real', 'is_transaction': False}
            for msg in self.non_transactions[:2000]  # Balance the dataset
        ]
        print(f"   Included {len(dataset['real_non_transactions'])} non-transaction messages")
        
        # Summary
        total = sum(len(v) if isinstance(v, list) else 0 for v in dataset.values())
        print(f"\n{'='*70}")
        print(f"DATASET SUMMARY")
        print(f"{'='*70}")
        print(f"Real transactions:        {len(dataset['real_transactions']):5d}")
        print(f"Augmented transactions:   {len(dataset['augmented_transactions']):5d}")
        print(f"Synthetic transactions:   {len(dataset['synthetic_transactions']):5d}")
        print(f"Non-transactions:         {len(dataset['real_non_transactions']):5d}")
        print(f"{'-'*70}")
        print(f"TOTAL:                    {total:5d}")
        print(f"{'='*70}\n")
        
        return dataset
    
    def save_training_data(self, dataset: Dict, output_file: str):
        """Save dataset in format ready for ML training"""
        
        # Flatten and prepare for training
        training_data = []
        
        for category, messages in dataset.items():
            for msg_dict in messages:
                training_data.append({
                    'text': msg_dict['sms_text'],
                    'label': 1 if msg_dict['is_transaction'] else 0,
                    'source': msg_dict.get('source', 'unknown'),
                    'category': msg_dict.get('category', category),
                })
        
        # Shuffle
        random.shuffle(training_data)
        
        # Split into train/validation/test (80/10/10)
        total = len(training_data)
        train_split = int(total * 0.8)
        val_split = int(total * 0.9)
        
        output = {
            'metadata': {
                'total_samples': total,
                'train_samples': train_split,
                'val_samples': val_split - train_split,
                'test_samples': total - val_split,
                'positive_samples': sum(1 for d in training_data if d['label'] == 1),
                'negative_samples': sum(1 for d in training_data if d['label'] == 0),
                'generated_date': '2026-04-19',
            },
            'train': training_data[:train_split],
            'validation': training_data[train_split:val_split],
            'test': training_data[val_split:],
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Training data saved to: {output_file}")
        print(f"\nSplit details:")
        print(f"  Train:      {len(output['train']):5d} samples ({len(output['train'])/total*100:.1f}%)")
        print(f"  Validation: {len(output['validation']):5d} samples ({len(output['validation'])/total*100:.1f}%)")
        print(f"  Test:       {len(output['test']):5d} samples ({len(output['test'])/total*100:.1f}%)")
        print(f"\nClass balance:")
        print(f"  Transaction:     {output['metadata']['positive_samples']:5d} ({output['metadata']['positive_samples']/total*100:.1f}%)")
        print(f"  Non-transaction: {output['metadata']['negative_samples']:5d} ({output['metadata']['negative_samples']/total*100:.1f}%)")


def main():
    """Generate synthetic SMS dataset for ML training"""
    
    # Generate dataset
    generator = SyntheticSmsGenerator('SMS Training Data.json')
    dataset = generator.generate_dataset(target_size=10000)
    
    # Save for training
    generator.save_training_data(dataset, 'sms_training_dataset.json')
    
    # Show examples
    print(f"\n{'='*70}")
    print("SAMPLE SYNTHETIC MESSAGES")
    print(f"{'='*70}\n")
    
    print("Real Transaction:")
    print(f"  {dataset['real_transactions'][0]['sms_text'][:100]}")
    
    print("\nAugmented Variation:")
    print(f"  {dataset['augmented_transactions'][0]['sms_text'][:100]}")
    
    print("\nSynthetic from Template:")
    print(f"  {dataset['synthetic_transactions'][0]['sms_text'][:100]}")
    
    print("\nNon-Transaction:")
    print(f"  {dataset['real_non_transactions'][0]['sms_text'][:100]}")
    
    print(f"\n{'='*70}\n")
    print("✅ Synthetic dataset generation complete!")
    print("📁 Ready to train ML model with: sms_training_dataset.json")
    print(f"{'='*70}\n")


if __name__ == '__main__':
    main()
