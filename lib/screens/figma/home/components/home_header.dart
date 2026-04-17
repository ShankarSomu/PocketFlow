import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/time_filter.dart';
import '../../profile_screen.dart';
import '../../settings_screen.dart';
import '../../shared.dart';
import '../../../../theme/app_theme.dart';

/// Home screen header with greeting, avatar, and controls
class HomeHeader extends StatelessWidget {
  final VoidCallback onNotificationsTap;

  const HomeHeader({
    super.key,
    required this.onNotificationsTap,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final firstName = user?.displayName?.split(' ').first;
    final userName = firstName ?? 'there';
    final photoUrl = user?.photoUrl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar → taps to Profile
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSecondary, size: 22)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        // Greeting + name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                userName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Time filter pill
        AnimatedBuilder(
          animation: appTimeFilter,
          builder: (ctx, _) => GestureDetector(
            onTap: () => showTimeFilterSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.tertiary,
                    Theme.of(context).colorScheme.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    appTimeFilter.current.shortLabel,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), size: 15),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Notifications
        GestureDetector(
          onTap: onNotificationsTap,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
          ),
        ),
        const SizedBox(width: 8),
        // Settings
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
          ),
        ),
      ],
    );
  }
}
