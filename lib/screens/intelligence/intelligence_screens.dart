/// Intelligence Screens
/// 
/// Barrel file for all SMS Intelligence UI components
/// 
/// Available screens:
/// - IntelligenceDashboardScreen: Main entry point with overview & quick stats
/// - TransferPairsScreen: Review and confirm detected transfers
/// - RecurringPatternsScreen: Manage detected recurring patterns
/// - MerchantInsightsScreen: View spending patterns by merchant
/// 
/// Usage:
/// ```dart
/// import 'package:pocket_flow/screens/intelligence/intelligence_screens.dart';
/// 
/// // Navigate to dashboard
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => const IntelligenceDashboardScreen()),
/// );
/// ```
library;

export 'intelligence_dashboard_screen.dart';
export 'merchant_insights_screen.dart';
export 'recurring_patterns_screen.dart';
export 'transfer_pairs_screen.dart';
