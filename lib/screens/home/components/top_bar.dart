import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  final String greeting;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSettingsTap;
  final String? userName;
  final String? avatarUrl;
  const TopBar({
    super.key,
    required this.greeting,
    required this.onNotificationTap,
    this.onSettingsTap,
    this.userName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
              child: avatarUrl == null
                  ? Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName ?? 'PocketFlow Dashboard',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: onNotificationTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.onPrimary, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSettingsTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
