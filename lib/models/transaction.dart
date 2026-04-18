class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final int? accountId;
  final int? recurringId;
  final String? smsSource;
  final int? deletedAt;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    this.accountId,
    this.recurringId,
    this.smsSource,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'account_id': accountId,
        'recurring_id': recurringId,
        'sms_source': smsSource,
        'deleted_at': deletedAt,
      };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'],
        type: m['type'],
        amount: m['amount'],
        category: m['category'],
        note: m['note'],
        date: DateTime.parse(m['date']),
        accountId: m['account_id'],
        recurringId: m['recurring_id'],
        smsSource: m['sms_source'],
        deletedAt: m['deleted_at'],
      );
}
