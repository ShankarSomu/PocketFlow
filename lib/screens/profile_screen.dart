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
      if (!granted) return;
    }
    await SmsService.setEnabled(value);
    if (!mounted) return;
    setState(() => _smsEnabled = value);
    if (value) _runSmsScan();
  }

  Future<void> _runSmsScan() async {
    if (_smsScanning) return;
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
        _smsResult = result.toString();
      });
    } catch (e) {
      setState(() {
        _smsScanning = false;
        _smsResult = 'Scan failed';
      });
    }
  }

  Future<void> _loadAccountHealth() async {
    final now = DateTime.now();
    final income =
        await AppDatabase.monthlyTotal('income', now.month, now.year);
    final expenses =
        await AppDatabase.monthlyTotal('expense', now.month, now.year);

    final savingsRate = income > 0
        ? ((income - expenses) / income * 100).clamp(0.0, 100.0)
        : 0.0;

    if (!mounted) return;
    setState(() => _savingsRate = savingsRate);
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppDatabase.getAccounts();
    if (!mounted) return;
    setState(() => _accounts = accounts);
  }

  Future<void> _loadPrefs() async {
    final t = await AuthService.lastBackupTime();
    final folder = await AuthService.getSelectedFolder();

    if (!mounted) return;
    setState(() {
      _lastBackup = t;
      _folder = folder;
    });
  }

  Future<void> _backup() async {
    if (_folder == null) {
      _showFolderPicker();
      return;
    }
    setState(() => _loading = true);
    await AuthService.backup();
    await _loadPrefs();
    setState(() => _loading = false);
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    await AuthService.restore();
    notifyDataChanged();
    setState(() => _loading = false);
  }

  Future<void> _showFolderPicker() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    final folder = DriveFolder(id: path, name: path.split('/').last, path: path);
    await AuthService.saveSelectedFolder(folder);

    setState(() => _folder = folder);
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = AuthService.isSignedIn;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.slate900,
                AppTheme.slate700,
                AppTheme.emeraldDark,
              ],
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _dragHandle(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _header(),
                      const SizedBox(height: 20),

                      // 🔥 HERO
                      AccountHealthCard(
                        savingsRate: _savingsRate,
                        budgetCompliance: _budgetCompliance,
                        goalsOnTrack: _goalsOnTrack,
                        totalGoals: _totalGoals,
                      ),

                      const SizedBox(height: 20),

                      _quickActions(),

                      const SizedBox(height: 20),

                      GlassCard(
                        child: BackupSection(
                          isSignedIn: isSignedIn,
                          folder: _folder,
                          lastBackup: _lastBackup,
                          backupFreq: _backupFreq,
                          loading: _loading,
                          onSignIn: () {},
                          onFolderPicker: _showFolderPicker,
                          onBackup: _backup,
                          onRestore: _restore,
                          onFrequencyChanged: (_) {},
                        ),
                      ),

                      const SizedBox(height: 16),

                      GlassCard(
                        child: PreferencesSection(
                          logLevel: _logLevel,
                          defaultExpenseAccount: _defaultExpenseAccount,
                          defaultIncomeAccount: _defaultIncomeAccount,
                          accounts: _accounts,
                          onLogLevelChanged: (_) {},
                          onExpenseAccountChanged: (_) {},
                          onIncomeAccountChanged: (_) {},
                        ),
                      ),

                      const SizedBox(height: 16),

                      GlassCard(
                        child: SmsMonitoringSection(
                          smsEnabled: _smsEnabled,
                          smsScanRange: _smsScanRange,
                          smsLastScan: _smsLastScan,
                          smsScanning: _smsScanning,
                          smsResult: _smsResult,
                          onToggleSms: _toggleSms,
                          onRangeChanged: (_) {},
                          onRunScan: _runSmsScan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dragHandle() => Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
      );

  Widget _header() => Column(
        children: const [
          CircleAvatar(radius: 32, child: Icon(Icons.person)),
          SizedBox(height: 10),
          Text("Your Profile", style: TextStyle(fontSize: 18)),
        ],
      );

  Widget _quickActions() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _btn(Icons.backup, _backup),
          _btn(Icons.restore, _restore),
          _btn(Icons.folder, _showFolderPicker),
        ],
      );

  Widget _btn(IconData i, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(i),
        ),
      );
}