// Example Settings screen for viewing and managing SMS classification rules

import 'package:flutter/material.dart';
import 'package:pocket_flow/sms_engine/rules/sms_rule_engine.dart';
import '../services/merchant_normalizer.dart';

class SmsRulesSettingsScreen extends StatefulWidget {
  const SmsRulesSettingsScreen({Key? key}) : super(key: key);

  @override
  State<SmsRulesSettingsScreen> createState() => _SmsRulesSettingsScreenState();
}

class _SmsRulesSettingsScreenState extends State<SmsRulesSettingsScreen> {
  final SmsRuleEngine _ruleEngine = SmsRuleEngine();
  final MerchantNormalizer _merchantNormalizer = MerchantNormalizer();
  
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _loading = true);
    
    final ruleStats = await _ruleEngine.getStatistics();
    final merchantStats = await _merchantNormalizer.getStatistics();
    
    setState(() {
      _stats = {
        ...ruleStats,
        'merchant_stats': merchantStats,
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Classification Rules'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reloadIndex,
            tooltip: 'Reload Rules',
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'How it works',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatisticsSection(),
                  SizedBox(height: 24),
                  _buildPerformanceSection(),
                  SizedBox(height: 24),
                  _buildRulesByCategorySection(),
                  SizedBox(height: 24),
                  _buildTopMerchantsSection(),
                  SizedBox(height: 24),
                  _buildActionsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildStatRow(
              icon: Icons.rule,
              label: 'Total Rules',
              value: '${_stats?['total_rules'] ?? 0}',
              color: Colors.blue,
            ),
            _buildStatRow(
              icon: Icons.flash_on,
              label: 'Cached Patterns',
              value: '${_stats?['cache_size'] ?? 0}',
              color: Colors.orange,
            ),
            _buildStatRow(
              icon: Icons.key,
              label: 'Index Keywords',
              value: '${_stats?['index_keywords'] ?? 0}',
              color: Colors.green,
            ),
            _buildStatRow(
              icon: Icons.store,
              label: 'Merchant Mappings',
              value: '${_stats?['merchant_stats']?['total_mappings'] ?? 0}',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection() {
    final cacheSize = _stats?['cache_size'] ?? 0;
    final totalRules = _stats?['total_rules'] ?? 1;
    final cacheHitEstimate = (cacheSize / (cacheSize + totalRules) * 100).toInt();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: cacheHitEstimate / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(Colors.green),
            ),
            SizedBox(height: 8),
            Text(
              'Estimated cache hit rate: ~$cacheHitEstimate%',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            SizedBox(height: 12),
            Text(
              'Higher cache hit rate = faster classification',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesByCategorySection() {
    final rulesByCategory = _stats?['rules_by_category'] as List? ?? [];

    if (rulesByCategory.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No rules created yet'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rules by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...rulesByCategory.map((rule) {
              final category = rule['category'] as String?;
              final count = rule['count'] as int;
              final avgCorrect = (rule['avg_correct'] as num?)?.toDouble() ?? 0.0;
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _getCategoryColor(category),
                  child: Text(
                    '${count}',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(category ?? 'Unknown'),
                subtitle: Text(
                  'Avg. correct: ${avgCorrect.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () => _showCategoryRules(category),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMerchantsSection() {
    final merchantStats = _stats?['merchant_stats'] as Map? ?? {};
    final topMerchants = merchantStats['top_merchants'] as List? ?? [];

    if (topMerchants.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Merchants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...topMerchants.take(10).map((merchant) {
              final name = merchant['normalized_name'] as String;
              final frequency = merchant['total_frequency'] as int;
              
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$frequency',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cleaning_services, color: Colors.orange),
              title: Text('Cleanup Cache'),
              subtitle: Text('Remove old cached patterns (keep top 10K)'),
              trailing: Icon(Icons.chevron_right),
              onTap: _cleanupCache,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.analytics, color: Colors.blue),
              title: Text('View Merchant Mappings'),
              subtitle: Text('See how merchants are normalized'),
              trailing: Icon(Icons.chevron_right),
              onTap: _showMerchantMappings,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'BLOCKED':
        return Colors.red;
      case 'SHOPPING':
        return Colors.blue;
      case 'FOOD':
        return Colors.orange;
      case 'TRANSPORT':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _reloadIndex() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reloading rules...')),
    );

    await _ruleEngine.reloadIndex();
    await _merchantNormalizer.reloadCache();
    await _loadStatistics();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Rules reloaded'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _cleanupCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cleanup Cache?'),
        content: Text(
          'This will remove old cached patterns, keeping only the top 10,000 most-used patterns.\n\n'
          'Classification may be slower for removed patterns until they are cached again.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cleanup'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _ruleEngine.cleanupCache();
      await _loadStatistics();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Cache cleaned up'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showCategoryRules(String? category) async {
    // TODO: Show list of rules for this category
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing rules for: $category')),
    );
  }

  Future<void> _showMerchantMappings() async {
    final mappings = await _merchantNormalizer.getAllMappings();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Merchant Normalizations'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mappings.length,
            itemBuilder: (context, index) {
              final entry = mappings.entries.elementAt(index);
              return ListTile(
                dense: true,
                title: Text(entry.key, style: TextStyle(fontSize: 12)),
                trailing: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How It Works'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎯 Two-Stage Classification',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Fast candidate retrieval using keyword index\n'
                '2. Scoring and conflict resolution\n\n',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '⚡ Performance',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Sub-50ms classification\n'
                '• No full rule scans\n'
                '• Scales to millions of rules\n\n',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '📚 Learning',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Rules created from your feedback\n'
                '• Merchants automatically normalized\n'
                '• Patterns cached for speed\n',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }
}
