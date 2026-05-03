import '../models/savings_goal.dart';

/// Repository interface for goal operations.
abstract class GoalsRepository {
  /// Insert a new goal
  Future<int> insert(Goal goal);

  /// Get all goals
  Future<List<Goal>> getAll();

  /// Update an existing goal
  Future<void> update(Goal goal);

  /// Update only the saved amount for a goal
  Future<void> updateSaved(int id, double saved);

  /// Delete a goal by ID
  Future<void> delete(int id);
}
