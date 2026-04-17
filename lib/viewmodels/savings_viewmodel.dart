import 'package:flutter/material.dart';

import '../repositories/savings_repository.dart';
import '../repositories/account_repository.dart';
import '../models/savings_goal.dart';
import '../models/account.dart';

/// ViewModel for Savings Screen
class SavingsViewModel extends ChangeNotifier {
  final SavingsRepository _savingsRepo;
  final AccountRepository _accountRepo;

  SavingsViewModel({
    required SavingsRepository savingsRepo,
    required AccountRepository accountRepo,
  })  : _savingsRepo = savingsRepo,
        _accountRepo = accountRepo;

  bool _loading = true;
  String? _error;
  List<SavingsGoal> _goals = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<SavingsGoal> get goals => List.unmodifiable(_goals);
  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, double> get accountBalances => Map.unmodifiable(_accountBalances);

  double get totalSaved => _goals.fold(0.0, (sum, g) => sum + g.saved);
  double get totalTarget => _goals.fold(0.0, (sum, g) => sum + g.target);
  
  double get totalProgress {
    if (totalTarget <= 0) return 0;
    return (totalSaved / totalTarget).clamp(0.0, 1.0);
  }

  List<SavingsGoal> get completedGoals {
    return _goals.where((g) => g.isComplete).toList();
  }

  List<SavingsGoal> get activeGoals {
    return _goals.where((g) => !g.isComplete).toList();
  }

  /// Load savings data
  Future<void> loadData() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        _savingsRepo.getAll(),
        _accountRepo.getAll(),
      ]);

      _goals = results[0] as List<SavingsGoal>;
      _accounts = results[1] as List<Account>;

      final balances = <int, double>{};
      for (final account in _accounts) {
        balances[account.id!] = await _accountRepo.getBalance(account.id!, account);
      }

      _accountBalances = balances;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load savings goals: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Add a new goal
  Future<bool> addGoal(SavingsGoal goal) async {
    try {
      await _savingsRepo.insert(goal);
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to add goal: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing goal
  Future<bool> updateGoal(SavingsGoal goal) async {
    try {
      await _savingsRepo.update(goal);
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _goals[index] = goal;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update goal: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update saved amount
  Future<bool> updateSaved(int id, double saved) async {
    try {
      await _savingsRepo.updateSaved(id, saved);
      final index = _goals.indexWhere((g) => g.id == id);
      if (index != -1) {
        final goal = _goals[index];
        _goals[index] = SavingsGoal(
          id: goal.id,
          name: goal.name,
          target: goal.target,
          saved: saved,
          accountId: goal.accountId,
          priority: goal.priority,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update saved amount: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a goal
  Future<bool> deleteGoal(int id) async {
    try {
      await _savingsRepo.delete(id);
      _goals.removeWhere((g) => g.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete goal: $e';
      notifyListeners();
      return false;
    }
  }

  /// Refresh data
  Future<void> refresh() => loadData();
}
