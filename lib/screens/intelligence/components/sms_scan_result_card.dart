import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../sms_engine/ingestion/sms_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class SmsScanResultCard extends StatelessWidget {
  const SmsScanResultCard({
    required this.result,
    required this.scanDate,
    required this.onReviewTap,
    required this.onImportedTap,
    required this.onNonFinancialTap,
    required this.onAlreadyProcessedTap,
    required this.onBlockedByRuleTap,
    required this.onOutOfRangeTap,
    required this.onParseFailedTap,
    super.key,
  });

  final SmsImportResult? result;
  final DateTime? scanDate;
  final VoidCallback onReviewTap;
  final VoidCallback onImportedTap;
  final VoidCallback onNonFinancialTap;
  final VoidCallback onAlreadyProcessedTap;
  final VoidCallback onBlockedByRuleTap;
  final VoidCallback onOutOfRangeTap;
  final VoidCallback onParseFailedTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (result == null) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            const Text('No scan results yet. Run a scan from Settings.',
                style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    final r = result!;
    final total = r.imported + r.skipped + r.failed + r.filteredByDate;
    final dateStr = scanDate != null
        ? DateFormat('MMM d, h:mm a').format(scanDate!)
        : 'Unknown';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Last Scan',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900)),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.slate500)),
            ],
          ),
          const SizedBox(height: 12),

          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (r.imported > 0)
                      Flexible(
                        flex: r.imported,
                        child: Container(color: Colors.green.shade400),
                      ),
                    if (r.nonFinancial > 0)
                      Flexible(
                        flex: r.nonFinancial,
                        child: Container(color: Colors.grey.shade300),
                      ),
                    if (r.alreadyProcessed > 0)
                      Flexible(
                        flex: r.alreadyProcessed,
                        child: Container(color: Colors.blue.shade100),
                      ),
                    if (r.blockedByRule > 0)
                      Flexible(
                        flex: r.blockedByRule,
                        child: Container(color: Colors.orange.shade300),
                      ),
                    if (r.parseFailed > 0)
                      Flexible(
                        flex: r.parseFailed,
                        child: Container(color: Colors.red.shade300),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SmsScanChip(
                  label: 'Imported',
                  count: r.imported,
                  color: Colors.green,
                  onTap: onImportedTap),
              SmsScanChip(
                  label: 'Non-financial',
                  count: r.nonFinancial,
                  color: Colors.grey,
                  onTap: onNonFinancialTap),
              SmsScanChip(
                  label: 'Already processed',
                  count: r.alreadyProcessed,
                  color: Colors.blue,
                  onTap: onAlreadyProcessedTap),
              SmsScanChip(
                  label: 'Blocked by rules',
                  count: r.blockedByRule,
                  color: Colors.orange,
                  onTap: onBlockedByRuleTap),
              SmsScanChip(
                  label: 'Out of range',
                  count: r.filteredByDate,
                  color: Colors.purple,
                  onTap: onOutOfRangeTap),
              SmsScanChip(
                  label: 'Parse failed',
                  count: r.parseFailed,
                  color: Colors.red,
                  onTap: onParseFailedTap),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReviewTap,
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('Open Review Queue'),
            ),
          ),
        ],
      ),
    );
  }
}

class SmsScanChip extends StatelessWidget {
  const SmsScanChip({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final MaterialColor color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color.shade700),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.shade600),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: color.shade600),
            ],
          ],
        ),
      ),
    );
  }
}
