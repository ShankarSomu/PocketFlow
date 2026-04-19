/// Detected transfer between two accounts
class TransferPair {

  TransferPair({
    required this.debitTransactionId, required this.creditTransactionId, required this.amount, required this.timestamp, required this.sourceAccountId, required this.destinationAccountId, required this.confidenceScore, required this.detectionMethod, required this.createdAt, this.id,
    this.status = 'detected',
  });

  factory TransferPair.fromMap(Map<String, dynamic> m) => TransferPair(
    id: m['id'],
    debitTransactionId: m['debit_transaction_id'],
    creditTransactionId: m['credit_transaction_id'],
    amount: (m['amount'] as num).toDouble(),
    timestamp: DateTime.parse(m['timestamp']),
    sourceAccountId: m['source_account_id'],
    destinationAccountId: m['destination_account_id'],
    confidenceScore: (m['confidence_score'] as num).toDouble(),
    detectionMethod: m['detection_method'],
    status: m['status'] ?? 'detected',
    createdAt: DateTime.parse(m['created_at']),
  );
  final int? id;
  final int debitTransactionId;     // Source transaction
  final int creditTransactionId;    // Destination transaction
  final double amount;
  final DateTime timestamp;
  
  final int sourceAccountId;
  final int destinationAccountId;
  
  final double confidenceScore;     // Match confidence (0.0-1.0)
  final String detectionMethod;     // 'amount_time', 'reference_id', 'user_confirmed'
  
  final String status;              // 'detected', 'confirmed', 'rejected'
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'debit_transaction_id': debitTransactionId,
    'credit_transaction_id': creditTransactionId,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'source_account_id': sourceAccountId,
    'destination_account_id': destinationAccountId,
    'confidence_score': confidenceScore,
    'detection_method': detectionMethod,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

  bool get isDetected => status == 'detected';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';

  bool get isHighConfidence => confidenceScore >= 0.90;
  bool get isMediumConfidence => confidenceScore >= 0.70 && confidenceScore < 0.90;
  bool get isLowConfidence => confidenceScore < 0.70;

  String get confidenceLabel {
    if (isHighConfidence) return '✅ High';
    if (isMediumConfidence) return '⚠️ Medium';
    return '❓ Low';
  }

  String get methodLabel {
    switch (detectionMethod) {
      case 'amount_time': return 'Amount & Time Match';
      case 'reference_id': return 'Reference Number';
      case 'user_confirmed': return 'User Confirmed';
      default: return detectionMethod;
    }
  }
}
