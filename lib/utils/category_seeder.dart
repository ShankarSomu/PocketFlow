import '../db/database.dart';
import '../models/category.dart';

/// Utility to check and reseed categories with subcategories
class CategorySeeder {
  /// Check if subcategories exist in the database
  static Future<bool> hasSubcategories() async {
    final all = await AppDatabase.getCategories();
    return all.any((c) => c.parentId != null);
  }

  /// Get count of categories
  static Future<int> getCategoryCount() async {
    final all = await AppDatabase.getCategories();
    return all.length;
  }

  /// Reseed all default categories (will skip if already exist)
  static Future<void> reseedCategories() async {
    final db = await AppDatabase.db;
    
    // Clear existing default categories
    await db.delete('categories', where: 'is_default = 1');
    
    // Seed default categories with subcategories
    for (final catDef in kDefaultCategories) {
      // Insert parent category
      final parentId = await db.insert('categories', {
        'name': catDef.name,
        'icon': catDef.icon,
        'color': catDef.color,
        'is_default': 1,
        'parent_id': null,
      });
      
      // Insert subcategories
      for (final subName in catDef.subs) {
        await db.insert('categories', {
          'name': subName,
          'icon': catDef.icon,
          'color': catDef.color,
          'is_default': 1,
          'parent_id': parentId,
        });
      }
    }
  }

  /// Get statistics about categories
  static Future<Map<String, int>> getStats() async {
    final all = await AppDatabase.getCategories();
    final parents = all.where((c) => c.parentId == null).length;
    final subs = all.where((c) => c.parentId != null).length;
    return {
      'total': all.length,
      'parents': parents,
      'subcategories': subs,
    };
  }
}
