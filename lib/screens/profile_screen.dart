import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../services/auth_service.dart';
import '../services/refresh_notifier.dart';
import '../services/app_logger.dart';
import '../services/chat_parser.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_text.dart';
import 'category_screen.dart';
import 'diagnostics_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAccounts();
    _loadAccountHealth();
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
    List<DriveFolder> folders = [];
    try {
      folders = await AuthService.listFolders();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _message = 'Failed to load folders: $e'; _isError = true; });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    final picked = await showModalBottomSheet<DriveFolder>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FolderPickerSheet(folders: folders),
    );

    if (picked != null) {
      await AuthService.saveSelectedFolder(picked);
      if (!mounted) return;
      setState(() {
        _folder = picked;
        _message = 'Backup folder set';
        _isError = false;
      });
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
            'This will permanently delete ALL transactions, accounts, budgets, savings goals and recurring transactions.\n\nMake sure you have backed up first. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'This will replace ALL current data with the backup from Google Drive. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

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
    final user = AuthService.currentUser;
    final isSignedIn = AuthService.isSignedIn;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.emeraldBlueGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emerald.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: user?.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    user!.photoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFD1FAE5)],
                                ).createShader(bounds),
                                child: Text(
                                  user?.displayName ?? 'Profile',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isSignedIn)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFD1FAE5), Color(0xFFDEEBFF)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 14, color: AppTheme.emerald),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Premium Member',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Text(
                                  'Manage your account',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  children: [

            // Account Health Card
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: child,
                  ),
                );
              },
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.emeraldGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.health_and_safety, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Account Health',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _HealthMetric(
                            label: 'Savings Rate',
                            value: '${_savingsRate.toStringAsFixed(0)}%',
                            icon: Icons.savings_outlined,
                            color: _savingsRate >= 20 ? AppTheme.emerald : Colors.orange,
                            status: _savingsRate >= 20 ? 'Good' : 'Low',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HealthMetric(
                            label: 'Budget',
                            value: '${_budgetCompliance.toStringAsFixed(0)}%',
                            icon: Icons.pie_chart_outline,
                            color: _budgetCompliance >= 80 ? AppTheme.emerald : Colors.orange,
                            status: _budgetCompliance >= 80 ? 'On Track' : 'Review',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HealthMetric(
                            label: 'Goals',
                            value: '$_goalsOnTrack/$_totalGoals',
                            icon: Icons.flag_outlined,
                            color: _totalGoals > 0 && _goalsOnTrack == _totalGoals ? AppTheme.emerald : AppTheme.indigo,
                            status: _totalGoals > 0 && _goalsOnTrack == _totalGoals ? 'All' : 'Active',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Google Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 16),
                if (isSignedIn) ...[
                  Row(children: [
                    CircleAvatar(
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.displayName ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(user?.email ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                  ),
                ] else ...[
                  const Text('Sign in with Google to backup and restore your data.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            if (isSignedIn) ...[
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Backup Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 12),
                  if (_folder != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.folder, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_folder!.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _showFolderPicker,
                            child: const Text('Change'),
                          ),
                        ]),
                      ],
                    )
                  else
                    Row(children: [
                      const Text('No folder selected',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _loading ? null : _showFolderPicker,
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Choose'),
                      ),
                    ]),
                ]),
              ),
              const SizedBox(height: 16),

              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Google Drive Backup',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 12),
                  if (_lastBackup != null)
                    Text(
                        'Last backup: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(_lastBackup!))}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    const Text('No backup yet',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Auto-backup: ',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _backupFreq,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('Manual only')),
                        DropdownMenuItem(value: 'hourly', child: Text('Every hour')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await AuthService.setBackupFrequency(v);
                        setState(() => _backupFreq = v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _backup,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Backup Now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _folder != null ? _restore : null,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Restore'),
                        ),
                      ),
                    ]),
                ]),
              ),
            ],

            if (_message != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isError ? Colors.red : Colors.green)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(
                    _isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: _isError ? Colors.red : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_message!,
                          style: TextStyle(
                              color: _isError ? Colors.red : Colors.green,
                              fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined,
                      color: AppTheme.indigo),
                  title: const Text('Manage Categories'),
                  subtitle: const Text('Add, edit or delete categories',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined,
                      color: Colors.orange),
                  title: const Text('Diagnostics'),
                  subtitle: const Text('View app logs and debug info',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DiagnosticsScreen()),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferences',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.analytics_outlined, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Logging Level',
                          style: TextStyle(fontSize: 13)),
                    ),
                    DropdownButton<LogLevel>(
                      value: _logLevel,
                      isDense: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: LogLevel.error, child: Text('Errors only')),
                        DropdownMenuItem(value: LogLevel.warning, child: Text('Warnings')),
                        DropdownMenuItem(value: LogLevel.info, child: Text('Normal')),
                        DropdownMenuItem(value: LogLevel.debug, child: Text('Verbose')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await AppLogger.setLevel(v);
                        setState(() => _logLevel = v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.arrow_upward, size: 20, color: Colors.red),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Default Expense Account',
                          style: TextStyle(fontSize: 13)),
                    ),
                    DropdownButton<int?>(
                      value: _defaultExpenseAccount,
                      isDense: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, style: const TextStyle(fontSize: 13)),
                        )),
                      ],
                      onChanged: (v) async {
                        await ChatParser.setDefaultExpenseAccount(v);
                        setState(() => _defaultExpenseAccount = v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.arrow_downward, size: 20, color: Colors.green),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Default Income Account',
                          style: TextStyle(fontSize: 13)),
                    ),
                    DropdownButton<int?>(
                      value: _defaultIncomeAccount,
                      isDense: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, style: const TextStyle(fontSize: 13)),
                        )),
                      ],
                      onChanged: (v) async {
                        await ChatParser.setDefaultIncomeAccount(v);
                        setState(() => _defaultIncomeAccount = v);
                      },
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danger Zone',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red)),
                  const SizedBox(height: 12),
                  const Text(
                    'Backup your data before deleting. This cannot be undone.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSignedIn && _folder != null
                            ? _backup
                            : null,
                        icon: const Icon(Icons.cloud_upload, size: 16),
                        label: const Text('Backup First'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _deleteAllData,
                        icon: const Icon(Icons.delete_forever, size: 16),
                        label: const Text('Delete All Data'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
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

class _FolderPickerSheet extends StatefulWidget {
  final List<DriveFolder> folders;
  const _FolderPickerSheet({required this.folders});

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  Future<void> _createFolder() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final folder = await AuthService.createFolder(name);
      if (mounted) Navigator.pop(context, folder);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('Choose Backup Folder',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Select where to save your backup on Google Drive',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'New folder name',
                  prefixIcon: Icon(Icons.create_new_folder_outlined),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _creating ? null : _createFolder,
              child: _creating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ]),
          const Divider(height: 24),
          Expanded(
            child: widget.folders.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.folder_off_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No folders found.\nCreate one above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ]))
                : ListView.builder(
                    controller: scroll,
                    itemCount: widget.folders.length,
                    itemBuilder: (_, i) {
                      final f = widget.folders[i];
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded,
                            color: Colors.amber),
                        title: Text(f.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(f.path,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        onTap: () => Navigator.pop(context, f),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}


class _HealthMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String status;

  const _HealthMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.slate600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
