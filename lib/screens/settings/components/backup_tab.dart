import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../db/database.dart';
import '../../../../services/app_logger.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/refresh_notifier.dart';
import 'backup_widgets.dart';
import 'settings_card.dart';
import 'settings_widgets.dart';

class BackupTab extends StatefulWidget {
  const BackupTab({super.key});

  @override
  State<BackupTab> createState() => BackupTabState();
}

class BackupTabState extends State<BackupTab> {
  bool _backingUp = false;
  bool _settingUpFolder = false;
  String? _lastBackup;
  DriveFolder? _folder;
  String _backupFreq = 'daily';
  bool _wifiOnly = true;
  bool _includeAttachments = false;
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
          prefs.getBool('backup_include_attachments') ?? false;
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
          SnackBar(content: const Text('Drive folder ready ✓'),
              backgroundColor: Theme.of(context).colorScheme.tertiary));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Backup successful ✓'),
          backgroundColor: Theme.of(context).colorScheme.tertiary));
    } catch (e) {
      if (!mounted) return;
      setState(() => _backingUp = false);
      AppLogger.err('settings_backup', e);
      
      // Check if it's a WiFi-only error
      final errorMsg = e.toString();
      final isWifiError = errorMsg.contains('WiFi-only');
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isWifiError 
              ? 'WiFi-only backup enabled. Please connect to WiFi.' 
              : 'Backup failed. ${errorMsg.contains('Exception:') ? errorMsg.split('Exception:')[1].trim() : 'Please try again.'}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: isWifiError ? 4 : 3)));
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
                  backgroundColor: Theme.of(context).colorScheme.error),
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

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
            'This will permanently delete all transactions, accounts, budgets, savings goals and recurring transactions. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete Everything')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _backingUp = true);
    try {
      await AppDatabase.deleteAllData();
      notifyDataChanged();
      if (!mounted) return;
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _backingUp = false);
      AppLogger.err('backup_delete_all_data', e);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to delete data')));
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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
                    ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1)
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
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                    ),
                    if (sel)
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: Theme.of(context).colorScheme.tertiary),
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
        BackupStatusCard(
          folder: _folder,
          lastBackup: _lastBackup,
          isSignedIn: isSignedIn,
          userEmail: user?.email,
        ),
        const SizedBox(height: 12),
        // Back Up Now
        BackupNowButton(backing: _backingUp, onTap: _backup),
        const SizedBox(height: 12),
        // Backup Settings
        SettingsCard(
          title: 'Backup Settings',
          icon: Icons.settings_rounded,
          children: [
            BackupSettingRow(
              icon: Icons.cloud_rounded,
              title: 'Cloud Storage',
              subtitle: _settingUpFolder
                  ? 'Connecting...'
                  : _folder == null
                      ? (AuthService.isSignedIn ? 'Tap to set up Drive folder' : 'Tap to connect Google Drive')
                      : _folder!.name,
              subtitleColor: _settingUpFolder
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                  : _folder != null ? Theme.of(context).colorScheme.tertiary : null,
              onTap: _settingUpFolder ? () {} : _autoSelectFolder,
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            BackupSettingRow(
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
        SettingsCard(
          title: 'Advanced Options',
          icon: Icons.tune_rounded,
          children: [
            ToggleRow(
              icon: Icons.wifi_rounded,
              title: 'Backup over Wi-Fi only',
              subtitle:
                  _wifiOnly ? 'Wi-Fi only' : 'Wi-Fi + Mobile Data',
              value: _wifiOnly,
              onChanged: (v) async {
                setState(() => _wifiOnly = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool('backup_wifi_only', v);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(v 
                        ? 'Backups will only occur over Wi-Fi' 
                        : 'Backups can use Wi-Fi or mobile data'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            // Hide attachments and encryption options
          ],
        ),
        const SizedBox(height: 12),
        // Restore
        SettingsCard(
          title: 'Restore',
          icon: Icons.restore_rounded,
          children: [
            SettingsActionButton(
              label: 'Restore from Drive Backup',
              icon: Icons.cloud_download_rounded,
              onTap: _restore,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Danger Zone',
          icon: Icons.warning_rounded,
          children: [
            SettingsActionButton(
              label: 'Delete All Data',
              icon: Icons.delete_forever_rounded,
              onTap: _deleteAllData,
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }
}

