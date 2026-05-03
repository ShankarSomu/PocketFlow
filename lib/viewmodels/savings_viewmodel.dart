import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/savings_goal.dart';
import '../repositories/account_repository.dart';
import '../repositories/savings_repository.dart';
import '../repositories/transaction_repository.dart';

/// ViewModel for Goals Screen
class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel({
    required GoalsRepository goalsRepo,
    required AccountRepository accountRepo,
    required TransactionRepository transactionRepo,
  })  : _goalsRepo = goalsRepo,
        _accountRepo = accountRepo,
        _transactionRepo = transactionRepo;
  final GoalsRepository _goalsRepo;
  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;

  bool _loading = true;
  String? _error;
  List<Goal> _goals = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};
  Map<int, double> _goalSaved = {}; // goalId -> computed saved amount

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<Goal> get goals => List.unmodifiable(_goals);
  double savedForGoal(int goalId) => _goalSaved[goalId] ?? 0.0;
  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, double> get accountBalances => Map.unmodifiable(_accountBalances);

  double get totalSaved => _goals.fold(0.0, (sum, g) => sum + savedForGoal(g.id!));
  double get totalTarget => _goals.fold(0.0, (sum, g) => sum + g.target);

  double get totalProgress {
    if (totalTarget <= 0) return 0;
    return (totalSaved / totalTarget).clamp(0.0, 1.0);
  }

  List<Goal> get completedGoals {
    return _goals.where((g) => savedForGoal(g.id!) >= g.target).toList();
  }

  List<Goal> get activeGoals {
    return _goals.where((g) => savedForGoal(g.id!) < g.target).toList();
  }

  /// Load goals data
  Future<void> loadData() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        _goalsRepo.getAll(),
        _accountRepo.getAll(),
      ]);

      _goals = results[0] as List<Goal>;
      _accounts = results[1] as List<Account>;

      final balances = <int, double>{};
      for (final account in _accounts) {
        balances[account.id!] = await _accountRepo.getBalance(account.id!, account);
      }
      _accountBalances = balances;

      // Compute saved for each goal
      _goalSaved.clear();
      for (final goal in _goals) {
        if (goal.accountId != null) {
          // Sum all income and transfer_in transactions for this account
          final txns = await _transactionRepo.getAll(accountId: goal.accountId);
          final saved = txns
              .where((t) => t.type == 'income' || t.type == 'transfer_in')
              .fold(0.0, (sum, t) => sum + t.amount);
          _goalSaved[goal.id!] = saved;
        } else {
          _goalSaved[goal.id!] = 0.0;
        }
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load goals: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Add a new goal
  Future<bool> addGoal(Goal goal) async {
    try {
      await _goalsRepo.insert(goal);
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to add goal: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing goal
  Future<bool> updateGoal(Goal goal) async {
    try {
      await _goalsRepo.update(goal);
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

  // No updateSaved method; savings is always computed from transactions

  /// Delete a goal
  Future<bool> deleteGoal(int id) async {
    try {
      await _goalsRepo.delete(id);
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
