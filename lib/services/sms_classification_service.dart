import '../models/sms_types.dart';

/// SMS Classification Service
/// Classifies SMS messages into financial categories
class SmsClassificationService {
  // ── Keywords for classification ────────────────────────────────────────────
  
  static const _debitKeywords = [
    'debited', 'deducted', 'spent', 'paid', 'payment of', 'purchase',
    'withdrawn', 'charged', 'transaction of', 'used at', 'txn of',
    'amount of rs', 'amt rs', 'transaction amt', 'payment done',
    'debit', 'withdraw', 'used for', 'bill payment',
  ];
  
  static const _creditKeywords = [
    'credited', 'received', 'deposited', 'refund', 'cashback',
    'salary', 'credit of', 'amount credited', 'added to',
    'deposit', 'incoming', 'transferred to you',
  ];
  
  static const _transferKeywords = [
    'transferred to', 'transfer from', 'sent to', 'received from',
    'upi transfer', 'imps transfer', 'neft transfer', 'rtgs transfer',
    'fund transfer', 'money sent', 'money received',
  ];
  
  static const _balanceKeywords = [
    'available balance', 'total balance', 'current balance',
    'avl bal', 'total bal', 'closing balance', 'balance is',
    'credit limit', 'available limit', 'outstanding balance',
  ];
  
  static const _reminderKeywords = [
    'due date', 'payment due', 'bill due', 'minimum amount due',
    'pay by', 'overdue', 'late fee', 'reminder', 'please pay',
  ];

  // Amount pattern to validate financial SMS
  static final _amountPattern = RegExp(
    r'(?:USD|INR|Rs\.?|₹|RM|AED|GBP|EUR|SGD|\$)\s*[\d,]+(?:\.\d{1,2})?|'
    r'[\d,]+(?:\.\d{1,2})?\s*(?:USD|INR|Rs|₹)',
    caseSensitive: false,
  );

  // Financial institution sender patterns
  static final _financialSenderPattern = RegExp(
    '(?:HDFCBK|ICICIBK|SBIINB|AXISBK|KOTAKB|PNBSMS|BOBIMT|CITIBK|'
    'SCBANK|HSBCIN|RBLBK|YESBK|IDFCBK|AUBANK|FEDERAL|INDUSIND|'
    'CANBNK|BOIIND|UNIONBK|JPBANK|DBANK|AMEXIN|CHASE|BOFA|WELLSFARGO|'
    'PAYTM|GPAY|PHONEPE|AMAZONP|VENMO|CASHAPP|ZELLE)',
    caseSensitive: false,
  );

  // ── Main Classification Method ─────────────────────────────────────────────

  /// Classify an SMS message into a financial category
  static SmsClassification classify(RawSmsMessage sms) {
    final body = sms.body.toLowerCase();
    final sender = sms.sender.toLowerCase();
    
    // Priority 1: Must be from financial sender OR contain financial keywords
    if (!_isFinancialSender(sender, body)) {
      return SmsClassification(
        type: SmsType.nonFinancial,
        confidence: 0.95,
        reason: 'Not from financial institution',
      );
    }
    
    // Priority 2: Check for specific message types
    final hasAmount = _amountPattern.hasMatch(sms.body);
    final hasDebit = _containsAny(body, _debitKeywords);
    final hasCredit = _containsAny(body, _creditKeywords);
    final hasTransfer = _containsAny(body, _transferKeywords);
    final hasBalance = _containsAny(body, _balanceKeywords);
    final hasReminder = _containsAny(body, _reminderKeywords);
    
    // Payment reminder (high priority to avoid misclassification)
    if (hasReminder && !hasDebit && !hasCredit) {
      return SmsClassification(
        type: SmsType.paymentReminder,
        confidence: 0.85,
        reason: 'Contains reminder keywords',
      );
    }
    
    // Transfer detection (specific patterns)
    if (hasTransfer && hasAmount) {
      return SmsClassification(
        type: SmsType.transfer,
        confidence: 0.90,
        reason: 'Contains transfer keywords and amount',
      );
    }
    
    // Transaction - Debit
    if (hasDebit && hasAmount) {
      return SmsClassification(
        type: SmsType.transactionDebit,
        confidence: 0.95,
        reason: 'Contains debit keywords and amount',
      );
    }
    
    // Transaction - Credit
    if (hasCredit && hasAmount) {
      return SmsClassification(
        type: SmsType.transactionCredit,
        confidence: 0.95,
        reason: 'Contains credit keywords and amount',
      );
    }
    
    // Balance update (without debit/credit action)
    if (hasBalance && hasAmount && !hasDebit && !hasCredit) {
      return SmsClassification(
        type: SmsType.accountUpdate,
        confidence: 0.85,
        reason: 'Contains balance keywords and amount',
      );
    }
    
    // Has amount but unclear type
    if (hasAmount) {
      return SmsClassification(
        type: SmsType.unknownFinancial,
        reason: 'Has amount but unclear transaction type',
      );
    }
    
    // From financial sender but no clear classification
    return SmsClassification(
      type: SmsType.unknownFinancial,
      confidence: 0.40,
      reason: 'From financial sender but no clear indicators',
    );
  }

  // ── Helper Methods ──────────────────────────────────────────────────────────

  /// Check if sender is from a financial institution
  static bool _isFinancialSender(String sender, String body) {
    // Check sender ID pattern
    if (_financialSenderPattern.hasMatch(sender)) return true;
    
    // Check for bank/financial keywords in message
    final financialInstitutions = [
      'bank', 'credit card', 'debit card', 'wallet', 'paytm',
      'phonepe', 'google pay', 'gpay', 'upi', 'visa', 'mastercard',
      'amex', 'american express', 'discover', 'capital one',
    ];
    
    for (final inst in financialInstitutions) {
      if (body.contains(inst)) return true;
    }
    
    return false;
  }

  /// Check if text contains any of the given keywords
  static bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  /// Get human-readable label for SMS type
  static String getTypeLabel(SmsType type) {
    switch (type) {
      case SmsType.transactionDebit:
        return '💳 Debit Transaction';
      case SmsType.transactionCredit:
        return '💰 Credit Transaction';
      case SmsType.transfer:
        return '↔️ Transfer';
      case SmsType.accountUpdate:
        return '📊 Account Update';
      case SmsType.paymentReminder:
        return '🔔 Payment Reminder';
      case SmsType.unknownFinancial:
        return '❓ Unknown Financial';
      case SmsType.nonFinancial:
        return '📱 Non-Financial';
    }
  }

  /// Get color for SMS type (for UI)
  static String getTypeColor(SmsType type) {
    switch (type) {
      case SmsType.transactionDebit:
        return '#FF5252'; // Red
      case SmsType.transactionCredit:
        return '#4CAF50'; // Green
      case SmsType.transfer:
        return '#2196F3'; // Blue
      case SmsType.accountUpdate:
        return '#9C27B0'; // Purple
      case SmsType.paymentReminder:
        return '#FF9800'; // Orange
      case SmsType.unknownFinancial:
        return '#FFC107'; // Amber
      case SmsType.nonFinancial:
        return '#9E9E9E'; // Gray
    }
  }
}
