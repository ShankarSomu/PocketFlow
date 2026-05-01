import 'package:flutter/material.dart';

/// Confidence Badge Widget
/// Displays confidence score with color-coded visual indicator
/// 
/// Usage:
/// ```dart
/// ConfidenceBadge(score: 0.85)  // Shows: ✓ 85% (green)
/// ConfidenceBadge(score: 0.65)  // Shows: ⚠ 65% (yellow)
/// ConfidenceBadge(score: 0.45)  // Shows: ⚠ 45% (red)
/// ```
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({
    required this.score,
    this.size = BadgeSize.small,
    super.key,
  });

  final double score;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();
    final color = _getColor();
    final icon = _getIcon();
    final fontSize = size == BadgeSize.small ? 10.0 : 12.0;
    final iconSize = size == BadgeSize.small ? 10.0 : 14.0;
    final padding = size == BadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 3),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    if (score >= 0.8) {
      return Colors.green;
    } else if (score >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getIcon() {
    if (score >= 0.8) {
      return Icons.check_circle;
    } else if (score >= 0.5) {
      return Icons.warning_amber;
    } else {
      return Icons.error;
    }
  }
}

/// Badge size options
enum BadgeSize {
  small,
  medium,
}

/// Source Badge Widget
/// Displays transaction source type with icon
/// 
/// Usage:
/// ```dart
/// SourceBadge(sourceType: 'sms', needsReview: true)
/// SourceBadge(sourceType: 'manual')
/// ```
class SourceBadge extends StatelessWidget {
  const SourceBadge({
    required this.sourceType,
    this.needsReview = false,
    super.key,
  });

  final String sourceType;
  final bool needsReview;

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final label = _getLabel();
    final color = needsReview
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (needsReview) ...[
            const SizedBox(width: 4),
            Icon(Icons.warning_amber, size: 10, color: color),
          ],
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (sourceType.toLowerCase()) {
      case 'sms':
        return Icons.sms_outlined;
      case 'manual':
        return Icons.edit_outlined;
      case 'recurring':
        return Icons.repeat;
      case 'import':
        return Icons.file_upload_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getLabel() {
    switch (sourceType.toLowerCase()) {
      case 'sms':
        return needsReview ? 'SMS (Review)' : 'SMS';
      case 'manual':
        return 'Manual';
      case 'recurring':
        return 'Recurring';
      case 'import':
        return 'Imported';
      default:
        return sourceType;
    }
  }
}

/// Region Badge Widget
/// Displays region with flag emoji
class RegionBadge extends StatelessWidget {
  const RegionBadge({
    required this.region,
    super.key,
  });

  final String region;

  @override
  Widget build(BuildContext context) {
    final emoji = _getEmoji();
    if (emoji == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String? _getEmoji() {
    switch (region.toUpperCase()) {
      case 'INDIA':
        return '🇮🇳';
      case 'US':
      case 'USA':
        return '🇺🇸';
      case 'UK':
        return '🇬🇧';
      case 'EU':
        return '🇪🇺';
      default:
        return null;
    }
  }
}
