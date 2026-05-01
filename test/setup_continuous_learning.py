#!/usr/bin/env python3
"""
Setup Continuous Learning Pipeline

This creates the database schema and export tools for continuous learning:
1. Database table to store user corrections
2. Export script to get real SMS data from users
3. Merge script to combine corrections with training data
4. Retrain script to update the model
"""

import sqlite3
from pathlib import Path


def create_correction_table_migration():
    """Generate SQL migration to add user corrections table"""
    
    migration_sql = """
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
"""
    
    # Save to file
    migration_file = Path('lib/db/migrations/add_sms_corrections_table.sql')
    migration_file.parent.mkdir(exist_ok=True)
    
    with open(migration_file, 'w', encoding='utf-8') as f:
        f.write(migration_sql)
    
    print(f"✓ Migration SQL created: {migration_file}")
    print("\nAdd this to your database.dart onCreate/onUpgrade:")
    print("""
// In database.dart:
static Future<void> _createTables(Database db, int version) async {
  // ... existing tables ...
  
  // Continuous learning table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sms_corrections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sms_text TEXT NOT NULL,
      sender_id TEXT,
      sms_received_time INTEGER,
      ml_predicted_transaction INTEGER,
      ml_confidence REAL,
      user_corrected_transaction INTEGER,
      user_corrected_type TEXT,
      user_corrected_amount REAL,
      user_corrected_merchant TEXT,
      was_misclassified INTEGER DEFAULT 0,
      correction_timestamp INTEGER NOT NULL,
      device_id TEXT,
      is_exported INTEGER DEFAULT 0,
      UNIQUE(sms_text, correction_timestamp)
    )
  ''');
}
""")


def create_dart_correction_service():
    """Generate Dart service to record user corrections"""
    
    dart_code = """
// lib/services/sms_correction_service.dart

import 'package:sqflite/sqflite.dart';
import '../db/database.dart';

/// Service for recording user corrections for continuous learning
class SmsCorrectionService {
  /// Record when user corrects ML classification
  static Future<void> recordCorrection({
    required String smsText,
    String? senderId,
    DateTime? smsReceivedTime,
    
    // What ML predicted
    bool? mlPredictedTransaction,
    double? mlConfidence,
    
    // What user corrected to
    required bool userCorrectedTransaction,
    String? userCorrectedType,
    double? userCorrectedAmount,
    String? userCorrectedMerchant,
  }) async {
    final db = await AppDatabase.database;
    
    final wasMisclassified = (mlPredictedTransaction != null && 
                             mlPredictedTransaction != userCorrectedTransaction);
    
    await db.insert(
      'sms_corrections',
      {
        'sms_text': smsText,
        'sender_id': senderId,
        'sms_received_time': smsReceivedTime?.millisecondsSinceEpoch,
        'ml_predicted_transaction': mlPredictedTransaction == true ? 1 : 0,
        'ml_confidence': mlConfidence,
        'user_corrected_transaction': userCorrectedTransaction ? 1 : 0,
        'user_corrected_type': userCorrectedType,
        'user_corrected_amount': userCorrectedAmount,
        'user_corrected_merchant': userCorrectedMerchant,
        'was_misclassified': wasMisclassified ? 1 : 0,
        'correction_timestamp': DateTime.now().millisecondsSinceEpoch,
        'is_exported': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    if (wasMisclassified) {
      print('📝 ML misclassification recorded for retraining');
    }
  }
  
  /// Get count of corrections ready for export
  static Future<int> getPendingCorrectionsCount() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sms_corrections WHERE is_exported = 0'
    );
    return result.first['count'] as int;
  }
  
  /// Get count of misclassifications (shows ML accuracy issues)
  static Future<int> getMisclassificationCount() async {
    final db = await AppDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sms_corrections WHERE was_misclassified = 1'
    );
    return result.first['count'] as int;
  }
  
  /// Export corrections for retraining
  static Future<List<Map<String, dynamic>>> exportCorrections() async {
    final db = await AppDatabase.database;
    
    final corrections = await db.query(
      'sms_corrections',
      where: 'is_exported = ?',
      whereArgs: [0],
    );
    
    // Mark as exported
    await db.update(
      'sms_corrections',
      {'is_exported': 1},
      where: 'is_exported = ?',
      whereArgs: [0],
    );
    
    return corrections;
  }
}
"""
    
    service_file = Path('lib/services/sms_correction_service.dart')
    with open(service_file, 'w', encoding='utf-8') as f:
        f.write(dart_code)
    
    print(f"\n✓ Dart service created: {service_file}")


