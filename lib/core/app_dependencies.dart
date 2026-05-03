import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../repositories/account_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/impl/account_repository_impl.dart';
import '../repositories/impl/budget_repository_impl.dart';
import '../repositories/impl/category_repository_impl.dart';
import '../repositories/impl/recurring_repository_impl.dart';
import '../repositories/impl/transaction_repository_impl.dart';
import '../repositories/impl/savings_repository_impl.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/savings_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/connectivity_service.dart';
import 'app_state.dart';

/// Dependency Injection container that provides repositories and services
/// to the widget tree using the Provider pattern.
class AppDependencies {
  /// Create all repository providers
  static List<SingleChildWidget> get repositories => [
        Provider<TransactionRepository>(
          create: (_) => TransactionRepositoryImpl(),
        ),
        Provider<AccountRepository>(
          create: (_) => AccountRepositoryImpl(),
        ),
        Provider<BudgetRepository>(
          create: (_) => BudgetRepositoryImpl(),
        ),
        Provider<GoalsRepository>(
          create: (_) => GoalsRepositoryImpl(),
        ),
        Provider<CategoryRepository>(
          create: (_) => CategoryRepositoryImpl(),
        ),
        Provider<RecurringRepository>(
          create: (_) => RecurringRepositoryImpl(),
        ),
        Provider<GoalsRepository>(
          create: (_) => GoalsRepositoryImpl(),
        ),
      ];

  /// Create all service providers
  static List<SingleChildWidget> get services => [
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(),
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
      ];

  /// Wrap the app with all providers
  static Widget wrapApp(Widget app) {
    return MultiProvider(
      providers: [
        ...services,
        ...repositories,
      ],
      child: app,
    );
  }
}
