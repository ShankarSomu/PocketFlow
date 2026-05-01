import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../services/merchant_normalization_service.dart';
import '../../services/recurring_pattern_engine.dart';
import '../../services/refresh_notifier.dart';
import '../../services/sms_correction_service.dart';
import '../../services/sms_service.dart';
import '../../services/transfer_detection_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/ui/screen_header.dart';
import '../../widgets/glass_card.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import 'merchant_insights_screen.dart';
import 'recurring_patterns_screen.dart';
import 'transfer_pairs_screen.dart';

class IntelligenceDashboardScreen extends StatefulWidget {
  const IntelligenceDashboardScreen({super.key});

  @override
  State<IntelligenceDashboardScreen> createState() =>
      _IntelligenceDashboardScreenState();
}

class _IntelligenceDashboardScreenState
    extends State<IntelligenceDashboardScreen> {
  bool _loading = true;
  String? _error;

  // Scan stats
  SmsImportResult? _lastScan;
  DateTime? _lastScanDate;

  // Transaction stats
  int _needsReviewCount = 0;
  int _totalSmsTransactions = 0;
  int _transferCount = 0;
  int _recurringCount = 0;

  // Learning stats
  int _learnedRules = 0;
  int _blockedPatterns = 0;
  int _positiveFeedback = 0;

  // Top merchants
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

      final db = await AppDatabase.db();

      // Last scan result
      final lastScan = await SmsService.getLastScanResult();
      final lastScanDate = await SmsService.getLastScan();

      // Needs review count
      final reviewResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM transactions WHERE needs_review = 1 AND deleted_at IS NULL",
      );
      final needsReviewCount = reviewResult.first['count'] as int? ?? 0;

      // Total SMS transactions
      final smsResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM transactions WHERE source_type = 'sms' AND deleted_at IS NULL",
      );
      final totalSms = smsResult.first['count'] as int? ?? 0;

      // Transfer pairs
      int transferCount = 0;
      try {
        final r = await db.rawQuery(
            'SELECT COUNT(*) as count FROM transfer_pairs WHERE status != ?',
            ['rejected']);
        transferCount = r.first['count'] as int? ?? 0;
      } catch (_) {}

      // Recurring patterns
      int recurringCount = 0;
      try {
        final r = await db.rawQuery(
            'SELECT COUNT(*) as count FROM recurring_patterns WHERE status != ?',
            ['rejected']);
        recurringCount = r.first['count'] as int? ?? 0;
      } catch (_) {}

      // Learning stats
      int learnedRules = 0;
      int blockedPatterns = 0;
      int positiveFeedback = 0;
      try {
        final stats = await SmsCorrectionService.getStatistics();
        learnedRules = (stats['total_rules'] as num?)?.toInt() ?? 0;
        final balance = stats['feedback_balance'] as Map<String, dynamic>? ?? {};
        blockedPatterns = (balance['negative_feedback'] as num?)?.toInt() ?? 0;
        positiveFeedback = (balance['positive_feedback'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      // Top merchants
      final merchantStats = await MerchantNormalizationService.getMerchantStatistics();
      final topMerchants = merchantStats.take(5).toList();

      if (!mounted) return;
      setState(() {
        _lastScan = lastScan;
        _lastScanDate = lastScanDate;
        _needsReviewCount = needsReviewCount;
        _totalSmsTransactions = totalSms;
        _transferCount = transferCount;
        _recurringCount = recurringCount;
        _learnedRules = learnedRules;
        _blockedPatterns = blockedPatterns;
        _positiveFeedback = positiveFeedback;
        _topMerchants = topMerchants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _showRulesDetail(String filter) async {
    final db = await AppDatabase.db();
    String title = 'All Learned Rules';

    if (filter == 'blocked') {
      // Show structural negative samples instead of old keyword rules
      final samples = await SmsCorrectionService.getNegativeSamples(limit: 50);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Blocked Patterns',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('${samples.length} samples',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.slate500)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: samples.isEmpty
                    ? const Center(child: Text('No blocked patterns yet'))
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(12),
                        itemCount: samples.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = samples[i];
                          final sender = s['sender'] as String? ?? '';
                          final pattern = s['pattern_type'] as String? ?? '';
                          final hasUrl = (s['has_url'] as int? ?? 0) == 1;
                          final hasNumber = (s['has_number'] as int? ?? 0) == 1;
                          final createdAt = s['created_at'] as int? ?? 0;
                          final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
                          final dateStr = DateFormat('MMM d, y').format(date);

                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.block,
                              color: Colors.red,
                              size: 20,
                            ),
                            title: Text(
                              sender.isNotEmpty ? sender : '(unknown sender)',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pattern: $pattern'
                                  '${hasNumber ? '  •  has numbers' : ''}'
                                  '${hasUrl ? '  •  has URL' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.slate500),
                                ),
                                Text(
                                  'Blocked on $dateStr',
                                  style: const TextStyle(
                                      fontSize: 10, color: AppTheme.slate500),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // For 'all' and 'positive' filters, use the existing rule engine table
    String whereClause = 'is_active = 1';
    if (filter == 'positive') {
      whereClause += " AND source IN ('user_positive_feedback', 'user_confirmation')";
      title = 'Confirmed Rules';
    }
    final rules = await db.query(
      'sms_classification_rules',
      where: whereClause,
      orderBy: 'created_at DESC',
      limit: 50,
    );

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${rules.length} rules',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.slate500)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rules.isEmpty
                  ? const Center(child: Text('No rules yet'))
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(12),
                      itemCount: rules.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final rule = rules[i];
                        final category = rule['category'] as String? ?? '?';
                        final source = rule['source'] as String? ?? '';
                        final keywords = rule['keywords'] as String? ?? '[]';
                        final correct = rule['correct_count'] as int? ?? 0;
                        final incorrect = rule['incorrect_count'] as int? ?? 0;
                        final isBlocked = category == 'NON_FINANCIAL';
                        final color = isBlocked ? Colors.red : Colors.green;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isBlocked ? Icons.block : Icons.check_circle_outline,
                            color: color,
                            size: 20,
                          ),
                          title: Text(
                            isBlocked ? 'BLOCKED' : category,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                keywords
                                    .replaceAll('[', '')
                                    .replaceAll(']', '')
                                    .replaceAll('"', ''),
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.slate500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Source: $source  •  ✓$correct  ✗$incorrect',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.slate500),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runDetection() async {
    try {
      final smsEnabled = await SmsService.isEnabled();
      if (!smsEnabled && mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable SMS Auto-Import?'),
            content: const Text(
                'SMS Intelligence requires SMS Auto-Import to be enabled.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings')),
            ],
          ),
        );
        if (enable == true && mounted) {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
        }
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Running detection...')));

      await TransferDetectionEngine.runDetection();
      await RecurringPatternEngine.runDetection();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Detection complete!'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detection failed: $e'), backgroundColor: Colors.red));
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
                ? ErrorStateWidget(message: _error, onRetry: _loadData)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(
                          child: ScreenHeader('SMS Intelligence',
                              icon: Icons.psychology_rounded),
                        ),

                        // ── Last Scan Results ──────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _ScanResultCard(
                              result: _lastScan,
                              scanDate: _lastScanDate,
                              onReviewTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TransactionsScreen(
                                      initialFilterNeedsReview: true),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── Transaction Stats ──────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _SectionLabel('Transactions'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatTile(
                                    label: 'SMS Imported',
                                    value: '$_totalSmsTransactions',
                                    icon: Icons.sms_outlined,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    label: 'Needs Review',
                                    value: '$_needsReviewCount',
                                    icon: Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    onTap: _needsReviewCount > 0
                                        ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TransactionsScreen(
                                                        initialFilterNeedsReview:
                                                            true),
                                              ),
                                            )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatTile(
                                    label: 'Transfers',
                                    value: '$_transferCount',
                                    icon: Icons.swap_horiz_rounded,
                                    color: Colors.purple,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const TransferPairsScreen())),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    label: 'Recurring',
                                    value: '$_recurringCount',
                                    icon: Icons.repeat_rounded,
                                    color: Colors.teal,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RecurringPatternsScreen())),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Learning Stats ─────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _SectionLabel('Learning'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatTile(
                                    label: 'Learned Rules',
                                    value: '$_learnedRules',
                                    icon: Icons.school_outlined,
                                    color: Colors.green,
                                    onTap: _learnedRules > 0 ? () => _showRulesDetail('all') : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    label: 'Blocked Patterns',
                                    value: '$_blockedPatterns',
                                    icon: Icons.block_rounded,
                                    color: Colors.red,
                                    onTap: _blockedPatterns > 0 ? () => _showRulesDetail('blocked') : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    label: 'Confirmed',
                                    value: '$_positiveFeedback',
                                    icon: Icons.thumb_up_outlined,
                                    color: Colors.blue,
                                    onTap: _positiveFeedback > 0 ? () => _showRulesDetail('positive') : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Top Merchants ──────────────────────────────────
                        if (_topMerchants.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _SectionLabel('Top Merchants'),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: _topMerchants
                                      .asMap()
                                      .entries
                                      .map((e) => _MerchantRow(
                                            rank: e.key + 1,
                                            merchant: e.value,
                                            fmt: fmt,
                                            isLast: e.key ==
                                                _topMerchants.length - 1,
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // ── Actions ────────────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _SectionLabel('Actions'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              children: [
                                _ActionTile(
                                  icon: Icons.store_rounded,
                                  label: 'Merchant Insights',
                                  subtitle: 'Spending patterns by merchant',
                                  color: Colors.orange,
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const MerchantInsightsScreen())),
                                ),
                                const SizedBox(height: 8),
                                _ActionTile(
                                  icon: Icons.auto_fix_high_rounded,
                                  label: 'Run Detection',
                                  subtitle:
                                      'Detect transfers and recurring patterns',
                                  color: Colors.indigo,
                                  onTap: _runDetection,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan Result Card
// ─────────────────────────────────────────────────────────────────────────────

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.result,
    required this.scanDate,
    required this.onReviewTap,
  });

  final SmsImportResult? result;
  final DateTime? scanDate;
  final VoidCallback onReviewTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (result == null) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            const Text('No scan results yet. Run a scan from Settings.',
                style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    final r = result!;
    final total = r.imported + r.skipped + r.failed + r.filteredByDate;
    final dateStr = scanDate != null
        ? DateFormat('MMM d, h:mm a').format(scanDate!)
        : 'Unknown';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Last Scan',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900)),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.slate500)),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (r.imported > 0)
                      Flexible(
                        flex: r.imported,
                        child: Container(color: Colors.green.shade400),
                      ),
                    if (r.nonFinancial > 0)
                      Flexible(
                        flex: r.nonFinancial,
                        child: Container(color: Colors.grey.shade300),
                      ),
                    if (r.alreadyProcessed > 0)
                      Flexible(
                        flex: r.alreadyProcessed,
                        child: Container(color: Colors.blue.shade100),
                      ),
                    if (r.blockedByRule > 0)
                      Flexible(
                        flex: r.blockedByRule,
                        child: Container(color: Colors.orange.shade300),
                      ),
                    if (r.parseFailed > 0)
                      Flexible(
                        flex: r.parseFailed,
                        child: Container(color: Colors.red.shade300),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Stats grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScanChip(
                  label: 'Imported',
                  count: r.imported,
                  color: Colors.green,
                  onTap: r.imported > 0 ? onReviewTap : null),
              _ScanChip(
                  label: 'Non-financial',
                  count: r.nonFinancial,
                  color: Colors.grey),
              _ScanChip(
                  label: 'Already processed',
                  count: r.alreadyProcessed,
                  color: Colors.blue),
              if (r.blockedByRule > 0)
                _ScanChip(
                    label: 'Blocked by rules',
                    count: r.blockedByRule,
                    color: Colors.orange),
              if (r.filteredByDate > 0)
                _ScanChip(
                    label: 'Out of range',
                    count: r.filteredByDate,
                    color: Colors.purple),
              if (r.parseFailed > 0)
                _ScanChip(
                    label: 'Parse failed',
                    count: r.parseFailed,
                    color: Colors.red),
              if (r.duplicates > 0)
                _ScanChip(
                    label: 'Duplicates fixed',
                    count: r.duplicates,
                    color: Colors.teal),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanChip extends StatelessWidget {
  const _ScanChip({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  final String label;
  final int count;
  final MaterialColor color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              '$count',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color.shade700),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.shade600),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: color.shade600),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
          letterSpacing: 0.5),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: color.shade600),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 10, color: color.shade400),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color.shade700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final MaterialColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate900)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.slate500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.rank,
    required this.merchant,
    required this.fmt,
    required this.isLast,
  });

  final int rank;
  final Map<String, dynamic> merchant;
  final NumberFormat fmt;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final name = merchant['merchant'] as String;
    final count = merchant['transaction_count'] as int;
    final total =
        (merchant['total_spent'] ?? merchant['total_amount'] ?? 0.0) as double;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$count txn${count != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.slate500)),
              ],
            ),
          ),
          Text(fmt.format(total),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900)),
        ],
      ),
    );
  }
}
