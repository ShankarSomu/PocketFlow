import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../services/connectivity_service.dart';

/// A reusable error state widget that displays error information
/// and provides a retry option.
class ErrorStateWidget extends StatelessWidget {

  const ErrorStateWidget({
    super.key,
    this.message,
    this.appError,
    this.onRetry,
    this.retryButtonText = 'Try Again',
    this.title,
  }) : assert(message != null || appError != null, 'Either message or appError must be provided');
  final String? message;
  final AppError? appError;
  final VoidCallback? onRetry;
  final String? retryButtonText;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final finalError = appError ?? AppError(
      message: message ?? 'Something went wrong',
      type: ErrorType.unknown,
    );

    // Determine icon and color based on error type
    IconData icon = Icons.error_outline;
    Color? iconColor = Theme.of(context).colorScheme.error;

    switch (finalError.type) {
      case ErrorType.network:
        icon = Icons.wifi_off;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case ErrorType.database:
        icon = Icons.storage;
        break;
      case ErrorType.validation:
        icon = Icons.warning_amber;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case ErrorType.permission:
        icon = Icons.lock_outline;
        break;
      case ErrorType.timeout:
        icon = Icons.hourglass_empty;
        break;
      case ErrorType.unknown:
        icon = Icons.error_outline;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'Oops!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              finalError.userMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            
            // Show offline status if applicable
            if (connectivity.isOffline && finalError.type == ErrorType.network) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'You are currently offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (onRetry != null && finalError.isRetryable) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryButtonText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget that displays a compact error message with retry option,
/// suitable for smaller areas like list tiles or cards.
class CompactErrorWidget extends StatelessWidget {

  const CompactErrorWidget({
    super.key,
    this.message = 'Failed to load data',
    this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

