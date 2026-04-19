import '../db/database.dart';
import '../models/pending_action.dart';

/// Pending Action Service
/// Manages SMS actions that need user review or confirmation
class PendingActionService {
  /// Create a new pending action
  static Future<int> createAction({
    String? smsSource,
    Map<String, dynamic>? metadata,
    required String actionType,
    String priority = 'medium',
    required String title,
    required String description,
    int? transactionId,
    int? accountCandidateId,
    double confidence = 0.0,
  }) async {
    final db = await AppDatabase.db();
    
    final action = PendingAction(
      actionType: actionType,
      priority: priority,
      title: title,
      description: description,
      smsSource: smsSource,
      metadata: metadata,
      transactionId: transactionId,
      accountCandidateId: accountCandidateId,
      createdAt: DateTime.now(),
      confidence: confidence,
    );
    
    return db.insert('pending_actions', action.toMap());
  }

  /// Get all pending actions
  static Future<List<PendingAction>> getAllActions({
    String? status,
    String? actionType,
    String? priority,
  }) async {
    final db = await AppDatabase.db();
    
    final where = <String>[];
    final whereArgs = <dynamic>[];
    
    if (status != null) {
      where.add('status = ?');
      whereArgs.add(status);
    }
    
    if (actionType != null) {
      where.add('action_type = ?');
      whereArgs.add(actionType);
    }
    
    if (priority != null) {
      where.add('priority = ?');
      whereArgs.add(priority);
    }
    
    final results = await db.query(
      'pending_actions',
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '''
        CASE priority
          WHEN 'high' THEN 1
          WHEN 'medium' THEN 2
          WHEN 'low' THEN 3
        END,
        created_at DESC
      ''',
    );
    
    return results.map(PendingAction.fromMap).toList();
  }

  /// Get pending actions (status = 'pending')
  static Future<List<PendingAction>> getPendingActions() async {
    return getAllActions(status: 'pending');
  }

