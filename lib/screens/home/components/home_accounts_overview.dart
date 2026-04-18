import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/account.dart';
import '../../../../theme/category_colors.dart';
import '../../../widgets/figma/figma_panel.dart';
import '../../shared/shared.dart';

/// Accounts overview widget showing all accounts with balances
class HomeAccountsOverview extends StatelessWidget {
  final List<Account> accounts;
  final Map<int, double> accountBalances;

  const HomeAccountsOverview({
    super.key,
    required this.accounts,
    required this.accountBalances,
  });

  static IconData _accountTypeIcon(String type) => switch (type) {
        'checking' => Icons.account_balance_rounded,
        'savings' => Icons.savings_rounded,
        'credit' => Icons.credit_card_rounded,
        'cash' => Icons.payments_rounded,
        _ => Icons.account_balance_wallet_rounded,
      };

  static Color _accountTypeColor(BuildContext context, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (type) {
      'checking' => isDark ? const Color(0xFF5FAEE3) : const Color(0xFF3498DB),
      'savings' => const Color(0xFF26DE81),
      'credit' => isDark ? const Color(0xFFFF8787) : const Color(0xFFFF6B6B),
      'cash' => const Color(0xFFF39C12),
      _ => Theme.of(context).colorScheme.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');

    return FigmaPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accounts',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Expanded(
            child: accounts.isEmpty
                ? Center(
                    child: Text('No accounts yet',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))))
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.08)),
                    itemBuilder: (_, i) {
                      final account = accounts[i];
                      final bal = accountBalances[account.id] ?? 0.0;
                      final color = _accountTypeColor(context, account.type);
                      final icon = _accountTypeIcon(account.type);
                      final typeLabel = account.type[0].toUpperCase() +
                          account.type.substring(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                      overflow: TextOverflow.ellipsis),
                                  Text(typeLabel,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6))),
                                ],
                              ),
                            ),
                            Text(fmt.format(bal),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
