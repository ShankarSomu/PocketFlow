import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../db/database.dart';
import '../../../../services/app_logger.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/refresh_notifier.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_service.dart';
import 'appearance_section.dart';
import 'settings_card.dart';
import 'settings_widgets.dart';

class PreferencesTab extends StatefulWidget {
  const PreferencesTab({super.key, this.autoStartSmsScan = false});

  final bool autoStartSmsScan;

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
  int _smsProgress = 0;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  DateTime? _lastSalaryDate;
  int? _detectedSalaryDay;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
    _initializeSmsPrefs();
    _detectSalaryDate();
  }

  Future<void> _initializeSmsPrefs() async {
    AppLogger.log(LogLevel.info, LogCategory.system, 'Initializing SMS preferences',
      detail: 'autoStartSmsScan=${widget.autoStartSmsScan}');
    
    await _loadSmsPrefs();
    
    AppLogger.log(LogLevel.info, LogCategory.system, 'SMS preferences loaded',
      detail: 'enabled=$_smsEnabled, range=${_smsScanRange.label}');
    
    // Auto-start SMS scan if requested (e.g., from profile screen)
    // Only start if SMS is enabled and prefs are loaded
    if (widget.autoStartSmsScan && _smsEnabled && mounted) {
      AppLogger.log(LogLevel.info, LogCategory.system, 'Auto-starting SMS scan',
        detail: 'Waiting 300ms for UI to be ready...');
      
      // Small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _runSmsScan();
      }
    } else if (widget.autoStartSmsScan && !_smsEnabled) {
      AppLogger.log(LogLevel.warning, LogCategory.system, 'Auto-scan blocked',
        detail: 'SMS not enabled (_smsEnabled=$_smsEnabled)');
    }
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
    final customStart = await SmsService.getCustomStartDate();
    final customEnd = await SmsService.getCustomEndDate();
    if (!mounted) return;
    setState(() {
      _smsEnabled = enabled;
      _smsScanRange = range;
      _smsLastScan = lastScan;
      _customStartDate = customStart;
      _customEndDate = customEnd;
      _prefsLoaded = true;
    });
  }

  Future<void> _toggleSms(bool value) async {
    if (value) {
      // Enabling SMS Auto-Import
      AppLogger.log(LogLevel.info, LogCategory.system, 'Enabling SMS Auto-Import',
        detail: 'Requesting permission...');
      
      final granted = await SmsService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        AppLogger.log(LogLevel.warning, LogCategory.system, 'SMS permission denied',
          detail: 'User denied SMS permission');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission is required')),
        );
        return;
      }
      
      AppLogger.log(LogLevel.info, LogCategory.system, 'SMS permission granted',
        detail: 'Setting scan range to ${_smsScanRange.label}');
      
      // Ensure scan range is saved before first scan (default to current selection)
      await SmsService.setScanRange(_smsScanRange);
    } else {
      // Disabling SMS Auto-Import
      AppLogger.log(LogLevel.info, LogCategory.system, 'Disabling SMS Auto-Import',
        detail: 'User manually disabled');
    }
    
    await SmsService.setEnabled(value);
    if (!mounted) return;
    setState(() => _smsEnabled = value);
    
    if (value) {
      AppLogger.log(LogLevel.info, LogCategory.system, 'Starting initial SMS scan',
        detail: 'Auto-triggered after enabling');
      _runSmsScan();
    }
  }

  Future<void> _runSmsScan({bool forceRescan = false}) async {
    if (_smsScanning) return;
    
    // Check if preferences are loaded
    if (!_prefsLoaded) {
      AppLogger.log(LogLevel.warning, LogCategory.system, 'SMS scan blocked',
        detail: 'Preferences not loaded yet');
      return;
    }
    
    // Check if SMS Auto-Import is enabled
    if (!_smsEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable SMS Auto-Import first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
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
      _smsProgress = 0;
    });
    
    AppLogger.log(LogLevel.info, LogCategory.system, 'Starting SMS scan',
      detail: 'force=$forceRescan, range=${_smsScanRange.label}');
    
    try {
      // Add timeout to prevent indefinite hangs
      final result = await SmsService.scanAndImport(
        force: forceRescan, // Only force when explicitly requested
        onProgress: (current) {
          if (mounted) {
            setState(() {
              _smsProgress = current;
            });
          }
        },
      ).timeout(
        const Duration(minutes: 5), // 5 minute timeout
        onTimeout: () {
          AppLogger.log(LogLevel.error, LogCategory.system, 'SMS scan timed out',
            detail: 'Scan exceeded 5 minute timeout at progress $_smsProgress');
          return const SmsImportResult(
            error: 'SMS scan timed out after 5 minutes. Try reducing the scan range or contact support.',
          );
        },
      );
      
      AppLogger.log(LogLevel.info, LogCategory.system, 'SMS scan completed',
        detail: result.toString());
      
      // Create accounts from transaction data
      AppLogger.log(LogLevel.info, LogCategory.system, 'Creating accounts from transactions...');
      // await SmsService.createAccountsFromTransactions();
      
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _smsScanning = false;
        _smsLastScan = DateTime.now();
        _smsResult = result.hasError ? result.error : result.toString();
        _smsProgress = 0;
      });
    } catch (e) {
      AppLogger.log(LogLevel.error, LogCategory.system, 'SMS scan failed',
        detail: e.toString());
      
      if (!mounted) return;
      setState(() {
        _smsScanning = false;
        _smsResult = 'Scan failed: $e';
        _smsProgress = 0;
      });
    }
  }

  Future<void> _showForceRescanDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Full Rescan?'),
        content: const Text(
          'This will reimport ALL messages in your selected date range, including ones already processed.\n\n'
          'Use this if:\n'
          '• You\'ve run "Fix Duplicate Transfers"\n'
          '• Messages were imported incorrectly\n'
          '• You want to rebuild your transaction history\n\n'
          'Note: This may create duplicates if you haven\'t run the duplicate fix first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Force Rescan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runSmsScan(forceRescan: true);
    }
  }

  Future<void> _fixDuplicateTransfers() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Duplicate Transfers?'),
        content: const Text(
          'This will scan your transactions for duplicate credit card payments and convert them to transfers.\n\n'
          'Example: If you have two expenses for the same amount on the same day (one from checking, one as credit card payment), '
          'they will be converted to transfers.\n\n'
          'This operation cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fix Duplicates'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading state
    setState(() => _smsScanning = true);

    // TODO: Re-enable when implementation is ready
    // try {
    //   final fixedCount = await SmsService.cleanupDuplicateTransfers();
    //
    //   if (!mounted) return;
    //   setState(() => _smsScanning = false);
    //
    //   notifyDataChanged();
    //
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //         fixedCount > 0
    //             ? 'Fixed $fixedCount duplicate transactions'
    //             : 'No duplicate transfers found',
    //       ),
    //       backgroundColor: fixedCount > 0 ? Colors.green : null,
    //     ),
    //   );
    // } catch (e) {
    //   if (!mounted) return;
    //   setState(() => _smsScanning = false);
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Failed to fix duplicates')),
    //   );
    // }

    // Temporary fallback so UI doesn't get stuck
    if (mounted) {
      setState(() => _smsScanning = false);
    }
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    // Default to current month if no custom dates set
    final defaultStart = _customStartDate ?? DateTime(now.year, now.month, 1);
    final defaultEnd = _customEndDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    DateTime? startDate = defaultStart;
    DateTime? endDate = defaultEnd;

    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Date Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(startDate ?? now)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? now,
                        firstDate: DateTime(2000),
                        lastDate: endDate ?? now,
                      );
                      if (picked != null) {
                        setDialogState(() => startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('End Date'),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(endDate ?? now)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? now,
                        firstDate: startDate ?? DateTime(2000),
                        lastDate: now,
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'start': startDate,
                    'end': endDate,
                  }),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result['start'] != null && result['end'] != null) {
      final start = result['start']!;
      final end = result['end']!;
      
      await SmsService.setCustomDateRange(start, end);
      
      if (!mounted) return;
      setState(() {
        _customStartDate = start;
        _customEndDate = end;
      });

      // Prompt to rescan with new date range
      if (!mounted) return;
      final rescan = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Date Range Updated'),
          content: Text(
            'Custom date range set to ${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}.\n\nWould you like to rescan now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rescan Now'),
            ),
          ],
        ),
      );

      if (rescan == true) {
        _runSmsScan();
      }
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
  
  bool _shouldClearProcessedIds(SmsScanRange oldRange, SmsScanRange newRange) {
    // Check if new range includes more messages than old range
    final oldDays = _rangeToDays(oldRange);
    final newDays = _rangeToDays(newRange);
    return newDays > oldDays;
  }
  
  int _rangeToDays(SmsScanRange range) {
    switch (range) {
      case SmsScanRange.oneWeek:
        return 7;
      case SmsScanRange.oneMonth:
        return 30;
      case SmsScanRange.threeMonths:
        return 91;
      case SmsScanRange.sixMonths:
        return 183;
      case SmsScanRange.allTime:
        return 99999;
      case SmsScanRange.customRange:
        // Calculate days from custom date range
        if (_customStartDate != null && _customEndDate != null) {
          return _customEndDate!.difference(_customStartDate!).inDays;
        }
        return 30; // Default to 1 month equivalent if dates not set
    }
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

  void _showManualSalaryPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        int selectedDay = _detectedSalaryDay ?? 1;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Salary Day'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select the day of the month when you typically receive your salary:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 31,
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        final isSelected = selectedDay == day;
                        
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                          title: Text(
                            '$day${_getDaySuffix(day)} of each month',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected 
                                  ? Theme.of(context).colorScheme.primary 
                                  : null,
                            ),
                          ),
                          trailing: isSelected 
                              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () {
                            setDialogState(() => selectedDay = day);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _detectedSalaryDay = selectedDay;
                      _lastSalaryDate = DateTime.now();
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Salary day set to $selectedDay${_getDaySuffix(selectedDay)} of each month'),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(v 
                        ? 'Transaction alerts enabled. You\'ll be notified when transactions are added.'
                        : 'Transaction alerts disabled.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(v 
                        ? 'Budget warnings enabled. You\'ll be alerted when approaching budget limits.'
                        : 'Budget warnings disabled.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ToggleRow(
              icon: Icons.calendar_today_rounded,
              title: 'Weekly Summary',
              subtitle: 'Get a weekly spending digest',
              value: _notifyWeekly,
              onChanged: (v) async {
                // Show immediate feedback
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(v 
                          ? 'Enabling weekly summary...'
                          : 'Disabling weekly summary...'),
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                }
                
                setState(() => _notifyWeekly = v);
                _setNotifPref('notif_weekly', v);
                
                // Reschedule or cancel weekly summary
                await NotificationService.scheduleWeeklySummary();
                
                // Show final confirmation
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(v 
                          ? '✓ Weekly summary enabled. You\'ll receive a spending digest every week.'
                          : '✓ Weekly summary disabled.'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: theme.colorScheme.tertiary,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SettingsCard(
          title: 'Appearance',
          icon: Icons.palette_rounded,
          children: [
            AppearanceSection(),
          ],
        ),
        // Performance section disabled as it's for development only
        // const SizedBox(height: 12),
        // SettingsCard(
        //   title: 'Performance',
        //   icon: Icons.speed_rounded,
        //   children: const [
        //     PerformanceSettings(),
        //   ],
        // ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Financial Period',
          icon: Icons.calendar_month_rounded,
          children: [
            if (_detectedSalaryDay != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
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
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          '$_detectedSalaryDay${_getDaySuffix(_detectedSalaryDay!)}',
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SettingsActionButton(
                      label: 'Refresh Detection',
                      icon: Icons.refresh_rounded,
                      onTap: _detectSalaryDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SettingsActionButton(
                      label: 'Set Manually',
                      icon: Icons.edit_calendar_rounded,
                      onTap: _showManualSalaryPicker,
                    ),
                  ),
                ],
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Once you have income transactions marked as "Salary", we\'ll automatically detect your typical salary date. Or you can set it manually.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SettingsActionButton(
                label: 'Set Salary Day Manually',
                icon: Icons.edit_calendar_rounded,
                onTap: _showManualSalaryPicker,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'SMS Auto-Import',
          icon: Icons.sms_outlined,
          children: [
            // Show loading indicator if prefs not loaded yet
            if (!_prefsLoaded)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
              onChanged: _smsScanning ? null : _toggleSms, // Disable during scan
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.date_range_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
                    onChanged: _smsScanning ? null : (v) async { // Disable during scan
                      if (v == null) return;
                      final oldRange = _smsScanRange;
                      await SmsService.setScanRange(v);
                      setState(() => _smsScanRange = v);
                      
                      // If custom range selected, show date picker
                      if (v == SmsScanRange.customRange) {
                        await _showDateRangePicker();
                        return;
                      }
                      
                      // If expanding range (e.g., 6 months → all), clear processed IDs to avoid duplicates
                      if (_shouldClearProcessedIds(oldRange, v)) {
                        // Prompt user to rescan with the new range
                        if (!mounted) return;
                        final rescan = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Scan Range Changed'),
                            content: const Text(
                              'You\'ve expanded the scan range. Would you like to rescan to import older messages?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Later'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Rescan Now'),
                              ),
                            ],
                          ),
                        );
                        
                        if (rescan == true) {
                          _runSmsScan();
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            // Info note about scan behavior
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All messages are checked to filter by date. Only messages in the selected range are imported.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Show custom date range if selected
            if (_smsScanRange == SmsScanRange.customRange && _customStartDate != null && _customEndDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  onTap: _showDateRangePicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month,
                            size: 16,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('MMM d, yyyy').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.edit_calendar,
                            size: 16,
                            color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_smsLastScan != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Last scan: ${_formatLastScan(_smsLastScan!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            if (_smsEnabled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SettingsActionButton(
                      label: _smsScanning 
                          ? (_smsProgress > 0 
                              ? 'Checked $_smsProgress messages' 
                              : 'Scanning...') 
                          : 'Scan New Messages',
                      icon: _smsScanning
                          ? Icons.hourglass_top_rounded
                          : Icons.play_arrow_rounded,
                      onTap: _smsScanning ? () {} : () => _runSmsScan(forceRescan: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Force full rescan\n(Reimport all messages)',
                    child: InkWell(
                      onTap: _smsScanning ? null : () => _showForceRescanDialog(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: _smsScanning 
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SettingsActionButton(
                label: 'Fix Duplicate Transfers',
                icon: Icons.auto_fix_high_rounded,
                onTap: _fixDuplicateTransfers,
              ),
            ],
            ], // Close the else block for _prefsLoaded
          ],
        ),
      ],
    );
  }
}

