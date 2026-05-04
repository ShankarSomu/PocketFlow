part of 'database.dart';

// ── Schema: fresh-install table creation ─────────────────────────────────────

extension _AppDatabaseSchema on AppDatabase {
  static Future<void> _createAll(Database db) async {
    // Core financial tables
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        last4 TEXT,
        deleted_at INTEGER,
        institution_name TEXT,
        account_identifier TEXT,
        sms_keywords TEXT,
        account_alias TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        confidence_score_account REAL,
        requires_confirmation INTEGER DEFAULT 0,
        created_from_sms_date TEXT,
        due_date_day INTEGER,
        credit_limit REAL,
        access_type TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
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
        user_disputed INTEGER DEFAULT 0,
        extracted_identifier TEXT,
        extracted_institution TEXT,
        linked_transaction_id INTEGER REFERENCES transactions(id),
        transfer_reference TEXT,
        recurring_group_id INTEGER REFERENCES recurring_patterns(id),
        is_recurring_candidate INTEGER DEFAULT 0,
        from_account_id INTEGER REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        rule_type TEXT,
        reference_rule_id INTEGER,
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
        start_date TEXT,
        end_date TEXT,
        max_occurrences INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        deleted_at INTEGER
      )''');
    await db.execute('''
      CREATE TABLE execution_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_type TEXT NOT NULL,
        rule_id INTEGER NOT NULL,
        execution_date TEXT NOT NULL,
        transaction_id INTEGER REFERENCES transactions(id),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(rule_type, rule_id, execution_date)
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
        confidence REAL NOT NULL DEFAULT 0.0,
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

    // SMS Classification / ML tables
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
        created_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
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

    // Account extraction / bank rules tables
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
    await db.execute('''CREATE TABLE IF NOT EXISTS account_extraction_index(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL,
        rule_id INTEGER NOT NULL,
        UNIQUE(keyword, rule_id),
        FOREIGN KEY(rule_id) REFERENCES account_extraction_rules(id) ON DELETE CASCADE
      )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bank_normalizations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_name TEXT NOT NULL UNIQUE,
        normalized_name TEXT NOT NULL,
        region TEXT,
        frequency INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL
      )''');
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

