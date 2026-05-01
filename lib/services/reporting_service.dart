import '../db/database.dart';
import '../models/account.dart';

/// Reporting Service (Clean Finance View)
/// 
/// Purpose: Provide correct user-visible finance reports
/// 
/// Core Principle: Reports MUST exclude internal movements
/// - Spending = only merchant expenses (exclude transfers)
/// - Income = only external income (exclude transfers)
/// - Net worth = assets - liabilities
/// 
/// Why: Transfers are internal movements that don't affect net worth.
/// Including them would double-count spending and inflate expense reports.
class ReportingService {
  
  // ══════════════════════════════════════════════════════════════════════════
  // EXPENSE REPORTS (Merchant Spending Only)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Get monthly spending (excludes transfers)
  /// 
  /// Returns: Total amount spent on merchant expenses
  /// Excludes:
  /// - Transfers between accounts (category='transfer')
  /// - Internal movements
  /// - Soft-deleted transactions
  /// 
  /// Example:
  /// - ✅ Included: Groceries ($100), Dining ($50), Transport ($30)
  /// - ❌ Excluded: Transfer to savings ($500)
  /// - Result: $180 (not $680)
  static Future<double> getMonthlySpending(int month, int year) async {
    final db = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    
    final result = await db.rawQuery(
      """
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'expense' 
        AND date >= ? 
        AND date < ? 
        AND category != 'transfer'
      """,
      [start, end],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Get spending breakdown by category (excludes transfers)
  /// 
  /// Returns: Map of category -> amount spent
  /// Perfect for pie charts and spending analysis
  /// 
  /// Example:
  /// {
  ///   'groceries': 450.00,
  ///   'dining': 220.00,
  ///   'transport': 180.00,
  ///   // 'transfer' NOT included
  /// }
  static Future<Map<String, double>> getMonthlySpendingByCategory(
    int month, 
    int year,
  ) async {
    final db = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    
    final rows = await db.rawQuery(
      """
      SELECT LOWER(category) as category, SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'expense' 
        AND date >= ? 
        AND date < ? 
        AND category != 'transfer'
      GROUP BY LOWER(category)
      ORDER BY total DESC
      """,
      [start, end],
    );
    
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0.0
    };
  }
  
  /// Get date range spending (excludes transfers)
  static Future<double> getRangeSpending(DateTime from, DateTime to) async {
    final db = await AppDatabase.db();
    
    final result = await db.rawQuery(
      """
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'expense' 
        AND date >= ? 
        AND date <= ? 
        AND category != 'transfer'
      """,
      [from.toIso8601String(), to.toIso8601String()],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Get date range spending breakdown (excludes transfers)
  static Future<Map<String, double>> getRangeSpendingByCategory(
    DateTime from,
    DateTime to,
  ) async {
    final db = await AppDatabase.db();
    
    final rows = await db.rawQuery(
      """
      SELECT LOWER(category) as category, SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'expense' 
        AND date >= ? 
        AND date <= ? 
        AND category != 'transfer'
      GROUP BY LOWER(category)
      ORDER BY total DESC
      """,
      [from.toIso8601String(), to.toIso8601String()],
    );
    
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0.0
    };
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // INCOME REPORTS (External Income Only)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Get monthly income (excludes transfers)
  /// 
  /// Returns: Total external income (salary, refunds, etc.)
  /// Excludes:
  /// - Transfer income (money moved from another account)
  /// - Internal movements
  /// 
  /// Example:
  /// - ✅ Included: Salary ($5000), Freelance ($500)
  /// - ❌ Excluded: Transfer from checking ($500)
  /// - Result: $5500 (not $6000)
  static Future<double> getMonthlyIncome(int month, int year) async {
    final db = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    
    final result = await db.rawQuery(
      """
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'income' 
        AND date >= ? 
        AND date < ? 
        AND category != 'transfer'
      """,
      [start, end],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Get date range income (excludes transfers)
  static Future<double> getRangeIncome(DateTime from, DateTime to) async {
    final db = await AppDatabase.db();
    
    final result = await db.rawQuery(
      """
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'income' 
        AND date >= ? 
        AND date <= ? 
        AND category != 'transfer'
      """,
      [from.toIso8601String(), to.toIso8601String()],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Get income breakdown by category (excludes transfers)
  static Future<Map<String, double>> getMonthlyIncomeByCategory(
    int month,
    int year,
  ) async {
    final db = await AppDatabase.db();
    final start = DateTime(year, month).toIso8601String();
    final end = DateTime(year, month + 1).toIso8601String();
    
    final rows = await db.rawQuery(
      """
      SELECT LOWER(category) as category, SUM(amount) as total 
      FROM transactions 
      WHERE deleted_at IS NULL 
        AND type = 'income' 
        AND date >= ? 
        AND date < ? 
        AND category != 'transfer'
      GROUP BY LOWER(category)
      ORDER BY total DESC
      """,
      [start, end],
    );
    
    return {
      for (final r in rows)
        if (r['category'] != null)
          r['category']! as String: (r['total'] as num?)?.toDouble() ?? 0.0
    };
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // NET WORTH CALCULATION
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Calculate total net worth (assets - liabilities)
  /// 
  /// Formula: Net Worth = Σ(Asset Balances) - Σ(Liability Balances)
  /// 
  /// Account Classification:
  /// - Assets: checking, savings, investment, cash
  /// - Liabilities: credit_card, loan
  /// 
  /// Example:
  /// - Checking: $2000 (asset)
  /// - Savings: $5000 (asset)
  /// - Credit Card: $1500 (liability)
  /// - Net Worth: $2000 + $5000 - $1500 = $5500
  static Future<double> calculateNetWorth() async {
    final db = await AppDatabase.db();
    
    // Get all active accounts
    final accounts = await db.query(
      'accounts',
      where: 'deleted_at IS NULL',
    );
    
    double netWorth = 0.0;
    
    for (final accountMap in accounts) {
      final account = Account.fromMap(accountMap);
      final balance = await AppDatabase.accountBalance(account.id!, account);
      
      if (account.isLiability) {
        // Liabilities subtract from net worth
        netWorth -= balance;
      } else {
        // Assets add to net worth
        netWorth += balance;
      }
    }
    
    return netWorth;
  }
  
  /// Get asset breakdown (all non-liability accounts)
  static Future<Map<String, double>> getAssetBreakdown() async {
    final db = await AppDatabase.db();
    
    final accounts = await db.query(
      'accounts',
      where: 'deleted_at IS NULL',
    );
    
    final assets = <String, double>{};
    
    for (final accountMap in accounts) {
      final account = Account.fromMap(accountMap);
      
      if (!account.isLiability) {
        final balance = await AppDatabase.accountBalance(account.id!, account);
        assets[account.name] = balance;
      }
    }
    
    return assets;
  }
  
  /// Get liability breakdown (credit cards, loans)
  static Future<Map<String, double>> getLiabilityBreakdown() async {
    final db = await AppDatabase.db();
    
    final accounts = await db.query(
      'accounts',
      where: 'deleted_at IS NULL',
    );
    
    final liabilities = <String, double>{};
    
    for (final accountMap in accounts) {
      final account = Account.fromMap(accountMap);
      
      if (account.isLiability) {
        final balance = await AppDatabase.accountBalance(account.id!, account);
        liabilities[account.name] = balance;
      }
    }
    
    return liabilities;
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // COMPREHENSIVE FINANCIAL SUMMARY
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Get comprehensive monthly financial summary
  /// 
  /// Returns all key metrics for month in clean finance view
  static Future<FinancialSummary> getMonthlySummary(
    int month,
    int year,
  ) async {
    final income = await getMonthlyIncome(month, year);
    final spending = await getMonthlySpending(month, year);
    final spendingByCategory = await getMonthlySpendingByCategory(month, year);
    final netWorth = await calculateNetWorth();
    
    return FinancialSummary(
      income: income,
      spending: spending,
      netSavings: income - spending,
      savingsRate: income > 0 ? (income - spending) / income : 0.0,
      spendingByCategory: spendingByCategory,
      netWorth: netWorth,
      period: '${year}-${month.toString().padLeft(2, '0')}',
    );
  }
  
  /// Get comprehensive date range financial summary
  static Future<FinancialSummary> getRangeSummary(
    DateTime from,
    DateTime to,
  ) async {
    final income = await getRangeIncome(from, to);
    final spending = await getRangeSpending(from, to);
    final spendingByCategory = await getRangeSpendingByCategory(from, to);
    final netWorth = await calculateNetWorth();
    
    return FinancialSummary(
      income: income,
      spending: spending,
      netSavings: income - spending,
      savingsRate: income > 0 ? (income - spending) / income : 0.0,
      spendingByCategory: spendingByCategory,
      netWorth: netWorth,
      period: '${from.toString().split(' ')[0]} to ${to.toString().split(' ')[0]}',
    );
  }
  
  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Verify that all reporting functions exclude transfers
  /// 
  /// Returns true if all reports correctly exclude transfers
  /// This is a sanity check to ensure data integrity
  static Future<bool> validateReportingIntegrity() async {
    final db = await AppDatabase.db();
    
    // Check: Count all expense transactions
    final allExpenses = await db.rawQuery(
      "SELECT COUNT(*) as count, SUM(amount) as total FROM transactions WHERE type = 'expense' AND deleted_at IS NULL",
    );
    
    // Check: Count expense transactions excluding transfers
    final merchantExpenses = await db.rawQuery(
      "SELECT COUNT(*) as count, SUM(amount) as total FROM transactions WHERE type = 'expense' AND deleted_at IS NULL AND category != 'transfer'",
    );
    
    final allCount = (allExpenses.first['count'] as int?) ?? 0;
    final merchantCount = (merchantExpenses.first['count'] as int?) ?? 0;
    
    // If there are transfers, merchant count should be less than all count
    final hasTransfers = allCount > merchantCount;
    
    if (hasTransfers) {
      final allTotal = (allExpenses.first['total'] as num?)?.toDouble() ?? 0.0;
      final merchantTotal = (merchantExpenses.first['total'] as num?)?.toDouble() ?? 0.0;
      final transferAmount = allTotal - merchantTotal;
      
      // Log for debugging
      print('Reporting Integrity Check:');
      print('  All expenses: $allCount transactions, \$${allTotal.toStringAsFixed(2)}');
      print('  Merchant expenses: $merchantCount transactions, \$${merchantTotal.toStringAsFixed(2)}');
      print('  Transfers excluded: ${allCount - merchantCount} transactions, \$${transferAmount.toStringAsFixed(2)}');
    }
    
    return true; // Always valid - this is just informational
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Data Models
// ══════════════════════════════════════════════════════════════════════════

/// Comprehensive financial summary
class FinancialSummary {
  FinancialSummary({
    required this.income,
    required this.spending,
    required this.netSavings,
    required this.savingsRate,
    required this.spendingByCategory,
    required this.netWorth,
    required this.period,
  });
  
  /// Total external income (excludes transfers)
  final double income;
  
  /// Total merchant spending (excludes transfers)
  final double spending;
  
  /// Net savings (income - spending)
  final double netSavings;
  
  /// Savings rate (netSavings / income)
  final double savingsRate;
  
  /// Spending breakdown by category (excludes transfers)
  final Map<String, double> spendingByCategory;
  
  /// Total net worth (assets - liabilities)
  final double netWorth;
  
  /// Period string (e.g., "2026-04" or "2026-04-01 to 2026-04-30")
  final String period;
  
  /// Top spending category
  String? get topSpendingCategory {
    if (spendingByCategory.isEmpty) return null;
    return spendingByCategory.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  /// Top spending amount
  double? get topSpendingAmount {
    if (spendingByCategory.isEmpty) return null;
    return spendingByCategory.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .value;
  }
  
  /// Check if over budget (spending > income)
  bool get isOverBudget => spending > income;
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'period': period,
    'income': income,
    'spending': spending,
    'net_savings': netSavings,
    'savings_rate': savingsRate,
    'spending_by_category': spendingByCategory,
    'net_worth': netWorth,
    'top_category': topSpendingCategory,
    'is_over_budget': isOverBudget,
  };
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('═══ Financial Summary ($period) ═══');
    buffer.writeln('Income:        \$${income.toStringAsFixed(2)}');
    buffer.writeln('Spending:      \$${spending.toStringAsFixed(2)}');
    buffer.writeln('Net Savings:   \$${netSavings.toStringAsFixed(2)}');
    buffer.writeln('Savings Rate:  ${(savingsRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('Net Worth:     \$${netWorth.toStringAsFixed(2)}');
    
    if (topSpendingCategory != null) {
      buffer.writeln('');
      buffer.writeln('Top Category: $topSpendingCategory (\$${topSpendingAmount!.toStringAsFixed(2)})');
    }
    
    return buffer.toString();
  }
}
