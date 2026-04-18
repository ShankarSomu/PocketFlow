import 'package:flutter/material.dart';

class ProfileSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
