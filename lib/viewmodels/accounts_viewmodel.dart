import 'package:flutter/material.dart';

import '../models/account.dart';
import '../repositories/account_repository.dart';

/// ViewModel for Accounts Screen
class AccountsViewModel extends ChangeNotifier {

  AccountsViewModel({required AccountRepository accountRepo})
      : _accountRepo = accountRepo;
  final AccountRepository _accountRepo;

  bool _loading = true;
  String? _error;
  List<Account> _accounts = [];
  Map<int, double> _balances = {};

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, double> get balances => Map.unmodifiable(_balances);

  double get totalAssets {
    double total = 0;
    for (final account in _accounts) {
      final balance = _balances[account.id] ?? 0;
      if (account.type != 'credit') {
        total += balance;
      }
    }
    return total;
  }

  double get totalDebt {
    double total = 0;
    for (final account in _accounts) {
      final balance = _balances[account.id] ?? 0;
      if (account.isLiability) {
        total += balance;
      }
    }
    return total;
  }

  double get netWorth => totalAssets - totalDebt;

  /// Load accounts data
  Future<void> loadData() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      _accounts = await _accountRepo.getAll();
      
      final balances = <int, double>{};
      for (final account in _accounts) {
        balances[account.id!] = await _accountRepo.getBalance(account.id!, account);
      }
      
      _balances = balances;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load accounts: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Add a new account
  Future<bool> addAccount(Account account) async {
    try {
      await _accountRepo.insert(account);
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to add account: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing account
  Future<bool> updateAccount(Account account) async {
    try {
      await _accountRepo.update(account);
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to update account: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete an account
  Future<bool> deleteAccount(int id) async {
    try {
      await _accountRepo.delete(id);
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to delete account: $e';
      notifyListeners();
      return false;
    }
  }

  /// Transfer between accounts
  Future<bool> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
  }) async {
    try {
      await _accountRepo.transfer(
        fromId: fromId,
        toId: toId,
        amount: amount,
        note: note,
      );
      await loadData();
      return true;
    } catch (e) {
      _error = 'Failed to transfer: $e';
      notifyListeners();
      return false;
    }
  }

  /// Refresh data
  Future<void> refresh() => loadData();
}
