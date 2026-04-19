/// Card variants library
/// 
/// Provides reusable card components with consistent styling
/// 
/// Available card types:
/// - StandardCard: Basic card with Material Design elevation
/// - ElevatedCard: Card with custom shadow elevation
/// - GradientCard: Card with gradient background
/// - OutlinedCard: Card with border outline
/// - CompactCard: Card with minimal padding
/// - InfoCard: Card for status messages with icon
/// 
/// Usage example:
/// ```dart
/// StandardCard(
///   child: Text('Content'),
///   onTap: () => print('Tapped'),
/// )
/// 
/// GradientCard.emerald(
///   child: Text('Gradient content'),
/// )
/// 
/// InfoCard.success(context,
///   message: 'Operation successful',
/// )
/// ```
library;
export 'card_variants.dart';
