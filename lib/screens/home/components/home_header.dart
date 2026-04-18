import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/image_cache_service.dart';
import '../../../../services/time_filter.dart';
import '../../../../services/refresh_notifier.dart';
import '../../../widgets/figma/global_filter_button.dart';
import '../../profile/profile_screen.dart';
import '../../settings/settings_screen.dart';
import '../../shared/shared.dart';
import '../../../../theme/app_theme.dart';

/// Home screen header with greeting, avatar, and controls
class HomeHeader extends StatefulWidget {
  final VoidCallback onNotificationsTap;

  const HomeHeader({
    super.key,
    required this.onNotificationsTap,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    // Only animate if device doesn't prefer reduced motion
    if (!_shouldReduceAnimations()) {
      _rippleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    } else {
      _rippleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
    }
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  bool _shouldReduceAnimations() {
    return WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
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
        // Avatar with ripple animation → taps to Profile
        GestureDetector(
          onTap: () => _showProfilePanel(context),
          child: AnimatedBuilder(
            animation: _rippleAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple effect
                  Container(
                    width: 40 + (_rippleAnimation.value * 16),
                    height: 40 + (_rippleAnimation.value * 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(
                          (1 - _rippleAnimation.value) * 0.4,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      child: photoUrl == null
                          ? Icon(Icons.person_rounded, 
                              color: Theme.of(context).colorScheme.primary, 
                              size: 22)
                          : ClipOval(
                              child: CachedImage(
                                imageUrl: photoUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
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
          onTap: widget.onNotificationsTap,
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
      ],
    );
  }
}

void _showProfilePanel(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Profile",
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.75,
          child: const ProfileScreen(),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final fade = Tween(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ));

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
  
  // Trigger refresh to update header with new auth state
  notifyDataChanged();
}
