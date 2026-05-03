import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/haptic_feedback.dart';
import '../../models/account.dart';
import '../../repositories/impl/account_repository_impl.dart';
import '../../services/refresh_notifier.dart';
import '../../services/time_filter.dart';
import '../../viewmodels/accounts_screen_viewmodel.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../shared/shared.dart';
import '../transactions/transactions_screen.dart';
import 'components/account_form_sheet.dart';
import 'components/account_transfer_sheet.dart';
import 'components/accounts_section.dart';
import 'components/accounts_summary_card.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _fmt = NumberFormat.currency(symbol: '\$');
  late final AccountsScreenViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AccountsScreenViewModel(accountRepository: AccountRepositoryImpl());
    _viewModel.loadData();
    appRefresh.addListener(_viewModel.loadData);
    appTimeFilter.addListener(_viewModel.loadData);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_viewModel.loadData);
    appTimeFilter.removeListener(_viewModel.loadData);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _showForm([Account? existing]) async {
    try {
      await showAccountFormSheet(
        context,
        existing: existing,
        balances: _viewModel.balances,
        onSave: _viewModel.saveAccount,
        onDelete: _viewModel.deleteAccount,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save account: $e')),
      );
    }
  }

  void _showTransactions(Account account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          initialAccountId: account.id,
        ),
      ),
    );
  }

  Future<void> _showTransferDialog() async {
    try {
      await showAccountTransferSheet(
        context,
        accounts: _viewModel.accounts,
        balances: _viewModel.balances,
        fmt: _fmt,
        onTransfer: _viewModel.transfer,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to transfer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final speedDialActions = <SpeedDialAction>[
          SpeedDialAction(
            icon: Icons.add,
            label: 'Add Account',
            onPressed: _showForm,
          ),
          if (_viewModel.accounts.length >= 2)
            SpeedDialAction(
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer',
              onPressed: _showTransferDialog,
            ),
        ];

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                _viewModel.loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _viewModel.error != null
                        ? ErrorStateWidget(
                            message: _viewModel.error!,
                            onRetry: _viewModel.loadData,
                          )
                        : Column(
                            children: [
                              const ScreenHeader(
                                'Accounts',
                                icon: Icons.account_balance_wallet_rounded,
                                subtitle: 'Net worth & balances',
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: AccountsSummaryCard(
                                  netWorth: _viewModel.netWorth,
                                  totalAssets: _viewModel.totalAssets,
                                  totalDebt: _viewModel.totalDebt,
                                  accountCount: _viewModel.accounts.length,
                                  fmt: _fmt,
                                ),
                              ),
                              Expanded(
                                child: _viewModel.accounts.isEmpty
                                    ? EmptyStates.accounts(
                                        context,
                                        onAdd: () async {
                                          await HapticFeedbackHelper.lightImpact();
                                          await _showForm();
                                        },
                                      )
                                    : RefreshIndicator(
                                        onRefresh: _viewModel.loadData,
                                        child: ListView(
                                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                                          children: [
                                            for (final type in Account.types)
                                              if (_viewModel.groupedAccounts.containsKey(type))
                                                AccountsSection(
                                                  type: type,
                                                  accounts: _viewModel.groupedAccounts[type]!,
                                                  balances: _viewModel.balances,
                                                  fmt: _fmt,
                                                  onTap: _showForm,
                                                  onViewTransactions: _showTransactions,
                                                ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  child: CalendarFab(),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  right: 16,
                  child: SpeedDialFab(actions: speedDialActions),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
