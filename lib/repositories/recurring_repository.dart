import '../models/recurring_transaction.dart';

/// Repository interface for recurring transaction operations.
abstract class RecurringRepository {
  /// Insert a new recurring transaction
  Future<int> insert(RecurringTransaction transaction);

  /// Get all recurring transactions
  Future<List<RecurringTransaction>> getAll();

  /// Update an existing recurring transaction
  Future<void> update(RecurringTransaction transaction);

  /// Delete a recurring transaction by ID
  Future<void> delete(int id);
}
