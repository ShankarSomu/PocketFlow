class Account {
  final int? id;
  final String name;
  final String type; // 'checking' | 'savings' | 'credit' | 'cash' | 'other'
  final double balance; // opening balance
  final String? last4;
  final int? dueDateDay;    // credit card due date (day of month 1-31)
  final double? creditLimit; // credit card limit

  Account({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.last4,
    this.dueDateDay,
    this.creditLimit,
  });

  static const types = ['checking', 'savings', 'credit', 'cash', 'other'];

  bool get isCredit => type == 'credit';

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
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'],
        name: m['name'],
        type: m['type'],
        balance: m['balance'],
        last4: m['last4'],
        dueDateDay: m['due_date_day'],
        creditLimit: m['credit_limit'],
      );
}
