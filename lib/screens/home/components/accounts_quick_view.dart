import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class AccountsQuickView extends StatelessWidget {

  const AccountsQuickView({required this.accounts, required this.fmt, super.key});
  final List<Map<String, dynamic>> accounts;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.blueGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.onPrimary, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Accounts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (accounts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No accounts',
                  style: TextStyle(color: AppTheme.slate400, fontSize: 12),
                ),
              ),
            )
          else
            ...accounts.map((a) {
              final type = a['type'] as String;
              final isLiability = (type == 'credit_card' || type == 'loan');
              final color = type == 'checking'
                  ? AppTheme.blue
                  : type == 'savings'
                      ? AppTheme.emerald
                      : isLiability
                          ? AppTheme.error
                          : Theme.of(context).colorScheme.secondary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a['name'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      fmt.format(a['balance']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isLiability ? AppTheme.error : AppTheme.slate900,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