def create_merge_corrections_script():
    """Script to merge user corrections with training data"""
    
    merge_script = """#!/usr/bin/env python3
'''
Merge User Corrections with Training Data

This combines:
1. Original training dataset
2. Exported user corrections (real SMS from users)
3. Extracted keywords from parser

Into an enhanced training dataset.
'''

import json
from pathlib import Path
from datetime import datetime


def merge_training_data():
    # Load original training data
    with open('test/sms_training_dataset.json', 'r') as f:
        original_data = json.load(f)
    
    # Load user corrections (exported from app)
    corrections_file = Path('test/user_corrections.json')
    if corrections_file.exists():
        with open(corrections_file, 'r') as f:
            corrections = json.load(f)
        
        print(f"Loaded {len(corrections)} user corrections")
        
        # Convert corrections to training format
        correction_samples = []
        for corr in corrections:
            correction_samples.append({
                'text': corr['sms_text'],
                'label': 1 if corr['user_corrected_transaction'] else 0,
                'source': 'user_correction',
                'metadata': {
                    'sender_id': corr.get('sender_id'),
                    'was_misclassified': corr.get('was_misclassified', 0),
                }
            })
        
        # Add to training set (prioritize real data)
        print(f"Adding {len(correction_samples)} real user SMS to training...")
        original_data['train'].extend(correction_samples)
    
    # Load keyword-enhanced data
    keyword_file = Path('test/sms_training_dataset_enhanced.json')
    if keyword_file.exists():
        with open(keyword_file, 'r') as f:
            keyword_data = json.load(f)
        
        print(f"Merging keyword-enhanced dataset...")
        original_data['train'].extend(keyword_data['train'][:1000])  # Add subset
    
    # Save merged dataset
    output_file = 'test/sms_training_dataset_merged.json'
    with open(output_file, 'w') as f:
        json.dump(original_data, f, indent=2)
    
    print(f"\\n✓ Merged training data saved: {output_file}")
    print(f"  Total training samples: {len(original_data['train'])}")
    print(f"\\nNext: python test/train_sms_classifier.py")


if __name__ == '__main__':
    merge_training_data()
"""
    
    merge_file = Path('test/merge_corrections.py')
    with open(merge_file, 'w', encoding='utf-8') as f:
        f.write(merge_script)
    
    merge_file.chmod(0o755)
    print(f"\n✓ Merge script created: {merge_file}")


