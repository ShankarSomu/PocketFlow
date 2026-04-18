import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Predefined empty states for common scenarios
class EmptyStates {
  static Widget transactions(BuildContext context, VoidCallback onAdd) {
    return EmptyStateWidget(
      icon: Icons.receipt_long_rounded,
      title: 'No Transactions Yet',
      message: 'Start tracking your finances by adding your first transaction.',
      actionLabel: 'Add Transaction',
      onAction: onAdd,
    );
  }

  static Widget budgets(BuildContext context, VoidCallback onAdd) {
    return EmptyStateWidget(
      icon: Icons.pie_chart_rounded,
      title: 'No Budgets Set',
      message: 'Create budgets to track your spending and stay on target.',
      actionLabel: 'Create Budget',
      onAction: onAdd,
    );
  }

  static Widget goals(BuildContext context, VoidCallback onAdd) {
    return EmptyStateWidget(
      icon: Icons.flag_rounded,
      title: 'No Savings Goals',
      message: 'Set goals to save for what matters most to you.',
      actionLabel: 'Create Goal',
      onAction: onAdd,
    );
  }

  static Widget accounts(BuildContext context, VoidCallback onAdd) {
    return EmptyStateWidget(
      icon: Icons.account_balance_wallet_rounded,
      title: 'No Accounts Added',
      message: 'Add your bank accounts, credit cards, or cash to get started.',
      actionLabel: 'Add Account',
      onAction: onAdd,
    );
  }

  static Widget bills(BuildContext context, VoidCallback onAdd) {
    return EmptyStateWidget(
      icon: Icons.calendar_today_rounded,
      title: 'No Bills Tracked',
      message: 'Add recurring bills to never miss a payment.',
      actionLabel: 'Add Bill',
      onAction: onAdd,
    );
  }

  static Widget search(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      message: 'Try adjusting your search or filters.',
    );
  }

  static Widget error(BuildContext context, String message, VoidCallback onRetry) {
    return EmptyStateWidget(
      icon: Icons.error_outline_rounded,
      title: 'Something Went Wrong',
      message: message,
      actionLabel: 'Try Again',
      onAction: onRetry,
    );
  }
}