    // User feedback / learning tables
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
        weight REAL NOT NULL DEFAULT 0.0,
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
        weight REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS feedback_events(
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

    // SMS keyword / merchant category tables
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

    // SMS event log (raw ingest + dedup + audit trail)
    await db.execute('''CREATE TABLE IF NOT EXISTS sms_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_body TEXT NOT NULL,
        sender TEXT NOT NULL,
        received_at TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        processing_status TEXT NOT NULL DEFAULT 'pending',
        transaction_id INTEGER REFERENCES transactions(id),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_events_hash ON sms_events(content_hash)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_events_status ON sms_events(processing_status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_events_received ON sms_events(received_at)');

    // SMS cluster memory (Phase 2) — one row per structural template
    await db.execute('''CREATE TABLE IF NOT EXISTS sms_clusters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_hash TEXT NOT NULL UNIQUE,
        sender TEXT NOT NULL,
        normalized_body TEXT NOT NULL,
        transaction_type TEXT,
        institution TEXT,
        match_count INTEGER NOT NULL DEFAULT 1,
        confirmed_count INTEGER NOT NULL DEFAULT 0,
        rejected_count INTEGER NOT NULL DEFAULT 0,
        confidence REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'learning',
        propagated_at TEXT,
        first_seen TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_clusters_status ON sms_clusters(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_clusters_sender ON sms_clusters(sender)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_clusters_propagated ON sms_clusters(propagated_at)');

    // SMS audit log (Phase 6) — immutable per-event signal breakdown for replay + audit
    await db.execute('''CREATE TABLE IF NOT EXISTS sms_audit_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL REFERENCES sms_events(id),
        cluster_id INTEGER REFERENCES sms_clusters(id),
        transaction_id INTEGER REFERENCES transactions(id),
        sender_known INTEGER NOT NULL DEFAULT 0,
        pattern_cache_hit INTEGER NOT NULL DEFAULT 0,
        sender_prior REAL NOT NULL DEFAULT 0.0,
        cluster_posterior REAL NOT NULL DEFAULT 0.0,
        signal_score REAL NOT NULL DEFAULT 0.0,
        account_score REAL NOT NULL DEFAULT 0.0,
        prob_score REAL NOT NULL DEFAULT 0.0,
        derived_from TEXT,
        stability_threat TEXT NOT NULL DEFAULT 'none',
        needs_review INTEGER NOT NULL DEFAULT 0,
        pipeline_version TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_audit_event ON sms_audit_log(event_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_audit_transaction ON sms_audit_log(transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_audit_created ON sms_audit_log(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_deleted ON transactions(deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_needs_review ON transactions(needs_review)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_source_type ON transactions(source_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_merchant ON transactions(merchant)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_sms_id ON transactions(sms_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_linked ON transactions(linked_transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_recurring_group ON transactions(recurring_group_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_from_account ON transactions(from_account_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions(to_account_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_deleted ON accounts(deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_institution ON accounts(institution_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_identifier ON accounts(account_identifier)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_source ON accounts(source)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_access_type ON accounts(access_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_deleted ON budgets(deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_goals_deleted ON savings_goals(deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recurring_deleted ON recurring_transactions(deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_execution_logs_rule ON execution_logs(rule_type, rule_id, execution_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_keywords_type ON sms_keywords(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_keywords_region ON sms_keywords(region)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_keywords_active ON sms_keywords(is_active) WHERE is_active = 1');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_merchant_categories_pattern ON merchant_categories(merchant_pattern)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_merchant_categories_region ON merchant_categories(region)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_merchant_categories_active ON merchant_categories(is_active) WHERE is_active = 1');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rule_index_keyword ON sms_rule_index(keyword)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_active ON sms_classification_rules(is_active) WHERE is_active = 1');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_extraction_index_keyword ON account_extraction_index(keyword)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_extraction_rules_active ON account_extraction_rules(is_active) WHERE is_active = 1');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bank_norm_original ON bank_normalizations(original_name)');

    // Seed data
    await _seedDefaultCategories(db);
    await _seedAccountExtractionRules(db);
    await _seedSmsKeywords(db);
    await _seedMerchantCategories(db);
    await _seedSenderPatterns(db);

    // Seed default signal weights
    const defaultSignalWeights = {
      'has_amount':           0.40,
      'has_account':          0.20,
      'has_bank':             0.10,
      'has_merchant':         0.10,
      'has_transaction_verb': 0.20,
    };
    for (final entry in defaultSignalWeights.entries) {
      await db.insert('signal_weights', {'signal': entry.key, 'weight': entry.value});
    }
  }

  static Future<void> _seedDefaultCategories(Database db) async {
    for (final catDef in kDefaultCategories) {
      final parentId = await db.insert('categories', {
        'name': catDef.name,
        'icon': catDef.icon,
        'color': catDef.color,
        'is_default': 1,
        'parent_id': null,
      });
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

  static Future<void> _seedAccountExtractionRules(Database db) async {
    await AccountExtractionSeed.seedBankRules(db);
    await AccountExtractionSeed.seedIdentifierRules(db);
    await AccountExtractionSeed.seedBankNormalizations(db);
  }

  static Future<void> _seedSmsKeywords(Database db) async {
    await SmsKeywordsSeed.seedKeywords(db);
  }

  static Future<void> _seedMerchantCategories(Database db) async {
    await SmsKeywordsSeed.seedMerchantCategories(db);
  }

  static Future<void> _seedSenderPatterns(Database db) async {
    await SmsKeywordsSeed.seedSenderPatterns(db);
  }
}
