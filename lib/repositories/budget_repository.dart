import '../models/budget.dart';

/// Repository interface for budget operations.
abstract class BudgetRepository {
  /// Upsert (insert or update) a budget
  Future<void> upsert(Budget budget);

  /// Get all budgets for a specific month and year
  Future<List<Budget>> getForMonth(int month, int year);
}
