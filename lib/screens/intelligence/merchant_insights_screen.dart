import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/merchant_normalization_service.dart';
import '../../services/refresh_notifier.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/ui/screen_header.dart';
import '../../widgets/glass_card.dart';

/// Merchant Insights Screen
/// Shows spending patterns and statistics by merchant
class MerchantInsightsScreen extends StatefulWidget {
  const MerchantInsightsScreen({super.key});

  @override
  State<MerchantInsightsScreen> createState() => _MerchantInsightsScreenState();
}

class _MerchantInsightsScreenState extends State<MerchantInsightsScreen> {
  bool _loading = true;
  String? _error;
  
  List<Map<String, dynamic>> _merchants = [];
  double _totalSpent = 0;
  int _totalTransactions = 0;

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

      // Get merchant statistics
      final merchantStats = await MerchantNormalizationService.getMerchantStatistics();
      
      final totalSpent = merchantStats.fold(0.0, (sum, m) => sum + (m['total_spent'] as double));
      final totalTransactions = merchantStats.fold(0, (sum, m) => sum + (m['transaction_count'] as int));

      if (!mounted) return;
      setState(() {
        _merchants = merchantStats;
        _totalSpent = totalSpent;
        _totalTransactions = totalTransactions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load merchant insights: $e';
        _loading = false;
      });
    }
  }

  Future<void> _normalizeAll() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Normalizing all merchants...')),
      );

      await MerchantNormalizationService.normalizeAllTransactions();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merchant normalization complete!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Normalization failed: $e'),
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
        child: Column(
          children: [
            const ScreenHeader(
              'Merchant Insights',
              icon: Icons.store_rounded,
              subtitle: 'Spending patterns by merchant',
            ),
            const SizedBox(height: 16),
            
            // Summary Card
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SummaryCard(
                  totalSpent: _totalSpent,
                  totalTransactions: _totalTransactions,
                  merchantCount: _merchants.length,
                  fmt: fmt,
                  onNormalize: _normalizeAll,
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Merchant List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ErrorStateWidget(
                          message: _error,
                          onRetry: _loadData,
                        )
                      : _merchants.isEmpty
                          ? const IllustratedEmptyState(
                              icon: Icons.store_outlined,
                              title: 'No merchants found',
                              subtitle: 'Transactions will be grouped by merchant',
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _merchants.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final merchant = _merchants[index];
                                  final merchantName = merchant['merchant'] as String;
                                  final transactionCount = merchant['transaction_count'] as int;
                                  final totalSpent = merchant['total_spent'] as double;
                                  final avgAmount = merchant['average_amount'] as double;
                                  final lastDate = merchant['last_transaction_date'] != null
                                      ? DateTime.parse(merchant['last_transaction_date'] as String)
                                      : null;
                                  
                                  // Calculate spending percentage
                                  final spendingPercentage = _totalSpent > 0
                                      ? (totalSpent / _totalSpent * 100)
                                      : 0.0;

                                  return _MerchantCard(
                                    merchant: merchantName,
                                    transactionCount: transactionCount,
                                    totalSpent: totalSpent,
                                    averageAmount: avgAmount,
                                    lastDate: lastDate,
                                    spendingPercentage: spendingPercentage,
                                    rank: index + 1,
                                    fmt: fmt,
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Summary Card
// -----------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {

  const _SummaryCard({
    required this.totalSpent,
    required this.totalTransactions,
    required this.merchantCount,
    required this.fmt,
    required this.onNormalize,
  });
  final double totalSpent;
  final int totalTransactions;
  final int merchantCount;
  final NumberFormat fmt;
  final VoidCallback onNormalize;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Spending',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
              IconButton(
                onPressed: onNormalize,
                icon: const Icon(Icons.auto_fix_high_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Normalize All',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Total Spent',
                  value: fmt.format(totalSpent),
                  icon: Icons.payments_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMetric(
                  label: 'Transactions',
                  value: '$totalTransactions',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryMetric(
            label: 'Unique Merchants',
            value: '$merchantCount',
            icon: Icons.store_rounded,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.9), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Merchant Card
// -----------------------------------------------------------------------------

class _MerchantCard extends StatelessWidget {

  const _MerchantCard({
    required this.merchant,
    required this.transactionCount,
    required this.totalSpent,
    required this.averageAmount,
    required this.lastDate,
    required this.spendingPercentage,
    required this.rank,
    required this.fmt,
  });
  final String merchant;
  final int transactionCount;
  final double totalSpent;
  final double averageAmount;
  final DateTime? lastDate;
  final double spendingPercentage;
  final int rank;
  final NumberFormat fmt;

  IconData _getMerchantIcon(String merchant) {
    final lowerMerchant = merchant.toLowerCase();
    
    // E-commerce
    if (lowerMerchant.contains('amazon')) return Icons.shopping_bag_rounded;
    if (lowerMerchant.contains('flipkart')) return Icons.shopping_cart_rounded;
    if (lowerMerchant.contains('walmart')) return Icons.store_rounded;
    if (lowerMerchant.contains('target')) return Icons.store_rounded;
    
    // Food & Dining
    if (lowerMerchant.contains('starbucks')) return Icons.coffee_rounded;
    if (lowerMerchant.contains('mcdonald')) return Icons.fastfood_rounded;
    if (lowerMerchant.contains('swiggy')) return Icons.restaurant_rounded;
    if (lowerMerchant.contains('zomato')) return Icons.restaurant_rounded;
    if (lowerMerchant.contains('uber eats')) return Icons.delivery_dining_rounded;
    
    // Transport
    if (lowerMerchant.contains('uber')) return Icons.local_taxi_rounded;
    if (lowerMerchant.contains('lyft')) return Icons.local_taxi_rounded;
    if (lowerMerchant.contains('ola')) return Icons.local_taxi_rounded;
    
    // Entertainment
    if (lowerMerchant.contains('netflix')) return Icons.movie_rounded;
    if (lowerMerchant.contains('spotify')) return Icons.music_note_rounded;
    if (lowerMerchant.contains('apple music')) return Icons.music_note_rounded;
    if (lowerMerchant.contains('prime video')) return Icons.video_library_rounded;
    
    // Utilities
    if (lowerMerchant.contains('electric')) return Icons.bolt_rounded;
    if (lowerMerchant.contains('gas')) return Icons.local_gas_station_rounded;
    if (lowerMerchant.contains('water')) return Icons.water_drop_rounded;
    
    // Default
    return Icons.storefront_rounded;
  }

  Color _getMerchantColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey;
    if (rank == 3) return Colors.brown;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final rankColor = _getMerchantColor(rank);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Rank Badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rankColor.withOpacity(0.4),
                      rankColor.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Merchant Icon & Name
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getMerchantIcon(merchant),
                        color: Colors.deepOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        merchant,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Total',
                  value: fmt.format(totalSpent),
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Average',
                  value: fmt.format(averageAmount),
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Count',
                  value: '$transactionCount',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Spending Percentage Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Share of spending',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.slate500,
                    ),
                  ),
                  Text(
                    '${spendingPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: spendingPercentage / 100,
                  minHeight: 6,
                  backgroundColor: AppTheme.slate200,
                  valueColor: AlwaysStoppedAnimation(Colors.orange.shade600),
                ),
              ),
            ],
          ),
          
          // Last Transaction Date
          if (lastDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: AppTheme.slate500,
                ),
                const SizedBox(width: 6),
                Text(
                  'Last: ${dateFmt.format(lastDate!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {

  const _StatItem({
    required this.label,
    required this.value,
  });
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.slate500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate900,
          ),
        ),
      ],
    );
  }
}

