import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/account.dart';
import '../../../theme/app_color_scheme.dart';
import '../../../theme/app_theme.dart';
import 'account_type_style.dart';

class AccountsSection extends StatelessWidget {
  const AccountsSection({
    super.key,
    required this.type,
    required this.accounts,
    required this.balances,
    required this.fmt,
    required this.onTap,
    required this.onViewTransactions,
  });

  final String type;
  final List<Account> accounts;
  final Map<int, double> balances;
  final NumberFormat fmt;
  final void Function(Account) onTap;
  final void Function(Account) onViewTransactions;

  @override
  Widget build(BuildContext context) {
    final label = AccountTypeStyle.label(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                for (int i = 0; i < accounts.length; i++) ...[
                  _AccountItem(
                    account: accounts[i],
                    balance: balances[accounts[i].id] ?? 0,
                    fmt: fmt,
                    icon: AccountTypeStyle.icon(type),
                    color: AccountTypeStyle.color(context, type),
                    onTap: () => onTap(accounts[i]),
                    onViewTransactions: () => onViewTransactions(accounts[i]),
                  ),
                  if (i < accounts.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 16,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  const _AccountItem({
    required this.account,
    required this.balance,
    required this.fmt,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onViewTransactions,
  });

  final Account account;
  final double balance;
  final NumberFormat fmt;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onViewTransactions;

  @override
  Widget build(BuildContext context) {
    final isLiability = account.isLiability;
    final daysUntil = account.daysUntilDue;
    final dueSoon = isLiability && daysUntil != null && daysUntil <= 3;

    return InkWell(
      onTap: onTap,
      onLongPress: onViewTransactions,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (account.last4 != null)
                        Text(
                          '•• ${account.last4}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      if (dueSoon) ...[
                        if (account.last4 != null)
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: Theme.of(context).extension<AppColorScheme>()!.error,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          daysUntil == 0 ? 'Due today' : 'Due in ${daysUntil}d',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).extension<AppColorScheme>()!.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isLiability ? fmt.format(balance.abs()) : fmt.format(balance),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isLiability
                        ? (balance < 0
                            ? Theme.of(context).extension<AppColorScheme>()!.error
                            : Theme.of(context).extension<AppColorScheme>()!.success)
                        : (balance < 0
                            ? Theme.of(context).extension<AppColorScheme>()!.error
                            : Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onViewTransactions,
                  child: Text(
                    'view txns',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).extension<AppColorScheme>()!.primaryVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
