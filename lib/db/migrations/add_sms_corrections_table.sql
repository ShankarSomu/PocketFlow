
-- Migration: Add SMS Corrections Table for Continuous Learning
-- Run this in your database.dart or migrations folder

CREATE TABLE IF NOT EXISTS sms_corrections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Original SMS data
    sms_text TEXT NOT NULL,
    sender_id TEXT,
    sms_received_time INTEGER,  -- Unix timestamp
    
    -- ML prediction (what model said)
    ml_predicted_transaction INTEGER,  -- 0 or 1
    ml_confidence REAL,
    
    -- User correction (ground truth)
    user_corrected_transaction INTEGER,  -- 0 or 1
    user_corrected_type TEXT,  -- debit, credit, unknown
    user_corrected_amount REAL,
    user_corrected_merchant TEXT,
    
    -- Metadata
    was_misclassified INTEGER DEFAULT 0,  -- 1 if ML was wrong
    correction_timestamp INTEGER NOT NULL,
    device_id TEXT,
    
    -- For privacy
    is_exported INTEGER DEFAULT 0,  -- Track if included in training
    
    UNIQUE(sms_text, correction_timestamp)
);

CREATE INDEX IF NOT EXISTS idx_sms_corrections_misclassified 
ON sms_corrections(was_misclassified) 
WHERE was_misclassified = 1;

CREATE INDEX IF NOT EXISTS idx_sms_corrections_export 
ON sms_corrections(is_exported) 
WHERE is_exported = 0;
