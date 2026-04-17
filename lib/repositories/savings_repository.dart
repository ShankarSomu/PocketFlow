import '../models/savings_goal.dart';

/// Repository interface for savings goal operations.
abstract class SavingsRepository {
  /// Insert a new savings goal
  Future<int> insert(SavingsGoal goal);

  /// Get all savings goals
  Future<List<SavingsGoal>> getAll();

  /// Update an existing savings goal
  Future<void> update(SavingsGoal goal);

  /// Update only the saved amount for a goal
  Future<void> updateSaved(int id, double saved);

  /// Delete a savings goal by ID
  Future<void> delete(int id);
}
