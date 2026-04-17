import '../../models/recurring_transaction.dart';

/// Interface for recurring transaction scheduler
abstract class IRecurringScheduler {
  /// Process a specific recurring transaction
  Future<void> processOne(int recurringId);

  /// Check if a recurring transaction is due
  bool isDue(RecurringTransaction recurring);

  /// Calculate next due date
  DateTime calculateNextDue(RecurringTransaction recurring);
}
