import 'package:flutter/material.dart';

import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../models/budget.dart';
import '../models/time_range.dart';

/// ViewModel for Budget Screen
class BudgetViewModel extends ChangeNotifier {
  final BudgetRepository _budgetRepo;
  final TransactionRepository _transactionRepo;

  BudgetViewModel({
    required BudgetRepository budgetRepo,
    required TransactionRepository transactionRepo,
  })  : _budgetRepo = budgetRepo,
        _transactionRepo = transactionRepo;

  bool _loading = true;
  String? _error;
  List<Budget> _budgets = [];
  Map<String, double> _spentByCategory = {};
  double _income = 0;

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<Budget> get budgets => List.unmodifiable(_budgets);
  Map<String, double> get spentByCategory => Map.unmodifiable(_spentByCategory);
  double get income => _income;

  double get totalLimit => _budgets.fold(0.0, (sum, b) => sum + b.limit);
  double get totalSpent => _spentByCategory.values.fold(0.0, (sum, v) => sum + v);
  
  double get progress {
    final limit = totalLimit;
    if (limit <= 0) return 0.0;
    return (totalSpent / limit).clamp(0.0, 1.0);
  }

  List<Budget> get onBudget {
    return _budgets
        .where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) <= b.limit)
        .toList();
  }

  List<Budget> get overBudget {
    return _budgets
        .where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) > b.limit)
        .toList();
  }

  List<Budget> get untracked {
    return _budgets.where((b) => b.limit <= 0).toList();
  }

  /// Load budget data
  Future<void> loadData(TimeRange filter) async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        _budgetRepo.getForMonth(filter.budgetMonth, filter.budgetYear),
        _transactionRepo.getRangeExpenseByCategory(filter.from, filter.to),
        _transactionRepo.getRangeTotal('income', filter.from, filter.to),
      ]);

      final budgets = results[0] as List<Budget>;
      final spent = results[1] as Map<String, double>;
      _income = results[2] as double;

      // Add untracked categories
      final budgetCategories = {for (final b in budgets) b.category};
      final extra = spent.keys
          .where((c) => !budgetCategories.contains(c))
          .map((c) => Budget(
                category: c,
                limit: 0,
                month: filter.budgetMonth,
                year: filter.budgetYear,
              ))
          .toList();

      _budgets = [...budgets, ...extra];
      _spentByCategory = spent;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load budgets: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Save or update a budget
  Future<bool> saveBudget(Budget budget) async {
    try {
      await _budgetRepo.upsert(budget);
      // Update local list
      final index = _budgets.indexWhere(
          (b) => b.category == budget.category && 
                 b.month == budget.month && 
                 b.year == budget.year);
      if (index != -1) {
        _budgets[index] = budget;
      } else {
        _budgets.add(budget);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save budget: $e';
      notifyListeners();
      return false;
    }
  }

  /// Refresh data
  Future<void> refresh(TimeRange filter) => loadData(filter);
}
