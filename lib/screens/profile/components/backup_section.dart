import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class BackupSection extends StatelessWidget {

  const BackupSection({
    required this.isSignedIn, required this.folder, required this.lastBackup, required this.backupFreq, required this.loading, required this.onSignIn, required this.onFolderPicker, required this.onBackup, required this.onRestore, required this.onFrequencyChanged, super.key,
  });
  final bool isSignedIn;
  final DriveFolder? folder;
  final String? lastBackup;
  final String backupFreq;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onFolderPicker;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final Function(String) onFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.cloud_outlined, color: AppTheme.blue),
      title: const Text('Google Drive Backup'),
      subtitle: Text(
        isSignedIn
            ? (folder != null ? 'Location: ${folder!.path}' : 'No location selected')
            : 'Sign in to backup',
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSignedIn) ...[
                const Text('Sign in with Google to backup and restore your data.',
                    style: TextStyle(color: AppTheme.slate400, fontSize: 13)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: loading ? null : onSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Choose where to save backups on your Google Drive',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (folder != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.folder, color: Theme.of(context).colorScheme.secondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(folder!.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(folder!.path,
                                style: TextStyle(
                                    fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: loading ? null : onFolderPicker,
                        child: const Text('Change'),
                      ),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.secondary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('No backup location selected',
                            style: TextStyle(fontSize: 13)),
                      ),
                      FilledButton.icon(
                        onPressed: loading ? null : onFolderPicker,
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Choose'),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                if (lastBackup != null)
                  Text(
                      'Last backup: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(lastBackup!))}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)))
                else
                  Text('No backup yet',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Auto-backup: ', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: backupFreq,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Manual only')),
                      DropdownMenuItem(value: 'hourly', child: Text('Every hour')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    ],
                    onChanged: (v) {
                      if (v != null) onFrequencyChanged(v);
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onBackup,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Backup Now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: folder != null ? onRestore : null,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Restore'),
                      ),
                    ),
                  ]),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

