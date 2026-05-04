import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class SmsIntelligenceSectionLabel extends StatelessWidget {
  const SmsIntelligenceSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
          letterSpacing: 0.5),
    );
  }
}

class SmsIntelligenceStatTile extends StatelessWidget {
  const SmsIntelligenceStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: color.shade600),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 10, color: color.shade400),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color.shade700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class SmsIntelligenceActionTile extends StatelessWidget {
  const SmsIntelligenceActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final MaterialColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate900)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }
}

class SmsTopMerchantRow extends StatelessWidget {
  const SmsTopMerchantRow({
    required this.rank,
    required this.merchant,
    required this.fmt,
    required this.isLast,
    super.key,
  });

  final int rank;
  final Map<String, dynamic> merchant;
  final NumberFormat fmt;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final name = merchant['merchant'] as String;
    final count = merchant['transaction_count'] as int;
    final total =
        (merchant['total_spent'] ?? merchant['total_amount'] ?? 0.0) as double;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$count txn${count != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate500)),
              ],
            ),
          ),
          Text(fmt.format(total),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900)),
        ],
      ),
    );
  }
}
