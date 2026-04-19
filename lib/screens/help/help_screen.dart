import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Help',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHelpSection(
                    context,
                    icon: Icons.home_rounded,
                    title: 'Getting Started',
                    items: [
                      _HelpItem(
                        'What is PocketFlow?',
                        'PocketFlow is a local-first personal finance tracker that helps you manage your expenses, budgets, and savings goals.',
                      ),
                      _HelpItem(
                        'How do I add a transaction?',
                        'Tap the + button on the home screen or transactions screen. You can also enable SMS auto-import in Settings > Preferences.',
                      ),
                      _HelpItem(
                        'How do I create a budget?',
                        'Go to the Budget screen and tap "Add Budget". Choose a category, set a limit, and select the time period.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildHelpSection(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Accounts & Transactions',
                    items: [
                      _HelpItem(
                        'How do I add accounts?',
                        'Go to Accounts screen and tap "+ Add Account". Enter account name, type, and initial balance.',
                      ),
                      _HelpItem(
                        'Can I edit or delete transactions?',
                        'Yes, tap on any transaction to view details, then use the edit or delete buttons.',
                      ),
                      _HelpItem(
                        'What categories are available?',
                        'PocketFlow includes common categories like Food, Transport, Shopping, Bills, etc. You can assign categories when adding transactions.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildHelpSection(
                    context,
                    icon: Icons.savings_rounded,
                    title: 'Savings Goals',
                    items: [
                      _HelpItem(
                        'How do I create a savings goal?',
                        'Go to Savings screen and tap "Add Goal". Set a target amount and deadline.',
                      ),
                      _HelpItem(
                        'How do I contribute to goals?',
                        'Tap on a goal and use the "Add Contribution" button to record savings.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildHelpSection(
                    context,
                    icon: Icons.cloud_sync_rounded,
                    title: 'Backup & Sync',
                    items: [
                      _HelpItem(
                        'How do I backup my data?',
                        'Go to Settings > Backup, sign in with Google, and tap "Back Up Now". You can also enable automatic backups.',
                      ),
                      _HelpItem(
                        'Is my data secure?',
                        'Yes! All data is stored locally on your device. Cloud backups are optional and stored in your personal Google Drive.',
                      ),
                      _HelpItem(
                        'How do I restore from backup?',
                        'In Settings > Backup, sign in and tap "Restore from Drive Backup".',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildHelpSection(
                    context,
                    icon: Icons.sms_rounded,
                    title: 'SMS Auto-Import',
                    items: [
                      _HelpItem(
                        'What is SMS Auto-Import?',
                        'PocketFlow can scan your SMS messages for bank/wallet transaction notifications and automatically import them.',
                      ),
                      _HelpItem(
                        'Is it safe?',
                        'Absolutely! SMS reading happens locally on your device. Data is never uploaded or shared.',
                      ),
                      _HelpItem(
                        'How do I enable it?',
                        'Go to Settings > Preferences > SMS Auto-Import. Grant SMS permission and enable the feature.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildHelpSection(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Assistant',
                    items: [
                      _HelpItem(
                        'How do I use the AI assistant?',
                        'Open the Chat screen from the bottom navigation. Ask questions about your finances, spending patterns, or request insights.',
                      ),
                      _HelpItem(
                        'What can AI help with?',
                        'The AI can analyze spending trends, suggest budgets, answer questions about categories, and provide financial insights.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Contact Support
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Still need help?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact our support team',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            const email = 'support@pocketflow.app';
                            final uri = Uri(
                              scheme: 'mailto',
                              path: email,
                              query: 'subject=${Uri.encodeComponent('Help Request from PocketFlow App')}',
                            );
                            
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please email us at support@pocketflow.app'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.email_rounded, size: 18),
                          label: const Text('Email Support'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<_HelpItem> items,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(
                    item.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Text(
                        item.answer,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (index < items.length - 1)
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _HelpItem {
  
  _HelpItem(this.question, this.answer);
  final String question;
  final String answer;
}