def create_workflow_doc():
    """Create documentation for the continuous learning workflow"""
    
    workflow = """# Continuous Learning Workflow

## Overview

The ML model **cannot retrain on-device** (TensorFlow Lite doesn't support training).
Instead, we use a **feedback loop**:

```
User SMS → ML Prediction → User Correction → Export → Retrain → Deploy
     ↓                            ↓              ↓         ↓         ↓
  Database              sms_corrections       JSON    .tflite    App Update
```

## Step-by-Step Process

### 1. User Makes Correction (In App)

When user edits a transaction imported from SMS:

```dart
// In transaction edit screen
await SmsCorrectionService.recordCorrection(
  smsText: transaction.smsSource ?? '',
  senderId: transaction.sourceDetails,
  mlPredictedTransaction: true,  // What ML said
  mlConfidence: transaction.confidenceScore,
  userCorrectedTransaction: false,  // User says: NOT a transaction
  userCorrectedType: null,
);
```

### 2. Export Corrections (Monthly/Quarterly)

Add button in Settings → Advanced:

```dart
// Export corrections for ML improvement
final corrections = await SmsCorrectionService.exportCorrections();
final json = jsonEncode(corrections);

// Save to file or send to server
await shareFile(json, 'user_corrections_${DateTime.now()}.json');
```

### 3. Retrain Model (Developer-Side)

After collecting 100+ corrections across users:

```bash
# Step 1: Extract keywords from parser
python test/extract_keywords_for_training.py

# Step 2: Merge with user corrections
python test/merge_corrections.py

# Step 3: Retrain model
python test/train_sms_classifier.py

# Step 4: Test accuracy
python test/test_tflite_model.py

# Step 5: Deploy
cp test/sms_classifier.tflite assets/models/
```

### 4. Deploy Updated Model

Release app update with improved model.

## Metrics to Track

### In App (Settings Screen)

```dart
class MLModelStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _getMLStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final stats = snapshot.data!;
        return Card(
          child: Column(
            children: [
              Text('ML Model Performance'),
              SizedBox(height: 8),
              Text('Model Version: 1.2'),
              Text('Total Corrections: ${stats['total']}'),
              Text('Misclassifications: ${stats['wrong']}'),
              Text('Accuracy: ${((stats['right']!/stats['total']!)*100).toStringAsFixed(1)}%'),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _exportCorrections,
                child: Text('Export for Model Improvement'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<Map<String, int>> _getMLStats() async {
    final total = await SmsCorrectionService.getPendingCorrectionsCount();
    final wrong = await SmsCorrectionService.getMisclassificationCount();
    return {
      'total': total,
      'wrong': wrong,
      'right': total - wrong,
    };
  }
}
```

## Why Not On-Device Training?

**Technical Limitations:**
- TensorFlow Lite = inference only (no training)
- Training requires full TensorFlow (~500 MB)
- Neural network training needs significant compute
- Android doesn't have Python runtime

**Alternative Considered:**
- Federated Learning (Google uses this)
- Requires server infrastructure
- Complex for indie apps

**Our Approach:**
- Collect corrections locally
- Export anonymized data
- Retrain offline
- Deploy in app updates
- Simple, privacy-safe, effective

## Privacy Considerations

- Store corrections in local database only
- User explicitly exports (opt-in)
- Can review/delete before export
- Anonymize sender IDs in export
- No automatic background uploads

## Expected Improvement Cycle

- **Week 1-4**: Collect user corrections
- **Month 2**: Analyze 100+ corrections, retrain
- **Month 3**: Deploy improved model in v1.1
- **Ongoing**: Repeat every 2-3 months

Over time, model learns user-specific patterns!
"""
    
    doc_file = Path('docs/CONTINUOUS_LEARNING.md')
    with open(doc_file, 'w', encoding='utf-8') as f:
        f.write(workflow)
    
    print(f"\n✓ Workflow documentation: {doc_file}")


def main():
    print("="*70)
    print("Setting up Continuous Learning Infrastructure")
    print("="*70)
    
    print("\n1. Creating database migration...")
    create_correction_table_migration()
    
    print("\n2. Creating Dart service...")
    create_dart_correction_service()
    
    print("\n3. Creating merge script...")
    create_merge_corrections_script()
    
    print("\n4. Creating documentation...")
    create_workflow_doc()
    
    print("\n" + "="*70)
    print("✓ SETUP COMPLETE")
    print("="*70)
    print("\nNext steps:")
    print("  1. Add migration to database.dart")
    print("  2. Import SmsCorrectionService in your transaction screens")
    print("  3. Call recordCorrection() when user edits transactions")
    print("  4. Add 'Export Corrections' button in Settings")
    print("\nSee docs/CONTINUOUS_LEARNING.md for full workflow")


if __name__ == '__main__':
    main()
