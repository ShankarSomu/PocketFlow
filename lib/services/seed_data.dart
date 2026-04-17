import '../db/database.dart';
import '../models/account.dart';
import '../models/transaction.dart' as model;
import '../models/budget.dart';
import '../models/savings_goal.dart';
import '../models/recurring_transaction.dart';

/// Populates the database with 13 months of realistic demo data
/// (April 2025 → April 2026) so every screen has meaningful content to display.
class SeedData {
  static Future<void> load() async {
    // ── 1. Accounts ───────────────────────────────────────────────────────────
    final checkingId = await AppDatabase.insertAccount(Account(
      name: 'Chase Checking',
      type: 'checking',
      balance: 3200.00,
    ));
    final savingsId = await AppDatabase.insertAccount(Account(
      name: 'High-Yield Savings',
      type: 'savings',
      balance: 11500.00,
    ));
    final creditId = await AppDatabase.insertAccount(Account(
      name: 'Visa Signature',
      type: 'credit',
      balance: 420.00,
      last4: '4821',
      creditLimit: 12000.00,
      dueDateDay: 15,
    ));
    final cashId = await AppDatabase.insertAccount(Account(
      name: 'Wallet Cash',
      type: 'cash',
      balance: 180.00,
    ));

    // ── 2. Savings Goals ──────────────────────────────────────────────────────
    final goalEmergencyId = await AppDatabase.insertGoal(SavingsGoal(
      name: 'Emergency Fund',
      target: 20000.00,
      saved: 7600.00,
      accountId: savingsId,
      priority: 1,
    ));
    final goalCarId = await AppDatabase.insertGoal(SavingsGoal(
      name: 'New Car',
      target: 28000.00,
      saved: 9400.00,
      accountId: savingsId,
      priority: 2,
    ));
    final goalVacationId = await AppDatabase.insertGoal(SavingsGoal(
      name: 'Europe Vacation',
      target: 6000.00,
      saved: 3200.00,
      accountId: savingsId,
      priority: 3,
    ));
    await AppDatabase.insertGoal(SavingsGoal(
      name: 'Home Down Payment',
      target: 60000.00,
      saved: 14000.00,
      accountId: savingsId,
      priority: 4,
    ));

    // ── 3. Recurring Transactions ─────────────────────────────────────────────
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'income',
      amount: 5800.00,
      category: 'Salary',
      note: 'Monthly net pay',
      accountId: checkingId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 1),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 1850.00,
      category: 'Rent',
      note: 'Apartment rent',
      accountId: checkingId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 1),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 85.00,
      category: 'Phone',
      note: 'Mobile plan',
      accountId: creditId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 10),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 69.99,
      category: 'Internet',
      note: 'Home broadband',
      accountId: checkingId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 5),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 15.99,
      category: 'Entertainment',
      note: 'Netflix',
      accountId: creditId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 6),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 9.99,
      category: 'Entertainment',
      note: 'Spotify',
      accountId: creditId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 8),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 45.00,
      category: 'Health & Fitness',
      note: 'Gym membership',
      accountId: creditId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 1),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'goal',
      amount: 300.00,
      category: 'Goal contribution',
      note: 'Emergency fund top-up',
      accountId: checkingId,
      goalId: goalEmergencyId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 2),
      isActive: true,
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'goal',
      amount: 400.00,
      category: 'Goal contribution',
      note: 'Car savings',
      accountId: savingsId,
      goalId: goalCarId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 2),
      isActive: false, // paused to show the paused state
    ));
    await AppDatabase.insertRecurring(RecurringTransaction(
      type: 'expense',
      amount: 220.00,
      category: 'Insurance',
      note: 'Auto + renters insurance',
      accountId: checkingId,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 5, 15),
      isActive: true,
    ));

    // ── 4. Transactions — 13 months ───────────────────────────────────────────
    // Each month gets: salary in, rent, utilities, groceries, dining, transport,
    // shopping, phone, internet, streaming, gym, plus occasional extras.

    final _rng = _SeededRandom(42);

    final months = <_Month>[];
    // Apr 2025 → Apr 2026 inclusive = 13 months
    for (var m = 4; m <= 12; m++) months.add(_Month(2025, m));
    for (var m = 1; m <= 4; m++) months.add(_Month(2026, m));

    for (final mo in months) {
      final y = mo.year;
      final m = mo.month;
      final lastDay = DateTime(y, m + 1, 0).day;

      // ── Income ──────────────────────────────────────────────────────────────
      await _tx('income', 5800.00, 'Salary', 'Monthly pay', y, m, 1, checkingId);

      // Side hustle — random months
      if (_rng.nextBool()) {
        await _tx('income', _rng.between(150, 550), 'Freelance', 'Side project', y, m, _rng.day(lastDay), checkingId);
      }

      // Occasional cash-back / refund
      if (_rng.chance(30)) {
        await _tx('income', _rng.between(20, 120), 'Refund', 'Credit card reward', y, m, _rng.day(lastDay), creditId);
      }

      // ── Fixed expenses ──────────────────────────────────────────────────────
      await _tx('expense', 1850.00, 'Rent', 'Apartment rent', y, m, 1, checkingId);
      await _tx('expense', 85.00, 'Phone', 'Mobile plan', y, m, 10, creditId);
      await _tx('expense', 69.99, 'Internet', 'Broadband', y, m, 5, checkingId);
      await _tx('expense', 15.99, 'Entertainment', 'Netflix', y, m, 6, creditId);
      await _tx('expense', 9.99, 'Entertainment', 'Spotify', y, m, 8, creditId);
      await _tx('expense', 45.00, 'Health & Fitness', 'Gym', y, m, 1, creditId);
      await _tx('expense', 220.00, 'Insurance', 'Auto + renters', y, m, 15, checkingId);

      // ── Utilities (varies) ────────────────────────────────────────────────
      final electric = _rng.between(60, 130);
      await _tx('expense', electric, 'Utilities', 'Electric bill', y, m, 12, checkingId);
      if (_rng.chance(60)) {
        await _tx('expense', _rng.between(30, 55), 'Utilities', 'Water bill', y, m, 14, checkingId);
      }

      // ── Groceries (2-4 trips/month) ────────────────────────────────────────
      final groceryTrips = _rng.intBetween(2, 4);
      for (var g = 0; g < groceryTrips; g++) {
        await _tx('expense', _rng.between(80, 180), 'Food & Groceries',
            ['Trader Joe\'s', 'Whole Foods', 'Costco', 'Safeway'][g % 4],
            y, m, _rng.day(lastDay), creditId);
      }

      // ── Dining out (4-10 times/month) ─────────────────────────────────────
      final diningCount = _rng.intBetween(4, 10);
      final restaurants = [
        'Chipotle', 'Subway', 'Thai Palace', 'Sushi Bar', 'Pizza Hut',
        'Shake Shack', 'Coffee shop', 'Brunch spot', 'Taco Bell', 'Italian bistro',
      ];
      for (var d = 0; d < diningCount; d++) {
        await _tx('expense', _rng.between(12, 75), 'Dining Out',
            restaurants[d % restaurants.length],
            y, m, _rng.day(lastDay), creditId);
      }

      // ── Transport ─────────────────────────────────────────────────────────
      await _tx('expense', _rng.between(40, 80), 'Transport', 'Gas', y, m, _rng.day(lastDay), creditId);
      if (_rng.chance(70)) {
        await _tx('expense', _rng.between(15, 45), 'Transport', 'Uber/Lyft', y, m, _rng.day(lastDay), creditId);
      }
      if (_rng.chance(40)) {
        await _tx('expense', _rng.between(3, 10), 'Transport', 'Parking', y, m, _rng.day(lastDay), cashId);
      }

      // ── Shopping ──────────────────────────────────────────────────────────
      if (_rng.chance(80)) {
        await _tx('expense', _rng.between(30, 200), 'Shopping',
            ['Amazon', 'Target', 'Best Buy', 'H&M', 'IKEA'][_rng.intBetween(0, 4)],
            y, m, _rng.day(lastDay), creditId);
      }
      if (_rng.chance(40)) {
        await _tx('expense', _rng.between(20, 120), 'Shopping', 'Amazon', y, m, _rng.day(lastDay), creditId);
      }

      // ── Healthcare (occasional) ────────────────────────────────────────────
      if (_rng.chance(35)) {
        await _tx('expense', _rng.between(20, 180), 'Healthcare',
            ['Pharmacy', 'Doctor visit', 'Eye care', 'Dental'][_rng.intBetween(0, 3)],
            y, m, _rng.day(lastDay), creditId);
      }

      // ── Personal care ─────────────────────────────────────────────────────
      if (_rng.chance(60)) {
        await _tx('expense', _rng.between(25, 80), 'Personal Care',
            ['Haircut', 'Pharmacy', 'Skincare'][_rng.intBetween(0, 2)],
            y, m, _rng.day(lastDay), cashId);
      }

      // ── Education (occasional) ────────────────────────────────────────────
      if (_rng.chance(20)) {
        await _tx('expense', _rng.between(15, 80), 'Education',
            ['Udemy course', 'Book', 'Online class'][_rng.intBetween(0, 2)],
            y, m, _rng.day(lastDay), creditId);
      }

      // ── Home & Maintenance ────────────────────────────────────────────────
      if (_rng.chance(25)) {
        await _tx('expense', _rng.between(20, 150), 'Home',
            ['Cleaning supplies', 'Home repair', 'Plant', 'Bedding'][_rng.intBetween(0, 3)],
            y, m, _rng.day(lastDay), creditId);
      }

      // ── Travel (summer months + December) ─────────────────────────────────
      if (m == 7 || m == 8 || m == 12 || (y == 2026 && m == 3)) {
        await _tx('expense', _rng.between(200, 800), 'Travel',
            m == 12 ? 'Holiday flights' : 'Vacation booking',
            y, m, _rng.day(lastDay), creditId);
        if (_rng.chance(60)) {
          await _tx('expense', _rng.between(80, 300), 'Travel', 'Hotel stay', y, m, _rng.day(lastDay), creditId);
        }
      }

      // ── Transfer to savings each month ────────────────────────────────────
      final transferAmt = _rng.between(200, 600);
      await AppDatabase.transfer(
        fromId: checkingId,
        toId: savingsId,
        amount: transferAmt,
        note: 'Monthly savings transfer',
        date: DateTime(y, m, 28),
      );

      // ── Goal contribution (manual record alongside saved amount) ──────────
      if (_rng.chance(70)) {
        await _tx('expense', 300.00, 'Savings Goal', 'Emergency fund contribution', y, m, 2, checkingId);
      }
    }

    // ── 5. Budgets — for each month in the range ──────────────────────────────
    // Create budgets for the key spending categories
    final budgetCategories = {
      'Food & Groceries': 500.00,
      'Dining Out': 350.00,
      'Transport': 200.00,
      'Shopping': 300.00,
      'Entertainment': 80.00,
      'Utilities': 160.00,
      'Health & Fitness': 100.00,
      'Healthcare': 150.00,
      'Personal Care': 80.00,
      'Travel': 600.00,
    };

    for (final mo in months) {
      for (final entry in budgetCategories.entries) {
        await AppDatabase.upsertBudget(Budget(
          category: entry.key,
          limit: entry.value,
          month: mo.month,
          year: mo.year,
        ));
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<void> _tx(
    String type,
    double amount,
    String category,
    String note,
    int year,
    int month,
    int day,
    int? accountId,
  ) async {
    await AppDatabase.insertTransaction(model.Transaction(
      type: type,
      amount: double.parse(amount.toStringAsFixed(2)),
      category: category,
      note: note,
      date: DateTime(year, month, day < 1 ? 1 : day),
      accountId: accountId,
    ));
  }
}

// ── Simple deterministic pseudo-random helper ──────────────────────────────────

class _Month {
  final int year;
  final int month;
  const _Month(this.year, this.month);
}

class _SeededRandom {
  int _state;
  _SeededRandom(this._state);

  int _next() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state;
  }

  double between(double min, double max) {
    final r = (_next() & 0x7FFFFFFF) / 0x7FFFFFFF;
    final raw = min + r * (max - min);
    return (raw * 100).round() / 100;
  }

  int intBetween(int min, int max) => min + (_next().abs() % (max - min + 1));

  int day(int lastDay) => intBetween(1, lastDay);

  bool nextBool() => (_next() & 1) == 1;

  /// Returns true with the given percentage probability (0-100).
  bool chance(int percent) => (_next().abs() % 100) < percent;
}
