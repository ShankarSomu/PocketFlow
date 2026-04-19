class Budget {

  Budget({
    required this.category, required this.limit, required this.month, required this.year, this.id,
  });

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'],
        category: m['category'],
        limit: m['`limit`'] ?? m['limit'],
        month: m['month'],
        year: m['year'],
      );
  final int? id;
  final String category;
  final double limit;
  final int month; // 1-12
  final int year;

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        '`limit`': limit,
        'month': month,
        'year': year,
      };
}
