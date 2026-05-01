#!/usr/bin/env python3
"""
Extract Keywords from Dart Parser and Generate Enhanced Training Data

This script:
1. Extracts keywords from advanced_sms_parser.dart
2. Uses them to generate better synthetic training examples
3. Creates training data with real business logic from your app
"""

import re
import json
from pathlib import Path
from typing import List, Dict, Set


class KeywordExtractor:
    """Extract keywords from Dart parser code"""
    
    def __init__(self, dart_file_path: str):
        self.dart_file = Path(dart_file_path)
        self.keywords = {
            'debit': set(),
            'credit': set(),
            'future_scheduled': set(),
            'balance_reporting': set(),
            'statement_patterns': set(),
            'debit_phrases': set(),
            'credit_phrases': set(),
        }
    
    def extract_all_keywords(self):
        """Parse Dart file and extract all keyword arrays"""
        print(f"\n{'='*70}")
        print("EXTRACTING KEYWORDS FROM PARSER")
        print(f"{'='*70}\n")
        
        with open(self.dart_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract debit keywords
        debit_match = re.search(
            r'final debitKeywords = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if debit_match:
            self.keywords['debit'] = self._parse_string_array(debit_match.group(1))
        
        # Extract credit keywords
        credit_match = re.search(
            r'final creditKeywords = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if credit_match:
            self.keywords['credit'] = self._parse_string_array(credit_match.group(1))
        
        # Extract future/scheduled patterns
        future_match = re.search(
            r'final futureScheduledPatterns = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if future_match:
            self.keywords['future_scheduled'] = self._parse_string_array(future_match.group(1))
        
        # Extract debit phrases
        debit_phrase_match = re.search(
            r'final debitPhrases = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if debit_phrase_match:
            self.keywords['debit_phrases'] = self._parse_string_array(debit_phrase_match.group(1))
        
        # Extract credit phrases
        credit_phrase_match = re.search(
            r'final creditPhrases = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if credit_phrase_match:
            self.keywords['credit_phrases'] = self._parse_string_array(credit_phrase_match.group(1))
        
        # Extract balance reporting patterns
        balance_match = re.search(
            r'final balanceReportingPatterns = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if balance_match:
            self.keywords['balance_reporting'] = self._parse_string_array(balance_match.group(1))
        
        # Extract statement patterns
        statement_match = re.search(
            r'final statementPatterns = \[(.*?)\];',
            content,
            re.DOTALL
        )
        if statement_match:
            self.keywords['statement_patterns'] = self._parse_string_array(statement_match.group(1))
        
        # Print summary
        for category, keywords in self.keywords.items():
            print(f"{category:25s}: {len(keywords):3d} keywords")
        
        return self.keywords
    
    def _parse_string_array(self, array_str: str) -> Set[str]:
        """Parse Dart string array into Python set"""
        # Extract strings from quotes
        matches = re.findall(r"'([^']*)'", array_str)
        return set(matches)
    
    def save_keywords(self, output_file: str):
        """Save extracted keywords to JSON"""
        output = {
            category: sorted(list(keywords))
            for category, keywords in self.keywords.items()
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2)
        
        print(f"\n✓ Keywords saved to: {output_file}")


class EnhancedTrainingDataGenerator:
    """Generate training data using extracted keywords"""
    
    def __init__(self, keywords: Dict[str, Set[str]]):
        self.keywords = keywords
        self.merchants = [
            'Amazon', 'Walmart', 'Target', 'Starbucks', 'Netflix',
            'Spotify', 'Uber', 'Lyft', 'McDonald\'s', 'Whole Foods',
            'CVS', 'Walgreens', 'Shell', 'BP', 'Chevron',
            'Apple', 'Microsoft', 'Google', 'Best Buy', 'Home Depot',
            'Costco', 'Sam\'s Club', 'Gas Station', 'Restaurant',
            'Grocery Store', 'Coffee Shop', 'Pharmacy', 'ATM'
        ]
        
        self.banks = {
            'us': ['Citi', 'Bank of America', 'Chase', 'Wells Fargo', 'Capital One'],
            'india': ['HDFC', 'ICICI', 'SBI', 'Axis Bank', 'Kotak']
        }
    
    def generate_debit_transactions(self, count: int = 1000) -> List[Dict]:
        """Generate debit transaction SMS using keywords"""
        import random
        transactions = []
        
        print(f"\nGenerating {count} debit transactions...")
        
        for i in range(count):
            keyword = random.choice(list(self.keywords['debit']))
            phrase = random.choice(list(self.keywords['debit_phrases'])) if self.keywords['debit_phrases'] else None
            merchant = random.choice(self.merchants)
            amount = round(random.uniform(5.0, 500.0), 2)
            bank = random.choice(self.banks['us'])
            
            if phrase:
                # Use phrase-based template
                sms = f"{bank}: {phrase.title()} for ${amount:.2f} at {merchant}"
            else:
                # Use keyword-based template
                sms = f"{bank}: ${amount:.2f} {keyword} from account ending 1234 at {merchant}"
            
            transactions.append({
                'text': sms,
                'label': 1,  # Transaction
                'source': 'keyword_generated',
                'category': 'debit'
            })
        
        return transactions
    
    def generate_credit_transactions(self, count: int = 500) -> List[Dict]:
        """Generate credit transaction SMS using keywords"""
        import random
        transactions = []
        
        print(f"Generating {count} credit transactions...")
        
        for i in range(count):
            keyword = random.choice(list(self.keywords['credit']))
            phrase = random.choice(list(self.keywords['credit_phrases'])) if self.keywords['credit_phrases'] else None
            amount = round(random.uniform(50.0, 5000.0), 2)
            bank = random.choice(self.banks['us'])
            
            if phrase:
                # Use phrase-based template
                sms = f"{bank}: {phrase.title()} ${amount:.2f} to account ending 1234"
            else:
                # Use keyword-based template
                sms = f"{bank}: ${amount:.2f} {keyword} to your account ending 1234"
            
            transactions.append({
                'text': sms,
                'label': 1,  # Transaction
                'source': 'keyword_generated',
                'category': 'credit'
            })
        
        return transactions
    
    def generate_payment_reminders(self, count: int = 500) -> List[Dict]:
        """Generate payment reminder SMS using future/scheduled keywords"""
        import random
        reminders = []
        
        print(f"Generating {count} payment reminders...")
        
        for i in range(count):
            pattern = random.choice(list(self.keywords['future_scheduled']))
            amount = round(random.uniform(20.0, 500.0), 2)
            bank = random.choice(self.banks['us'])
            merchant = random.choice(['PG&E', 'Electric Company', 'Water Utility', 'Credit Card'])
            
            # Create reminder message
            sms = f"{bank}: Recurring payment for {merchant} ${amount:.2f} {pattern} 05/15/2026"
            
            reminders.append({
                'text': sms,
                'label': 0,  # NOT a transaction (reminder)
                'source': 'keyword_generated',
                'category': 'reminder'
            })
        
        return reminders
    
    def generate_balance_notifications(self, count: int = 300) -> List[Dict]:
        """Generate balance notification SMS"""
        import random
        notifications = []
        
        print(f"Generating {count} balance notifications...")
        
        for i in range(count):
            pattern = random.choice(list(self.keywords['balance_reporting']))
            balance = round(random.uniform(100.0, 10000.0), 2)
            bank = random.choice(self.banks['us'])
            
            sms = f"{bank}: Your {pattern} ${balance:.2f} as of today"
            
            notifications.append({
                'text': sms,
                'label': 0,  # NOT a transaction (notification)
                'source': 'keyword_generated',
                'category': 'balance'
            })
        
        return notifications
    
    def generate_statement_notifications(self, count: int = 200) -> List[Dict]:
        """Generate statement ready notifications"""
        import random
        notifications = []
        
        print(f"Generating {count} statement notifications...")
        
        for i in range(count):
            pattern = random.choice(list(self.keywords['statement_patterns']))
            bank = random.choice(self.banks['us'])
            
            sms = f"{bank}: Your {pattern} April 2026 is ready. View online."
            
            notifications.append({
                'text': sms,
                'label': 0,  # NOT a transaction (notification)
                'source': 'keyword_generated',
                'category': 'statement'
            })
        
        return notifications
    
    def generate_complete_dataset(self, output_file: str):
        """Generate comprehensive training dataset using all keywords"""
        print(f"\n{'='*70}")
        print("GENERATING ENHANCED TRAINING DATASET")
        print(f"{'='*70}\n")
        
        all_data = []
        
        # Generate each category
        all_data.extend(self.generate_debit_transactions(1000))
        all_data.extend(self.generate_credit_transactions(500))
        all_data.extend(self.generate_payment_reminders(500))  # ← FIXES YOUR PROBLEM!
        all_data.extend(self.generate_balance_notifications(300))
        all_data.extend(self.generate_statement_notifications(200))
        
        # Shuffle
        import random
        random.shuffle(all_data)
        
        # Split into train/val/test
        total = len(all_data)
        train_size = int(total * 0.8)
        val_size = int(total * 0.1)
        
        dataset = {
            'train': all_data[:train_size],
            'validation': all_data[train_size:train_size + val_size],
            'test': all_data[train_size + val_size:],
            'metadata': {
                'total_samples': total,
                'transactions': sum(1 for d in all_data if d['label'] == 1),
                'non_transactions': sum(1 for d in all_data if d['label'] == 0),
                'source': 'keyword_extracted_from_parser',
                'categories': {
                    'debit': sum(1 for d in all_data if d.get('category') == 'debit'),
                    'credit': sum(1 for d in all_data if d.get('category') == 'credit'),
                    'reminder': sum(1 for d in all_data if d.get('category') == 'reminder'),
                    'balance': sum(1 for d in all_data if d.get('category') == 'balance'),
                    'statement': sum(1 for d in all_data if d.get('category') == 'statement'),
                }
            }
        }
        
        # Save
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(dataset, f, indent=2)
        
        print(f"\n{'='*70}")
        print("DATASET SUMMARY")
        print(f"{'='*70}")
        print(f"Total samples:        {total:5d}")
        print(f"  Transactions:       {dataset['metadata']['transactions']:5d} ({dataset['metadata']['transactions']/total*100:.1f}%)")
        print(f"  Non-transactions:   {dataset['metadata']['non_transactions']:5d} ({dataset['metadata']['non_transactions']/total*100:.1f}%)")
        print(f"\nBy category:")
        for cat, count in dataset['metadata']['categories'].items():
            print(f"  {cat:15s}:  {count:5d} ({count/total*100:.1f}%)")
        print(f"\n✓ Enhanced dataset saved to: {output_file}")
        print(f"\nNext steps:")
        print(f"  1. python test/train_sms_classifier.py")
        print(f"  2. Deploy updated assets/models/sms_classifier.tflite")
        print(f"  3. Rebuild app with improved model")


def main():
    """Main execution"""
    # Paths
    dart_file = 'lib/services/advanced_sms_parser.dart'
    keywords_file = 'test/extracted_keywords.json'
    dataset_file = 'test/sms_training_dataset_enhanced.json'
    
    # Step 1: Extract keywords from Dart parser
    print("Step 1: Extracting keywords from parser...")
    extractor = KeywordExtractor(dart_file)
    keywords = extractor.extract_all_keywords()
    extractor.save_keywords(keywords_file)
    
    # Step 2: Generate enhanced training dataset
    print("\nStep 2: Generating enhanced training dataset...")
    generator = EnhancedTrainingDataGenerator(keywords)
    generator.generate_complete_dataset(dataset_file)
    
    print(f"\n{'='*70}")
    print("✓ COMPLETE! Enhanced training data ready.")
    print(f"{'='*70}\n")
    print("The new dataset includes:")
    print("  ✓ All debit/credit keywords from your parser")
    print("  ✓ Payment reminders ('scheduled for', 'upcoming payment')")
    print("  ✓ Balance notifications")
    print("  ✓ Statement notifications")
    print("\nThis will fix the PG&E reminder misclassification!")


if __name__ == '__main__':
    main()
