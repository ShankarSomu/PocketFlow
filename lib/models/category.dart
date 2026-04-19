class Category {    // hex color string e.g. '#FF6584'

  const Category({
    required this.name, this.id,
    this.parentId,
    this.isDefault = false,
    this.icon = '📁',
    this.color = '#6C63FF',
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'],
        name: m['name'],
        parentId: m['parent_id'],
        isDefault: m['is_default'] == 1,
        icon: m['icon'] ?? '📁',
        color: m['color'] ?? '#6C63FF',
      );
  final int? id;
  final String name;
  final int? parentId;   // null = top-level category
  final bool isDefault;
  final String icon;     // emoji
  final String color;

  bool get isSubcategory => parentId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'is_default': isDefault ? 1 : 0,
        'icon': icon,
        'color': color,
      };

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
  (name: 'Housing',       icon: '🏠', color: '#FF6584', subs: ['Rent', 'Mortgage', 'Property Tax', 'Home Insurance', 'Repairs', 'Maintenance', 'Furniture', 'Home Improvement']),
  (name: 'Food & Dining', icon: '🍽️', color: '#FF9F43', subs: ['Groceries', 'Dining Out', 'Fast Food', 'Coffee & Tea', 'Snacks', 'Alcohol', 'Swiggy', 'Zomato', 'Takeaway']),
  (name: 'Transportation', icon: '🚗', color: '#54A0FF', subs: ['Fuel', 'Uber', 'Ola', 'Taxi', 'Auto', 'Metro', 'Bus', 'Train', 'Parking', 'Toll', 'Car Insurance', 'Car Maintenance', 'Car Loan EMI']),
  (name: 'Health & Fitness', icon: '🏥', color: '#5F27CD', subs: ['Doctor', 'Hospital', 'Pharmacy', 'Gym', 'Yoga', 'Dental', 'Vision', 'Lab Tests', 'Supplements', 'Therapy', 'Health Insurance']),
  (name: 'Entertainment', icon: '🎬', color: '#00D2D3', subs: ['Netflix', 'Spotify', 'Amazon Prime', 'Hotstar', 'YouTube Premium', 'Movies', 'Games', 'Sports', 'Concerts', 'Events', 'Books', 'Magazines']),
  (name: 'Shopping',      icon: '🛍️', color: '#FF6B6B', subs: ['Amazon', 'Flipkart', 'Clothing', 'Shoes', 'Accessories', 'Jewelry', 'Electronics', 'Home & Garden', 'Beauty', 'Cosmetics', 'Nykaa']),
  (name: 'Education',     icon: '📚', color: '#1DD1A1', subs: ['Tuition', 'School Fees', 'College Fees', 'Courses', 'Books', 'Supplies', 'Udemy', 'Coursera', 'Coaching']),
  (name: 'Bills & Utilities', icon: '🧾', color: '#C8D6E5', subs: ['Electricity', 'Water', 'Gas', 'Phone', 'Mobile', 'Internet', 'Broadband', 'TV', 'DTH', 'Newspaper', 'Subscriptions', 'Maintenance Charges']),
  (name: 'Travel',        icon: '✈️', color: '#48DBFB', subs: ['Flights', 'Hotels', 'Airbnb', 'Car Rental', 'Visa', 'Travel Insurance', 'Luggage', 'IRCTC', 'MakeMyTrip', 'Vacation']),
  (name: 'Personal Care', icon: '💆', color: '#FF9FF3', subs: ['Haircut', 'Salon', 'Spa', 'Massage', 'Skincare', 'Self Care', 'Grooming']),
  (name: 'Family & Kids', icon: '👶', color: '#FFA07A', subs: ['Childcare', 'Diapers', 'Baby Products', 'Toys', 'Kids Clothing', 'Kids Education', 'Babysitter']),
  (name: 'Pets',          icon: '🐾', color: '#98D8C8', subs: ['Pet Food', 'Vet', 'Pet Supplies', 'Pet Grooming', 'Pet Insurance']),
  (name: 'Gifts & Donations', icon: '🎁', color: '#F7B731', subs: ['Gifts', 'Charity', 'Donations', 'Religious', 'NGO', 'Fundraiser']),
  (name: 'Insurance',     icon: '🛡️', color: '#6C5CE7', subs: ['Life Insurance', 'Health Insurance', 'Car Insurance', 'Home Insurance', 'LIC', 'Term Plan']),
  (name: 'Investments',   icon: '📈', color: '#00B894', subs: ['Stocks', 'Mutual Funds', 'SIP', 'Fixed Deposit', 'Gold', 'Crypto', 'Zerodha', 'Groww', 'Real Estate']),
  (name: 'Loans & EMI',   icon: '🏦', color: '#E17055', subs: ['Home Loan', 'Car Loan', 'Personal Loan', 'Education Loan', 'Credit Card EMI', 'Credit Card Bill']),
  (name: 'Taxes',         icon: '📋', color: '#A29BFE', subs: ['Income Tax', 'Property Tax', 'GST', 'Professional Tax', 'TDS']),
  (name: 'Business',      icon: '💼', color: '#6C5CE7', subs: ['Office Supplies', 'Software', 'Marketing', 'Legal', 'Accounting', 'Consulting', 'Business Travel']),
  (name: 'Hobbies',       icon: '🎨', color: '#FD79A8', subs: ['Art Supplies', 'Music', 'Photography', 'Crafts', 'Collections', 'Sports Equipment']),
  (name: 'Other',         icon: '🎯', color: '#8395A7', subs: ['Miscellaneous', 'Uncategorised', 'Cash Withdrawal', 'Bank Charges', 'Fees']),
  
  // ── Income categories ───────────────────────────────────────────────────
  (name: 'Income',        icon: '💰', color: '#2ECC71', subs: ['Salary', 'Wages', 'Freelance', 'Business Income', 'Rental Income', 'Bonus', 'Incentive', 'Commission', 'Tips']),
  (name: 'Investment Returns', icon: '📊', color: '#26de81', subs: ['Dividends', 'Interest', 'Capital Gains', 'Crypto Profit', 'Stock Profit', 'Mutual Fund Returns']),
  (name: 'Refunds & Cashback', icon: '💸', color: '#55EFC4', subs: ['Tax Refund', 'Cashback', 'Rewards', 'Reimbursement', 'Insurance Claim']),
  (name: 'Gifts Received', icon: '🎉', color: '#74B9FF', subs: ['Birthday', 'Wedding', 'Festival', 'Bonus Gift', 'Prize']),
  (name: 'Transfer',      icon: '🔄', color: '#95A5A6', subs: <String>[]),
];
