import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/theme_service.dart';

class BackupStatusCard extends StatelessWidget {

  const BackupStatusCard({
    required this.folder, required this.lastBackup, required this.isSignedIn, required this.userEmail, super.key,
  });
  final DriveFolder? folder;
  final String? lastBackup;
  final bool isSignedIn;
  final String? userEmail;

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
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.cloud_sync_rounded,
                color: Theme.of(context).colorScheme.onPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('Backup Status',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(statusLabel,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class BackupNowButton extends StatelessWidget {
  
  const BackupNowButton({
    required this.backing, required this.onTap, super.key,
  });
  final bool backing;
  final VoidCallback onTap;

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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const SizedBox(width: 10),
              Text('Backing up...',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ] else ...[
              Icon(Icons.backup_rounded,
                  color: theme.colorScheme.onPrimary, size: 18),
              const SizedBox(width: 8),
              Text('Back Up Now',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimary)),
            ],
          ],
        ),
      ),
    );
  }
}

class BackupSettingRow extends StatelessWidget {

  const BackupSettingRow({
    required this.icon, required this.title, required this.subtitle, required this.onTap, super.key,
    this.subtitleColor,
  });
  final IconData icon;
  final String title, subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

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
                          color: subtitleColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

