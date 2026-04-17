class SavingsGoal {
  final int? id;
  final String name;
  final double target;
  final double saved;
  final int? accountId;   // linked account
  final int priority;     // lower = higher priority (1 = top)

  SavingsGoal({
    this.id,
    required this.name,
    required this.target,
    required this.saved,
    this.accountId,
    this.priority = 999,
  });

  double get progress => target > 0 ? (saved / target).clamp(0.0, 1.0) : 0;
  double get remaining => (target - saved).clamp(0.0, double.infinity);
  bool get isComplete => saved >= target;

  /// Estimate completion date given a monthly contribution amount.
  /// Returns null if monthlyContribution <= 0 or goal already reached.
  DateTime? estimateCompletion(double monthlyContribution) {
    if (monthlyContribution <= 0) return null;
    if (remaining <= 0) return DateTime.now();
    final monthsNeeded = (remaining / monthlyContribution).ceil();
    final now = DateTime.now();
    return DateTime(now.year, now.month + monthsNeeded, now.day);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'account_id': accountId,
        'priority': priority,
      };

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
        id: m['id'],
        name: m['name'],
        target: m['target'],
        saved: m['saved'],
        accountId: m['account_id'],
        priority: m['priority'] ?? 999,
      );

  SavingsGoal copyWith({
    double? saved,
    int? accountId,
    int? priority,
  }) =>
      SavingsGoal(
        id: id,
        name: name,
        target: target,
        saved: saved ?? this.saved,
        accountId: accountId ?? this.accountId,
        priority: priority ?? this.priority,
      );
}