  /// Get action by ID
  static Future<PendingAction?> getActionById(int id) async {
    final db = await AppDatabase.db();
    
    final results = await db.query(
      'pending_actions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    return PendingAction.fromMap(results.first);
  }

  /// Resolve action with user feedback
  static Future<void> resolveAction({
    required int actionId,
    required String resolutionAction, // 'confirmed', 'dismissed', 'modified'
    Map<String, dynamic>? resolutionData,
    String? userFeedback,
  }) async {
    final db = await AppDatabase.db();
    
    await db.update(
      'pending_actions',
      {
        'status': 'resolved',
        'resolution_action': resolutionAction,
        'resolution_data': resolutionData?.toString(),
        'user_feedback': userFeedback,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  /// Dismiss action
  static Future<void> dismissAction(int actionId, {String? reason}) async {
    await resolveAction(
      actionId: actionId,
      resolutionAction: 'dismissed',
      userFeedback: reason,
    );
  }

  /// Confirm action
  static Future<void> confirmAction(
    int actionId, {
    Map<String, dynamic>? data,
  }) async {
    await resolveAction(
      actionId: actionId,
      resolutionAction: 'confirmed',
      resolutionData: data,
    );
  }

  /// Update action status
  static Future<void> updateStatus(int actionId, String status) async {
    final db = await AppDatabase.db();
    
    await db.update(
      'pending_actions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  /// Update action priority
  static Future<void> updatePriority(int actionId, String priority) async {
    final db = await AppDatabase.db();
    
    await db.update(
      'pending_actions',
      {'priority': priority},
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  /// Delete action
  static Future<void> deleteAction(int actionId) async {
    final db = await AppDatabase.db();
    
    await db.delete(
      'pending_actions',
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  /// Get statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final db = await AppDatabase.db();
    
    // Count by status
    final statusCounts = <String, int>{};
    final statusResults = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM pending_actions
      GROUP BY status
    ''');
    
    for (final row in statusResults) {
      statusCounts[row['status']! as String] = row['count']! as int;
    }
    
    // Count by action type
    final typeCounts = <String, int>{};
    final typeResults = await db.rawQuery('''
      SELECT action_type, COUNT(*) as count
      FROM pending_actions
      WHERE status = 'pending'
      GROUP BY action_type
    ''');
    
    for (final row in typeResults) {
      typeCounts[row['action_type']! as String] = row['count']! as int;
    }
    
    // Count by priority
    final priorityCounts = <String, int>{};
    final priorityResults = await db.rawQuery('''
      SELECT priority, COUNT(*) as count
      FROM pending_actions
      WHERE status = 'pending'
      GROUP BY priority
    ''');
    
    for (final row in priorityResults) {
      priorityCounts[row['priority']! as String] = row['count']! as int;
    }
    
    // Average confidence
    final confidenceResult = await db.rawQuery('''
      SELECT AVG(confidence) as avg_confidence
      FROM pending_actions
      WHERE status = 'pending'
    ''');
    
    final avgConfidence = confidenceResult.first['avg_confidence'] as double? ?? 0.0;
    
    return {
      'by_status': statusCounts,
      'by_type': typeCounts,
      'by_priority': priorityCounts,
      'average_confidence': avgConfidence,
      'total_pending': statusCounts['pending'] ?? 0,
      'total_resolved': statusCounts['resolved'] ?? 0,
    };
  }

  /// Bulk dismiss actions
  static Future<int> bulkDismiss(List<int> actionIds, {String? reason}) async {
    final db = await AppDatabase.db();
    
    final placeholders = actionIds.map((_) => '?').join(',');
    
    final updated = await db.rawUpdate('''
      UPDATE pending_actions
      SET status = 'resolved',
          resolution_action = 'dismissed',
          user_feedback = ?,
          resolved_at = ?
      WHERE id IN ($placeholders)
    ''', [reason, DateTime.now().toIso8601String(), ...actionIds]);
    
    return updated;
  }

  /// Bulk update priority
  static Future<int> bulkUpdatePriority(List<int> actionIds, String priority) async {
    final db = await AppDatabase.db();
    
    final placeholders = actionIds.map((_) => '?').join(',');
    
    final updated = await db.rawUpdate('''
      UPDATE pending_actions
      SET priority = ?
      WHERE id IN ($placeholders)
    ''', [priority, ...actionIds]);
    
    return updated;
  }

  /// Clean up old resolved actions
  static Future<int> cleanupOldActions({int daysOld = 90}) async {
    final db = await AppDatabase.db();
    
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    
    final deleted = await db.delete(
      'pending_actions',
      where: 'status = ? AND resolved_at < ?',
      whereArgs: ['resolved', cutoff.toIso8601String()],
    );
    
    return deleted;
  }

  /// Get actions by SMS type
  static Future<List<PendingAction>> getActionsBySmsType(String smsType) async {
    return getAllActions(status: 'pending', actionType: smsType);
  }

  /// Get high priority actions
  static Future<List<PendingAction>> getHighPriorityActions() async {
    return getAllActions(status: 'pending', priority: 'high');
  }

  /// Get low confidence actions
  static Future<List<PendingAction>> getLowConfidenceActions({double threshold = 0.6}) async {
    final db = await AppDatabase.db();
    
    final results = await db.query(
      'pending_actions',
      where: 'status = ? AND confidence < ?',
      whereArgs: ['pending', threshold],
      orderBy: 'confidence ASC, created_at DESC',
    );
    
    return results.map(PendingAction.fromMap).toList();
  }

  /// Auto-resolve high confidence actions
  static Future<int> autoResolveHighConfidence({double threshold = 0.90}) async {
    final db = await AppDatabase.db();
    
    // Find high confidence actions
    final results = await db.query(
      'pending_actions',
      where: 'status = ? AND confidence >= ?',
      whereArgs: ['pending', threshold],
    );
    
    int resolved = 0;
    
    for (final row in results) {
      final action = PendingAction.fromMap(row);
      
      // Auto-confirm based on action type
      if (action.actionType == 'balance_update' || 
          action.actionType == 'payment_confirmation') {
        await confirmAction(action.id!);
        resolved++;
      }
    }
    
    return resolved;
  }

  /// Create action for missing account
  static Future<int> createMissingAccountAction({
    required String smsText,
    required Map<String, dynamic> extractedData,
  }) async {
    return createAction(
      smsSource: smsText,
      metadata: extractedData,
      actionType: 'account_unresolved',
      priority: 'high',
      title: 'Account Not Found',
      description: 'Bank account could not be matched. Please review.',
    );
  }

  /// Create action for missing amount
  static Future<int> createMissingAmountAction({
    required String smsText,
    required Map<String, dynamic> extractedData,
  }) async {
    return createAction(
      smsSource: smsText,
      metadata: extractedData,
      actionType: 'missing_amount',
      title: 'Amount Not Detected',
      description: 'Transaction amount could not be extracted.',
    );
  }

  /// Create action for transfer confirmation
  static Future<int> createTransferConfirmationAction({
    required String smsText,
    required Map<String, dynamic> extractedData,
    required int debitTransactionId,
    required int creditTransactionId,
  }) async {
    return createAction(
      smsSource: smsText,
      metadata: {
        ...extractedData,
        'debit_transaction_id': debitTransactionId,
        'credit_transaction_id': creditTransactionId,
      },
      actionType: 'transfer_confirmation',
      title: 'Confirm Transfer',
      description: 'Potential transfer detected. Please confirm.',
    );
  }

  /// Create action for recurring pattern confirmation
  static Future<int> createRecurringConfirmationAction({
    required String merchant,
    required int patternId,
    required List<int> transactionIds,
  }) async {
    return createAction(
      metadata: {
        'pattern_id': patternId,
        'transaction_ids': transactionIds,
      },
      actionType: 'recurring_confirmation',
      priority: 'low',
      title: 'Recurring Pattern Detected',
      description: 'Recurring transactions detected for $merchant.',
    );
  }
}
