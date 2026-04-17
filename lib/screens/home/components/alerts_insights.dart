import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/account.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class AlertsInsights extends StatelessWidget {
  final List<Account> accounts;
  final NumberFormat fmt;
  const AlertsInsights({super.key, required this.accounts, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final activeCount = accounts.length;
    final creditCount = accounts.where((a) => a.type == 'credit').length;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Alerts & Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
              Icon(Icons.insights_outlined, color: AppTheme.slate700),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: InsightTile(label: 'Accounts', value: '$activeCount', color: AppTheme.blue)),
              const SizedBox(width: 12),
              Expanded(child: InsightTile(label: 'Credit cards', value: '$creditCount', color: AppTheme.emerald)),
            ],
          ),
        ],
      ),
    );
  }
}

class InsightTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const InsightTile({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slate600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
        ],
      ),
    );
  }
}
