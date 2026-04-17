import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/chat_parser.dart';
import '../../services/groq_service.dart';
import '../../services/refresh_notifier.dart';
import '../../services/sms_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';

// -- Settings Screen -----------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // -- Header --
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.8), size: 18),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // -- Tab Bar --
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    gradient: ThemeService.instance.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_sync_rounded, size: 15),
                          SizedBox(width: 6),
                          Text('Backup'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 15),
                          SizedBox(width: 6),
                          Text('AI'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune_rounded, size: 15),
                          SizedBox(width: 6),
                          Text('Preferences'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  _BackupTab(),
                  _AITab(),
                  _PreferencesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Backup Tab ----------------------------------------------------------------

class _BackupTab extends StatefulWidget {
  const _BackupTab();

  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  bool _backingUp = false;
  bool _settingUpFolder = false;
  String? _lastBackup;
  DriveFolder? _folder;
  String _backupFreq = 'daily';
  bool _wifiOnly = true;
  bool _includeAttachments = true;
  bool _encrypted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lastBackup = await AuthService.lastBackupTime();
    final folder = await AuthService.getSelectedFolder();
    final freq = await AuthService.getBackupFrequency();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastBackup = lastBackup;
      _folder = folder;
      _backupFreq = freq;
      _wifiOnly = prefs.getBool('backup_wifi_only') ?? true;
      _includeAttachments =
          prefs.getBool('backup_include_attachments') ?? true;
      _encrypted = prefs.getBool('backup_encrypted') ?? false;
    });
  }

  Future<void> _autoSelectFolder() async {
    setState(() => _settingUpFolder = true);
    try {
      if (!AuthService.isSignedIn) {
        final user = await AuthService.signIn();
        if (user == null) {
          if (!mounted) return;
          setState(() => _settingUpFolder = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in failed')));
          return;
        }
      }
      // Find or create the dedicated app folder automatically
      const folderName = 'PocketFlow Backups';
      final folders = await AuthService.listFolders();
      final existing = folders.where((f) => f.name == folderName).firstOrNull;
      final DriveFolder folder;
      if (existing != null) {
        folder = existing;
      } else {
        folder = await AuthService.createFolder(folderName);
      }
      await AuthService.saveSelectedFolder(folder);
      if (!mounted) return;
      setState(() => _folder = folder);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive folder ready ?'),
              backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      AppLogger.err('settings_auto_folder', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect to Drive')));
      }
    } finally {
      if (mounted) setState(() => _settingUpFolder = false);
    }
  }

  Future<void> _backup() async {
    if (!AuthService.isSignedIn) {
      await _autoSelectFolder();
      if (!AuthService.isSignedIn) return;
    }
    if (_folder == null) {
      await _autoSelectFolder();
      if (_folder == null) return;
    }
    setState(() => _backingUp = true);
    try {
      await AuthService.backup();
      await _load();
      if (!mounted) return;
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup successful ?'),
          backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _backingUp = false);
      AppLogger.err('settings_backup', e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup failed. Please try again.'),
          backgroundColor: Color(0xFFEF4444)));
    }
  }

  Future<void> _restore() async {
    if (_folder == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a backup folder first')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore Backup?'),
        content: Text(
            'This will replace your current data with the backup. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _backingUp = true);
    try {
      await AuthService.restore();
      if (!mounted) return;
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore successful')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _backingUp = false);
      AppLogger.err('settings_restore', e);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed')));
    }
  }

  void _showFrequencyPicker() {
    const options = {
      'manual': 'Off',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('Auto Backup Frequency',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ...options.entries.map((e) {
            final sel = _backupFreq == e.key;
            return InkWell(
              onTap: () async {
                await AuthService.setBackupFrequency(e.key);
                setState(() => _backupFreq = e.key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                color: sel
                    ? const Color(0xFF10B981).withValues(alpha: 0.07)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: sel
                                  ? const Color(0xFF10B981)
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
                    ),
                    if (sel)
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = AuthService.isSignedIn;
    final user = AuthService.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // Status card
        _BackupStatusCard(
          folder: _folder,
          lastBackup: _lastBackup,
          isSignedIn: isSignedIn,
          userEmail: user?.email,
        ),
        const SizedBox(height: 12),
        // Back Up Now
        _BackupNowButton(backing: _backingUp, onTap: _backup),
        const SizedBox(height: 12),
        // Backup Settings
        _SettingsCard(
          title: 'Backup Settings',
          icon: Icons.settings_rounded,
          children: [
            _BackupSettingRow(
              icon: Icons.cloud_rounded,
              title: 'Cloud Storage',
              subtitle: _settingUpFolder
                  ? 'Connecting...'
                  : _folder == null
                      ? (AuthService.isSignedIn ? 'Tap to set up Drive folder' : 'Tap to connect Google Drive')
                      : _folder!.name,
              subtitleColor: _settingUpFolder
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                  : _folder != null ? const Color(0xFF10B981) : null,
              onTap: _settingUpFolder ? () {} : _autoSelectFolder,
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _BackupSettingRow(
              icon: Icons.schedule_rounded,
              title: 'Auto Backup',
              subtitle: const {
                    'manual': 'Off',
                    'daily': 'Daily',
                    'weekly': 'Weekly',
                    'monthly': 'Monthly',
                  }[_backupFreq] ??
                  'Daily',
              onTap: _showFrequencyPicker,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Advanced Options
        _SettingsCard(
          title: 'Advanced Options',
          icon: Icons.tune_rounded,
          children: [
            _ToggleRow(
              icon: Icons.wifi_rounded,
              title: 'Backup over Wi-Fi only',
              subtitle:
                  _wifiOnly ? 'Wi-Fi only' : 'Wi-Fi + Mobile Data',
              value: _wifiOnly,
              onChanged: (v) async {
                setState(() => _wifiOnly = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('backup_wifi_only', v);
              },
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _ToggleRow(
              icon: Icons.attach_file_rounded,
              title: 'Include attachments',
              subtitle: 'Transaction receipts, invoices',
              value: _includeAttachments,
              onChanged: (v) async {
                setState(() => _includeAttachments = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('backup_include_attachments', v);
              },
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _ToggleRow(
              icon: Icons.shield_rounded,
              title: 'End-to-end encryption',
              subtitle: 'Encrypts your backup data',
              value: _encrypted,
              onChanged: (v) async {
                setState(() => _encrypted = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('backup_encrypted', v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Restore
        _SettingsCard(
          title: 'Restore',
          icon: Icons.restore_rounded,
          children: [
            _SettingsActionButton(
              label: 'Restore from Drive Backup',
              icon: Icons.cloud_download_rounded,
              onTap: _restore,
            ),
          ],
        ),
      ],
    );
  }
}

// -- AI Tab --------------------------------------------------------------------

class _AITab extends StatefulWidget {
  const _AITab();

  @override
  State<_AITab> createState() => _AITabState();
}

class _AITabState extends State<_AITab> {
  List<Account> _accounts = [];
  int? _defaultExpenseAccount;
  int? _defaultIncomeAccount;
  LogLevel _logLevel = LogLevel.info;
  AiProvider _provider = AiProvider.groq;
  bool _hasKey = false;
  String _maskedKey = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AppDatabase.getAccounts();
    final expId = await ChatParser.getDefaultExpenseAccount();
    final incId = await ChatParser.getDefaultIncomeAccount();
    final level = AppLogger.getLevel();
    final provider = await AiService.getProvider();
    final hasKey = await AiService.hasApiKey();
    final rawKey = await AiService.getApiKey(provider);
    final masked = rawKey != null && rawKey.length > 8
        ? '${rawKey.substring(0, 4)}...${rawKey.substring(rawKey.length - 4)}'
        : (rawKey != null && rawKey.isNotEmpty ? '****' : '');
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _defaultExpenseAccount = expId;
      _defaultIncomeAccount = incId;
      _logLevel = level;
      _provider = provider;
      _hasKey = hasKey;
      _maskedKey = masked;
    });
  }

  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController();
    var selectedProvider = _provider;
    var obscure = true;

    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFFF7F5F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.key_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Configure AI Key',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          ]),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Provider picker
              Row(
                children: AiProvider.values.map((p) => Expanded(
                  child: GestureDetector(
                    onTap: () => setLocal(() => selectedProvider = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedProvider == p ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(p.label, textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selectedProvider == p ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {},
                child: Text(
                  'Get key: ${selectedProvider.setupUrl}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                style: TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: selectedProvider.hint,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    onPressed: () => setLocal(() => obscure = !obscure),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            if (_hasKey)
              TextButton(
                onPressed: () async {
                  await AiService.clearApiKey(_provider);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text('Remove',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              onPressed: () async {
                final key = ctrl.text.trim();
                if (key.isEmpty) return;
                await AiService.saveApiKey(key, selectedProvider);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final accountItems = [
      const DropdownMenuItem<int>(value: null, child: Text('None selected')),
      ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // -- AI Overview card --
        ListenableBuilder(
          listenable: ThemeService.instance,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: ThemeService.instance.primaryShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Assistant',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 3),
                        Text(
                            'Configure how the AI interprets your transactions',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        // -- API Configuration --
        _SettingsCard(
          title: 'API Configuration',
          icon: Icons.key_rounded,
          children: [
            _ActionRow(
              icon: _hasKey ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              iconColor: _hasKey
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              title: _hasKey ? '${_provider.label} key configured' : 'No API key set',
              subtitle: _hasKey ? _maskedKey : 'Required to use AI chat features',
              trailingLabel: _hasKey ? 'Change' : 'Setup',
              onTap: _showApiKeyDialog,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // -- Default Accounts --
        _SettingsCard(
          title: 'Default Accounts',
          icon: Icons.account_balance_wallet_rounded,
          children: [
            _DropdownRow(
              icon: Icons.remove_circle_outline_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Default Expense Account',
              subtitle: 'Used when AI logs expenses',
              value: _defaultExpenseAccount,
              items: accountItems,
              onChanged: (v) async {
                await ChatParser.setDefaultExpenseAccount(v);
                setState(() => _defaultExpenseAccount = v);
              },
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _DropdownRow(
              icon: Icons.add_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Default Income Account',
              subtitle: 'Used when AI logs income',
              value: _defaultIncomeAccount,
              items: accountItems,
              onChanged: (v) async {
                await ChatParser.setDefaultIncomeAccount(v);
                setState(() => _defaultIncomeAccount = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // -- Diagnostics --
        _SettingsCard(
          title: 'Diagnostics',
          icon: Icons.bug_report_rounded,
          children: [
            _DropdownRow(
              icon: Icons.tune_rounded,
              iconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              title: 'Log Level',
              subtitle: 'Controls verbosity of app logs',
              value: _logLevel,
              items: LogLevel.values
                  .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l.name[0].toUpperCase() +
                          l.name.substring(1))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                AppLogger.setLevel(v);
                setState(() => _logLevel = v);
              },
            ),
          ],
        ),
      ],
    );
  }
}

// -- Preferences Tab ----------------------------------------------------------

class _PreferencesTab extends StatefulWidget {
  const _PreferencesTab();

  @override
  State<_PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<_PreferencesTab> {
  bool _notifyTransactions = true;
  bool _notifyBudget = true;
  bool _notifyWeekly = false;

  bool _smsEnabled = false;
  SmsScanRange _smsScanRange = SmsScanRange.oneMonth;
  DateTime? _smsLastScan;
  bool _smsScanning = false;
  String? _smsResult;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
    _loadSmsPrefs();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _SettingsCard(
          title: 'Notifications',
          icon: Icons.notifications_rounded,
          children: [
            _ToggleRow(
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
            _ToggleRow(
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
            _ToggleRow(
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
        _SettingsCard(
          title: 'Appearance',
          icon: Icons.palette_rounded,
          children: const [
            _AppearanceSection(),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsCard(
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
            _ToggleRow(
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
              _SettingsActionButton(
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

// -- Shared Settings Widgets ---------------------------------------------------

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SettingsCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsActionButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox(),
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w600),
            icon: Icon(Icons.expand_more_rounded,
                size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle, trailingLabel;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(trailingLabel,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Backup-specific widgets ---------------------------------------------------

class _BackupStatusCard extends StatelessWidget {
  final DriveFolder? folder;
  final String? lastBackup;
  final bool isSignedIn;
  final String? userEmail;

  const _BackupStatusCard({
    required this.folder,
    required this.lastBackup,
    required this.isSignedIn,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance;
    final statusLabel = isSignedIn ? 'Connected' : 'Not signed in';
    final detail = !isSignedIn
        ? 'Sign in to enable backup'
        : folder == null
            ? 'Drive folder not set'
            : (lastBackup != null ? 'Last backup: $lastBackup' : 'No backups yet');
    final badge = isSignedIn ? (folder == null ? 'Setup' : 'Ready') : 'Offline';
    return Container(
      decoration: BoxDecoration(
        gradient: themeService.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: themeService.primaryShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_sync_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Backup Status',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(statusLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MetaChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: Colors.white54),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BackupNowButton extends StatelessWidget {
  final bool backing;
  final VoidCallback onTap;
  const _BackupNowButton({required this.backing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService.instance;
    return GestureDetector(
      onTap: backing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: backing ? null : themeService.cardGradient,
          color: backing ? theme.colorScheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: backing ? null : themeService.primaryShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (backing) ...[
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurface.withOpacity(0.5))),
              const SizedBox(width: 10),
              Text('Backing up...',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5))),
            ] else ...[
              const Icon(Icons.backup_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Back Up Now',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupSettingRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const _BackupSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 17,
                color: value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// -- Appearance Section ----------------------------------------------------

class _AppearanceSection extends StatefulWidget {
  const _AppearanceSection();
  @override
  State<_AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<_AppearanceSection> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Accent Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppAccentColor.values.map((accent) {
              final color = ThemeService.accentColors[accent]!;
              final name = ThemeService.accentNames[accent]!;
              final selected = ts.accent == accent;
              return GestureDetector(
                onTap: () => ts.setAccent(accent),
                child: Tooltip(
                  message: name,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(selected ? 0.5 : 0.2),
                          blurRadius: selected ? 10 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Contrast',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Row(
            children: [
              Icon(Icons.contrast_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              Expanded(
                child: Slider(
                  value: ts.contrast,
                  min: 0.7,
                  max: 1.3,
                  divisions: 30,
                  label: '${((ts.contrast - 0.7) / 0.6 * 100).round()}%',
                  onChanged: (v) => ts.setContrast(v),
                ),
              ),
              Text('${((ts.contrast - 0.7) / 0.6 * 100).round()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Text Size',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Row(
            children: [
              Icon(Icons.text_fields_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              Expanded(
                child: Slider(
                  value: ts.textSizeIndex.toDouble(),
                  min: 0,
                  max: 2,
                  divisions: 2,
                  label: ts.textSizeIndex == 0 ? 'Small' : ts.textSizeIndex == 1 ? 'Normal' : 'Large',
                  onChanged: (v) => ts.setTextSizeIndex(v.toInt()),
                ),
              ),
              Text(ts.textSizeIndex == 0 ? 'Small (85%)' : ts.textSizeIndex == 1 ? 'Normal (100%)' : 'Large (120%)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          _ToggleRow(
            icon: Icons.swap_horiz_rounded,
            title: 'Left-Handed Mode',
            subtitle: 'Moves FAB to left side',
            value: ts.leftHanded,
            onChanged: (v) => ts.setLeftHanded(v),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Theme',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Row(
            children: AppThemeMode.values.map((m) {
              final selected = ts.mode == m;
              final label = m == AppThemeMode.system
                  ? 'System'
                  : m == AppThemeMode.light
                      ? 'Light'
                      : 'Dark';
              final icon = m == AppThemeMode.system
                  ? Icons.brightness_auto_rounded
                  : m == AppThemeMode.light
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded;
              return Expanded(
                child: GestureDetector(
                  onTap: () => ts.setMode(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: m != AppThemeMode.dark ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? ts.primaryColor : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 20,
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(height: 4),
                        Text(label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

