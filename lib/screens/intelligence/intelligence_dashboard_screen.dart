import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../services/merchant_normalization_service.dart';
import '../../services/pending_action_service.dart';
import '../../services/recurring_pattern_engine.dart';
import '../../services/refresh_notifier.dart';
import '../../services/transfer_detection_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/ui/screen_header.dart';
import '../../widgets/glass_card.dart';
import '../pending_actions_screen.dart';
import 'merchant_insights_screen.dart';
import 'recurring_patterns_screen.dart';
import 'transfer_pairs_screen.dart';

/// Intelligence Dashboard Screen
/// Main entry point for all SMS Intelligence features
class IntelligenceDashboardScreen extends StatefulWidget {
  const IntelligenceDashboardScreen({super.key});

  @override
  State<IntelligenceDashboardScreen> createState() => _IntelligenceDashboardScreenState();
}

class _IntelligenceDashboardScreenState extends State<IntelligenceDashboardScreen> {
  bool _loading = true;
  String? _error;
  
  // Statistics
  Map<String, dynamic> _pendingStats = {};
  int _transferCount = 0;
  int _recurringCount = 0;
  int _highConfidenceCount = 0;
  int _pendingReviewCount = 0;
  List<Map<String, dynamic>> _topMerchants = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
    appRefresh.addListener(_loadData);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Get pending actions statistics
      final pendingStats = await PendingActionService.getStatistics();
      
