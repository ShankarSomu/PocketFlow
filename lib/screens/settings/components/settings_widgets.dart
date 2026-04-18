import 'package:flutter/material.dart';

class SettingsActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const SettingsActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class DropdownRow<T> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const DropdownRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox(),
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w600),
            icon: Icon(Icons.expand_more_rounded,
                size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle, trailingLabel;
  final VoidCallback onTap;
  
  const ActionRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(trailingLabel,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 17,
                color: value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
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
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
