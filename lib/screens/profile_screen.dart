import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database.dart';
import '../services/auth_service.dart';
import '../services/refresh_notifier.dart';
import '../services/app_logger.dart';
import '../services/chat_parser.dart';
import '../services/sms_service.dart';
import '../services/seed_data.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'profile/components/profile_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _lastBackup;
  String? _message;
  bool _isError = false;
  DriveFolder? _folder;
  String _backupFreq = 'daily';
  LogLevel _logLevel = LogLevel.info;
  int? _defaultExpenseAccount;
  int? _defaultIncomeAccount;
  List<Account> _accounts = [];
  double _savingsRate = 0;
  double _budgetCompliance = 0;
  int _goalsOnTrack = 0;
  int _totalGoals = 0;

  // SMS settings
  bool _smsEnabled = false;
  SmsScanRange _smsScanRange = SmsScanRange.oneMonth;
  DateTime? _smsLastScan;
  bool _smsScanning = false;
  String? _smsResult;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAccounts();
    _loadAccountHealth();
    _loadSmsPrefs();
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
          const SnackBar(content: Text('SMS permission is required to enable this feature')),
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
    final granted = await SmsService.hasPermission();
    if (!granted) {
      final ok = await SmsService.requestPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission denied')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() { _smsScanning = true; _smsResult = null; });
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

  Future<void> _loadAccountHealth() async {
    final now = DateTime.now();
    final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
    final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
    final savingsRate = income > 0 ? ((income - expenses) / income * 100).clamp(0.0, 100.0) : 0.0;
    
    final budgets = await AppDatabase.getBudgets(now.month, now.year);
    final spent = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
    final budgetsWithLimit = budgets.where((b) => b.limit > 0).toList();
    int onTrackCount = 0;
    for (final b in budgetsWithLimit) {
      final s = spent[b.category] ?? 0;
      if (s <= b.limit) onTrackCount++;
    }
    final budgetCompliance = budgetsWithLimit.isNotEmpty
        ? (onTrackCount / budgetsWithLimit.length * 100)
        : 0.0;
    
    final goals = await AppDatabase.getGoals();
    final goalsOnTrack = goals.where((g) => g.progress >= 0.5).length;
    
    if (!mounted) return;
    setState(() {
      _savingsRate = savingsRate;
      _budgetCompliance = budgetCompliance;
      _goalsOnTrack = goalsOnTrack;
      _totalGoals = goals.length;
    });
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppDatabase.getAccounts();
    final expenseId = await ChatParser.getDefaultExpenseAccount();
    final incomeId = await ChatParser.getDefaultIncomeAccount();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _defaultExpenseAccount = expenseId;
      _defaultIncomeAccount = incomeId;
    });
  }

  Future<void> _loadPrefs() async {
    final t = await AuthService.lastBackupTime();
    final folder = await AuthService.getSelectedFolder();
    final freq = await AuthService.getBackupFrequency();
    final level = AppLogger.getLevel();
    if (!mounted) return;
    setState(() {
      _lastBackup = t;
      _folder = folder;
      _backupFreq = freq;
      _logLevel = level;
    });
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final user = await AuthService.signIn();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = user != null ? 'Signed in as ${user.email}' : 'Sign in failed';
      _isError = user == null;
    });
    if (user != null) _showFolderPicker();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    await AuthService.clearSelectedFolder();
    if (!mounted) return;
    setState(() {
      _message = 'Signed out';
      _folder = null;
    });
  }

  Future<void> _showFolderPicker() async {
    setState(() { _loading = true; _message = null; });
    
    try {
      // Use native file picker to select directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        // Extract folder name from path
        final folderName = selectedDirectory.split('/').last;
        final folder = DriveFolder(
          id: selectedDirectory, // Use path as ID for local folders
          name: folderName,
          path: selectedDirectory,
        );
        
        await AuthService.saveSelectedFolder(folder);
        if (!mounted) return;
        setState(() {
          _folder = folder;
          _message = 'Backup location set';
          _isError = false;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Failed to select folder: $e';
        _isError = true;
      });
    }
  }

  Future<void> _showProfileMenu() async {
    await ProfileDialogs.showProfileMenu(
      context,
      onSignIn: _signIn,
      onSignOut: _signOut,
      onDeleteAllData: _deleteAllData,
    );
  }

  Future<void> _deleteAllData() async {
    final confirm = await ProfileDialogs.showDeleteConfirmation(context);
    if (!confirm) return;

    setState(() { _loading = true; _message = null; });
    try {
      await AppDatabase.deleteAllData();
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'All data deleted successfully.';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Delete failed: $e';
        _isError = true;
      });
    }
  }

  Future<void> _loadSampleData() async {
    final confirm = await ProfileDialogs.showLoadSampleDataConfirmation(context);
    if (!confirm) return;

    setState(() { _loading = true; _message = null; });
    try {
      await SeedData.load();
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Sample data loaded successfully!';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Failed to load sample data: $e';
        _isError = true;
      });
    }
  }

  Future<void> _backup() async {
    if (_folder == null) {
      _showFolderPicker();
      return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      await AuthService.backup();
      await _loadPrefs();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Backup successful!';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Backup failed: $e';
        _isError = true;
      });
    }
  }

  Future<void> _restore() async {
    if (_folder == null) {
      setState(() { _message = 'Please select a backup folder first'; _isError = true; });
      return;
    }
    final confirm = await ProfileDialogs.showRestoreConfirmation(context);
    if (!confirm) return;

    setState(() { _loading = true; _message = null; });
    try {
      await AuthService.restore();
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Restore successful!';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Restore failed: $e';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = AuthService.isSignedIn;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.slate900, AppTheme.slate800, AppTheme.emeraldDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed Header
              ProfileHeader(onTap: _showProfileMenu),
              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  children: [
                    // Account Health Card
                    AccountHealthCard(
                      savingsRate: _savingsRate,
                      budgetCompliance: _budgetCompliance,
                      goalsOnTrack: _goalsOnTrack,
                      totalGoals: _totalGoals,
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        const Divider(height: 1),
                        BackupSection(
                          isSignedIn: isSignedIn,
                          folder: _folder,
                          lastBackup: _lastBackup,
                          backupFreq: _backupFreq,
                          loading: _loading,
                          onSignIn: _signIn,
                          onFolderPicker: _showFolderPicker,
                          onBackup: _backup,
                          onRestore: _restore,
                          onFrequencyChanged: (v) async {
                            await AuthService.setBackupFrequency(v);
                            setState(() => _backupFreq = v);
                          },
                        ),
                        const Divider(height: 1),
                        PreferencesSection(
                          logLevel: _logLevel,
                          defaultExpenseAccount: _defaultExpenseAccount,
                          defaultIncomeAccount: _defaultIncomeAccount,
                          accounts: _accounts,
                          onLogLevelChanged: (v) async {
                            await AppLogger.setLevel(v);
                            setState(() => _logLevel = v);
                          },
                          onExpenseAccountChanged: (v) async {
                            await ChatParser.setDefaultExpenseAccount(v);
                            setState(() => _defaultExpenseAccount = v);
                          },
                          onIncomeAccountChanged: (v) async {
                            await ChatParser.setDefaultIncomeAccount(v);
                            setState(() => _defaultIncomeAccount = v);
                          },
                        ),
                        const Divider(height: 1),
                        SmsMonitoringSection(
                          smsEnabled: _smsEnabled,
                          smsScanRange: _smsScanRange,
                          smsLastScan: _smsLastScan,
                          smsScanning: _smsScanning,
                          smsResult: _smsResult,
                          onToggleSms: _toggleSms,
                          onRangeChanged: (v) async {
                            await SmsService.setScanRange(v);
                            setState(() => _smsScanRange = v);
                          },
                          onRunScan: _runSmsScan,
                        ),
                        const Divider(height: 1),
                        DataManagementSection(
                          onLoadSampleData: _loadSampleData,
                        ),
                        const Divider(height: 1),
                      ]),
                    ),

                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(
                            _isError ? Icons.error_outline : Icons.check_circle_outline,
                            color: _isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_message!,
                                  style: TextStyle(
                                      color: _isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                                      fontSize: 13))),
                        ]),
                      ),
                    ],

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
