part of 'database.dart';

// ── Categories ────────────────────────────────────────────────────────────────

extension AppDatabaseCategories on AppDatabase {
  static Future<List<Category>> getCategories() async {
    final rows = await (await AppDatabase.db()).query('categories',
        orderBy: 'parent_id ASC, name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<List<Category>> getTopLevelCategories() async {
    final rows = await (await AppDatabase.db()).query('categories',
        where: 'parent_id IS NULL', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<List<Category>> getSubcategories(int parentId) async {
    final rows = await (await AppDatabase.db()).query('categories',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<int> insertCategory(Category c) async =>
      (await AppDatabase.db()).insert('categories', c.toMap()..remove('id'));

  static Future<void> updateCategory(Category c) async =>
      (await AppDatabase.db()).update('categories', c.toMap(),
          where: 'id = ?', whereArgs: [c.id]);

  static Future<void> deleteCategory(int id) async {
    final d = await AppDatabase.db();
    await d.delete('categories', where: 'parent_id = ?', whereArgs: [id]);
    await d.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
