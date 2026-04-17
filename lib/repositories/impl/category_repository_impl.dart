import '../../db/database.dart';
import '../../models/category.dart';
import '../category_repository.dart';

/// SQLite implementation of CategoryRepository
class CategoryRepositoryImpl implements CategoryRepository {
  @override
  Future<List<Category>> getAll() async {
    final db = await AppDatabase.db;
    final rows = await db.query('categories',
        orderBy: 'parent_id ASC, name ASC');
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<List<Category>> getTopLevel() async {
    final db = await AppDatabase.db;
    final rows = await db.query('categories',
        where: 'parent_id IS NULL', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<List<Category>> getSubcategories(int parentId) async {
    final db = await AppDatabase.db;
    final rows = await db.query('categories',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<int> insert(Category category) async {
    final db = await AppDatabase.db;
    return db.insert('categories', category.toMap()..remove('id'));
  }

  @override
  Future<void> update(Category category) async {
    final db = await AppDatabase.db;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await AppDatabase.db;
    // Delete subcategories first
    await db.delete('categories', where: 'parent_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
