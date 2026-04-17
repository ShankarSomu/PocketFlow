import 'package:flutter/material.dart';

import '../repositories/recurring_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/savings_repository.dart';
import '../models/recurring_transaction.dart';
import '../models/account.dart';
import '../models/savings_goal.dart';

/// ViewModel for Recurring Transactions Screen
class RecurringViewModel extends ChangeNotifier {
  final RecurringRepository _recurringRepo;
  final AccountRepository _accountRepo;
  final SavingsRepository _savingsRepo;

  RecurringViewModel({
    required RecurringRepository recurringRepo,
    required AccountRepository accountRepo,
    required SavingsRepository savingsRepo,
  })  : _recurringRepo = recurringRepo,
        _accountRepo = accountRepo,
        _savingsRepo = savingsRepo;

  bool _loading = true;
  String? _error;
  List<RecurringTransaction> _items = [];
  List<Account> _accounts = [];
  List<SavingsGoal> _goals = [];

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<RecurringTransaction> get items => List.unmodifiable(_items);
  List<Account> get accounts => List.unmodifiable(_accounts);
  List<SavingsGoal> get goals => List.unmodifiable(_goals);

  List<RecurringTransaction> get activeItems {
    return _items.where((i) => i.isActive).toList();
  }

  List<RecurringTransaction> get pausedItems {
    return _items.where((i) => !i.isActive).toList();
  }

  double get totalMonthlyAmount {
    return activeItems.fold(0.0, (sum, item) {
      final monthlyAmount = _getMonthlyEquivalent(item);
      return item.type == 'expense' ? sum + monthlyAmount : sum - monthlyAmount;
    });
  }

  double _getMonthlyEquivalent(RecurringTransaction item) {
    switch (item.frequency) {
      case 'daily':
        return item.amount * 30;
      case 'weekly':
        return item.amount * 4;
      case 'bi-weekly':
        return item.amount * 2;
      case 'monthly':
        return item.amount;
      case 'quarterly':
        return item.amount / 3;
      case 'yearly':
        return item.amount / 12;
      default:
        return item.amount;
    }
  }

  /// Load recurring data
  Future<void> loadData() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        _recurringRepo.getAll(),
        _accountRepo.getAll(),
        _savingsRepo.getAll(),
      ]);

      _items = results[0] as List<RecurringTransaction>;
      _accounts = results[1] as List<Account>;
      _goals = results[2] as List<SavingsGoal>;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load recurring transactions: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Add a new recurring transaction
  Future<bool> addRecurring(RecurringTransaction item) async {
    try {
      await _recurringRepo.insert(item);
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to add recurring transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing recurring transaction
  Future<bool> updateRecurring(RecurringTransaction item) async {
    try {
      await _recurringRepo.update(item);
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _items[index] = item;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update recurring transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a recurring transaction
  Future<bool> deleteRecurring(int id) async {
    try {
      await _recurringRepo.delete(id);
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete recurring transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle active status
  Future<bool> toggleActive(RecurringTransaction item) async {
    final updated = RecurringTransaction(
      id: item.id,
      type: item.type,
      amount: item.amount,
      category: item.category,
      note: item.note,
      accountId: item.accountId,
      toAccountId: item.toAccountId,
      goalId: item.goalId,
      frequency: item.frequency,
      nextDueDate: item.nextDueDate,
      isActive: !item.isActive,
    );
    return updateRecurring(updated);
  }

  /// Refresh data
  Future<void> refresh() => loadData();
}
