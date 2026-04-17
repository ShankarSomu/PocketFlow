import 'package:flutter/material.dart';

import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';
import '../models/transaction.dart' as model;
import '../models/account.dart';
import '../models/time_range.dart';
import '../services/time_filter.dart';

/// ViewModel for Transactions Screen
class TransactionsViewModel extends ChangeNotifier {
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  TransactionsViewModel({
    required TransactionRepository transactionRepo,
    required AccountRepository accountRepo,
  })  : _transactionRepo = transactionRepo,
        _accountRepo = accountRepo;

  bool _loading = true;
  String? _error;
  List<model.Transaction> _transactions = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<model.Transaction> get transactions => List.unmodifiable(_transactions);
  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, double> get accountBalances => Map.unmodifiable(_accountBalances);

  /// Load transactions data
  Future<void> loadData(TimeRange filter) async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        _transactionRepo.getAll(from: filter.from, to: filter.to),
        _accountRepo.getAll(),
      ]);

      _transactions = results[0] as List<model.Transaction>;
      _accounts = results[1] as List<Account>;

      final balances = <int, double>{};
      for (final account in _accounts) {
        balances[account.id!] = await _accountRepo.getBalance(account.id!, account);
      }

      _accountBalances = balances;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load transactions: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Add a new transaction
  Future<bool> addTransaction(model.Transaction transaction) async {
    try {
      await _transactionRepo.insert(transaction);
      // Don't reload all data, just add to list
      _transactions.insert(0, transaction);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing transaction
  Future<bool> updateTransaction(model.Transaction transaction) async {
    try {
      await _transactionRepo.update(transaction);
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a transaction
  Future<bool> deleteTransaction(int id) async {
    try {
      await _transactionRepo.delete(id);
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Refresh data
  Future<void> refresh(TimeRange filter) => loadData(filter);
}
