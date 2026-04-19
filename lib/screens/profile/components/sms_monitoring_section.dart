import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/sms_service.dart';
import '../../../theme/app_theme.dart';

class SmsMonitoringSection extends StatelessWidget {

  const SmsMonitoringSection({
    required this.smsEnabled, required this.smsScanRange, required this.smsLastScan, required this.smsScanning, required this.smsResult, required this.onToggleSms, required this.onRangeChanged, required this.onRunScan, super.key,
  });
  final bool smsEnabled;
  final SmsScanRange smsScanRange;
  final DateTime? smsLastScan;
  final bool smsScanning;
  final String? smsResult;
  final Function(bool) onToggleSms;
  final Function(SmsScanRange) onRangeChanged;
  final VoidCallback onRunScan;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.sms_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 18),
      ),
      title: const Text('SMS Auto-Import'),
      subtitle: Text(
        smsEnabled ? 'Active — reads financial SMS' : 'Disabled',
        style: TextStyle(
          fontSize: 12,
          color: smsEnabled ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Consent banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25).withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PocketFlow reads only financial SMS (bank/wallet alerts) to record transactions automatically. Messages are processed locally on your device and never uploaded.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Enable toggle
              Row(
                children: [
                  Icon(Icons.toggle_on_outlined, size: 20, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Enable SMS Import',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Switch.adaptive(
                    value: smsEnabled,
                    activeColor: AppTheme.emerald,
                    onChanged: onToggleSms,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Scan range
              Row(
                children: [
                  Icon(Icons.date_range_outlined, size: 20, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Scan range', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownButton<SmsScanRange>(
                    value: smsScanRange,
                    isDense: true,
                    underline: const SizedBox(),
                    dropdownColor: AppTheme.slate700,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
                    items: SmsScanRange.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onRangeChanged(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Last scan info
              if (smsLastScan != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38)),
                      const SizedBox(width: 6),
                      Text(
                        'Last scan: ${DateFormat('MMM d, h:mm a').format(smsLastScan!)}',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38)),
                      ),
                    ],
                  ),
                ),

              // Result chip
              if (smsResult != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    smsResult!,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                  ),
                ),

              // Rescan button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: smsScanning ? null : onRunScan,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  icon: smsScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.slate200),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(smsScanning ? 'Scanning…' : 'Rescan SMS'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

