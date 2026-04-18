import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../db/database.dart';
import '../../../../services/refresh_notifier.dart';
import '../../../../services/sms_service.dart';
import '../../../../widgets/performance_settings.dart';
import 'appearance_section.dart';
import 'settings_card.dart';
import 'settings_widgets.dart';

class PreferencesTab extends StatefulWidget {
  const PreferencesTab({super.key});

  @override
  State<PreferencesTab> createState() => PreferencesTabState();
}

class PreferencesTabState extends State<PreferencesTab> {
  bool _notifyTransactions = true;
  bool _notifyBudget = true;
  bool _notifyWeekly = false;

  bool _smsEnabled = false;
  SmsScanRange _smsScanRange = SmsScanRange.oneMonth;
  DateTime? _smsLastScan;
  bool _smsScanning = false;
  String? _smsResult;

  DateTime? _lastSalaryDate;
  int? _detectedSalaryDay;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
    _loadSmsPrefs();
    _detectSalaryDate();
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifyTransactions = prefs.getBool('notif_transactions') ?? true;
      _notifyBudget = prefs.getBool('notif_budget') ?? true;
      _notifyWeekly = prefs.getBool('notif_weekly') ?? false;
    });
  }

  Future<void> _setNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadSmsPrefs() async {
    final enabled = await SmsService.isEnabled();
    final range = await SmsService.getScanRange();
    final lastScan = await SmsService.getLastScan();
    if (!mounted) return;
    setState(() {
      _smsEnabled = enabled;
      _smsScanRange = range;
      _smsLastScan = lastScan;
    });
  }

  Future<void> _toggleSms(bool value) async {
    if (value) {
      final granted = await SmsService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission is required')),
        );
        return;
      }
    }
    await SmsService.setEnabled(value);
    if (!mounted) return;
    setState(() => _smsEnabled = value);
    if (value) _runSmsScan();
  }

  Future<void> _runSmsScan() async {
    if (_smsScanning) return;
    final ok = await SmsService.hasPermission();
    if (!ok) {
      final granted = await SmsService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission denied')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _smsScanning = true;
      _smsResult = null;
    });
    try {
      final result = await SmsService.scanAndImport();
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _smsScanning = false;
        _smsLastScan = DateTime.now();
        _smsResult = result.hasError ? result.error : result.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _smsScanning = false;
        _smsResult = 'Scan failed: $e';
      });
    }
  }

  String _formatLastScan(DateTime time) {
    return DateFormat('MMM d, h:mm a').format(time);
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

  Future<void> _detectSalaryDate() async {
    try {
      // Get all salary transactions from the last 3 months
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
      
      final transactions = await AppDatabase.getTransactions(
        from: threeMonthsAgo,
        to: now,
      );
      
      // Filter for income transactions, prioritize "Salary" category
      final salaryTxns = transactions.where((t) => 
        t.type == 'income' && 
        (t.category.toLowerCase().contains('salary') || 
         t.category.toLowerCase().contains('income'))
      ).toList();
      
      if (salaryTxns.isEmpty) {
        // If no salary transactions, just use all income
        final incomeTxns = transactions.where((t) => t.type == 'income').toList();
        if (incomeTxns.isNotEmpty) {
          incomeTxns.sort((a, b) => b.date.compareTo(a.date));
          final mostRecent = incomeTxns.first;
          if (!mounted) return;
          setState(() {
            _lastSalaryDate = mostRecent.date;
            _detectedSalaryDay = mostRecent.date.day;
          });
        }
        return;
      }
      
      // Sort by date (most recent first)
      salaryTxns.sort((a, b) => b.date.compareTo(a.date));
      final mostRecentSalary = salaryTxns.first;
      
      if (!mounted) return;
      setState(() {
        _lastSalaryDate = mostRecentSalary.date;
        _detectedSalaryDay = mostRecentSalary.date.day;
      });
    } catch (e) {
      // Silently fail, not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        SettingsCard(
          title: 'Notifications',
          icon: Icons.notifications_rounded,
          children: [
            ToggleRow(
              icon: Icons.receipt_long_rounded,
              title: 'Transaction Alerts',
              subtitle: 'Notify when transactions are logged',
              value: _notifyTransactions,
              onChanged: (v) {
                setState(() => _notifyTransactions = v);
                _setNotifPref('notif_transactions', v);
              },
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ToggleRow(
              icon: Icons.pie_chart_rounded,
              title: 'Budget Warnings',
              subtitle: 'Alert when nearing budget limits',
              value: _notifyBudget,
              onChanged: (v) {
                setState(() => _notifyBudget = v);
                _setNotifPref('notif_budget', v);
              },
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ToggleRow(
              icon: Icons.calendar_today_rounded,
              title: 'Weekly Summary',
              subtitle: 'Get a weekly spending digest',
              value: _notifyWeekly,
              onChanged: (v) {
                setState(() => _notifyWeekly = v);
                _setNotifPref('notif_weekly', v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Appearance',
          icon: Icons.palette_rounded,
          children: const [
            AppearanceSection(),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Performance',
          icon: Icons.speed_rounded,
          children: const [
            PerformanceSettings(),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Financial Period',
          icon: Icons.calendar_month_rounded,
          children: [
            if (_detectedSalaryDay != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_fix_high_rounded,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-Detected Salary Date',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Your salary is typically credited on or around the ',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          '${_detectedSalaryDay}${_getDaySuffix(_detectedSalaryDay!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (_lastSalaryDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last detected: ${DateFormat('MMM d, yyyy').format(_lastSalaryDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SettingsActionButton(
                label: 'Refresh Salary Detection',
                icon: Icons.refresh_rounded,
                onTap: _detectSalaryDate,
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No salary transactions detected yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Once you have income transactions marked as "Salary", we\'ll automatically detect your typical salary date.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'SMS Auto-Import',
          icon: Icons.sms_outlined,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reads only bank/wallet SMS locally on your device. Never uploaded.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ToggleRow(
              icon: Icons.sms_outlined,
              title: 'Enable SMS Import',
              subtitle: _smsEnabled
                  ? 'Active - reads financial SMS'
                  : 'Disabled',
              value: _smsEnabled,
              onChanged: _toggleSms,
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.date_range_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Scan range',
                        style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface)),
                  ),
                  DropdownButton<SmsScanRange>(
                    value: _smsScanRange,
                    isDense: true,
                    underline: const SizedBox(),
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface),
                    items: SmsScanRange.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      await SmsService.setScanRange(v);
                      setState(() => _smsScanRange = v);
                    },
                  ),
                ],
              ),
            ),
            if (_smsLastScan != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Last scan: ${_formatLastScan(_smsLastScan!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            if (_smsResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _smsResult!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            if (_smsEnabled) ...[
              const SizedBox(height: 10),
              SettingsActionButton(
                label: _smsScanning ? 'Scanning...' : 'Scan Now',
                icon: _smsScanning
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
                onTap: _smsScanning ? () {} : _runSmsScan,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
