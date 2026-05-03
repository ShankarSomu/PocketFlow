/// SMS message types for classification
enum SmsType {
  transactionDebit,   // Money spent/debited
  transactionCredit,  // Money received/credited
  transfer,           // Transfer between accounts
  accountUpdate,      // Balance/limit updates
  paymentReminder,    // Due date/payment reminders
  unknownFinancial,   // Has financial keywords but unclear type
  nonFinancial,       // Not a financial SMS
}

/// Classification result with confidence
class SmsClassification {    // Why it was classified this way

  SmsClassification({
    required this.type,
    this.confidence = 0.5,
    this.reason,
  });
  final SmsType type;
  final double confidence; // 0.0 to 1.0
  final String? reason;

  bool get isFinancial => type != SmsType.nonFinancial;
  bool get isTransaction => 
      type == SmsType.transactionDebit || type == SmsType.transactionCredit;
  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.5 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.5;
}

/// Raw SMS message container
class RawSmsMessage {

  RawSmsMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
  });
  final int id;
  final String sender;
  final String body;
  final DateTime timestamp;
}
