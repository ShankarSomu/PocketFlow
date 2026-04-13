class Category {
  final int? id;
  final String name;
  final int? parentId;   // null = top-level category
  final bool isDefault;
  final String icon;     // emoji
  final String color;    // hex color string e.g. '#FF6584'

  const Category({
    this.id,
    required this.name,
    this.parentId,
    this.isDefault = false,
    this.icon = '📁',
    this.color = '#6C63FF',
  });

  bool get isSubcategory => parentId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'is_default': isDefault ? 1 : 0,
        'icon': icon,
        'color': color,
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'],
        name: m['name'],
        parentId: m['parent_id'],
        isDefault: m['is_default'] == 1,
        icon: m['icon'] ?? '📁',
        color: m['color'] ?? '#6C63FF',
      );

  Category copyWith({String? name, String? icon, String? color}) => Category(
        id: id,
        name: name ?? this.name,
        parentId: parentId,
        isDefault: isDefault,
        icon: icon ?? this.icon,
        color: color ?? this.color,
      );
}

// ── Default categories ────────────────────────────────────────────────────────

const kDefaultCategories = [
  // ── Expense categories ──────────────────────────────────────────────────
  (name: 'Housing',       icon: '🏠', color: '#FF6584', subs: ['Rent', 'Mortgage', 'Utilities', 'Insurance', 'Repairs']),
  (name: 'Food',          icon: '🍔', color: '#FF9F43', subs: ['Groceries', 'Dining Out', 'Coffee', 'Takeaway']),
  (name: 'Transport',     icon: '🚗', color: '#54A0FF', subs: ['Fuel', 'Public Transit', 'Parking', 'Car Insurance', 'Maintenance']),
  (name: 'Health',        icon: '💊', color: '#5F27CD', subs: ['Doctor', 'Pharmacy', 'Gym', 'Dental', 'Vision']),
  (name: 'Entertainment', icon: '🎮', color: '#00D2D3', subs: ['Streaming', 'Games', 'Movies', 'Sports', 'Hobbies']),
  (name: 'Shopping',      icon: '🛍️', color: '#FF6B6B', subs: ['Clothing', 'Electronics', 'Home & Garden', 'Beauty']),
  (name: 'Education',     icon: '📚', color: '#1DD1A1', subs: ['Courses', 'Books', 'Tuition', 'Supplies']),
  (name: 'Bills',         icon: '📱', color: '#C8D6E5', subs: ['Phone', 'Internet', 'Subscriptions', 'TV']),
  (name: 'Travel',        icon: '✈️', color: '#48DBFB', subs: ['Flights', 'Hotels', 'Car Rental', 'Activities']),
  (name: 'Personal',      icon: '👤', color: '#FF9FF3', subs: ['Haircut', 'Clothing', 'Self Care']),
  (name: 'Other',         icon: '🎯', color: '#8395A7', subs: ['Gifts', 'Charity', 'Miscellaneous']),
  // ── Income categories ───────────────────────────────────────────────────
  (name: 'Income',        icon: '💰', color: '#2ECC71', subs: ['Salary', 'Freelance', 'Investment', 'Business', 'Rental', 'Bonus']),
  (name: 'Transfer',      icon: '🔄', color: '#95A5A6', subs: <String>[]),
];
