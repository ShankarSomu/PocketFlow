/// Base mixin for entities that support soft deletion
mixin DeletableEntity {
  /// When the entity was soft deleted (null if not deleted)
  int? get deletedAt;
  
  /// Whether this entity is currently deleted
  bool get isDeleted => deletedAt != null;
  
  /// Get the deletion date as DateTime (null if not deleted)
  DateTime? get deletedDate => 
      deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(deletedAt!) : null;
  
  /// Whether this entity can be restored
  bool get canRestore => isDeleted;
  
  /// Mark this entity as deleted (returns timestamp)
  int markDeleted() => DateTime.now().millisecondsSinceEpoch;
  
  /// Convert deleted_at timestamp to map entry for database
  Map<String, dynamic> deletedAtToMap() => 
      {'deleted_at': deletedAt};
}

/// Helper class for soft delete operations
class SoftDeleteHelper {
  /// Create WHERE clause to exclude deleted items
  static String excludeDeleted([String? additionalWhere]) {
    const base = 'deleted_at IS NULL';
    if (additionalWhere == null || additionalWhere.isEmpty) {
      return base;
    }
    return '$base AND ($additionalWhere)';
  }
  
  /// Create WHERE clause to only include deleted items
  static String onlyDeleted([String? additionalWhere]) {
    const base = 'deleted_at IS NOT NULL';
    if (additionalWhere == null || additionalWhere.isEmpty) {
      return base;
    }
    return '$base AND ($additionalWhere)';
  }
  
  /// Get timestamp for deletion
  static int now() => DateTime.now().millisecondsSinceEpoch;
  
  /// Check if item should be auto-purged (older than retention period)
  /// Default retention: 30 days
  static bool shouldPurge(int? deletedAt, {int retentionDays = 30}) {
    if (deletedAt == null) return false;
    final deletedDate = DateTime.fromMillisecondsSinceEpoch(deletedAt);
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    return deletedDate.isBefore(cutoff);
  }
  
  /// Calculate days remaining before auto-purge
  static int daysUntilPurge(int deletedAt, {int retentionDays = 30}) {
    final deletedDate = DateTime.fromMillisecondsSinceEpoch(deletedAt);
    final purgeDate = deletedDate.add(Duration(days: retentionDays));
    final now = DateTime.now();
    if (purgeDate.isBefore(now)) return 0;
    return purgeDate.difference(now).inDays;
  }
}

/// Statistics about deleted items
class DeletedItemsStats {
  
  const DeletedItemsStats({
    required this.transactions,
    required this.accounts,
    required this.budgets,
    required this.goals,
    required this.recurring,
  });
  final int transactions;
  final int accounts;
  final int budgets;
  final int goals;
  final int recurring;
  
  int get total => transactions + accounts + budgets + goals + recurring;
  
  bool get hasAny => total > 0;
  
  Map<String, int> toMap() => {
    'transactions': transactions,
    'accounts': accounts,
    'budgets': budgets,
    'goals': goals,
    'recurring': recurring,
    'total': total,
  };
}
