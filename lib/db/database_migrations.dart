part of 'database.dart';

// ── Migrations: incremental schema upgrades ───────────────────────────────────

extension _AppDatabaseMigrations on AppDatabase {
  static Future<void> _migrate(Database db, int oldVersion) async {
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
      await db.execute('ALTER TABLE savings_goals ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN priority INTEGER NOT NULL DEFAULT 999');
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
      await _AppDatabaseSchema._seedDefaultCategories(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE transactions ADD COLUMN recurring_id INTEGER REFERENCES recurring_transactions(id)');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN to_account_id INTEGER REFERENCES accounts(id)');
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN goal_id INTEGER REFERENCES savings_goals(id)');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE accounts ADD COLUMN due_date_day INTEGER');
      await db.execute('ALTER TABLE accounts ADD COLUMN credit_limit REAL');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE transactions ADD COLUMN deleted_at INTEGER');
      await db.execute('ALTER TABLE accounts ADD COLUMN deleted_at INTEGER');
      await db.execute('ALTER TABLE budgets ADD COLUMN deleted_at INTEGER');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN deleted_at INTEGER');
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN deleted_at INTEGER');
      await db.execute('CREATE INDEX idx_transactions_deleted ON transactions(deleted_at)');
      await db.execute('CREATE INDEX idx_accounts_deleted ON accounts(deleted_at)');
      await db.execute('CREATE INDEX idx_budgets_deleted ON budgets(deleted_at)');
      await db.execute('CREATE INDEX idx_goals_deleted ON savings_goals(deleted_at)');
      await db.execute('CREATE INDEX idx_recurring_deleted ON recurring_transactions(deleted_at)');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE transactions ADD COLUMN sms_source TEXT');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE accounts ADD COLUMN institution_name TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN account_identifier TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN sms_keywords TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN account_alias TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN source_type TEXT NOT NULL DEFAULT "manual"');
      await db.execute('ALTER TABLE transactions ADD COLUMN merchant TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN confidence_score REAL');
      await db.execute('ALTER TABLE transactions ADD COLUMN needs_review INTEGER DEFAULT 0');
      await db.execute('CREATE INDEX idx_accounts_institution ON accounts(institution_name)');
      await db.execute('CREATE INDEX idx_accounts_identifier ON accounts(account_identifier)');
      await db.execute('CREATE INDEX idx_transactions_needs_review ON transactions(needs_review)');
      await db.execute('CREATE INDEX idx_transactions_source_type ON transactions(source_type)');
      await db.execute('CREATE INDEX idx_transactions_merchant ON transactions(merchant)');
      await db.execute('UPDATE transactions SET source_type = "manual" WHERE source_type IS NULL');
      await db.execute('UPDATE accounts SET account_identifier = "****" || last4 WHERE last4 IS NOT NULL AND account_identifier IS NULL');
    }
    if (oldVersion < 12) {
      await db.execute('''CREATE TABLE IF NOT EXISTS account_candidates(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          institution_name TEXT, account_identifier TEXT, sms_keywords TEXT,
          suggested_type TEXT NOT NULL DEFAULT 'checking',
          confidence_score REAL NOT NULL DEFAULT 0.5,
          transaction_count INTEGER NOT NULL DEFAULT 1,
          first_seen_date TEXT NOT NULL, last_seen_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          merged_into_account_id INTEGER REFERENCES accounts(id),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )''');
      await db.execute('CREATE INDEX idx_account_candidates_status ON account_candidates(status)');
      await db.execute('CREATE INDEX idx_account_candidates_institution ON account_candidates(institution_name)');
      await db.execute('''CREATE TABLE IF NOT EXISTS pending_actions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_type TEXT NOT NULL, priority TEXT NOT NULL DEFAULT 'medium',
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          transaction_id INTEGER REFERENCES transactions(id),
          account_candidate_id INTEGER REFERENCES account_candidates(id),
          sms_source TEXT, metadata TEXT, confidence REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'pending', resolved_at TEXT, resolution_action TEXT,
          title TEXT NOT NULL, description TEXT NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_pending_actions_status ON pending_actions(status)');
      await db.execute('CREATE INDEX idx_pending_actions_priority ON pending_actions(priority)');
      await db.execute('CREATE INDEX idx_pending_actions_type ON pending_actions(action_type)');
      await db.execute('''CREATE TABLE IF NOT EXISTS recurring_patterns(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          merchant TEXT, category TEXT NOT NULL, type TEXT NOT NULL,
          average_amount REAL NOT NULL, amount_variance REAL NOT NULL,
          frequency TEXT NOT NULL, interval_days INTEGER NOT NULL,
          occurrence_count INTEGER NOT NULL, confidence_score REAL NOT NULL,
          first_occurrence TEXT NOT NULL, last_occurrence TEXT NOT NULL,
          next_expected_date TEXT, transaction_ids TEXT NOT NULL,
          account_id INTEGER REFERENCES accounts(id),
          status TEXT NOT NULL DEFAULT 'candidate',
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )''');
      await db.execute('CREATE INDEX idx_recurring_patterns_merchant ON recurring_patterns(merchant)');
      await db.execute('CREATE INDEX idx_recurring_patterns_status ON recurring_patterns(status)');
      await db.execute('CREATE INDEX idx_recurring_patterns_next_date ON recurring_patterns(next_expected_date)');
      await db.execute('''CREATE TABLE IF NOT EXISTS sms_templates(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          institution_name TEXT NOT NULL, sender_patterns TEXT NOT NULL,
          message_pattern TEXT NOT NULL, amount_pattern TEXT,
          merchant_pattern TEXT, account_id_pattern TEXT, balance_pattern TEXT,
          transaction_type TEXT NOT NULL,
          match_count INTEGER NOT NULL DEFAULT 0,
          user_confirmations INTEGER NOT NULL DEFAULT 0,
          user_rejections INTEGER NOT NULL DEFAULT 0,
          accuracy REAL NOT NULL DEFAULT 0.5, is_user_created INTEGER DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, last_used TEXT
        )''');
      await db.execute('CREATE INDEX idx_sms_templates_institution ON sms_templates(institution_name)');
      await db.execute('CREATE INDEX idx_sms_templates_accuracy ON sms_templates(accuracy)');
      await db.execute('''CREATE TABLE IF NOT EXISTS transfer_pairs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          debit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
          credit_transaction_id INTEGER NOT NULL REFERENCES transactions(id),
          amount REAL NOT NULL, timestamp TEXT NOT NULL,
          source_account_id INTEGER NOT NULL REFERENCES accounts(id),
          destination_account_id INTEGER NOT NULL REFERENCES accounts(id),
          confidence_score REAL NOT NULL, detection_method TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'detected',
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )''');
      await db.execute('CREATE INDEX idx_transfer_pairs_status ON transfer_pairs(status)');
      await db.execute('CREATE INDEX idx_transfer_pairs_debit ON transfer_pairs(debit_transaction_id)');
      await db.execute('CREATE INDEX idx_transfer_pairs_credit ON transfer_pairs(credit_transaction_id)');
      await db.execute('''CREATE TABLE IF NOT EXISTS merchant_mappings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          extracted_name TEXT NOT NULL, correct_name TEXT NOT NULL,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(extracted_name, correct_name)
        )''');
      await db.execute('CREATE INDEX idx_merchant_mappings_extracted ON merchant_mappings(extracted_name)');
      await db.execute('ALTER TABLE transactions ADD COLUMN sms_id TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN extracted_identifier TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN extracted_institution TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN linked_transaction_id INTEGER REFERENCES transactions(id)');
      await db.execute('ALTER TABLE transactions ADD COLUMN transfer_reference TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN recurring_group_id INTEGER REFERENCES recurring_patterns(id)');
      await db.execute('ALTER TABLE transactions ADD COLUMN is_recurring_candidate INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE accounts ADD COLUMN source TEXT NOT NULL DEFAULT "manual"');
      await db.execute('ALTER TABLE accounts ADD COLUMN confidence_score_account REAL');
      await db.execute('ALTER TABLE accounts ADD COLUMN requires_confirmation INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE accounts ADD COLUMN created_from_sms_date TEXT');
      await db.execute('CREATE INDEX idx_transactions_sms_id ON transactions(sms_id)');
      await db.execute('CREATE INDEX idx_transactions_linked ON transactions(linked_transaction_id)');
      await db.execute('CREATE INDEX idx_transactions_recurring_group ON transactions(recurring_group_id)');
      await db.execute('CREATE INDEX idx_accounts_source ON accounts(source)');
    }
    if (oldVersion < 13) {
      await db.execute('''CREATE TABLE IF NOT EXISTS sms_classification_rules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rule_type TEXT NOT NULL, keywords TEXT NOT NULL,
          normalized_merchants TEXT, category TEXT, transaction_type TEXT,
          confidence REAL DEFAULT 1.0, correct_count INTEGER DEFAULT 0,
          incorrect_count INTEGER DEFAULT 0, created_at INTEGER NOT NULL,
          last_used_at INTEGER, source TEXT DEFAULT 'user', is_active INTEGER DEFAULT 1
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS sms_rule_index(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          keyword TEXT NOT NULL, rule_id INTEGER NOT NULL,
          UNIQUE(keyword, rule_id),
          FOREIGN KEY(rule_id) REFERENCES sms_classification_rules(id) ON DELETE CASCADE
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS sms_pattern_cache(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pattern_signature TEXT NOT NULL UNIQUE, category TEXT,
          transaction_type TEXT, matched_rule_ids TEXT,
          hit_count INTEGER DEFAULT 1, last_hit_at INTEGER NOT NULL, created_at INTEGER NOT NULL
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS merchant_normalizations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_name TEXT NOT NULL UNIQUE, normalized_name TEXT NOT NULL,
          frequency INTEGER DEFAULT 1, created_at INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_rule_index_keyword ON sms_rule_index(keyword)');
      await db.execute('CREATE INDEX idx_rule_index_rule ON sms_rule_index(rule_id)');
      await db.execute('CREATE INDEX idx_rules_active ON sms_classification_rules(is_active) WHERE is_active = 1');
      await db.execute('CREATE INDEX idx_rules_category ON sms_classification_rules(category)');
      await db.execute('CREATE INDEX idx_cache_signature ON sms_pattern_cache(pattern_signature)');
      await db.execute('CREATE INDEX idx_merchant_norm ON merchant_normalizations(normalized_name)');
      await db.execute('''CREATE TABLE IF NOT EXISTS feedback_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER, feedback_type TEXT NOT NULL, created_at INTEGER NOT NULL,
          FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
        )''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_type ON feedback_history(feedback_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_date ON feedback_history(created_at)');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE transactions ADD COLUMN user_disputed INTEGER DEFAULT 0');
      await db.execute('''CREATE TABLE IF NOT EXISTS feedback_events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL, event_type TEXT NOT NULL,
          outcome TEXT, created_at INTEGER NOT NULL,
          FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
        )''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_events_txn ON feedback_events(transaction_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_feedback_events_type ON feedback_events(event_type)');
    }
    if (oldVersion < 15) {
      await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_rules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rule_type TEXT NOT NULL, extraction_type TEXT NOT NULL,
          pattern TEXT NOT NULL, keywords TEXT NOT NULL, region TEXT,
          output_value TEXT, confidence REAL DEFAULT 1.0,
          correct_count INTEGER DEFAULT 0, incorrect_count INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL, last_used_at INTEGER,
          source TEXT DEFAULT 'system', is_active INTEGER DEFAULT 1, priority INTEGER DEFAULT 0
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_index(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          keyword TEXT NOT NULL, rule_id INTEGER NOT NULL,
          UNIQUE(keyword, rule_id),
          FOREIGN KEY(rule_id) REFERENCES account_extraction_rules(id) ON DELETE CASCADE
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS bank_normalizations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_name TEXT NOT NULL UNIQUE, normalized_name TEXT NOT NULL,
          region TEXT, frequency INTEGER DEFAULT 1, created_at INTEGER NOT NULL
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_feedback(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sms_text TEXT NOT NULL, extracted_bank TEXT, extracted_identifier TEXT,
          correct_bank TEXT, correct_identifier TEXT,
          feedback_type TEXT NOT NULL, created_at INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_extraction_index_keyword ON account_extraction_index(keyword)');
      await db.execute('CREATE INDEX idx_extraction_index_rule ON account_extraction_index(rule_id)');
      await db.execute('CREATE INDEX idx_extraction_rules_active ON account_extraction_rules(is_active) WHERE is_active = 1');
      await db.execute('CREATE INDEX idx_extraction_rules_type ON account_extraction_rules(extraction_type)');
      await db.execute('CREATE INDEX idx_extraction_rules_region ON account_extraction_rules(region)');
      await db.execute('CREATE INDEX idx_bank_norm_original ON bank_normalizations(original_name)');
      await db.execute('CREATE INDEX idx_bank_norm_normalized ON bank_normalizations(normalized_name)');
      await _AppDatabaseSchema._seedAccountExtractionRules(db);
    }
    if (oldVersion < 16) {
      await db.execute('''CREATE TABLE IF NOT EXISTS sms_keywords(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          keyword TEXT NOT NULL, type TEXT NOT NULL, region TEXT,
          confidence REAL DEFAULT 1.0, priority INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1, usage_count INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS merchant_categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          merchant_pattern TEXT NOT NULL, category TEXT NOT NULL,
          region TEXT, priority INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1, match_count INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_sms_keywords_type ON sms_keywords(type)');
      await db.execute('CREATE INDEX idx_sms_keywords_region ON sms_keywords(region)');
      await db.execute('CREATE INDEX idx_sms_keywords_active ON sms_keywords(is_active) WHERE is_active = 1');
      await db.execute('CREATE INDEX idx_merchant_categories_pattern ON merchant_categories(merchant_pattern)');
      await db.execute('CREATE INDEX idx_merchant_categories_region ON merchant_categories(region)');
      await db.execute('CREATE INDEX idx_merchant_categories_active ON merchant_categories(is_active) WHERE is_active = 1');
      await _AppDatabaseSchema._seedSmsKeywords(db);
      await _AppDatabaseSchema._seedMerchantCategories(db);
      await _AppDatabaseSchema._seedSenderPatterns(db);
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE transactions ADD COLUMN from_account_id INTEGER REFERENCES accounts(id)');
      await db.execute('ALTER TABLE transactions ADD COLUMN to_account_id INTEGER REFERENCES accounts(id)');
      await db.execute('CREATE INDEX idx_transactions_from_account ON transactions(from_account_id)');
      await db.execute('CREATE INDEX idx_transactions_to_account ON transactions(to_account_id)');
      await db.execute('''
        UPDATE transactions
        SET from_account_id = (SELECT source_account_id FROM transfer_pairs WHERE transfer_pairs.debit_transaction_id = transactions.id),
            to_account_id = (SELECT destination_account_id FROM transfer_pairs WHERE transfer_pairs.debit_transaction_id = transactions.id)
        WHERE id IN (SELECT debit_transaction_id FROM transfer_pairs)
      ''');
      await db.execute('''
        UPDATE transactions
        SET from_account_id = (SELECT source_account_id FROM transfer_pairs WHERE transfer_pairs.credit_transaction_id = transactions.id),
            to_account_id = (SELECT destination_account_id FROM transfer_pairs WHERE transfer_pairs.credit_transaction_id = transactions.id)
        WHERE id IN (SELECT credit_transaction_id FROM transfer_pairs)
      ''');
    }
    if (oldVersion < 18) {
      await db.execute('ALTER TABLE accounts ADD COLUMN access_type TEXT');
      await db.execute('CREATE INDEX idx_accounts_access_type ON accounts(access_type)');
    }
    if (oldVersion < 19) {
      final orphanedCount = await db.rawQuery('SELECT COUNT(*) as count FROM transactions WHERE account_id IS NULL');
      final count = (orphanedCount.first['count'] as int?) ?? 0;
      if (count > 0) {
        AppLogger.db('migration_v19', detail: 'Removing $count orphaned transactions');
        await db.delete('transactions', where: 'account_id IS NULL');
      }
      await db.execute("UPDATE transactions SET category = 'uncategorized' WHERE category IS NULL OR category = ''");
      AppLogger.db('migration_v19', detail: 'Enforced accountId NOT NULL and category defaults');
    }
    if (oldVersion < 20) {
      AppLogger.db('migration_v20', detail: 'Creating feedback learning tables');
      await db.execute('''CREATE TABLE IF NOT EXISTS user_account_confirmations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL, institution TEXT, merchant TEXT,
          sender_id TEXT, confirmed INTEGER NOT NULL, confidence_before REAL,
          confirmation_date TEXT NOT NULL,
          FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
        )''');
      await db.execute('CREATE INDEX idx_confirmations_txn ON user_account_confirmations(transaction_id)');
      await db.execute('CREATE INDEX idx_confirmations_merchant ON user_account_confirmations(merchant)');
      await db.execute('''CREATE TABLE IF NOT EXISTS user_corrections(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL, field_name TEXT NOT NULL,
          original_value TEXT, corrected_value TEXT, correction_date TEXT NOT NULL,
          sms_text TEXT, feedback_type TEXT NOT NULL,
          FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
        )''');
      await db.execute('CREATE INDEX idx_corrections_txn ON user_corrections(transaction_id)');
      await db.execute('CREATE INDEX idx_corrections_field ON user_corrections(field_name)');
      await db.execute('''CREATE TABLE IF NOT EXISTS parsing_feedback(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL, field_name TEXT NOT NULL,
          is_correct INTEGER NOT NULL, feedback_date TEXT NOT NULL,
          sms_text TEXT, extracted_value TEXT,
          FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
        )''');
      await db.execute('CREATE INDEX idx_feedback_txn ON parsing_feedback(transaction_id)');
      await db.execute('CREATE INDEX idx_feedback_field ON parsing_feedback(field_name)');
      AppLogger.db('migration_v20', detail: 'Feedback learning system ready');
    }
    if (oldVersion < 21) {
      AppLogger.db('migration_v21', detail: 'Creating adaptive learning tables');
      await db.execute('''CREATE TABLE IF NOT EXISTS merchant_normalization_rules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          raw_pattern TEXT NOT NULL UNIQUE, normalized_name TEXT NOT NULL,
          usage_count INTEGER NOT NULL DEFAULT 1, success_count INTEGER NOT NULL DEFAULT 1,
          confidence REAL NOT NULL DEFAULT 1.0, last_used_at TEXT NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_merchant_norm_rules_pattern ON merchant_normalization_rules(raw_pattern)');
      await db.execute('''CREATE TABLE IF NOT EXISTS merchant_category_map(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          merchant TEXT NOT NULL UNIQUE, category TEXT NOT NULL,
          usage_count INTEGER NOT NULL DEFAULT 1, confidence REAL NOT NULL DEFAULT 1.0,
          last_used_at TEXT NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_merchant_category_map_merchant ON merchant_category_map(merchant)');
      AppLogger.db('migration_v21', detail: 'Adaptive learning tables ready');
    }
    if (oldVersion < 22) {
      AppLogger.db('migration_v22', detail: 'Creating signal_weights table');
      await db.execute('''CREATE TABLE IF NOT EXISTS signal_weights(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          signal TEXT NOT NULL UNIQUE, weight REAL NOT NULL
        )''');
      const defaultWeights = {
        'has_amount': 0.40, 'has_account': 0.20, 'has_bank': 0.10,
        'has_merchant': 0.10, 'has_transaction_verb': 0.20,
      };
      for (final entry in defaultWeights.entries) {
        await db.insert('signal_weights', {'signal': entry.key, 'weight': entry.value});
      }
      AppLogger.db('migration_v22', detail: 'signal_weights table ready with defaults');
    }
    if (oldVersion < 23) {
      await db.execute("UPDATE accounts SET type = 'credit_card' WHERE type = 'credit'");
      await db.execute('ALTER TABLE savings_goals ADD COLUMN target_date TEXT');
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN end_date TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE accounts SET sort_order = id WHERE sort_order = 0');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)');
      AppLogger.db('migration_v23', detail: 'credit→credit_card, target_date, end_date, sort_order, indexes');
    }
    if (oldVersion < 24) {
      await db.execute('''CREATE TABLE IF NOT EXISTS sms_negative_samples(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender TEXT NOT NULL, pattern_type TEXT NOT NULL,
          length_bucket INTEGER NOT NULL, has_number INTEGER NOT NULL DEFAULT 0,
          has_url INTEGER NOT NULL DEFAULT 0, original_sms TEXT, created_at INTEGER NOT NULL
        )''');
      await db.execute('CREATE INDEX idx_neg_samples_sender ON sms_negative_samples(sender)');
      await db.execute('CREATE INDEX idx_neg_samples_pattern ON sms_negative_samples(pattern_type)');
      AppLogger.db('migration_v24', detail: 'sms_negative_samples table created');
    }
    if (oldVersion < 25) {
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN start_date TEXT');
      await db.execute('UPDATE recurring_transactions SET start_date = next_due_date WHERE start_date IS NULL');
      AppLogger.db('migration_v25', detail: 'recurring_transactions.start_date added');
    }
    if (oldVersion < 26) {
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN max_occurrences INTEGER');
      AppLogger.db('migration_v26', detail: 'recurring_transactions.max_occurrences added');
    }
    if (oldVersion < 27) {
      await db.execute('ALTER TABLE transactions ADD COLUMN rule_type TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN reference_rule_id INTEGER');
      await db.execute('''CREATE TABLE IF NOT EXISTS execution_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rule_type TEXT NOT NULL, rule_id INTEGER NOT NULL,
          execution_date TEXT NOT NULL,
          transaction_id INTEGER REFERENCES transactions(id),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(rule_type, rule_id, execution_date)
        )''');
      await db.execute('CREATE INDEX idx_execution_logs_rule ON execution_logs(rule_type, rule_id, execution_date)');
      AppLogger.db('migration_v27', detail: 'execution log + rule refs enabled');
    }
  }
}
