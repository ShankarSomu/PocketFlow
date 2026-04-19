import 'package:flutter/material.dart';
import '../../../models/account.dart';
import '../../../services/app_logger.dart';
import '../../../theme/app_theme.dart';

class PreferencesSection extends StatelessWidget {

  const PreferencesSection({
    required this.logLevel, required this.defaultExpenseAccount, required this.defaultIncomeAccount, required this.accounts, required this.onLogLevelChanged, required this.onExpenseAccountChanged, required this.onIncomeAccountChanged, super.key,
  });
  final LogLevel logLevel;
  final int? defaultExpenseAccount;
  final int? defaultIncomeAccount;
  final List<Account> accounts;
  final Function(LogLevel) onLogLevelChanged;
  final Function(int?) onExpenseAccountChanged;
  final Function(int?) onIncomeAccountChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.settings_outlined, color: AppTheme.emerald),
      title: const Text('Preferences'),
      subtitle: const Text('Logging, default accounts', style: TextStyle(fontSize: 12)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(children: [
                Icon(Icons.analytics_outlined, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Logging Level', style: TextStyle(fontSize: 13)),
                ),
                DropdownButton<LogLevel>(
                  value: logLevel,
                  isDense: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: LogLevel.error, child: Text('Errors only')),
                    DropdownMenuItem(value: LogLevel.warning, child: Text('Warnings')),
                    DropdownMenuItem(value: LogLevel.info, child: Text('Normal')),
                    DropdownMenuItem(value: LogLevel.debug, child: Text('Verbose')),
                  ],
                  onChanged: (v) {
                    if (v != null) onLogLevelChanged(v);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.arrow_upward, size: 20, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Default Expense Account', style: TextStyle(fontSize: 13)),
                ),
                DropdownButton<int?>(
                  value: defaultExpenseAccount,
                  isDense: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(child: Text('None')),
                    ...accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: onExpenseAccountChanged,
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.arrow_downward, size: 20, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Default Income Account', style: TextStyle(fontSize: 13)),
                ),
                DropdownButton<int?>(
                  value: defaultIncomeAccount,
                  isDense: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(child: Text('None')),
                    ...accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: onIncomeAccountChanged,
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

