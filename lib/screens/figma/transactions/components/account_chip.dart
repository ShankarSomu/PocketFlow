import 'package:flutter/material.dart';
import '../../../../services/theme_service.dart';

class AccountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool light;

  const AccountChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (light
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.primary)
              : (light
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.18)
                  : Theme.of(context).colorScheme.surface),
          borderRadius: BorderRadius.circular(20),
          boxShadow: light ? null : ThemeService.instance.primaryShadow,
          border: light
              ? null
              : (selected
                  ? null
                  : Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? (light
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onPrimary)
                : (light
                    ? Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.7)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7)),
          ),
        ),
      ),
    );
  }
}
