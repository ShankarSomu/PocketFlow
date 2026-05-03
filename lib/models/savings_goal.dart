class Goal {
  Goal({
    required this.name,
    required this.target,
    this.id,
    this.accountId,
    this.priority = 999,
    this.deletedAt,
  });

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'],
        name: m['name'],
        target: m['target'],
        accountId: m['account_id'],
        priority: m['priority'] ?? 999,
        deletedAt: m['deleted_at'],
      );
  final int? id;
  final String name;
  final double target;
  final int? accountId;   // linked account
  final int priority;     // lower = higher priority (1 = top)
  final int? deletedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target': target,
        'account_id': accountId,
        'priority': priority,
        'deleted_at': deletedAt,
      };

  Goal copyWith({
    int? accountId,
    int? priority,
  }) =>
      Goal(
        id: id,
        name: name,
        target: target,
        accountId: accountId ?? this.accountId,
        priority: priority ?? this.priority,
      );
}
