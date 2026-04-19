import 'dart:convert';

/// Pending action requiring user review
class PendingAction { // Detailed explanation

  PendingAction({
    required this.actionType, required this.priority, required this.createdAt, required this.title, required this.description, this.id,
    this.transactionId,
    this.accountCandidateId,
    this.smsSource,
    this.metadata,
    this.status = 'pending',
    this.resolvedAt,
    this.resolutionAction,
    this.confidence = 0.0,
  });

  factory PendingAction.fromMap(Map<String, dynamic> m) => PendingAction(
    id: m['id'],
    actionType: m['action_type'],
    priority: m['priority'],
    createdAt: DateTime.parse(m['created_at']),
    transactionId: m['transaction_id'],
    accountCandidateId: m['account_candidate_id'],
    smsSource: m['sms_source'],
    metadata: m['metadata'] != null ? jsonDecode(m['metadata']) : null,
    status: m['status'] ?? 'pending',
    resolvedAt: m['resolved_at'] != null ? DateTime.parse(m['resolved_at']) : null,
    resolutionAction: m['resolution_action'],
    title: m['title'],
    description: m['description'],
    confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
  );
  final int? id;
  final String actionType; // 'confirm_account', 'confirm_transaction', 
                           // 'resolve_transfer', 'review_recurring', 'review_failed'
  final String priority;   // 'high', 'medium', 'low'
  final DateTime createdAt;
  final double confidence;
  
  // Associated Data
  final int? transactionId;
  final int? accountCandidateId;
  final String? smsSource;
  final Map<String, dynamic>? metadata; // JSON blob for context
  
  // Resolution
  final String status;     // 'pending', 'resolved', 'dismissed'
  final DateTime? resolvedAt;
  final String? resolutionAction; // What user did
  
  // Display
  final String title;      // "Confirm new account: Chase ****1234"
  final String description;

  Map<String, dynamic> toMap() => {
    'id': id,
    'action_type': actionType,
    'priority': priority,
    'created_at': createdAt.toIso8601String(),
    'transaction_id': transactionId,
    'account_candidate_id': accountCandidateId,
    'sms_source': smsSource,
    'metadata': metadata != null ? jsonEncode(metadata) : null,
    'status': status,
    'resolved_at': resolvedAt?.toIso8601String(),
    'resolution_action': resolutionAction,
    'title': title,
    'description': description,
    'confidence': confidence,
  };

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isHighPriority => priority == 'high';
  bool get isMediumPriority => priority == 'medium';
  bool get isLowPriority => priority == 'low';

  String get priorityLabel {
    switch (priority) {
      case 'high': return '🔴 High';
      case 'medium': return '🟡 Medium';
      case 'low': return '🟢 Low';
      default: return priority;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return '⏳ Pending';
      case 'resolved': return '✅ Resolved';
      case 'dismissed': return '❌ Dismissed';
      default: return status;
    }
  }
}
