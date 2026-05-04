import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/app_notification.dart';
import '../services/notification_manager.dart';
import '../theme/app_color_scheme.dart';
import 'transactions/transactions_screen.dart';
import 'accounts/accounts_screen.dart';
import 'intelligence/sms_intelligence_dashboard_screen.dart';
import 'intelligence/transfer_pairs_screen.dart';
import 'intelligence/recurring_patterns_screen.dart';

/// Screen showing all notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (NotificationManager.instance.unreadCount > 0)
            TextButton(
              onPressed: () async {
                await NotificationManager.instance.markAllAsRead();
                if (mounted) setState(() {});
              },
              child: const Text('Mark all read'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete_read') {
                await NotificationManager.instance.deleteRead();
                if (mounted) setState(() {});
              } else if (value == 'delete_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete All Notifications?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm ?? false) {
                  await NotificationManager.instance.deleteAll();
                  if (mounted) setState(() {});
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_read',
                child: Text('Delete read'),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Text('Delete all'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: NotificationManager.instance,
        builder: (context, _) {
          final notifications = NotificationManager.instance.all;
          
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: Theme.of(context).extension<AppColorScheme>()!.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).extension<AppColorScheme>()!.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).extension<AppColorScheme>()!.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                onTap: () => _handleNotificationTap(notification),
                onDelete: () async {
                  await NotificationManager.instance.delete(notification.id);
                  if (mounted) setState(() {});
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Mark as read
    if (!notification.isRead) {
      await NotificationManager.instance.markAsRead(notification.id);
      if (mounted) setState(() {});
    }

    // Navigate if action route is specified
    if (notification.actionRoute != null) {
      final route = notification.actionRoute!;
      Widget? screen;

      // Parse route and determine destination
      if (route.contains('pending')) {
        // Pending actions now live in the Transactions screen as needs-review filter
        screen = const TransactionsScreen(initialFilterNeedsReview: true);
      } else if (route.contains('transaction')) {
        screen = const TransactionsScreen();
      } else if (route.contains('account')) {
        screen = const AccountsScreen();
      } else if (route.contains('transfer')) {
        screen = const TransferPairsScreen();
      } else if (route.contains('recurring')) {
        screen = const RecurringPatternsScreen();
      } else if (route.contains('intelligence')) {
        screen = const SmsIntelligenceDashboardScreen();
      }

      if (screen != null && mounted) {
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen!),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }
}

/// Individual notification card
class _NotificationCard extends StatelessWidget {

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.transaction:
        return Icons.receipt_long_rounded;
      case NotificationType.budget:
        return Icons.pie_chart_rounded;
      case NotificationType.goal:
        return Icons.savings_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.insight:
        return Icons.lightbulb_rounded;
      case NotificationType.system:
        return Icons.settings_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  Color _getColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorScheme>()!;
    switch (notification.type) {
      case NotificationType.transaction:
        return appColors.primary;
      case NotificationType.budget:
        return appColors.warning;
      case NotificationType.goal:
        return appColors.success;
      case NotificationType.reminder:
        return appColors.error;
      case NotificationType.insight:
        return appColors.primaryVariant;
      case NotificationType.system:
        return appColors.onSurfaceVariant;
      case NotificationType.info:
        return appColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorScheme>()!;
    final color = _getColor(context);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: appColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Theme.of(context).colorScheme.surface
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? appColors.outline
                : color.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: notification.isRead
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: appColors.onSurface,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: appColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormatter.relative(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: appColors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

