import 'package:flutter/material.dart';

import '../../../models/account.dart';

class AccountTypeStyle {
  const AccountTypeStyle._();

  static List<Color> gradient(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (type) {
      'checking' || 'debit' => [
          colorScheme.primary,
          colorScheme.primary.withValues(alpha: 0.8),
        ],
      'savings' => [
          colorScheme.tertiary,
          colorScheme.tertiary.withValues(alpha: 0.8),
        ],
      'credit' || 'credit_card' || 'loan' => [
          colorScheme.error,
          colorScheme.error.withValues(alpha: 0.8),
        ],
      'cash' => [
          colorScheme.secondary,
          colorScheme.secondary.withValues(alpha: 0.8),
        ],
      'investment' => [
          colorScheme.primary.withValues(alpha: 0.7),
          colorScheme.primary.withValues(alpha: 0.5),
        ],
      _ => [
          colorScheme.primary.withValues(alpha: 0.6),
          colorScheme.primary.withValues(alpha: 0.4),
        ],
    };
  }

  static IconData icon(String type) => switch (type) {
        'checking' || 'debit' => Icons.account_balance_rounded,
        'savings' => Icons.savings_rounded,
        'credit' || 'credit_card' => Icons.credit_card_rounded,
        'loan' => Icons.request_quote_rounded,
        'cash' => Icons.payments_rounded,
        'investment' => Icons.trending_up_rounded,
        _ => Icons.account_balance_wallet_rounded,
      };

  static Color color(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (type) {
      'checking' || 'debit' => colorScheme.primary,
      'savings' => colorScheme.tertiary,
      'credit' || 'credit_card' || 'loan' => colorScheme.error,
      'cash' => colorScheme.secondary,
      'investment' => colorScheme.primary.withValues(alpha: 0.7),
      _ => colorScheme.primary.withValues(alpha: 0.6),
    };
  }

  static String label(String type) {
    final normalized = switch (type) {
      'credit_card' => 'Credit Card',
      'unidentified' => 'Unidentified',
      _ => type[0].toUpperCase() + type.substring(1),
    };
    return normalized;
  }

  static int sortOrder(Account account) {
    return Account.types.indexOf(account.type);
  }
}
