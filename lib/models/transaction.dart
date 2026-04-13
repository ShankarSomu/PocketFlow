class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final int? accountId;
  final int? recurringId;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    this.accountId,
    this.recurringId,
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
      );
}
