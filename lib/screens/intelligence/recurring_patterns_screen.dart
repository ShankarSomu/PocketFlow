import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../models/recurring_pattern.dart';
import '../../services/confidence_scoring.dart';
import '../../services/recurring_pattern_engine.dart';
import '../../services/refresh_notifier.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/ui/screen_header.dart';
import '../../widgets/glass_card.dart';

/// Recurring Patterns Screen
/// Shows detected recurring patterns (subscriptions, EMIs, salaries, bills)
class RecurringPatternsScreen extends StatefulWidget {
  const RecurringPatternsScreen({super.key});

  @override
  State<RecurringPatternsScreen> createState() => _RecurringPatternsScreenState();
}

class _RecurringPatternsScreenState extends State<RecurringPatternsScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  
  List<RecurringPattern> _allPatterns = [];
  List<RecurringPattern> _pendingPatterns = [];
  List<RecurringPattern> _confirmedPatterns = [];
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    appRefresh.addListener(_loadData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    appRefresh.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final db = await AppDatabase.db();
      
      // Load all recurring patterns
      final patternMaps = await db.query(
        'recurring_patterns',
        where: 'status != ?',
        whereArgs: ['rejected'],
        orderBy: 'created_at DESC',
      );
      
      final patterns = patternMaps.map(RecurringPattern.fromMap).toList();
      
      final pending = patterns.where((p) => p.status == 'pending').toList();
      final confirmed = patterns.where((p) => p.status == 'confirmed').toList();

      if (!mounted) return;
      setState(() {
        _allPatterns = patterns;
        _pendingPatterns = pending;
        _confirmedPatterns = confirmed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load recurring patterns: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmPattern(RecurringPattern pattern) async {
    try {
      await RecurringPatternEngine.confirmPattern(pattern.id!);
      await _loadData();
      notifyDataChanged();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pattern confirmed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPattern(RecurringPattern pattern) async {
    try {
      await RecurringPatternEngine.rejectPattern(pattern.id!);
      await _loadData();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pattern rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runDetection() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Running pattern detection...')),
      );

      await RecurringPatternEngine.runDetection();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${_pendingPatterns.length} new patterns'),
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              'Recurring Patterns',
              icon: Icons.repeat_rounded,
              subtitle: 'Subscriptions, EMIs & recurring bills',
            ),
            const SizedBox(height: 16),
            
            // Summary Card
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SummaryCard(
                  pendingCount: _pendingPatterns.length,
                  confirmedCount: _confirmedPatterns.length,
                  totalMonthly: _confirmedPatterns
                      .where((p) => p.type == 'subscription' || p.type == 'emi')
                      .fold(0.0, (sum, p) => sum + p.averageAmount),
                  onRunDetection: _runDetection,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.slate600,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Pending'),
                          if (_pendingPatterns.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_pendingPatterns.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Confirmed'),
                          if (_confirmedPatterns.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_confirmedPatterns.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tab Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ErrorStateWidget(
                          message: _error,
                          onRetry: _loadData,
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Pending Tab
                            _pendingPatterns.isEmpty
                                ? const IllustratedEmptyState(
                                    icon: Icons.repeat_rounded,
                                    title: 'No pending patterns',
                                    subtitle: 'Run detection to find recurring transactions',
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _pendingPatterns.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final pattern = _pendingPatterns[index];
                                        return _RecurringPatternCard(
                                          pattern: pattern,
                                          onConfirm: () => _confirmPattern(pattern),
                                          onReject: () => _rejectPattern(pattern),
                                          showActions: true,
                                        );
                                      },
                                    ),
                                  ),
                            
                            // Confirmed Tab
                            _confirmedPatterns.isEmpty
                                ? const IllustratedEmptyState(
                                    icon: Icons.check_circle_outline,
                                    title: 'No confirmed patterns',
                                    subtitle: 'Confirmed patterns will appear here',
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _confirmedPatterns.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final pattern = _confirmedPatterns[index];
                                        return _RecurringPatternCard(
                                          pattern: pattern,
                                        );
                                      },
                                    ),
                                  ),
                          ],
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
    required this.pendingCount,
    required this.confirmedCount,
    required this.totalMonthly,
    required this.onRunDetection,
  });
  final int pendingCount;
  final int confirmedCount;
  final double totalMonthly;
  final VoidCallback onRunDetection;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detection Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900,
                ),
              ),
              IconButton(
                onPressed: onRunDetection,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip(
                label: 'Pending',
                count: pendingCount,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Confirmed',
                count: confirmedCount,
                color: Colors.green,
              ),
            ],
          ),
          if (totalMonthly > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Recurring',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate600,
                  ),
                ),
                Text(
                  fmt.format(totalMonthly),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
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

class _SummaryChip extends StatelessWidget {

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Recurring Pattern Card
// -----------------------------------------------------------------------------

class _RecurringPatternCard extends StatelessWidget {

  const _RecurringPatternCard({
    required this.pattern,
    this.onConfirm,
    this.onReject,
    this.showActions = false,
  });
  final RecurringPattern pattern;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final bool showActions;

  IconData _getPatternIcon(String patternType) {
    switch (patternType) {
      case 'subscription':
        return Icons.subscriptions_rounded;
      case 'emi':
        return Icons.credit_card_rounded;
      case 'salary':
        return Icons.attach_money_rounded;
      case 'bill':
        return Icons.receipt_long_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }

  Color _getPatternColor(String patternType) {
    switch (patternType) {
      case 'subscription':
        return Colors.purple;
      case 'emi':
        return Colors.orange;
      case 'salary':
        return Colors.green;
      case 'bill':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getFrequencyText(int intervalDays) {
    if (intervalDays <= 7) return 'Weekly';
    if (intervalDays <= 15) return 'Bi-weekly';
    if (intervalDays <= 35) return 'Monthly';
    if (intervalDays <= 95) return 'Quarterly';
    return 'Yearly';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final dateFmt = DateFormat('MMM d, yyyy');
    final confidenceColor = ConfidenceScoring.getConfidenceColor(pattern.confidenceScore);
    final confidenceLevel = ConfidenceScoring.getConfidenceLevel(pattern.confidenceScore);
    final patternColor = _getPatternColor(pattern.type);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: patternColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getPatternIcon(pattern.type),
                  color: patternColor.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pattern.merchant ?? pattern.category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: patternColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pattern.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: patternColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getFrequencyText(pattern.intervalDays),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: confidenceColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  ConfidenceScoring.formatConfidence(pattern.confidenceScore),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: confidenceColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Amount & Occurrences
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Average Amount',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.slate500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(pattern.averageAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Occurrences',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.slate500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pattern.occurrenceCount} times',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Next Expected Date
          if (pattern.nextExpectedDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppTheme.slate600,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Next expected:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateFmt.format(pattern.nextExpectedDate!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Actions
          if (showActions && (onConfirm != null || onReject != null)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null)
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Not Recurring'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                if (onConfirm != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

