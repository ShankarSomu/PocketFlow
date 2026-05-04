import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../services/merchant_normalization_service.dart';
import '../../services/recurring_pattern_engine.dart';
import '../../services/refresh_notifier.dart';
import 'package:pocket_flow/sms_engine/rules/sms_correction_service.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_service.dart';
import '../../services/transfer_detection_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/ui/screen_header.dart';
import '../../widgets/glass_card.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import 'components/sms_intelligence_ui_components.dart';
import 'components/sms_scan_result_card.dart';
import 'merchant_insights_screen.dart';
import 'recurring_patterns_screen.dart';
import 'transfer_pairs_screen.dart';

class SmsIntelligenceDashboardScreen extends StatefulWidget {
  const SmsIntelligenceDashboardScreen({super.key});

  @override
  State<SmsIntelligenceDashboardScreen> createState() =>
    _SmsIntelligenceDashboardScreenState();
}

class _SmsIntelligenceDashboardScreenState
  extends State<SmsIntelligenceDashboardScreen> {
  bool _loading = true;
  String? _error;

  // Scan stats
  SmsImportResult? _lastScan;
  DateTime? _lastScanDate;
  Map<String, dynamic> _lastScanBreakdown = {};

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
      final lastScanBreakdown = await SmsService.getLastScanBreakdown();

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
        _lastScanBreakdown = lastScanBreakdown;
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

  Future<void> _showScanBucketDetail({
    required String bucketKey,
    required String title,
    required int count,
    required Color color,
    required String emptyHint,
  }) async {
    final raw = _lastScanBreakdown[bucketKey] as List<dynamic>? ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.circle, color: color, size: 10),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$count in last scan',
                    style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          emptyHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.slate500),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final sender = item['sender'] as String? ?? 'UNKNOWN';
                        final preview = item['preview'] as String? ?? '<no text>';
                        final detail = item['detail'] as String?;
                        final isoDate = item['date'] as String?;
                        DateTime? parsed;
                        if (isoDate != null) {
                          parsed = DateTime.tryParse(isoDate);
                        }
                        final dateStr = parsed != null
                            ? DateFormat('MMM d, h:mm a').format(parsed)
                            : 'Unknown date';

                        return ListTile(
                          dense: true,
                          title: Text(
                            sender,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.slate900),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preview,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.slate700),
                              ),
                              if (detail != null && detail.isNotEmpty)
                                Text(
                                  detail,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.slate500),
                                ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.slate500),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (bucketKey == 'imported')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tip: Use Filters > Source > SMS to view imported SMS transactions'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Open Transactions'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
                            child: SmsScanResultCard(
                              result: _lastScan,
                              scanDate: _lastScanDate,
                              onReviewTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TransactionsScreen(
                                      initialFilterNeedsReview: true),
                                ),
                              ),
                              onImportedTap: () => _showScanBucketDetail(
                                bucketKey: 'imported',
                                title: 'Imported Transactions',
                                count: _lastScan?.imported ?? 0,
                                color: Colors.green,
                                emptyHint:
                                    'No import detail captured for this scan yet. Run a new scan and check again.',
                              ),
                              onNonFinancialTap: () => _showScanBucketDetail(
                                bucketKey: 'non_financial',
                                title: 'Non-financial Messages',
                                count: _lastScan?.nonFinancial ?? 0,
                                color: Colors.grey,
                                emptyHint:
                                    'No non-financial messages captured in the latest scan.',
                              ),
                              onAlreadyProcessedTap: () => _showScanBucketDetail(
                                bucketKey: 'already_processed',
                                title: 'Already Processed',
                                count: _lastScan?.alreadyProcessed ?? 0,
                                color: Colors.blue,
                                emptyHint:
                                    'No already-processed messages captured in the latest scan.',
                              ),
                              onBlockedByRuleTap: () => _showScanBucketDetail(
                                bucketKey: 'blocked_by_rule',
                                title: 'Blocked by Learned Rules',
                                count: _lastScan?.blockedByRule ?? 0,
                                color: Colors.orange,
                                emptyHint:
                                    'No rule-blocked messages captured in the latest scan.',
                              ),
                              onOutOfRangeTap: () => _showScanBucketDetail(
                                bucketKey: 'out_of_range',
                                title: 'Out of Range Messages',
                                count: _lastScan?.filteredByDate ?? 0,
                                color: Colors.purple,
                                emptyHint:
                                    'No out-of-range message samples were captured in the latest scan.',
                              ),
                              onParseFailedTap: () => _showScanBucketDetail(
                                bucketKey: 'parse_failed',
                                title: 'Parse/Processing Failures',
                                count: _lastScan?.parseFailed ?? 0,
                                color: Colors.red,
                                emptyHint:
                                    'No parse failure details were captured in the latest scan.',
                              ),
                            ),
                          ),
                        ),

                        // ── Transaction Stats ──────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: const SmsIntelligenceSectionLabel('Transactions'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SmsIntelligenceStatTile(
                                    label: 'SMS Imported',
                                    value: '$_totalSmsTransactions',
                                    icon: Icons.sms_outlined,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SmsIntelligenceStatTile(
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
                                  child: SmsIntelligenceStatTile(
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
                                  child: SmsIntelligenceStatTile(
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
                            child: const SmsIntelligenceSectionLabel('Learning'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SmsIntelligenceStatTile(
                                    label: 'Learned Rules',
                                    value: '$_learnedRules',
                                    icon: Icons.school_outlined,
                                    color: Colors.green,
                                    onTap: _learnedRules > 0 ? () => _showRulesDetail('all') : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SmsIntelligenceStatTile(
                                    label: 'Blocked Patterns',
                                    value: '$_blockedPatterns',
                                    icon: Icons.block_rounded,
                                    color: Colors.red,
                                    onTap: _blockedPatterns > 0 ? () => _showRulesDetail('blocked') : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SmsIntelligenceStatTile(
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
                              child: const SmsIntelligenceSectionLabel('Top Merchants'),
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
                                        .map((e) => SmsTopMerchantRow(
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
                            child: const SmsIntelligenceSectionLabel('Actions'),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              children: [
                                SmsIntelligenceActionTile(
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
                                SmsIntelligenceActionTile(
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

