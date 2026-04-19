import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../models/transaction.dart';
import '../../models/transfer_pair.dart';
import '../../services/confidence_scoring.dart';
import '../../services/refresh_notifier.dart';
import '../../services/transfer_detection_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/ui/screen_header.dart';
import '../../widgets/glass_card.dart';

/// Transfer Pairs Screen
/// Shows detected transfer pairs (debit-credit) and allows confirmation/rejection
class TransferPairsScreen extends StatefulWidget {
  const TransferPairsScreen({super.key});

  @override
  State<TransferPairsScreen> createState() => _TransferPairsScreenState();
}

class _TransferPairsScreenState extends State<TransferPairsScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  
  List<TransferPair> _allPairs = [];
  List<TransferPair> _pendingPairs = [];
  List<TransferPair> _confirmedPairs = [];
  
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
      
      // Load all transfer pairs
      final pairMaps = await db.query(
        'transfer_pairs',
        where: 'status != ?',
        whereArgs: ['rejected'],
        orderBy: 'created_at DESC',
      );
      
      final pairs = pairMaps.map(TransferPair.fromMap).toList();
      
      final pending = pairs.where((p) => p.status == 'pending').toList();
      final confirmed = pairs.where((p) => p.status == 'confirmed').toList();

      if (!mounted) return;
      setState(() {
        _allPairs = pairs;
        _pendingPairs = pending;
        _confirmedPairs = confirmed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load transfer pairs: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmPair(TransferPair pair) async {
    try {
      await TransferDetectionEngine.confirmPair(pair.id!);
      await _loadData();
      notifyDataChanged();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer confirmed'),
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

  Future<void> _rejectPair(TransferPair pair) async {
    try {
      await TransferDetectionEngine.rejectPair(pair.id!);
      await _loadData();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer rejected')),
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

  Future<void> _showPairDetails(TransferPair pair) async {
    try {
      final details = await TransferDetectionEngine.getPairDetails(pair.id!);
      
      if (!mounted) return;
      
      if (details == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load transfer pair details'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _TransferPairDetailsSheet(
          pair: pair,
          debitTransaction: details['debit_transaction'] as Transaction,
          creditTransaction: details['credit_transaction'] as Transaction,
          onConfirm: () {
            Navigator.pop(context);
            _confirmPair(pair);
          },
          onReject: () {
            Navigator.pop(context);
            _rejectPair(pair);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runDetection() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Running transfer detection...')),
      );

      await TransferDetectionEngine.runDetection();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${_pendingPairs.length} new transfers'),
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
              'Transfer Pairs',
              icon: Icons.swap_horiz_rounded,
              subtitle: 'Automatically detected transfers',
            ),
            const SizedBox(height: 16),
            
            // Summary Card
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SummaryCard(
                  pendingCount: _pendingPairs.length,
                  confirmedCount: _confirmedPairs.length,
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
                          if (_pendingPairs.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_pendingPairs.length}',
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
                          if (_confirmedPairs.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_confirmedPairs.length}',
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
                            _pendingPairs.isEmpty
                                ? const IllustratedEmptyState(
                                    icon: Icons.swap_horiz_rounded,
                                    title: 'No pending transfers',
                                    subtitle: 'Run detection to find new transfer pairs',
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _pendingPairs.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final pair = _pendingPairs[index];
                                        return _TransferPairCard(
                                          pair: pair,
                                          onTap: () => _showPairDetails(pair),
                                          onConfirm: () => _confirmPair(pair),
                                          onReject: () => _rejectPair(pair),
                                          showActions: true,
                                        );
                                      },
                                    ),
                                  ),
                            
                            // Confirmed Tab
                            _confirmedPairs.isEmpty
                                ? const IllustratedEmptyState(
                                    icon: Icons.check_circle_outline,
                                    title: 'No confirmed transfers',
                                    subtitle: 'Confirmed transfers will appear here',
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _confirmedPairs.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final pair = _confirmedPairs[index];
                                        return _TransferPairCard(
                                          pair: pair,
                                          onTap: () => _showPairDetails(pair),
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
    required this.onRunDetection,
  });
  final int pendingCount;
  final int confirmedCount;
  final VoidCallback onRunDetection;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detection Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(height: 8),
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
              ],
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
// Transfer Pair Card
// -----------------------------------------------------------------------------

class _TransferPairCard extends StatelessWidget {

  const _TransferPairCard({
    required this.pair,
    required this.onTap,
    this.onConfirm,
    this.onReject,
    this.showActions = false,
  });
  final TransferPair pair;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final confidenceColor = ConfidenceScoring.getConfidenceColor(pair.confidenceScore);
    final confidenceLevel = ConfidenceScoring.getConfidenceLevel(pair.confidenceScore);

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fmt.format(pair.amount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: confidenceColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ConfidenceScoring.getConfidenceIcon(pair.confidenceScore),
                        size: 12,
                        color: confidenceColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$confidenceLevel ${ConfidenceScoring.formatConfidence(pair.confidenceScore)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: confidenceColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Detection Method & Status
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppTheme.slate500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Method: ${pair.detectionMethod}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate600,
                    ),
                  ),
                ],
              ),
            ),
            
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
                      label: const Text('Reject'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                    ),
                  if (onConfirm != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Transfer Pair Details Sheet
// -----------------------------------------------------------------------------

class _TransferPairDetailsSheet extends StatelessWidget {

  const _TransferPairDetailsSheet({
    required this.pair,
    required this.debitTransaction,
    required this.creditTransaction,
    required this.onConfirm,
    required this.onReject,
  });
  final TransferPair pair;
  final Transaction debitTransaction;
  final Transaction creditTransaction;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.slate100,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Debit Transaction
          _TransactionDetail(
            title: 'Debit (From)',
            transaction: debitTransaction,
            fmt: fmt,
            dateFmt: dateFmt,
            icon: Icons.arrow_upward_rounded,
            color: Colors.red,
          ),
          
          const SizedBox(height: 16),
          
          // Transfer Icon
          Center(
            child: Icon(
              Icons.swap_vert_rounded,
              color: Colors.blue.shade600,
              size: 32,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Credit Transaction
          _TransactionDetail(
            title: 'Credit (To)',
            transaction: creditTransaction,
            fmt: fmt,
            dateFmt: dateFmt,
            icon: Icons.arrow_downward_rounded,
            color: Colors.green,
          ),
          
          const SizedBox(height: 20),
          
          // Match Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      ConfidenceScoring.getConfidenceIcon(pair.confidenceScore),
                      size: 18,
                      color: ConfidenceScoring.getConfidenceColor(pair.confidenceScore),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confidence: ${ConfidenceScoring.formatConfidence(pair.confidenceScore)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ConfidenceScoring.getConfidenceColor(pair.confidenceScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Detected by: ${pair.detectionMethod}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Actions
          if (pair.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Not a Transfer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirm Transfer'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TransactionDetail extends StatelessWidget {

  const _TransactionDetail({
    required this.title,
    required this.transaction,
    required this.fmt,
    required this.dateFmt,
    required this.icon,
    required this.color,
  });
  final String title;
  final Transaction transaction;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fmt.format(transaction.amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          if (transaction.note != null && transaction.note!.isNotEmpty)
            Text(
              transaction.note!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slate700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            dateFmt.format(transaction.date),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

