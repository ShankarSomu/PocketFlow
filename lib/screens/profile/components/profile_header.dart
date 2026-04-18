import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  final VoidCallback onTap;
  
  const ProfileHeader({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isSignedIn = AuthService.isSignedIn;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
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
                      : Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Theme.of(context).colorScheme.onPrimary, AppTheme.emerald],
                      ).createShader(bounds),
                      child: Text(
                        user?.displayName ?? 'Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isSignedIn)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.emerald.withValues(alpha: 0.2), AppTheme.blue.withValues(alpha: 0.2)],
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
                                color: AppTheme.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        'Manage your account',
                        style: TextStyle(color: AppTheme.slate400, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