      // Count transfer pairs
      final db = await AppDatabase.db();
      final transferResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM transfer_pairs WHERE status != ?',
        ['rejected'],
      );
      final transferCount = transferResult.first['count'] as int? ?? 0;
      
      // Count recurring patterns
      final recurringResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM recurring_patterns WHERE status != ?',
        ['rejected'],
      );
      final recurringCount = recurringResult.first['count'] as int? ?? 0;
      
      // Count high confidence items (across all intelligence features)
      final highConfResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM (
          SELECT id FROM pending_actions WHERE confidence >= 0.85 AND status = 'pending'
          UNION ALL
          SELECT id FROM transfer_pairs WHERE confidence_score >= 0.85 AND status = 'pending'
          UNION ALL
          SELECT id FROM recurring_patterns WHERE confidence_score >= 0.80 AND status = 'pending'
        )
      ''');
      final highConfCount = highConfResult.first['count'] as int? ?? 0;
      
      // Count items pending review
      final pendingReviewResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM (
          SELECT id FROM pending_actions WHERE status = 'pending'
          UNION ALL
          SELECT id FROM transfer_pairs WHERE status = 'pending'
          UNION ALL
          SELECT id FROM recurring_patterns WHERE status = 'pending'
        )
      ''');
      final pendingReviewCount = pendingReviewResult.first['count'] as int? ?? 0;
      
      // Get top merchants by transaction count
      final merchantStats = await MerchantNormalizationService.getMerchantStatistics();
      final topMerchants = merchantStats.take(5).toList();

      if (!mounted) return;
      setState(() {
        _pendingStats = pendingStats;
        _transferCount = transferCount;
        _recurringCount = recurringCount;
        _highConfidenceCount = highConfCount;
        _pendingReviewCount = pendingReviewCount;
        _topMerchants = topMerchants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load intelligence data: $e';
        _loading = false;
      });
    }
  }

  void _navigateToPendingActions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PendingActionsScreen()),
    );
  }

  void _navigateToTransferPairs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransferPairsScreen()),
    );
  }

  void _navigateToRecurringPatterns() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecurringPatternsScreen()),
    );
  }

  void _navigateToMerchantInsights() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MerchantInsightsScreen()),
    );
  }

  Future<void> _runDetection() async {
    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Running intelligence detection...')),
      );

      // Run transfer detection
      await TransferDetectionEngine.runDetection();
      
      // Run recurring pattern detection
      await RecurringPatternEngine.runDetection();

      // Reload data
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detection complete!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorStateWidget(
                    message: _error,
                    onRetry: _loadData,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        // Header
                        const SliverToBoxAdapter(
                          child: Column(
                            children: [
                              ScreenHeader(
                                'SMS Intelligence',
                                icon: Icons.psychology_rounded,
                              ),
                              SizedBox(height: 12),
                            ],
                          ),
                        ),
                        
                        // Quick Stats
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: _QuickStatsGrid(
                              pendingReviewCount: _pendingReviewCount,
                              highConfidenceCount: _highConfidenceCount,
                              transferCount: _transferCount,
                              recurringCount: _recurringCount,
                            ),
                          ),
                        ),
                        
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        
                        // Pending Actions
                        if (_pendingStats['total_pending'] != null && _pendingStats['total_pending'] > 0)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _PendingActionsSummary(
                                stats: _pendingStats,
                                onTap: _navigateToPendingActions,
                              ),
                            ),
                          ),
                        
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        
                        // Feature Cards Grid
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Intelligence Features',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.slate900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FeatureCard(
                                  title: 'Transfer Detection',
                                  description: 'Automatically link debit-credit pairs',
                                  icon: Icons.swap_horiz_rounded,
                                  count: _transferCount,
                                  color: Colors.blue,
                                  onTap: _navigateToTransferPairs,
                                ),
                                const SizedBox(height: 12),
                                _FeatureCard(
                                  title: 'Recurring Patterns',
                                  description: 'Subscriptions, EMIs, and regular bills',
                                  icon: Icons.repeat_rounded,
                                  count: _recurringCount,
                                  color: Colors.purple,
                                  onTap: _navigateToRecurringPatterns,
                                ),
                                const SizedBox(height: 12),
                                _FeatureCard(
                                  title: 'Merchant Insights',
                                  description: 'Spending patterns by merchant',
                                  icon: Icons.store_rounded,
                                  count: _topMerchants.length,
                                  color: Colors.orange,
                                  onTap: _navigateToMerchantInsights,
                                ),
                                const SizedBox(height: 12),
                                _FeatureCard(
                                  title: 'Pending Review',
                                  description: 'Actions requiring your confirmation',
                                  icon: Icons.pending_actions_rounded,
                                  count: _pendingStats['total_pending'] ?? 0,
                                  color: Colors.red,
                                  onTap: _navigateToPendingActions,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        
                        // Top Merchants
                        if (_topMerchants.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _TopMerchantsCard(
                                merchants: _topMerchants,
                                fmt: fmt,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                        
                        // Run Detection Button
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ElevatedButton.icon(
                              onPressed: _runDetection,
                              icon: const Icon(Icons.auto_fix_high_rounded),
                              label: const Text('Run Detection'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                          ),
                        ),
                        
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Quick Stats Grid
// -----------------------------------------------------------------------------

class _QuickStatsGrid extends StatelessWidget {

  const _QuickStatsGrid({
    required this.pendingReviewCount,
    required this.highConfidenceCount,
    required this.transferCount,
    required this.recurringCount,
  });
  final int pendingReviewCount;
  final int highConfidenceCount;
  final int transferCount;
  final int recurringCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            label: 'Pending Review',
            value: pendingReviewCount.toString(),
            icon: Icons.pending_outlined,
            gradient: const LinearGradient(
              colors: [
                Colors.redAccent,
                Colors.red,
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
            label: 'High Confidence',
            value: highConfidenceCount.toString(),
            icon: Icons.check_circle_outline,
            gradient: const LinearGradient(
              colors: [
                Colors.lightGreen,
                Colors.green,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {

  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pending Actions Summary
// -----------------------------------------------------------------------------

class _PendingActionsSummary extends StatelessWidget {

  const _PendingActionsSummary({
    required this.stats,
    required this.onTap,
  });
  final Map<String, dynamic> stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalPending = stats['total_pending'] ?? 0;
    final priorityCounts = stats['by_priority'] as Map<String, int>? ?? {};
    final highPriority = priorityCounts['high'] ?? 0;
    final mediumPriority = priorityCounts['medium'] ?? 0;
    final lowPriority = priorityCounts['low'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalPending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                        color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (highPriority > 0) ...[
                  _PriorityChip(
                    label: 'High',
                    count: highPriority,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                ],
                if (mediumPriority > 0) ...[
                  _PriorityChip(
                    label: 'Medium',
                    count: mediumPriority,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                ],
                if (lowPriority > 0)
                  _PriorityChip(
                    label: 'Low',
                    count: lowPriority,
                    color: Colors.blue,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {

  const _PriorityChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
                  color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                    color: color.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Feature Card
// -----------------------------------------------------------------------------

class _FeatureCard extends StatelessWidget {

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final int count;
  final MaterialColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color.shade700, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.shade200),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.slate400,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Top Merchants Card
// -----------------------------------------------------------------------------

class _TopMerchantsCard extends StatelessWidget {

  const _TopMerchantsCard({
    required this.merchants,
    required this.fmt,
  });
  final List<Map<String, dynamic>> merchants;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Merchants',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
              Icon(Icons.store_outlined, color: AppTheme.slate500, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          ...merchants.asMap().entries.map((entry) {
            final index = entry.key;
            final merchant = entry.value;
            final merchantName = merchant['merchant'] as String;
            final transactionCount = merchant['transaction_count'] as int;
            final totalSpent = merchant['total_spent'] as double;

            return Padding(
              padding: EdgeInsets.only(bottom: index < merchants.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchantName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$transactionCount transaction${transactionCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    fmt.format(totalSpent),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
