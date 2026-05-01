import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/retry_helper.dart';
import '../models/account.dart';
import '../models/time_range.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/app_logger.dart';

/// ViewModel for Home Screen
/// Separates business logic from UI with enhanced error handling and retry
class HomeViewModel extends ChangeNotifier with RetryMixin {

  HomeViewModel({
    required TransactionRepository transactionRepo,
    required AccountRepository accountRepo,
  })  : _transactionRepo = transactionRepo,
        _accountRepo = accountRepo;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  bool _loading = true;
  AppError? _error;
  double _totalBalance = 0;
  double _income = 0;
  double _expenses = 0;
  double _prevIncome = 0;
  double _prevExpenses = 0;
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};
  Map<String, double> _categorySpend = {};

  // Getters
  bool get loading => _loading;
  AppError? get error => _error;
  double get totalBalance => _totalBalance;
  double get income => _income;
  double get expenses => _expenses;
  double get prevIncome => _prevIncome;
  double get prevExpenses => _prevExpenses;
  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, double> get accountBalances => Map.unmodifiable(_accountBalances);
  Map<String, double> get categorySpend => Map.unmodifiable(_categorySpend);

  double get savingsRate {
    if (_income <= 0) return 0;
    return ((_income - _expenses) / _income).clamp(0, 1);
  }

  String percentageChange(double current, double previous) {
    if (previous == 0) return current > 0 ? '+100%' : '—';
    final pct = (current - previous) / previous * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  /// Load home screen data with automatic retry on failure
  Future<void> loadData(TimeRange filter) async {
    await withRetry(
      operation: () => _loadDataImpl(filter),
      onRetry: (attempt, error) {
        AppLogger.log(
          LogLevel.warning,
          LogCategory.userAction,
          'Home Data Load',
          detail: 'Retry attempt $attempt after error: $error',
        );
      },
    );
  }

  Future<void> _loadDataImpl(TimeRange filter) async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final prevFrom = filter.prevFrom;
      final prevTo = filter.prevTo;

      // Load all data in parallel for better performance
      final results = await Future.wait([
        _accountRepo.getAll(),
        _transactionRepo.getRangeTotal('income', filter.from, filter.to),
        _transactionRepo.getRangeTotal('expense', filter.from, filter.to),
        _transactionRepo.getRangeTotal('income', prevFrom, prevTo),
        _transactionRepo.getRangeTotal('expense', prevFrom, prevTo),
        _transactionRepo.getRangeExpenseByCategory(filter.from, filter.to),
      ]);

      _accounts = results[0] as List<Account>;
      _income = results[1] as double;
      _expenses = results[2] as double;
      _prevIncome = results[3] as double;
      _prevExpenses = results[4] as double;
      _categorySpend = results[5] as Map<String, double>;

      // Calculate balances
      double totalBalance = 0;
      final balances = <int, double>{};
      for (final account in _accounts) {
        final balance = await _accountRepo.getBalance(account.id!, account);
        balances[account.id!] = balance;
        if (account.isLiability) {
          totalBalance -= balance;
        } else {
          totalBalance += balance;
        }
      }

      _accountBalances = balances;
      _totalBalance = totalBalance;
      _loading = false;
      _error = null;
      notifyListeners();

      AppLogger.log(
        LogLevel.info,
        LogCategory.userAction,
        'Home Data Load',
        detail: 'Successfully loaded home data',
      );
    } catch (e, stackTrace) {
      _error = AppError.fromException(e, stackTrace);
      _loading = false;
      notifyListeners();

      AppLogger.log(
        LogLevel.error,
        LogCategory.error,
        'Home Data Load Error',
        detail: '${_error!.message}\n${_error!.technicalDetails}',
      );

      rethrow; // Re-throw for retry mechanism
    }
  }

  /// Refresh data
  Future<void> refresh(TimeRange filter) => loadData(filter);
}
