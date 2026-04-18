import 'package:flutter/material.dart';

class ProfileHeroCard extends StatelessWidget {
  final dynamic user;
  final bool isSignedIn;
  final double savingsRate, budgetCompliance;
  final int goalsOnTrack, totalGoals;

  const ProfileHeroCard({
    super.key,
    required this.user,
    required this.isSignedIn,
    required this.savingsRate,
    required this.budgetCompliance,
    required this.goalsOnTrack,
    required this.totalGoals,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: user?.photoUrl != null
                      ? ClipOval(child: Image.network(user!.photoUrl!, fit: BoxFit.cover))
                      : Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.onPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Profile',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSignedIn ? (user?.email ?? '') : 'Not signed in',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6), fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, size: 10, color: Theme.of(context).colorScheme.onPrimary),
                      const SizedBox(width: 4),
                      Text(
                        isSignedIn ? 'Premium' : 'Guest',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Savings',
                    value: '${savingsRate.toStringAsFixed(0)}%',
                    good: savingsRate >= 20,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _StatChip(
                    label: 'Budget',
                    value: '${budgetCompliance.toStringAsFixed(0)}%',
                    good: budgetCompliance >= 80,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _StatChip(
                    label: 'Goals',
                    value: '$goalsOnTrack/$totalGoals',
                    good: goalsOnTrack == totalGoals && totalGoals > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final bool good;
  const _StatChip({required this.label, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
              Icon(
                good ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }
}
