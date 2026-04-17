import '../models/transaction.dart' as model;

/// Repository interface for transaction operations.
/// Provides abstraction layer between UI and data source.
abstract class TransactionRepository {
  /// Insert a new transaction
  Future<int> insert(model.Transaction transaction);

  /// Update an existing transaction
  Future<void> update(model.Transaction transaction);

  /// Delete a transaction by ID
  Future<void> delete(int id);

  /// Get all transactions with optional filters
  Future<List<model.Transaction>> getAll({
    String? type,
    DateTime? from,
    DateTime? to,
    String? keyword,
    int? accountId,
  });

  /// Get total amount for a specific type in a month
  Future<double> getMonthlyTotal(String type, int month, int year);

  /// Get expense breakdown by category for a month
  Future<Map<String, double>> getMonthlyExpenseByCategory(int month, int year);

  /// Get total amount for a specific type in a date range
  Future<double> getRangeTotal(String type, DateTime from, DateTime to);

  /// Get expense breakdown by category for a date range
  Future<Map<String, double>> getRangeExpenseByCategory(DateTime from, DateTime to);
}
