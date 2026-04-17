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
  (name: 'Housing',       icon: '🏠', color: '#FF6584', subs: ['Rent', 'Mortgage', 'Utilities', 'Insurance', 'Repairs', 'Maintenance']),
  (name: 'Food',          icon: '🍽️', color: '#FF9F43', subs: ['Groceries', 'Dining Out', 'Coffee', 'Takeaway', 'Swiggy', 'Zomato']),
  (name: 'Transport',     icon: '🚗', color: '#54A0FF', subs: ['Fuel', 'Uber', 'Ola', 'Metro', 'Bus', 'Parking', 'Car Insurance', 'Maintenance']),
  (name: 'Health',        icon: '🏥', color: '#5F27CD', subs: ['Doctor', 'Pharmacy', 'Gym', 'Dental', 'Vision', 'Lab Tests']),
  (name: 'Entertainment', icon: '🎬', color: '#00D2D3', subs: ['Netflix', 'Spotify', 'Hotstar', 'Movies', 'Games', 'Sports', 'Concerts']),
  (name: 'Shopping',      icon: '🛍️', color: '#FF6B6B', subs: ['Amazon', 'Flipkart', 'Clothing', 'Electronics', 'Home & Garden', 'Beauty', 'Nykaa']),
  (name: 'Groceries',     icon: '🛒', color: '#FFA502', subs: ['Big Basket', 'Blinkit', 'DMart', 'Zepto', 'Local Market']),
  (name: 'Education',     icon: '📚', color: '#1DD1A1', subs: ['Courses', 'Books', 'Tuition', 'Supplies', 'Udemy', 'Coursera']),
  (name: 'Bills',         icon: '🧾', color: '#C8D6E5', subs: ['Phone', 'Internet', 'Electricity', 'Gas', 'Water', 'TV', 'Subscriptions']),
  (name: 'Travel',        icon: '✈️', color: '#48DBFB', subs: ['Flights', 'Hotels', 'Airbnb', 'Car Rental', 'IRCTC', 'MakeMyTrip']),
  (name: 'Personal',      icon: '💆', color: '#FF9FF3', subs: ['Haircut', 'Salon', 'Skincare', 'Self Care', 'Clothing']),
  (name: 'Insurance',     icon: '🛡️', color: '#6C5CE7', subs: ['Health Insurance', 'Car Insurance', 'Life Insurance', 'LIC', 'Term Plan']),
  (name: 'Investment',    icon: '📈', color: '#00B894', subs: ['Stocks', 'Mutual Funds', 'Crypto', 'Zerodha', 'Groww', 'SIP']),
  (name: 'EMI / Loans',   icon: '🏦', color: '#E17055', subs: ['Home Loan', 'Car Loan', 'Personal Loan', 'Credit Card EMI']),
  (name: 'Other',         icon: '🎯', color: '#8395A7', subs: ['Gifts', 'Charity', 'Miscellaneous', 'Uncategorised']),
  // ── Income categories ───────────────────────────────────────────────────
  (name: 'Income',        icon: '💰', color: '#2ECC71', subs: ['Salary', 'Freelance', 'Business', 'Rental Income', 'Bonus', 'Incentive']),
  (name: 'Investment',    icon: '📊', color: '#26de81', subs: ['Dividends', 'Interest', 'Capital Gains', 'Crypto Profit']),
  (name: 'Transfer',      icon: '🔄', color: '#95A5A6', subs: <String>[]),
];
