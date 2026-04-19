class Account {

  Account({
    required this.name, required this.type, required this.balance, this.id,
    this.last4,
    this.dueDateDay,
    this.creditLimit,
    this.institutionName,
    this.accountIdentifier,
    this.smsKeywords,
    this.accountAlias,
    this.deletedAt,
  });

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'],
        name: m['name'],
        type: m['type'],
        balance: m['balance'],
        last4: m['last4'],
        dueDateDay: m['due_date_day'],
        creditLimit: m['credit_limit'],
        institutionName: m['institution_name'],
        accountIdentifier: m['account_identifier'],
        smsKeywords: m['sms_keywords'] != null 
            ? (m['sms_keywords'] as String).split(',').where((s) => s.isNotEmpty).toList()
            : null,
        accountAlias: m['account_alias'],
        deletedAt: m['deleted_at'],
      );
  final int? id;
  final String name;
  final String type; // 'checking' | 'savings' | 'credit' | 'cash' | 'other'
  final double balance; // opening balance
  final String? last4;
  final int? dueDateDay;    // credit card due date (day of month 1-31)
  final double? creditLimit; // credit card limit
  
  // ── Enhanced Mapping Fields for Hybrid Transaction Matching ──
  final String? institutionName;   // e.g., "Chase", "Amex", "Bank of America"
  final String? accountIdentifier;  // Masked format: "****1234" (primary matching key)
  final List<String>? smsKeywords;  // SMS parsing fallback: ["CHASE", "JP MORGAN"]
  final String? accountAlias;       // User-friendly label for manual selection
  
  final int? deletedAt;

  static const types = ['checking', 'debit', 'savings', 'credit', 'loan', 'cash', 'investment', 'other'];

  bool get isCredit => type == 'credit' || type == 'loan';

  /// Next due date based on dueDateDay
  DateTime? get nextDueDate {
    if (!isCredit || dueDateDay == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, dueDateDay!);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, dueDateDay!);
    }
    return due;
  }

  int? get daysUntilDue {
    final d = nextDueDate;
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'last4': last4,
        'due_date_day': dueDateDay,
        'credit_limit': creditLimit,
        'institution_name': institutionName,
        'account_identifier': accountIdentifier,
        'sms_keywords': smsKeywords?.join(','),
        'account_alias': accountAlias,
        'deleted_at': deletedAt,
      };
  
  /// Get display name for UI (uses alias if available, otherwise name)
  String get displayName => accountAlias?.isNotEmpty ?? false ? accountAlias! : name;
  
  /// Get formatted account identifier with institution name
  String get formattedIdentifier {
    final parts = <String>[];
    if (institutionName != null) parts.add(institutionName!);
    if (accountIdentifier != null) {
      parts.add(accountIdentifier!);
    } else if (last4 != null) {
      parts.add('****$last4');
    }
    return parts.isNotEmpty ? parts.join(' ') : name;
  }
}
