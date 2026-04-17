import '../models/account.dart';

/// Repository interface for account operations.
abstract class AccountRepository {
  /// Insert a new account
  Future<int> insert(Account account);

  /// Get all accounts
  Future<List<Account>> getAll();

  /// Update an existing account
  Future<void> update(Account account);

  /// Delete an account by ID
  Future<void> delete(int id);

  /// Calculate account balance
  Future<double> getBalance(int accountId, Account account);

  /// Transfer money between accounts
  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
    DateTime? date,
  });
}
