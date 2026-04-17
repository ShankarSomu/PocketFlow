import '../models/category.dart';

/// Repository interface for category operations.
abstract class CategoryRepository {
  /// Get all categories
  Future<List<Category>> getAll();

  /// Get top-level categories (no parent)
  Future<List<Category>> getTopLevel();

  /// Get subcategories for a parent category
  Future<List<Category>> getSubcategories(int parentId);

  /// Insert a new category
  Future<int> insert(Category category);

  /// Update an existing category
  Future<void> update(Category category);

  /// Delete a category and its subcategories
  Future<void> delete(int id);
}
