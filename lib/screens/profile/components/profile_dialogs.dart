import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class ProfileDialogs {
  static Future<void> showProfileMenu(
    BuildContext context, {
    required VoidCallback onSignIn,
    required VoidCallback onSignOut,
    required VoidCallback onDeleteAllData,
  }) async {
    final user = AuthService.currentUser;
    final isSignedIn = AuthService.isSignedIn;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSignedIn) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user?.displayName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user?.email ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(ctx).colorScheme.error),
                title: Text('Sign Out', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onSignOut();
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Theme.of(ctx).colorScheme.error),
                title: Text('Delete All Data', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                subtitle: const Text('Permanently delete all data', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDeleteAllData();
                },
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sign in to access more features',
                    style: TextStyle(color: AppTheme.slate400)),
              ),
              ListTile(
                leading: Icon(Icons.login, color: Theme.of(ctx).colorScheme.primary),
                title: const Text('Sign in with Google'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSignIn();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<bool> showDeleteConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<bool> showRestoreConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<bool> showLoadSampleDataConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Sample Data?'),
        content: const Text(
            'This will add demo accounts, transactions, budgets, and savings goals to your database. Existing data will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class FolderPickerSheet extends StatefulWidget {
  final List<DriveFolder> folders;
  const FolderPickerSheet({super.key, required this.folders});

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('Choose Backup Folder',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Select where to save your backup on Google Drive',
            style: TextStyle(fontSize: 12, color: AppTheme.slate400),
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
                          strokeWidth: 2, color: AppTheme.slate200))
                  : const Text('Create'),
            ),
          ]),
          const Divider(height: 24),
          Expanded(
            child: widget.folders.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.folder_off_outlined,
                          size: 48, color: AppTheme.slate400),
                      SizedBox(height: 8),
                      Text('No folders found.\nCreate one above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.slate400)),
                    ]))
                : ListView.builder(
                    controller: scroll,
                    itemCount: widget.folders.length,
                    itemBuilder: (_, i) {
                      final f = widget.folders[i];
                      return ListTile(
                        leading: Icon(Icons.folder_rounded,
                            color: Theme.of(context).colorScheme.secondary),
                        title: Text(f.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(f.path,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.slate400)),
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
