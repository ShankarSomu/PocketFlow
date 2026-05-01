/// Account Extraction Rules Seed Data
/// 
/// This file contains bank name patterns and account identifier extraction rules
/// used by the AccountExtractionService to extract bank information from SMS.
/// 
/// To add new banks or patterns, edit this file and bump database version.

import 'package:sqflite/sqflite.dart';

class AccountExtractionSeed {
  /// Seed bank name extraction rules
  static Future<void> seedBankRules(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // ═══════════════════════════════════════════════════════════════
    // US BANKS
    // ═══════════════════════════════════════════════════════════════
    
    final usBanks = [
      // ═══════════════════════════════════════════════════════════════
      // TRADITIONAL US BANKS
      // ═══════════════════════════════════════════════════════════════
      {'keywords': 'bofa,bank of america', 'output': 'Bank of America', 'pattern': 'keyword_match'},
      {'keywords': 'chase,chase bank', 'output': 'Chase', 'pattern': 'keyword_match'},
      {'keywords': 'citi,citibank,citi bank', 'output': 'Citi', 'pattern': 'keyword_match'},
      {'keywords': 'wells fargo,wellsfargo', 'output': 'Wells Fargo', 'pattern': 'keyword_match'},
      {'keywords': 'capital one,capitalone,capone', 'output': 'Capital One', 'pattern': 'keyword_match'},
      {'keywords': 'us bank,usbank', 'output': 'US Bank', 'pattern': 'keyword_match'},
      {'keywords': 'pnc,pnc bank', 'output': 'PNC Bank', 'pattern': 'keyword_match'},
      {'keywords': 'discover,discover card', 'output': 'Discover', 'pattern': 'keyword_match'},
      {'keywords': 'american express,amex', 'output': 'American Express', 'pattern': 'keyword_match'},
      {'keywords': 'td bank,td ameritrade', 'output': 'TD Bank', 'pattern': 'keyword_match'},
      {'keywords': 'citizens bank,citizens', 'output': 'Citizens Bank', 'pattern': 'keyword_match'},
      {'keywords': 'fifth third,5/3 bank', 'output': 'Fifth Third Bank', 'pattern': 'keyword_match'},
      {'keywords': 'regions,regions bank', 'output': 'Regions Bank', 'pattern': 'keyword_match'},
      {'keywords': 'suntrust,truist', 'output': 'Truist Bank', 'pattern': 'keyword_match'},
      {'keywords': 'ally bank,ally', 'output': 'Ally Bank', 'pattern': 'keyword_match'},
      {'keywords': 'bank of the west', 'output': 'Bank of the West', 'pattern': 'keyword_match'},
      {'keywords': 'huntington,huntington bank', 'output': 'Huntington Bank', 'pattern': 'keyword_match'},
      {'keywords': 'keybank,key bank', 'output': 'KeyBank', 'pattern': 'keyword_match'},
      {'keywords': 'navy federal,navyfcu,nfcu', 'output': 'Navy Federal Credit Union', 'pattern': 'keyword_match'},
      {'keywords': 'usaa', 'output': 'USAA', 'pattern': 'keyword_match'},
      {'keywords': 'schwab,charles schwab', 'output': 'Charles Schwab', 'pattern': 'keyword_match'},
      
      // ═══════════════════════════════════════════════════════════════
      // NEOBANKS & FINTECH
      // ═══════════════════════════════════════════════════════════════
      {'keywords': 'chime,chime bank', 'output': 'Chime', 'pattern': 'keyword_match'},
      {'keywords': 'varo,varo bank', 'output': 'Varo Bank', 'pattern': 'keyword_match'},
      {'keywords': 'current,current card', 'output': 'Current', 'pattern': 'keyword_match'},
      {'keywords': 'sofi,sofi money', 'output': 'SoFi', 'pattern': 'keyword_match'},
      {'keywords': 'marcus,marcus by goldman', 'output': 'Marcus by Goldman Sachs', 'pattern': 'keyword_match'},
      {'keywords': 'aspiration', 'output': 'Aspiration', 'pattern': 'keyword_match'},
      {'keywords': 'axos,axos bank', 'output': 'Axos Bank', 'pattern': 'keyword_match'},
      {'keywords': 'n26', 'output': 'N26', 'pattern': 'keyword_match'},
      {'keywords': 'revolut', 'output': 'Revolut', 'pattern': 'keyword_match'},
      {'keywords': 'monzo', 'output': 'Monzo', 'pattern': 'keyword_match'},
      {'keywords': 'dave', 'output': 'Dave', 'pattern': 'keyword_match'},
      {'keywords': 'step,step card', 'output': 'Step', 'pattern': 'keyword_match'},
      {'keywords': 'acorns', 'output': 'Acorns', 'pattern': 'keyword_match'},
      {'keywords': 'robinhood', 'output': 'Robinhood', 'pattern': 'keyword_match'},
      
      // ═══════════════════════════════════════════════════════════════
      // PAYMENT SERVICES & DIGITAL WALLETS
      // ═══════════════════════════════════════════════════════════════
      {'keywords': 'paypal', 'output': 'PayPal', 'pattern': 'keyword_match'},
      {'keywords': 'venmo', 'output': 'Venmo', 'pattern': 'keyword_match'},
      {'keywords': 'cash app,cashapp,square cash', 'output': 'Cash App', 'pattern': 'keyword_match'},
      {'keywords': 'zelle', 'output': 'Zelle', 'pattern': 'keyword_match'},
      {'keywords': 'apple pay,apple card,applepay', 'output': 'Apple Pay', 'pattern': 'keyword_match'},
      {'keywords': 'google pay,gpay,google wallet', 'output': 'Google Pay', 'pattern': 'keyword_match'},
      {'keywords': 'samsung pay', 'output': 'Samsung Pay', 'pattern': 'keyword_match'},
      {'keywords': 'stripe', 'output': 'Stripe', 'pattern': 'keyword_match'},
      {'keywords': 'square', 'output': 'Square', 'pattern': 'keyword_match'},
      {'keywords': 'affirm', 'output': 'Affirm', 'pattern': 'keyword_match'},
      {'keywords': 'klarna', 'output': 'Klarna', 'pattern': 'keyword_match'},
      {'keywords': 'afterpay', 'output': 'Afterpay', 'pattern': 'keyword_match'},
      {'keywords': 'payoneer', 'output': 'Payoneer', 'pattern': 'keyword_match'},
      {'keywords': 'wise,transferwise', 'output': 'Wise', 'pattern': 'keyword_match'},
      {'keywords': 'remitly', 'output': 'Remitly', 'pattern': 'keyword_match'},
    ];
    
    for (final bank in usBanks) {
      final ruleId = await db.insert('account_extraction_rules', {
        'rule_type': 'bank_name',
        'extraction_type': 'bank',
        'pattern': bank['pattern'],
        'keywords': bank['keywords'],
        'region': 'US',
        'output_value': bank['output'],
        'confidence': 1.0,
        'created_at': now,
        'source': 'system',
        'is_active': 1,
        'priority': 10,
      });
      
      // Create inverted index for fast keyword lookup
      final keywords = (bank['keywords'] as String).split(',');
      for (final keyword in keywords) {
        await db.insert('account_extraction_index', {
          'keyword': keyword.trim().toLowerCase(),
          'rule_id': ruleId,
        });
      }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INDIAN BANKS
    // ═══════════════════════════════════════════════════════════════
    
    final indianBanks = [
      {'keywords': 'hdfc,hdfcbank', 'output': 'HDFC Bank', 'pattern': 'keyword_match'},
      {'keywords': 'icici,icicibank', 'output': 'ICICI Bank', 'pattern': 'keyword_match'},
      {'keywords': 'sbi,state bank', 'output': 'State Bank of India', 'pattern': 'keyword_match'},
      {'keywords': 'axis,axis bank', 'output': 'Axis Bank', 'pattern': 'keyword_match'},
      {'keywords': 'kotak,kotak mahindra', 'output': 'Kotak Mahindra Bank', 'pattern': 'keyword_match'},
      {'keywords': 'indusind', 'output': 'IndusInd Bank', 'pattern': 'keyword_match'},
      {'keywords': 'yes bank', 'output': 'YES Bank', 'pattern': 'keyword_match'},
      {'keywords': 'pnb,punjab national', 'output': 'Punjab National Bank', 'pattern': 'keyword_match'},
    ];
    
    for (final bank in indianBanks) {
      final ruleId = await db.insert('account_extraction_rules', {
        'rule_type': 'bank_name',
        'extraction_type': 'bank',
        'pattern': bank['pattern'],
        'keywords': bank['keywords'],
        'region': 'INDIA',
        'output_value': bank['output'],
        'confidence': 1.0,
        'created_at': now,
        'source': 'system',
        'is_active': 1,
        'priority': 10,
      });
      
      // Create inverted index
      final keywords = (bank['keywords'] as String).split(',');
      for (final keyword in keywords) {
        await db.insert('account_extraction_index', {
          'keyword': keyword.trim().toLowerCase(),
          'rule_id': ruleId,
        });
      }
    }
  }

  /// Seed account identifier extraction patterns
  static Future<void> seedIdentifierRules(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // ═══════════════════════════════════════════════════════════════
    // ACCOUNT IDENTIFIER PATTERNS
    // ═══════════════════════════════════════════════════════════════
    
    final identifierRules = [
      {
        'keywords': 'ending,last,acct,account',
        'pattern': r'(?:ending|last)\s+(?:in\s+)?(\d{4})',
        'desc': 'ending in 1234'
      },
      {
        'keywords': 'account,a/c,ac',
        'pattern': r'(?:a\/c|ac|acc|account)\s*[:\s-]+([xX*]{2,}\d{4,6}|\d{4,16})',
        'desc': 'account - 3281'
      },
      {
        'keywords': 'card,debit,credit',
        'pattern': r'(?:card|debit|credit)\s*(?:card)?\s*[:\s-]+([xX*]{1,4}\d{4})',
        'desc': 'card - 5517'
      },
      {
        'keywords': 'card,ending',
        'pattern': r'card\s+ending\s+(?:in\s+)?(\d{4})',
        'desc': 'card ending 1234'
      },
      {
        'keywords': '',
        'pattern': r'\b([xX]{2,}\d{4,6})\b',
        'desc': 'XX1234 standalone'
      },
      {
        'keywords': '',
        'pattern': r'(\*{4}\d{4})\b',
        'desc': '****1234 standalone'
      },
      {
        'keywords': '',
        'pattern': r'…\(([xX*]{4})\)',
        'desc': '…(XXXX) Capital One format'
      },
    ];
    
    for (final rule in identifierRules) {
      final ruleId = await db.insert('account_extraction_rules', {
        'rule_type': 'account_identifier',
        'extraction_type': 'identifier',
        'pattern': rule['pattern'],
        'keywords': rule['keywords'],
        'region': null, // Universal patterns
        'output_value': null,
        'confidence': 1.0,
        'created_at': now,
        'source': 'system',
        'is_active': 1,
        'priority': 10,
      });
      
      // Create inverted index for keywords (if any)
      final keywords = (rule['keywords'] as String).split(',');
      for (final keyword in keywords) {
        if (keyword.trim().isNotEmpty) {
          await db.insert('account_extraction_index', {
            'keyword': keyword.trim().toLowerCase(),
            'rule_id': ruleId,
          });
        }
      }
    }
  }

  /// Seed bank normalizations (variations -> canonical name)
  static Future<void> seedBankNormalizations(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final normalizations = [
      {'original': 'BofA', 'normalized': 'Bank of America'},
      {'original': 'BOA', 'normalized': 'Bank of America'},
      {'original': 'Chase Bank', 'normalized': 'Chase'},
      {'original': 'CitiBank', 'normalized': 'Citi'},
      {'original': 'Wells', 'normalized': 'Wells Fargo'},
      {'original': 'CapOne', 'normalized': 'Capital One'},
      {'original': 'Amex', 'normalized': 'American Express'},
      {'original': 'HDFC Bank', 'normalized': 'HDFC Bank'},
      {'original': 'ICICI Bank', 'normalized': 'ICICI Bank'},
      {'original': 'SBI', 'normalized': 'State Bank of India'},
    ];
    
    for (final norm in normalizations) {
      await db.insert('bank_normalizations', {
        'original_name': norm['original'],
        'normalized_name': norm['normalized'],
        'created_at': now,
      });
    }
  }
}
