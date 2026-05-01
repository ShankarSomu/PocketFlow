import 'package:path/path.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database_optimizer.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/deletable_entity.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart' as model;
import '../services/data_integrity_service.dart';
import '../services/notification_service.dart';
import 'seeds/account_extraction_seed.dart';
import 'seeds/sms_keywords_seed.dart';

// Wrap DB init to log errors


class AppDatabase {
  static Database? _db;

  static Future<Database> db() async {
    _db ??= await _init();
    return _db!;
  }

  /// Replaces the shared database instance.
  ///
  /// **For testing only.** Call this in [setUp] / [setUpAll] to inject an
  /// in-memory database, and call `resetForTesting()` in [tearDown] to clean
  /// up.
  // ignore: invalid_use_of_visible_for_testing_member
  static void setDatabaseForTesting(Database database) {
    _db = database;
  }

  /// Clears the cached database instance so the next [db()] call re-opens it.
  ///
  /// **For testing only.**
  // ignore: invalid_use_of_visible_for_testing_member
  static void resetForTesting() {
    _db = null;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'pocket_flow.db');
    return openDatabase(path, version: 24,
      onCreate: (db, _) => _createAll(db),
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS accounts('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, type TEXT NOT NULL, '
            'balance REAL NOT NULL DEFAULT 0, last4 TEXT)');
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
          await db.execute(
            'CREATE TABLE IF NOT EXISTS budgets('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'category TEXT NOT NULL, `limit` REAL NOT NULL, '
            'month INTEGER NOT NULL, year INTEGER NOT NULL, '
            'UNIQUE(category, month, year))');
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS recurring_transactions('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'type TEXT NOT NULL, amount REAL NOT NULL, '
            'category TEXT NOT NULL, note TEXT, '
            'account_id INTEGER REFERENCES accounts(id), '
            'frequency TEXT NOT NULL, '
            'next_due_date TEXT NOT NULL, '
            'is_active INTEGER NOT NULL DEFAULT 1)');
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE savings_goals ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
          await db.execute(
              'ALTER TABLE savings_goals ADD COLUMN priority INTEGER NOT NULL DEFAULT 999');
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS categories('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, '
            'parent_id INTEGER REFERENCES categories(id), '
            'is_default INTEGER NOT NULL DEFAULT 0, '
            'icon TEXT NOT NULL DEFAULT "📁", '
            'color TEXT NOT NULL DEFAULT "#6C63FF")');
          // Seed default categories for existing databases
          await _seedDefaultCategories(db);
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN recurring_id INTEGER REFERENCES recurring_transactions(id)');
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE recurring_transactions ADD COLUMN to_account_id INTEGER REFERENCES accounts(id)');
          await db.execute(
            'ALTER TABLE recurring_transactions ADD COLUMN goal_id INTEGER REFERENCES savings_goals(id)');
        }
        if (oldVersion < 8) {
          await db.execute(
              'ALTER TABLE accounts ADD COLUMN due_date_day INTEGER');
          await db.execute(
              'ALTER TABLE accounts ADD COLUMN credit_limit REAL');
        }
        if (oldVersion < 9) {
          // Add soft delete support
          await db.execute('ALTER TABLE transactions ADD COLUMN deleted_at INTEGER');
          await db.execute('ALTER TABLE accounts ADD COLUMN deleted_at INTEGER');
          await db.execute('ALTER TABLE budgets ADD COLUMN deleted_at INTEGER');
          await db.execute('ALTER TABLE savings_goals ADD COLUMN deleted_at INTEGER');
          await db.execute('ALTER TABLE recurring_transactions ADD COLUMN deleted_at INTEGER');
          // Create indexes for deleted_at
          await db.execute('CREATE INDEX idx_transactions_deleted ON transactions(deleted_at)');
          await db.execute('CREATE INDEX idx_accounts_deleted ON accounts(deleted_at)');
          await db.execute('CREATE INDEX idx_budgets_deleted ON budgets(deleted_at)');
          await db.execute('CREATE INDEX idx_goals_deleted ON savings_goals(deleted_at)');
          await db.execute('CREATE INDEX idx_recurring_deleted ON recurring_transactions(deleted_at)');
        }
        if (oldVersion < 10) {
          // Add SMS source tracking for transactions
          await db.execute('ALTER TABLE transactions ADD COLUMN sms_source TEXT');
        }
        if (oldVersion < 11) {
          // Add hybrid transaction mapping fields
          // Account enhancements
          await db.execute('ALTER TABLE accounts ADD COLUMN institution_name TEXT');
          await db.execute('ALTER TABLE accounts ADD COLUMN account_identifier TEXT');
          await db.execute('ALTER TABLE accounts ADD COLUMN sms_keywords TEXT');
          await db.execute('ALTER TABLE accounts ADD COLUMN account_alias TEXT');
          
          // Transaction enhancements
          await db.execute('ALTER TABLE transactions ADD COLUMN source_type TEXT NOT NULL DEFAULT "manual"');
          await db.execute('ALTER TABLE transactions ADD COLUMN merchant TEXT');
          await db.execute('ALTER TABLE transactions ADD COLUMN confidence_score REAL');
          await db.execute('ALTER TABLE transactions ADD COLUMN needs_review INTEGER DEFAULT 0');
          
          // Create indexes for fast matching
          await db.execute('CREATE INDEX idx_accounts_institution ON accounts(institution_name)');
          await db.execute('CREATE INDEX idx_accounts_identifier ON accounts(account_identifier)');
          await db.execute('CREATE INDEX idx_transactions_needs_review ON transactions(needs_review)');
          await db.execute('CREATE INDEX idx_transactions_source_type ON transactions(source_type)');
          await db.execute('CREATE INDEX idx_transactions_merchant ON transactions(merchant)');
          
          // Backfill existing data
          await db.execute('UPDATE transactions SET source_type = "manual" WHERE source_type IS NULL');
          
          // Generate account identifiers from last4 for existing accounts
          await db.execute('UPDATE accounts SET account_identifier = "****" || last4 WHERE last4 IS NOT NULL AND account_identifier IS NULL');
        }
        if (oldVersion < 12) {
          // SMS Intelligence Engine tables
          
          // Account Candidates
          await db.execute('''
            CREATE TABLE IF NOT EXISTS account_candidates(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              institution_name TEXT,
              account_identifier TEXT,
              sms_keywords TEXT,
              suggested_type TEXT NOT NULL DEFAULT 'checking',
              confidence_score REAL NOT NULL DEFAULT 0.5,
              transaction_count INTEGER NOT NULL DEFAULT 1,
              first_seen_date TEXT NOT NULL,
              last_seen_date TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              merged_into_account_id INTEGER REFERENCES accounts(id),
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )''');
          await db.execute('CREATE INDEX idx_account_candidates_status ON account_candidates(status)');
          await db.execute('CREATE INDEX idx_account_candidates_institution ON account_candidates(institution_name)');
          
          // Pending Actions
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_actions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action_type TEXT NOT NULL,
              priority TEXT NOT NULL DEFAULT 'medium',
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              transaction_id INTEGER REFERENCES transactions(id),
              account_candidate_id INTEGER REFERENCES account_candidates(id),
              sms_source TEXT,
              metadata TEXT,
              confidence REAL NOT NULL DEFAULT 0.0,
              status TEXT NOT NULL DEFAULT 'pending',
              resolved_at TEXT,
              resolution_action TEXT,
              title TEXT NOT NULL,
              description TEXT NOT NULL
            )''');
          await db.execute('CREATE INDEX idx_pending_actions_status ON pending_actions(status)');
          await db.execute('CREATE INDEX idx_pending_actions_priority ON pending_actions(priority)');
          await db.execute('CREATE INDEX idx_pending_actions_type ON pending_actions(action_type)');
          
          // Recurring Patterns
          await db.execute('''
            CREATE TABLE IF NOT EXISTS recurring_patterns(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              merchant TEXT,
              category TEXT NOT NULL,
              type TEXT NOT NULL,
              average_amount REAL NOT NULL,
              amount_variance REAL NOT NULL,
              frequency TEXT NOT NULL,
              interval_days INTEGER NOT NULL,
              occurrence_count INTEGER NOT NULL,
              confidence_score REAL NOT NULL,
              first_occurrence TEXT NOT NULL,
              last_occurrence TEXT NOT NULL,
              next_expected_date TEXT,
              transaction_ids TEXT NOT NULL,
              account_id INTEGER REFERENCES accounts(id),
              status TEXT NOT NULL DEFAULT 'candidate',
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )''');
          await db.execute('CREATE INDEX idx_recurring_patterns_merchant ON recurring_patterns(merchant)');
          await db.execute('CREATE INDEX idx_recurring_patterns_status ON recurring_patterns(status)');
          await db.execute('CREATE INDEX idx_recurring_patterns_next_date ON recurring_patterns(next_expected_date)');
          
          // SMS Templates (Learning System)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sms_templates(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              institution_name TEXT NOT NULL,
              sender_patterns TEXT NOT NULL,
              message_pattern TEXT NOT NULL,
              amount_pattern TEXT,
              merchant_pattern TEXT,
              account_id_pattern TEXT,
              balance_pattern TEXT,
              transaction_type TEXT NOT NULL,
              match_count INTEGER NOT NULL DEFAULT 0,
              user_confirmations INTEGER NOT NULL DEFAULT 0,
              user_rejections INTEGER NOT NULL DEFAULT 0,
              accuracy REAL NOT NULL DEFAULT 0.5,
              is_user_created INTEGER DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              last_used TEXT
            )''');
          await db.execute('CREATE INDEX idx_sms_templates_institution ON sms_templates(institution_name)');
          await db.execute('CREATE INDEX idx_sms_templates_accuracy ON sms_templates(accuracy)');
          
          // Transfer Pairs
          await db.execute('''
            CREATE TABLE IF NOT EXISTS transfer_pairs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              debit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
              credit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
              amount REAL NOT NULL,
              timestamp TEXT NOT NULL,
              source_account_id INTEGER NOT NULL REFERENCES accounts(id),
              destination_account_id INTEGER NOT NULL REFERENCES accounts(id),
              confidence_score REAL NOT NULL,
              detection_method TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'detected',
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )''');
          await db.execute('CREATE INDEX idx_transfer_pairs_status ON transfer_pairs(status)');
          await db.execute('CREATE INDEX idx_transfer_pairs_debit ON transfer_pairs(debit_transaction_id)');
          await db.execute('CREATE INDEX idx_transfer_pairs_credit ON transfer_pairs(credit_transaction_id)');
          
          // Merchant Mappings (Learning System)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS merchant_mappings(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              extracted_name TEXT NOT NULL,
              correct_name TEXT NOT NULL,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(extracted_name, correct_name)
            )''');
          await db.execute('CREATE INDEX idx_merchant_mappings_extracted ON merchant_mappings(extracted_name)');
          
          // Add new transaction fields for SMS intelligence
          await db.execute('ALTER TABLE transactions ADD COLUMN sms_id TEXT');
          await db.execute('ALTER TABLE transactions ADD COLUMN extracted_identifier TEXT');
          await db.execute('ALTER TABLE transactions ADD COLUMN extracted_institution TEXT');
          await db.execute('ALTER TABLE transactions ADD COLUMN linked_transaction_id INTEGER REFERENCES transactions(id)');
          await db.execute('ALTER TABLE transactions ADD COLUMN transfer_reference TEXT');
          await db.execute('ALTER TABLE transactions ADD COLUMN recurring_group_id INTEGER REFERENCES recurring_patterns(id)');
          await db.execute('ALTER TABLE transactions ADD COLUMN is_recurring_candidate INTEGER DEFAULT 0');
          
          // Add new account fields for SMS intelligence
          await db.execute('ALTER TABLE accounts ADD COLUMN source TEXT NOT NULL DEFAULT "manual"');
          await db.execute('ALTER TABLE accounts ADD COLUMN confidence_score_account REAL');
          await db.execute('ALTER TABLE accounts ADD COLUMN requires_confirmation INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE accounts ADD COLUMN created_from_sms_date TEXT');
          
          // Create additional indexes
          await db.execute('CREATE INDEX idx_transactions_sms_id ON transactions(sms_id)');
          await db.execute('CREATE INDEX idx_transactions_linked ON transactions(linked_transaction_id)');
          await db.execute('CREATE INDEX idx_transactions_recurring_group ON transactions(recurring_group_id)');
          await db.execute('CREATE INDEX idx_accounts_source ON accounts(source)');
        }
        if (oldVersion < 13) {
          // Add indexed rule engine for scalable SMS classification
          await db.execute('''CREATE TABLE IF NOT EXISTS sms_classification_rules(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_type TEXT NOT NULL,
            keywords TEXT NOT NULL,
            normalized_merchants TEXT,
            category TEXT,
            transaction_type TEXT,
            confidence REAL DEFAULT 1.0,
            correct_count INTEGER DEFAULT 0,
            incorrect_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            last_used_at INTEGER,
            source TEXT DEFAULT 'user',
            is_active INTEGER DEFAULT 1
          )''');
          
          await db.execute('''CREATE TABLE IF NOT EXISTS sms_rule_index(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            keyword TEXT NOT NULL,
            rule_id INTEGER NOT NULL,
            UNIQUE(keyword, rule_id),
            FOREIGN KEY(rule_id) REFERENCES sms_classification_rules(id) ON DELETE CASCADE
          )''');
          
          await db.execute('''CREATE TABLE IF NOT EXISTS sms_pattern_cache(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pattern_signature TEXT NOT NULL UNIQUE,
            category TEXT,
            transaction_type TEXT,
            matched_rule_ids TEXT,
            hit_count INTEGER DEFAULT 1,
            last_hit_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )''');
          
          await db.execute('''CREATE TABLE IF NOT EXISTS merchant_normalizations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            original_name TEXT NOT NULL UNIQUE,
            normalized_name TEXT NOT NULL,
            frequency INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL
          )''');
          
          // Indexes for fast lookups
          await db.execute('CREATE INDEX idx_rule_index_keyword ON sms_rule_index(keyword)');
          await db.execute('CREATE INDEX idx_rule_index_rule ON sms_rule_index(rule_id)');
          await db.execute('CREATE INDEX idx_rules_active ON sms_classification_rules(is_active) WHERE is_active = 1');
          await db.execute('CREATE INDEX idx_rules_category ON sms_classification_rules(category)');
          await db.execute('CREATE INDEX idx_cache_signature ON sms_pattern_cache(pattern_signature)');
          await db.execute('CREATE INDEX idx_merchant_norm ON merchant_normalizations(normalized_name)');
          
          await db.execute('''CREATE TABLE IF NOT EXISTS feedback_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER,
            feedback_type TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
          )''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_type ON feedback_history(feedback_type)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_date ON feedback_history(created_at)');
        }
        if (oldVersion < 14) {
          // Add user_disputed column to transactions
          await db.execute('ALTER TABLE transactions ADD COLUMN user_disputed INTEGER DEFAULT 0');
          
          // Create feedback_events table
          await db.execute('''CREATE TABLE IF NOT EXISTS feedback_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            outcome TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
          )''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_events_txn ON feedback_events(transaction_id)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_events_type ON feedback_events(event_type)');
        }
        
        if (oldVersion < 15) {
          // ═══════════════════════════════════════════════════════════════
          // Account Identity Extraction Rules (Phase 1)
          // Rule-based system for extracting bank names and account identifiers
          // Similar architecture to SMS Intelligence Engine
          // ═══════════════════════════════════════════════════════════════
          
          // Core extraction rules table
          await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_rules(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_type TEXT NOT NULL,
            extraction_type TEXT NOT NULL,
            pattern TEXT NOT NULL,
            keywords TEXT NOT NULL,
            region TEXT,
            output_value TEXT,
            confidence REAL DEFAULT 1.0,
            correct_count INTEGER DEFAULT 0,
            incorrect_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            last_used_at INTEGER,
            source TEXT DEFAULT 'system',
            is_active INTEGER DEFAULT 1,
            priority INTEGER DEFAULT 0
          )''');
          
          // Inverted index for fast keyword matching
          await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_index(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            keyword TEXT NOT NULL,
            rule_id INTEGER NOT NULL,
            UNIQUE(keyword, rule_id),
            FOREIGN KEY(rule_id) REFERENCES account_extraction_rules(id) ON DELETE CASCADE
          )''');
          
          // Bank name normalizations (e.g., "BofA" → "Bank of America")
          await db.execute('''CREATE TABLE IF NOT EXISTS bank_normalizations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            original_name TEXT NOT NULL UNIQUE,
            normalized_name TEXT NOT NULL,
            region TEXT,
            frequency INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL
          )''');
          
          // Extraction feedback and learning
          await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_feedback(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sms_text TEXT NOT NULL,
            extracted_bank TEXT,
            extracted_identifier TEXT,
            correct_bank TEXT,
            correct_identifier TEXT,
            feedback_type TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )''');
          
          // Performance indexes
          await db.execute('CREATE INDEX idx_extraction_index_keyword ON account_extraction_index(keyword)');
          await db.execute('CREATE INDEX idx_extraction_index_rule ON account_extraction_index(rule_id)');
          await db.execute('CREATE INDEX idx_extraction_rules_active ON account_extraction_rules(is_active) WHERE is_active = 1');
          await db.execute('CREATE INDEX idx_extraction_rules_type ON account_extraction_rules(extraction_type)');
          await db.execute('CREATE INDEX idx_extraction_rules_region ON account_extraction_rules(region)');
          await db.execute('CREATE INDEX idx_bank_norm_original ON bank_normalizations(original_name)');
          await db.execute('CREATE INDEX idx_bank_norm_normalized ON bank_normalizations(normalized_name)');
          
          // Seed initial extraction rules
          await _seedAccountExtractionRules(db);
        }
        
        if (oldVersion < 16) {
          // ═══════════════════════════════════════════════════════════════
          // SMS Keywords & Merchant Categories in Database  
          // Move hardcoded keywords to database for easier maintenance
          // ═══════════════════════════════════════════════════════════════
          
          // SMS transaction keywords (debit/credit/financial indicators)
          await db.execute('''CREATE TABLE IF NOT EXISTS sms_keywords(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            keyword TEXT NOT NULL,
            type TEXT NOT NULL,
            region TEXT,
            confidence REAL DEFAULT 1.0,
            priority INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            usage_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
          )''');
          
          // Merchant to category mappings
          await db.execute('''CREATE TABLE IF NOT EXISTS merchant_categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant_pattern TEXT NOT NULL,
            category TEXT NOT NULL,
            region TEXT,
            priority INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            match_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
          )''');
          
          // Performance indexes
          await db.execute('CREATE INDEX idx_sms_keywords_type ON sms_keywords(type)');
          await db.execute('CREATE INDEX idx_sms_keywords_region ON sms_keywords(region)');
          await db.execute('CREATE INDEX idx_sms_keywords_active ON sms_keywords(is_active) WHERE is_active = 1');
          await db.execute('CREATE INDEX idx_merchant_categories_pattern ON merchant_categories(merchant_pattern)');
          await db.execute('CREATE INDEX idx_merchant_categories_region ON merchant_categories(region)');
          await db.execute('CREATE INDEX idx_merchant_categories_active ON merchant_categories(is_active) WHERE is_active = 1');
          
          // Seed keywords and merchant categories
          await _seedSmsKeywords(db);
          await _seedMerchantCategories(db);
          await _seedSenderPatterns(db);
        }
        if (oldVersion < 17) {
          // ═══════════════════════════════════════════════════════════════
          // Transfer Account Fields
          // Add from_account_id and to_account_id for explicit transfer tracking
          // ═══════════════════════════════════════════════════════════════
          
          await db.execute('ALTER TABLE transactions ADD COLUMN from_account_id INTEGER REFERENCES accounts(id)');
          await db.execute('ALTER TABLE transactions ADD COLUMN to_account_id INTEGER REFERENCES accounts(id)');
          
          // Create indexes for transfer queries
          await db.execute('CREATE INDEX idx_transactions_from_account ON transactions(from_account_id)');
          await db.execute('CREATE INDEX idx_transactions_to_account ON transactions(to_account_id)');
          
          // Backfill existing transfers from transfer_pairs table
          await db.execute('''
            UPDATE transactions
            SET from_account_id = (
              SELECT source_account_id 
              FROM transfer_pairs 
              WHERE transfer_pairs.debit_transaction_id = transactions.id
            ),
            to_account_id = (
              SELECT destination_account_id 
              FROM transfer_pairs 
              WHERE transfer_pairs.debit_transaction_id = transactions.id
            )
            WHERE id IN (
              SELECT debit_transaction_id FROM transfer_pairs
            )
          ''');
          
          await db.execute('''
            UPDATE transactions
            SET from_account_id = (
              SELECT source_account_id 
              FROM transfer_pairs 
              WHERE transfer_pairs.credit_transaction_id = transactions.id
            ),
            to_account_id = (
              SELECT destination_account_id 
              FROM transfer_pairs 
              WHERE transfer_pairs.credit_transaction_id = transactions.id
            )
            WHERE id IN (
              SELECT credit_transaction_id FROM transfer_pairs
            )
          ''');
        }
        if (oldVersion < 18) {
          // ═══════════════════════════════════════════════════════════════
          // Access Type Field
          // Critical for SMS parsing - tracks HOW transactions are made
          // (debit_card, credit_card, upi, bank_transfer, ach, cash, unknown)
          // ═══════════════════════════════════════════════════════════════
          
          await db.execute('ALTER TABLE accounts ADD COLUMN access_type TEXT');
          
          // Create index for access_type queries
          await db.execute('CREATE INDEX idx_accounts_access_type ON accounts(access_type)');
        }
        if (oldVersion < 19) {
          // ═══════════════════════════════════════════════════════════════
          // Enforce Transaction Integrity (Single Source of Truth)
          // - accountId becomes required (NOT NULL)
          // - category gets default value ('uncategorized')
          // ═══════════════════════════════════════════════════════════════
          
          // Step 1: Delete orphaned transactions (those with null account_id)
          final orphanedCount = await db.rawQuery(
            'SELECT COUNT(*) as count FROM transactions WHERE account_id IS NULL'
          );
          final count = (orphanedCount.first['count'] as int?) ?? 0;
          if (count > 0) {
            AppLogger.db('migration_v19', detail: 'Removing $count orphaned transactions');
            await db.delete('transactions', where: 'account_id IS NULL');
          }
          
          // Step 2: Set default category for any null/empty categories
          await db.execute(
            "UPDATE transactions SET category = 'uncategorized' WHERE category IS NULL OR category = ''"
          );
          
          AppLogger.db('migration_v19', detail: 'Enforced accountId NOT NULL and category defaults');
        }
        
        if (oldVersion < 20) {
          // ═══════════════════════════════════════════════════════════════
          // User Feedback Learning System (v20)
          // - Capture user corrections for machine learning
          // - Track account confirmations for confidence boosting
          // - Store quick feedback (thumbs up/down) for field-level learning
          // ═══════════════════════════════════════════════════════════════
          
          AppLogger.db('migration_v20', detail: 'Creating feedback learning tables');
          
          // Table 1: User Account Confirmations
          // Tracks when user approves/rejects sender+merchant mappings
          await db.execute('''CREATE TABLE IF NOT EXISTS user_account_confirmations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            institution TEXT,
            merchant TEXT,
            sender_id TEXT,
            confirmed INTEGER NOT NULL,
            confidence_before REAL,
            confirmation_date TEXT NOT NULL,
            FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
          )''');
          await db.execute('CREATE INDEX idx_confirmations_txn ON user_account_confirmations(transaction_id)');
          await db.execute('CREATE INDEX idx_confirmations_merchant ON user_account_confirmations(merchant)');
          
          // Table 2: User Corrections
          // Tracks every field-level correction for learning
          await db.execute('''CREATE TABLE IF NOT EXISTS user_corrections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            field_name TEXT NOT NULL,
            original_value TEXT,
            corrected_value TEXT,
            correction_date TEXT NOT NULL,
            sms_text TEXT,
            feedback_type TEXT NOT NULL,
            FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
          )''');
          await db.execute('CREATE INDEX idx_corrections_txn ON user_corrections(transaction_id)');
          await db.execute('CREATE INDEX idx_corrections_field ON user_corrections(field_name)');
          
          // Table 3: Parsing Feedback
          // Quick thumbs up/down per field for granular feedback
          await db.execute('''CREATE TABLE IF NOT EXISTS parsing_feedback(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            field_name TEXT NOT NULL,
            is_correct INTEGER NOT NULL,
            feedback_date TEXT NOT NULL,
            sms_text TEXT,
            extracted_value TEXT,
            FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
          )''');
          await db.execute('CREATE INDEX idx_feedback_txn ON parsing_feedback(transaction_id)');
          await db.execute('CREATE INDEX idx_feedback_field ON parsing_feedback(field_name)');
          
          AppLogger.db('migration_v20', detail: 'Feedback learning system ready');
        }

        if (oldVersion < 21) {
          // ═══════════════════════════════════════════════════════════════
          // Adaptive Learning Tables (v21)
          // - merchant_normalization_rules: "AMZN MKTPLACE" → "Amazon"
          // - merchant_category_map: "Amazon" → "Shopping"
          // Both tables grow automatically from user corrections.
          // ═══════════════════════════════════════════════════════════════

          AppLogger.db('migration_v21', detail: 'Creating adaptive learning tables');

          // Merchant normalization: raw SMS text → canonical display name
          await db.execute('''CREATE TABLE IF NOT EXISTS merchant_normalization_rules(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            raw_pattern TEXT NOT NULL UNIQUE,
            normalized_name TEXT NOT NULL,
            usage_count INTEGER NOT NULL DEFAULT 1,
            success_count INTEGER NOT NULL DEFAULT 1,
            confidence REAL NOT NULL DEFAULT 1.0,
            last_used_at TEXT NOT NULL
          )''');
          await db.execute(
            'CREATE INDEX idx_merchant_norm_rules_pattern ON merchant_normalization_rules(raw_pattern)',
          );

          // Merchant → category mapping learned from user corrections
          await db.execute('''CREATE TABLE IF NOT EXISTS merchant_category_map(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            usage_count INTEGER NOT NULL DEFAULT 1,
            confidence REAL NOT NULL DEFAULT 1.0,
            last_used_at TEXT NOT NULL
          )''');
          await db.execute(
            'CREATE INDEX idx_merchant_category_map_merchant ON merchant_category_map(merchant)',
          );

          AppLogger.db('migration_v21', detail: 'Adaptive learning tables ready');
        }

        if (oldVersion < 22) {
          // ═══════════════════════════════════════════════════════════════
          // Signal Weight Persistence (v22)
          // - signal_weights: persists per-signal confidence weights
          // - Seeded with five default weights on first run
          // ═══════════════════════════════════════════════════════════════

          AppLogger.db('migration_v22', detail: 'Creating signal_weights table');

          await db.execute('''CREATE TABLE IF NOT EXISTS signal_weights (
            id     INTEGER PRIMARY KEY AUTOINCREMENT,
            signal TEXT    NOT NULL UNIQUE,
            weight REAL    NOT NULL
          )''');

          // Seed default signal weights
          const defaultWeights = {
            'has_amount':           0.40,
            'has_account':          0.20,
            'has_bank':             0.10,
            'has_merchant':         0.10,
            'has_transaction_verb': 0.20,
          };
          for (final entry in defaultWeights.entries) {
            await db.insert('signal_weights', {
              'signal': entry.key,
              'weight': entry.value,
            });
          }

          AppLogger.db('migration_v22', detail: 'signal_weights table ready with defaults');
        }

        if (oldVersion < 23) {
          // ═══════════════════════════════════════════════════════════════
          // Normalize account type 'credit' → 'credit_card' (v23)
          // The form previously saved 'credit'; the model defines 'credit_card'.
          // ═══════════════════════════════════════════════════════════════
          await db.execute(
            "UPDATE accounts SET type = 'credit_card' WHERE type = 'credit'",
          );

          // Add target_date to savings_goals for task 15
          await db.execute(
            'ALTER TABLE savings_goals ADD COLUMN target_date TEXT',
          );

          // Add end_date to recurring_transactions for task 22
          await db.execute(
            'ALTER TABLE recurring_transactions ADD COLUMN end_date TEXT',
          );

          // Add sort_order to accounts for task 29
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
          // Default sort_order = rowid so existing order is preserved
          await db.execute(
            'UPDATE accounts SET sort_order = id WHERE sort_order = 0',
          );

          // Performance indexes for task 39
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)',
          );

          AppLogger.db('migration_v23', detail: 'credit→credit_card, target_date, end_date, sort_order, indexes');
        }

        if (oldVersion < 24) {
          // ═══════════════════════════════════════════════════════════════
          // SMS Negative Samples (v24)
          // Structural, sender-aware learning — replaces keyword-based blocking.
          // ═══════════════════════════════════════════════════════════════
          await db.execute('''CREATE TABLE IF NOT EXISTS sms_negative_samples(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT NOT NULL,
            pattern_type TEXT NOT NULL,
            length_bucket INTEGER NOT NULL,
            has_number INTEGER NOT NULL DEFAULT 0,
            has_url INTEGER NOT NULL DEFAULT 0,
            original_sms TEXT,
            created_at INTEGER NOT NULL
          )''');
          await db.execute('CREATE INDEX idx_neg_samples_sender ON sms_negative_samples(sender)');
          await db.execute('CREATE INDEX idx_neg_samples_pattern ON sms_negative_samples(pattern_type)');
          AppLogger.db('migration_v24', detail: 'sms_negative_samples table created');
        }
      },
      onOpen: (db) async {
        // Run maintenance in background to avoid blocking splash screen
        _runAsyncMaintenance(db);
      },
    );
  }

  static Future<void> _runAsyncMaintenance(Database db) async {
    try {
      // For existing databases that might have empty categories table or missing subcategories
      final count = await db.rawQuery('SELECT COUNT(*) as count FROM categories');
      final subCount = await db.rawQuery('SELECT COUNT(*) as count FROM categories WHERE parent_id IS NOT NULL');
      
      if (count.isNotEmpty && subCount.isNotEmpty) {
        final categoryCount = (count.first['count'] as num?)?.toInt() ?? 0;
        final subcategoryCount = (subCount.first['count'] as num?)?.toInt() ?? 0;
        
        // Reseed if no categories at all, or if we have categories but no subcategories
        if (categoryCount == 0 || (categoryCount > 0 && subcategoryCount == 0)) {
          // Clear existing categories before reseeding
          await db.delete('categories');
          await _seedDefaultCategories(db);
        }
      }
      
      // Create performance indexes
      await DatabaseOptimizer.createIndexes(db);
    } catch (e) {
      AppLogger.log(LogLevel.error, LogCategory.database, 'Maintenance Error', detail: e.toString());
    }
  }

  static Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        last4 TEXT,
        due_date_day INTEGER,
        credit_limit REAL,
        institution_name TEXT,
        account_identifier TEXT,
        sms_keywords TEXT,
        account_alias TEXT,
        access_type TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        confidence_score_account REAL,
        requires_confirmation INTEGER DEFAULT 0,
        created_from_sms_date TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'uncategorized',
        note TEXT,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        recurring_id INTEGER REFERENCES recurring_transactions(id),
        sms_source TEXT,
        sms_id TEXT,
        source_type TEXT NOT NULL DEFAULT 'manual',
        merchant TEXT,
        confidence_score REAL,
        needs_review INTEGER DEFAULT 0,
        extracted_identifier TEXT,
        extracted_institution TEXT,
        linked_transaction_id INTEGER REFERENCES transactions(id),
        transfer_reference TEXT,
        recurring_group_id INTEGER REFERENCES recurring_patterns(id),
        is_recurring_candidate INTEGER DEFAULT 0,
        from_account_id INTEGER REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        deleted_at INTEGER
      )''');
    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        `limit` REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        deleted_at INTEGER,
        UNIQUE(category, month, year)
      )''');
    await db.execute('''
      CREATE TABLE recurring_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        account_id INTEGER REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        goal_id INTEGER REFERENCES savings_goals(id),
        frequency TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        deleted_at INTEGER
      )''');
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parent_id INTEGER REFERENCES categories(id),
        is_default INTEGER NOT NULL DEFAULT 0,
        icon TEXT NOT NULL DEFAULT '📁',
        color TEXT NOT NULL DEFAULT '#6C63FF'
      )''');
    await db.execute('''
      CREATE TABLE savings_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        target REAL NOT NULL,
        saved REAL NOT NULL DEFAULT 0,
        account_id INTEGER REFERENCES accounts(id),
        priority INTEGER NOT NULL DEFAULT 999,
        target_date TEXT,
        deleted_at INTEGER
      )''');
    
    // SMS Intelligence Engine tables
    await db.execute('''
      CREATE TABLE account_candidates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        institution_name TEXT,
        account_identifier TEXT,
        sms_keywords TEXT,
        suggested_type TEXT NOT NULL DEFAULT 'checking',
        confidence_score REAL NOT NULL DEFAULT 0.5,
        transaction_count INTEGER NOT NULL DEFAULT 1,
        first_seen_date TEXT NOT NULL,
        last_seen_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        merged_into_account_id INTEGER REFERENCES accounts(id),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('''
      CREATE TABLE pending_actions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'medium',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        transaction_id INTEGER REFERENCES transactions(id),
        account_candidate_id INTEGER REFERENCES account_candidates(id),
        sms_source TEXT,
        metadata TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        resolved_at TEXT,
        resolution_action TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE recurring_patterns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        average_amount REAL NOT NULL,
        amount_variance REAL NOT NULL,
        frequency TEXT NOT NULL,
        interval_days INTEGER NOT NULL,
        occurrence_count INTEGER NOT NULL,
        confidence_score REAL NOT NULL,
        first_occurrence TEXT NOT NULL,
        last_occurrence TEXT NOT NULL,
        next_expected_date TEXT,
        transaction_ids TEXT NOT NULL,
        account_id INTEGER REFERENCES accounts(id),
        status TEXT NOT NULL DEFAULT 'candidate',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('''
      CREATE TABLE sms_templates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        institution_name TEXT NOT NULL,
        sender_patterns TEXT NOT NULL,
        message_pattern TEXT NOT NULL,
        amount_pattern TEXT,
        merchant_pattern TEXT,
        account_id_pattern TEXT,
        balance_pattern TEXT,
        transaction_type TEXT NOT NULL,
        match_count INTEGER NOT NULL DEFAULT 0,
        user_confirmations INTEGER NOT NULL DEFAULT 0,
        user_rejections INTEGER NOT NULL DEFAULT 0,
        accuracy REAL NOT NULL DEFAULT 0.5,
        is_user_created INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_used TEXT
      )''');
    await db.execute('''
      CREATE TABLE transfer_pairs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
        credit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
        amount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        source_account_id INTEGER NOT NULL REFERENCES accounts(id),
        destination_account_id INTEGER NOT NULL REFERENCES accounts(id),
        confidence_score REAL NOT NULL,
        detection_method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'detected',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('''
      CREATE TABLE merchant_mappings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        extracted_name TEXT NOT NULL,
        correct_name TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(extracted_name, correct_name)
      )''');
    
    await db.execute('''CREATE TABLE sms_classification_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_type TEXT NOT NULL,
        keywords TEXT NOT NULL,
        normalized_merchants TEXT,
        category TEXT,
        transaction_type TEXT,
        confidence REAL DEFAULT 1.0,
        correct_count INTEGER DEFAULT 0,
        incorrect_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER,
        source TEXT DEFAULT 'user',
        is_active INTEGER DEFAULT 1
      )''');
    
    await db.execute('''CREATE TABLE sms_rule_index(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL,
        rule_id INTEGER NOT NULL,
        UNIQUE(keyword, rule_id),
        FOREIGN KEY(rule_id) REFERENCES sms_classification_rules(id) ON DELETE CASCADE
      )''');
    
    await db.execute('''CREATE TABLE sms_pattern_cache(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern_signature TEXT NOT NULL UNIQUE,
        category TEXT,
        transaction_type TEXT,
        matched_rule_ids TEXT,
        hit_count INTEGER DEFAULT 1,
        last_hit_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    
    await db.execute('''CREATE TABLE merchant_normalizations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_name TEXT NOT NULL UNIQUE,
        normalized_name TEXT NOT NULL,
        frequency INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL
      )''');
    
    await db.execute('''CREATE TABLE feedback_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        feedback_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
      )''');
    
    await db.execute('''CREATE TABLE merchant_normalization_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_pattern TEXT NOT NULL UNIQUE,
        normalized_name TEXT NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 1,
        success_count INTEGER NOT NULL DEFAULT 1,
        confidence REAL NOT NULL DEFAULT 1.0,
        last_used_at TEXT NOT NULL
      )''');
    await db.execute('''CREATE TABLE merchant_category_map(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL UNIQUE,
        category TEXT NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 1,
        confidence REAL NOT NULL DEFAULT 1.0,
        last_used_at TEXT NOT NULL
      )''');
    await db.execute('''CREATE TABLE signal_weights(
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        signal TEXT    NOT NULL UNIQUE,
        weight REAL    NOT NULL
      )''');
    await db.execute('''CREATE TABLE user_account_confirmations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        institution TEXT,
        merchant TEXT,
        sender_id TEXT,
        confirmed INTEGER NOT NULL,
        confidence_before REAL,
        confirmation_date TEXT NOT NULL,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )''');
    await db.execute('''CREATE TABLE user_corrections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        field_name TEXT NOT NULL,
        original_value TEXT,
        corrected_value TEXT,
        correction_date TEXT NOT NULL,
        sms_text TEXT,
        feedback_type TEXT NOT NULL,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )''');
    await db.execute('''CREATE TABLE parsing_feedback(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        field_name TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        feedback_date TEXT NOT NULL,
        sms_text TEXT,
        extracted_value TEXT,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )''');
    await db.execute('''CREATE TABLE feedback_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        outcome TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )''');

    await db.execute('''CREATE TABLE IF NOT EXISTS sms_negative_samples(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        pattern_type TEXT NOT NULL,
        length_bucket INTEGER NOT NULL,
        has_number INTEGER NOT NULL DEFAULT 0,
        has_url INTEGER NOT NULL DEFAULT 0,
        original_sms TEXT,
        created_at INTEGER NOT NULL
      )''');
    
    // Seed default categories
    await _seedDefaultCategories(db);

    // Seed default signal weights
    const defaultSignalWeights = {
      'has_amount':           0.40,
      'has_account':          0.20,
      'has_bank':             0.10,
      'has_merchant':         0.10,
      'has_transaction_verb': 0.20,
    };
    for (final entry in defaultSignalWeights.entries) {
      await db.insert('signal_weights', {
        'signal': entry.key,
        'weight': entry.value,
      });
    }
  }

  static Future<void> _seedDefaultCategories(Database db) async {
    // Import categories from kDefaultCategories with subcategories
    for (final catDef in kDefaultCategories) {
      // Insert parent category
      final parentId = await db.insert('categories', {
        'name': catDef.name,
        'icon': catDef.icon,
        'color': catDef.color,
        'is_default': 1,
        'parent_id': null,
      });
      
      // Insert subcategories
      for (final subName in catDef.subs) {
        await db.insert('categories', {
          'name': subName,
          'icon': catDef.icon,
          'color': catDef.color,
          'is_default': 1,
          'parent_id': parentId,
        });
      }
    }
  }

  /// Seed account extraction rules from external seed file
  static Future<void> _seedAccountExtractionRules(Database db) async {
    // Bank name extraction rules (US and Indian banks)
    await AccountExtractionSeed.seedBankRules(db);
    
    // Account identifier patterns (card endings, account numbers, etc.)
    await AccountExtractionSeed.seedIdentifierRules(db);
    
    // Bank name normalizations (variations -> canonical)
    await AccountExtractionSeed.seedBankNormalizations(db);
  }

  /// Seed SMS keywords from external seed file
  static Future<void> _seedSmsKeywords(Database db) async {
    await SmsKeywordsSeed.seedKeywords(db);
  }

  /// Seed merchant categories from external seed file
  static Future<void> _seedMerchantCategories(Database db) async {
    await SmsKeywordsSeed.seedMerchantCategories(db);
  }

  /// Seed bank/payment app sender ID patterns from external seed file
  static Future<void> _seedSenderPatterns(Database db) async {
    await SmsKeywordsSeed.seedSenderPatterns(db);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  static Future<List<Category>> getCategories() async {
    final rows = await (await db()).query('categories',
        orderBy: 'parent_id ASC, name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<List<Category>> getTopLevelCategories() async {
    final rows = await (await db()).query('categories',
        where: 'parent_id IS NULL', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<List<Category>> getSubcategories(int parentId) async {
    final rows = await (await db()).query('categories',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<int> insertCategory(Category c) async =>
      (await db()).insert('categories', c.toMap()..remove('id'));

  static Future<void> updateCategory(Category c) async =>
      (await db()).update('categories', c.toMap(),
          where: 'id = ?', whereArgs: [c.id]);

  static Future<void> deleteCategory(int id) async {
    final d = await db();
    await d.delete('categories', where: 'parent_id = ?', whereArgs: [id]);
    await d.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Accounts ────────────────────────────────────────────────────────────────

  static Future<int> insertAccount(Account a) async =>
      (await db()).insert('accounts', a.toMap()..remove('id'));

  static Future<List<Account>> getAccounts() async {
    final rows = await (await db()).query('accounts',
        where: 'deleted_at IS NULL',
        orderBy: 'name ASC');
    return rows.map(Account.fromMap).toList();
  }

  /// Find account by institution and identifier (for SMS auto-linking)
  static Future<Account?> findAccountByIdentity({
    String? institutionName,
    String? accountIdentifier,
  }) async {
    if (institutionName == null && accountIdentifier == null) return null;
    
    final d = await db();
    
    // Try exact match first (both institution and identifier)
    if (institutionName != null && accountIdentifier != null) {
      final results = await d.query(
        'accounts',
        where: 'institution_name = ? AND account_identifier = ? AND deleted_at IS NULL',
        whereArgs: [institutionName, accountIdentifier],
        limit: 1,
      );
      if (results.isNotEmpty) return Account.fromMap(results.first);
    }
    
    // Try identifier only
    if (accountIdentifier != null) {
      final results = await d.query(
        'accounts',
        where: 'account_identifier = ? AND deleted_at IS NULL',
        whereArgs: [accountIdentifier],
        limit: 1,
      );
      if (results.isNotEmpty) return Account.fromMap(results.first);
    }
    
    // Try institution only
    if (institutionName != null) {
      final results = await d.query(
        'accounts',
        where: 'institution_name = ? AND deleted_at IS NULL',
        whereArgs: [institutionName],
        limit: 1,
      );
      if (results.isNotEmpty) return Account.fromMap(results.first);
    }
    
    return null;
  }

  static Future<void> updateAccount(Account a) async =>
      (await db()).update('accounts', a.toMap(), where: 'id=?', whereArgs: [a.id]);

  /// Soft delete account (marks as deleted, doesn't remove)
  static Future<void> deleteAccount(int id) async {
    final d = await db();
    await d.update('accounts',
        {'deleted_at': SoftDeleteHelper.now()},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteAccount', detail: 'id=$id');
  }

  /// Restore soft-deleted account
  static Future<void> restoreAccount(int id) async {
    await (await db()).update('accounts',
        {'deleted_at': null},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreAccount', detail: 'id=$id');
  }

  /// Permanently delete account (cannot be undone)
  /// ⚠️ Will throw if account has transactions - use soft delete instead
  static Future<void> permanentlyDeleteAccount(int id) async {
    final d = await db();
    
    // Check if account has transactions
    final txnCount = await d.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE account_id = ?',
      [id],
    );
    final count = (txnCount.first['count'] as int?) ?? 0;
    
    if (count > 0) {
      throw Exception(
        'Cannot delete account with transactions. '
        'Account has $count transaction(s). Use soft delete instead.'
      );
    }
    
    await d.delete('accounts', where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteAccount', detail: 'id=$id');
  }

  /// Transfer money from one account to another.
  /// Records an expense on [fromId] and income on [toId].
  static Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final d = await db();
    final now = date ?? DateTime.now();
    final memo = note ?? 'transfer';
    await d.transaction((txn) async {
      await txn.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': 'transfer',
        'note': memo,
        'date': now.toIso8601String(),
        'account_id': fromId,
        'from_account_id': fromId,
        'to_account_id': toId,
      });
      await txn.insert('transactions', {
        'type': 'income',
        'amount': amount,
        'category': 'transfer',
        'note': memo,
        'date': now.toIso8601String(),
        'account_id': toId,
        'from_account_id': fromId,
        'to_account_id': toId,
      });
    });
    
    // Validate transfer integrity after creation
    final isValid = await validateTransferIntegrity();
    if (!isValid) {
      AppLogger.warn(
        'Transfer created but integrity check failed',
        detail: 'Amount: \$${amount.toStringAsFixed(2)}, From: $fromId, To: $toId',
        category: LogCategory.database
      );
    }
  }

  /// Validate transfer integrity
  /// Ensures that sum of all transfers has zero net impact on total net worth
  /// Returns true if valid, false if there's an integrity violation
  static Future<bool> validateTransferIntegrity() async {
    final d = await db();
    
    // Sum all transfer expenses (money leaving accounts)
    final transferExpenses = await d.rawQuery(
      "SELECT SUM(amount) as total FROM transactions "
      "WHERE deleted_at IS NULL AND category = 'transfer' AND type = 'expense'",
    );
    
    // Sum all transfer income (money entering accounts)
    final transferIncome = await d.rawQuery(
      "SELECT SUM(amount) as total FROM transactions "
      "WHERE deleted_at IS NULL AND category = 'transfer' AND type = 'income'",
    );
    
    final expenseTotal = (transferExpenses.first['total'] as num?)?.toDouble() ?? 0;
    final incomeTotal = (transferIncome.first['total'] as num?)?.toDouble() ?? 0;
    
    // Transfers are valid if expense total equals income total (net = 0)
    final difference = (expenseTotal - incomeTotal).abs();
    final isValid = difference < 0.01; // Allow for floating point precision
    
    if (!isValid) {
      AppLogger.err(
        'Transfer integrity violation',
        'Expense: \$${expenseTotal.toStringAsFixed(2)}, '
        'Income: \$${incomeTotal.toStringAsFixed(2)}, '
        'Difference: \$${difference.toStringAsFixed(2)}',
        category: LogCategory.database
      );
    }
    
    return isValid;
  }

  /// Running balance = opening balance + income − expenses for that account.
  /// Liabilities (credit_card, loan): opening balance is amount owed; expenses add to it.
  /// Assets (checking, savings, etc): opening balance increases with income.
  static Future<double> accountBalance(int accountId, Account account) async {
    final d = await db();
    final income = await d.rawQuery(
      "SELECT SUM(amount) as t FROM transactions WHERE deleted_at IS NULL AND account_id=? AND type='income'",
      [accountId],
    );
    final expense = await d.rawQuery(
      "SELECT SUM(amount) as t FROM transactions WHERE deleted_at IS NULL AND account_id=? AND type='expense'",
      [accountId],
    );
    final i = (income.first['t'] as num?)?.toDouble() ?? 0;
    final e = (expense.first['t'] as num?)?.toDouble() ?? 0;
    
    // Standardized formula based on account type
    if (account.isLiability) {
      // Liabilities: expenses increase debt, income reduces debt
      return account.balance + e - i;
    } else {
      // Assets: income increases balance, expenses decrease balance
      return account.balance + i - e;
    }
  }

  // ── Transactions ─────────────────────────────────────────────────────────────

  static Future<int> insertTransaction(model.Transaction t) async {
    // ⚠️ CRITICAL: Validate transaction integrity before insert
    // Prevents accounting corruption (Rule A: No transaction without accountId)
    await DataIntegrityService.validateTransactionBeforeInsert(t);
    
    final d = await db();
    final id = await d.insert('transactions', t.toMap()..remove('id'));
    AppLogger.db('insertTransaction', detail: '${t.type} \$${t.amount} ${t.category}');
    
    // Trigger notifications
    final transactionWithId = model.Transaction(
      id: id,
      type: t.type,
      amount: t.amount,
      category: t.category,
      note: t.note,
      date: t.date,
      accountId: t.accountId,
      recurringId: t.recurringId,
      smsSource: t.smsSource,
    );
    
    // Show transaction notification
    NotificationService.notifyTransaction(transactionWithId);
    
    // Check budget warnings for expenses
    if (t.type == 'expense') {
      NotificationService.checkBudgetWarnings(t.category, t.date);
    }
    
    return id;
  }

  /// Update existing transaction
  /// 
  /// ⚠️ DEPRECATION WARNING: Updating transactions violates immutability principle.
  /// Transactions should be immutable ledger entries.
  /// 
  /// Acceptable use cases:
  /// - Updating metadata (needsReview, userDisputed, confidenceScore)
  /// - Fixing data entry errors with audit trail
  ///
  /// For amount/type/accountId changes, consider:
  /// 1. Soft delete old transaction
  /// 2. Create new corrected transaction
  /// This preserves audit trail and maintains true immutability.
  static Future<void> updateTransaction(model.Transaction t) async {
    if (t.id == null) {
      throw ArgumentError('Transaction ID is required for updates');
    }
    
    await (await db()).update('transactions', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    AppLogger.db('updateTransaction', detail: 'id=${t.id} ${t.type} \$${t.amount}');
  }

  /// Soft delete transaction
  static Future<void> deleteTransaction(int id) async {
    await (await db()).update('transactions',
        {'deleted_at': SoftDeleteHelper.now()},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteTransaction', detail: 'id=$id');
  }

  /// Restore soft-deleted transaction
  static Future<void> restoreTransaction(int id) async {
    await (await db()).update('transactions',
        {'deleted_at': null},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreTransaction', detail: 'id=$id');
  }

  /// Permanently delete transaction (cannot be undone)
  static Future<void> permanentlyDeleteTransaction(int id) async {
    await (await db()).delete('transactions', where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteTransaction', detail: 'id=$id');
  }

  static Future<List<model.Transaction>> getTransactions({
    String? type,
    DateTime? from,
    DateTime? to,
    String? keyword,
    int? accountId,
  }) async {
    final d = await db();
    final where = <String>['deleted_at IS NULL'];
    final args = <dynamic>[];
    if (type != null) { where.add('type = ?'); args.add(type); }
    if (from != null) { where.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null) { where.add('date <= ?'); args.add(to.toIso8601String()); }
    if (keyword != null) {
      where.add('(category LIKE ? OR note LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }
    if (accountId != null) { where.add('account_id = ?'); args.add(accountId); }
    final rows = await d.query(
      'transactions',
      where: where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map(model.Transaction.fromMap).toList();
  }

  static Future<double> monthlyTotal(String type, int month, int year) async {
    final d = await db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final result = await d.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE deleted_at IS NULL AND type=? AND date>=? AND date<? AND category != 'transfer'",
      [type, start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  static Future<Map<String, double>> monthlyExpenseByCategory(int month, int year) async {
    final d = await db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    final rows = await d.rawQuery(
      'SELECT LOWER(category) as category, SUM(amount) as total FROM transactions '
      "WHERE deleted_at IS NULL AND type='expense' AND category != 'transfer' AND date>=? AND date<? GROUP BY LOWER(category)",
      [start, end],
    );
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0
    };
  }

  /// Returns the sum of [type] transactions in a custom date range.
  static Future<double> rangeTotal(String type, DateTime from, DateTime to) async {
    final d = await db();
    final result = await d.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE deleted_at IS NULL AND type=? AND date>=? AND date<=? AND category != 'transfer'",
      [type, from.toIso8601String(), to.toIso8601String()],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Returns a map of category -> total for expenses in a custom date range.
  static Future<Map<String, double>> rangeExpenseByCategory(DateTime from, DateTime to) async {
    final d = await db();
    final rows = await d.rawQuery(
      'SELECT LOWER(category) as category, SUM(amount) as total FROM transactions '
      "WHERE deleted_at IS NULL AND type='expense' AND category != 'transfer' AND date>=? AND date<=? GROUP BY LOWER(category)",
      [from.toIso8601String(), to.toIso8601String()],
    );
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0
    };
  }

  // ── Budgets ──────────────────────────────────────────────────────────────────

  static Future<void> upsertBudget(Budget b) async =>
      (await db()).insert('budgets', b.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Budget>> getBudgets(int month, int year) async {
    final rows = await (await db()).query('budgets',
        where: 'deleted_at IS NULL AND month=? AND year=?',
        whereArgs: [month, year]);
    return rows.map(Budget.fromMap).toList();
  }

  // ── Savings ──────────────────────────────────────────────────────────────────

  static Future<int> insertGoal(SavingsGoal g) async =>
      (await db()).insert('savings_goals', g.toMap()..remove('id'));

  static Future<List<SavingsGoal>> getGoals() async {
    final rows = await (await db()).query('savings_goals',
        where: 'deleted_at IS NULL',
        orderBy: 'priority ASC, name ASC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  static Future<void> updateGoal(SavingsGoal g) async =>
      (await db()).update('savings_goals', g.toMap(), where: 'id=?', whereArgs: [g.id]);

  static Future<void> updateGoalSaved(int id, double saved) async =>
      (await db()).update('savings_goals', {'saved': saved}, where: 'id=?', whereArgs: [id]);

  /// Soft delete savings goal
  static Future<void> deleteGoal(int id) async {
    await (await db()).update('savings_goals',
        {'deleted_at': SoftDeleteHelper.now()},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteGoal', detail: 'id=$id');
  }

  /// Restore soft-deleted goal
  static Future<void> restoreGoal(int id) async {
    await (await db()).update('savings_goals',
        {'deleted_at': null},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreGoal', detail: 'id=$id');
  }

  /// Permanently delete goal (cannot be undone)
  static Future<void> permanentlyDeleteGoal(int id) async {
    await (await db()).delete('savings_goals', where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteGoal', detail: 'id=$id');
  }

  // ── Recurring Transactions ───────────────────────────────────────────────────

  static Future<int> insertRecurring(RecurringTransaction r) async =>
      (await db()).insert('recurring_transactions', r.toMap()..remove('id'));

  static Future<List<RecurringTransaction>> getRecurring() async {
    final rows = await (await db()).query('recurring_transactions',
        where: 'deleted_at IS NULL',
        orderBy: 'next_due_date ASC');
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  static Future<void> updateRecurring(RecurringTransaction r) async =>
      (await db()).update('recurring_transactions', r.toMap(),
          where: 'id=?', whereArgs: [r.id]);

  /// Soft delete recurring transaction
  static Future<void> deleteRecurring(int id) async {
    await (await db()).update('recurring_transactions',
        {'deleted_at': SoftDeleteHelper.now()},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('softDeleteRecurring', detail: 'id=$id');
  }

  /// Restore soft-deleted recurring transaction
  static Future<void> restoreRecurring(int id) async {
    await (await db()).update('recurring_transactions',
        {'deleted_at': null},
        where: 'id=?', whereArgs: [id]);
    AppLogger.db('restoreRecurring', detail: 'id=$id');
  }

  /// Permanently delete recurring transaction (cannot be undone)
  static Future<void> permanentlyDeleteRecurring(int id) async {
    await (await db()).delete('recurring_transactions', where: 'id=?', whereArgs: [id]);
    AppLogger.db('permanentlyDeleteRecurring', detail: 'id=$id');
  }

  // ── Export ───────────────────────────────────────────────────────────────────

  /// Get statistics about deleted items
  static Future<DeletedItemsStats> getDeletedItemsStats() async {
    final d = await db();
    
    final txnCount = await d.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE deleted_at IS NOT NULL'
    );
    final accountCount = await d.rawQuery(
      'SELECT COUNT(*) as count FROM accounts WHERE deleted_at IS NOT NULL'
    );
    final budgetCount = await d.rawQuery(
      'SELECT COUNT(*) as count FROM budgets WHERE deleted_at IS NOT NULL'
    );
    final goalCount = await d.rawQuery(
      'SELECT COUNT(*) as count FROM savings_goals WHERE deleted_at IS NOT NULL'
    );
    final recurringCount = await d.rawQuery(
      'SELECT COUNT(*) as count FROM recurring_transactions WHERE deleted_at IS NOT NULL'
    );
    
    return DeletedItemsStats(
      transactions: (txnCount.first['count'] as num?)?.toInt() ?? 0,
      accounts: (accountCount.first['count'] as num?)?.toInt() ?? 0,
      budgets: (budgetCount.first['count'] as num?)?.toInt() ?? 0,
      goals: (goalCount.first['count'] as num?)?.toInt() ?? 0,
      recurring: (recurringCount.first['count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Get all deleted transactions
  static Future<List<model.Transaction>> getDeletedTransactions() async {
    final rows = await (await db()).query('transactions',
        where: 'deleted_at IS NOT NULL',
        orderBy: 'deleted_at DESC');
    return rows.map(model.Transaction.fromMap).toList();
  }

  /// Get all deleted accounts
  static Future<List<Account>> getDeletedAccounts() async {
    final rows = await (await db()).query('accounts',
        where: 'deleted_at IS NOT NULL',
        orderBy: 'deleted_at DESC');
    return rows.map(Account.fromMap).toList();
  }

  /// Get all deleted goals
  static Future<List<SavingsGoal>> getDeletedGoals() async {
    final rows = await (await db()).query('savings_goals',
        where: 'deleted_at IS NOT NULL',
        orderBy: 'deleted_at DESC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  /// Get all deleted recurring transactions
  static Future<List<RecurringTransaction>> getDeletedRecurring() async {
    final rows = await (await db()).query('recurring_transactions',
        where: 'deleted_at IS NOT NULL',
        orderBy: 'deleted_at DESC');
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  /// Purge old deleted items (default: older than 30 days)
  static Future<int> purgeOldDeletedItems({int retentionDays = 30}) async {
    final d = await db();
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    
    int totalPurged = 0;
    totalPurged += await d.delete('transactions',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff]);
    totalPurged += await d.delete('accounts',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff]);
    totalPurged += await d.delete('budgets',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff]);
    totalPurged += await d.delete('savings_goals',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff]);
    totalPurged += await d.delete('recurring_transactions',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff]);
    
    AppLogger.db('purgeOldDeletedItems',
        detail: 'Purged $totalPurged items older than $retentionDays days');
    return totalPurged;
  }

  // ── Export ───────────────────────────────────────────────────────────────────

  static Future<void> deleteAllData() async {
    AppLogger.userAction('deleteAllData', detail: 'All data wiped');
    final d = await db();
    await d.transaction((txn) async {
      await txn.delete('recurring_transactions');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('accounts');
    });
  }

  static Future<String> exportCsv() async {
    final txns = await getTransactions();
    final accounts = await getAccounts();
    final accountMap = {for (final a in accounts) a.id: a.name};
    final lines = ['type,amount,category,note,date,account'];
    for (final t in txns) {
      lines.add(
        '${t.type},${t.amount},${t.category},'
        '${t.note ?? ''},${t.date.toIso8601String()},'
        '${accountMap[t.accountId] ?? ''}',
      );
    }
    return lines.join('\n');
  }
}

