import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/chat_parser.dart';
import '../../services/groq_service.dart';
import '../../theme/app_theme.dart';

// ── Settings Screen ───────────────────────────────────────────────────────────

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
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.slate700, size: 18),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Tab Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2E22), Color(0xFF0F766E)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.slate500,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Backup Tab ────────────────────────────────────────────────────────────────

class _BackupTab extends StatefulWidget {
  const _BackupTab();

  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  bool _backingUp = false;
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

  Future<void> _showFolderPicker() async {
    setState(() => _backingUp = true);
    try {
      if (!AuthService.isSignedIn) {
        final user = await AuthService.signIn();
        if (user == null) {
          if (!mounted) return;
          setState(() => _backingUp = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in failed')));
          return;
        }
      }
      final folder = await _pickFolder();
      if (folder != null) {
        await AuthService.saveSelectedFolder(folder);
        if (!mounted) return;
        setState(() => _folder = folder);
      }
    } catch (e) {
      AppLogger.err('settings_folder_pick', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to select folder')));
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<DriveFolder?> _pickFolder() async {
    final folders = await AuthService.listFolders();
    return showModalBottomSheet<DriveFolder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Select Google Drive Folder',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                        'No folders found. Create one to continue.',
                        style: TextStyle(color: AppTheme.slate500)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.emerald),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _createFolder();
                      },
                      child: const Text('Create Backup Folder'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              )
            else
              SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.55,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: folders.length + 1,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) {
                    if (i == folders.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.emerald),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _createFolder();
                          },
                          child: const Text('Create New Folder'),
                        ),
                      );
                    }
                    final f = folders[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_open_rounded,
                          color: AppTheme.emerald),
                      title: Text(f.name),
                      subtitle: Text(f.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 11)),
                      trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14),
                      onTap: () => Navigator.pop(ctx, f),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController(text: 'PocketFlow Backups');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Drive Folder'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final f = await AuthService.createFolder(name);
      await AuthService.saveSelectedFolder(f);
      if (!mounted) return;
      setState(() => _folder = f);
    } catch (e) {
      AppLogger.err('settings_create_folder', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to create folder')));
      }
    }
  }

  Future<void> _backup() async {
    if (!AuthService.isSignedIn) {
      await _showFolderPicker();
      if (!AuthService.isSignedIn) return;
    }
    if (_folder == null) {
      await _showFolderPicker();
      if (_folder == null) return;
    }
    setState(() => _backingUp = true);
    try {
      await AuthService.backup();
      await _load();
      if (!mounted) return;
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup successful ✓'),
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
        title: const Text('Restore Backup?'),
        content: const Text(
            'This will replace your current data with the backup. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Restore')),
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
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
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
                                  : AppTheme.slate700)),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
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
              subtitle: _folder == null
                  ? (isSignedIn ? 'Tap to select folder' : 'Not connected')
                  : _folder!.name,
              subtitleColor:
                  _folder != null ? const Color(0xFF10B981) : null,
              onTap: _showFolderPicker,
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

// ── AI Tab ────────────────────────────────────────────────────────────────────

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
            const Icon(Icons.key_rounded, color: AppTheme.emerald, size: 20),
            const SizedBox(width: 8),
            const Text('Configure AI Key',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
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
                        color: selectedProvider == p ? AppTheme.emerald : AppTheme.slate100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(p.label, textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selectedProvider == p ? Colors.white : AppTheme.slate600,
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
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate500, decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: selectedProvider.hint,
                  hintStyle: const TextStyle(color: AppTheme.slate400, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.slate200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.slate200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.emerald, width: 2)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18, color: AppTheme.slate400),
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
                child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
              onPressed: () async {
                final key = ctrl.text.trim();
                if (key.isEmpty) return;
                await AiService.saveApiKey(key, selectedProvider);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
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
        // ── AI Overview card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2E22), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Assistant',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 3),
                    Text(
                        'Configure how the AI interprets your transactions',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── API Configuration ──
        _SettingsCard(
          title: 'API Configuration',
          icon: Icons.key_rounded,
          children: [
            _ActionRow(
              icon: _hasKey ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              iconColor: _hasKey ? AppTheme.emerald : AppTheme.warning,
              title: _hasKey ? '${_provider.label} key configured' : 'No API key set',
              subtitle: _hasKey ? _maskedKey : 'Required to use AI chat features',
              trailingLabel: _hasKey ? 'Change' : 'Setup',
              onTap: _showApiKeyDialog,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // ── Default Accounts ──
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
        // ── Diagnostics ──
        _SettingsCard(
          title: 'Diagnostics',
          icon: Icons.bug_report_rounded,
          children: [
            _DropdownRow(
              icon: Icons.tune_rounded,
              iconColor: AppTheme.slate500,
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

// ── Shared Settings Widgets ───────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SettingsCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.emerald),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate700)),
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
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate900)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.slate500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox(),
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slate700,
                fontWeight: FontWeight.w600),
            icon: const Icon(Icons.expand_more_rounded,
                size: 18, color: AppTheme.slate400),
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
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate900)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.slate500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(trailingLabel,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Backup-specific widgets ───────────────────────────────────────────────────

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
    final hasBackup = lastBackup != null;
    String timeLabel = 'Never';
    if (hasBackup) {
      try {
        final dt = DateTime.parse(lastBackup!).toLocal();
        timeLabel = DateFormat('MMM d, y  h:mm a').format(dt);
      } catch (_) {
        timeLabel = lastBackup!;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E22), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
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
                    Text(
                      isSignedIn ? (userEmail ?? 'Signed in') : 'Not signed in',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isSignedIn
                        ? const Color(0xFF10B981).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  isSignedIn ? 'Connected' : 'Offline',
                  style: TextStyle(
                      color: isSignedIn
                          ? const Color(0xFF6EE7B7)
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: 'Last backup',
                  value: timeLabel),
              const SizedBox(width: 10),
              if (folder != null)
                Expanded(
                  child: _MetaChip(
                      icon: Icons.folder_rounded,
                      label: 'Folder',
                      value: folder!.name),
                ),
            ],
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
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
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
    return GestureDetector(
      onTap: backing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: backing
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
          color: backing ? AppTheme.slate200 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: backing ? null : AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (backing) ...[
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.slate500)),
              const SizedBox(width: 10),
              const Text('Backing up…',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate500)),
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
                  color: AppTheme.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: AppTheme.emerald),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate900)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: subtitleColor ?? AppTheme.slate500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.slate400),
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
                  ? AppTheme.emerald.withValues(alpha: 0.12)
                  : AppTheme.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 17,
                color: value ? AppTheme.emerald : AppTheme.slate400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate900)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.slate500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.emerald,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
