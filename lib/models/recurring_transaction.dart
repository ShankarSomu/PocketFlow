class RecurringTransaction {
  final int? id;
  final String type; // 'income' | 'expense' | 'transfer' | 'goal'
  final double amount;
  final String category;
  final String? note;
  final int? accountId;      // source account
  final int? toAccountId;    // destination account (transfer only)
  final int? goalId;         // savings goal (goal contribution only)
  final String frequency;
  final DateTime nextDueDate;
  final bool isActive;
  final int? deletedAt;

  RecurringTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    this.accountId,
    this.toAccountId,
    this.goalId,
    required this.frequency,
    required this.nextDueDate,
    this.isActive = true,
    this.deletedAt,
  });

  DateTime nextAfter(DateTime from) {
    return switch (frequency) {
      'once'        => from.add(const Duration(days: 36500)), // far future = won't repeat
      'daily'       => from.add(const Duration(days: 1)),
      'weekly'      => from.add(const Duration(days: 7)),
      'biweekly'    => from.add(const Duration(days: 14)),
      'half-yearly' => DateTime(from.year, from.month + 6, from.day),
      'yearly'      => DateTime(from.year + 1, from.month, from.day),
      _             => DateTime(from.year, from.month + 1, from.day),
    };
  }

  static const frequencies = ['once', 'daily', 'weekly', 'biweekly', 'monthly', 'half-yearly', 'yearly'];

  bool get isTransfer => type == 'transfer';
  bool get isGoalContribution => type == 'goal';

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'goal_id': goalId,
        'frequency': frequency,
        'next_due_date': nextDueDate.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'deleted_at': deletedAt,
      };

  factory RecurringTransaction.fromMap(Map<String, dynamic> m) =>
      RecurringTransaction(
        id: m['id'],
        type: m['type'],
        amount: m['amount'],
        category: m['category'],
        note: m['note'],
        accountId: m['account_id'],
        toAccountId: m['to_account_id'],
        goalId: m['goal_id'],
        frequency: m['frequency'],
        nextDueDate: DateTime.parse(m['next_due_date']),
        isActive: m['is_active'] == 1,
        deletedAt: m['deleted_at'],
      );
}
