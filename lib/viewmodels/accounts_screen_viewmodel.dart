import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';
import '../services/refresh_notifier.dart';

class AccountsScreenViewModel extends ChangeNotifier {
  AccountsScreenViewModel({required AccountRepository accountRepository})
      : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;

  bool _loading = true;
  String? _error;
  List<Account> _accounts = [];
  Map<int, double> _balances = {};

  bool get loading => _loading;
  String? get error => _error;
  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, double> get balances => Map.unmodifiable(_balances);

  double get totalAssets {
    double total = 0;
    for (final account in _accounts) {
      final balance = _balances[account.id] ?? 0;
      if (!account.isLiability) {
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
        total += balance.abs();
      }
    }
    return total;
  }

  double get netWorth => totalAssets - totalDebt;

  Map<String, List<Account>> get groupedAccounts {
    final groups = <String, List<Account>>{};
    for (final account in _accounts) {
      groups.putIfAbsent(account.type, () => []).add(account);
    }
    return groups;
  }

  Future<void> loadData() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final accounts = await _accountRepository.getAll();
      final balances = <int, double>{};
      for (final account in accounts) {
        if (account.id == null) continue;
        balances[account.id!] = await _accountRepository.getBalance(account.id!, account);
      }

      _accounts = accounts;
      _balances = balances;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load accounts: $e';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveAccount(Account account) async {
    if (account.id == null) {
      await _accountRepository.insert(account);
    } else {
      await _accountRepository.update(account);
    }
    notifyDataChanged();
  }

  Future<void> deleteAccount(Account account) async {
    if (account.id == null) return;
    await AppDatabase.deleteAccount(account.id!);
    notifyDataChanged();
  }

  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
  }) async {
    await _accountRepository.transfer(
      fromId: fromId,
      toId: toId,
      amount: amount,
      note: note,
    );
    notifyDataChanged();
  }
}
