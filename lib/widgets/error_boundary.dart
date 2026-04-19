import 'package:flutter/material.dart';
import '../services/app_logger.dart';

/// Error boundary widget that catches and handles widget build errors
class ErrorBoundary extends StatefulWidget {

  const ErrorBoundary({
    required this.child, super.key,
    this.errorBuilder,
    this.onError,
  });
  final Widget child;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;
  final void Function(Object error, StackTrace? stackTrace)? onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    
    // Set up global error handler for uncaught errors
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.log(
        LogLevel.error,
        LogCategory.error,
        'Widget Error',
        detail: details.exceptionAsString(),
      );
      if (details.stack != null) {
        AppLogger.log(
          LogLevel.error,
          LogCategory.error,
          'Stack Trace',
          detail: details.stack.toString(),
        );
      }
      
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
      }
      
      widget.onError?.call(details.exception, details.stack);
    };

    // Set up error widget builder
    ErrorWidget.builder = (details) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.error,
        'Widget Build Error',
        detail: details.exceptionAsString(),
      );
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = details.exception;
            _stackTrace = details.stack;
          });
        }
      });

      return _DefaultErrorView(
        error: details.exception,
        stackTrace: details.stack,
        onReset: () => setState(() {
          _error = null;
          _stackTrace = null;
        }),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, _stackTrace);
      }
      
      return _DefaultErrorView(
        error: _error!,
        stackTrace: _stackTrace,
        onReset: () => setState(() {
          _error = null;
          _stackTrace = null;
        }),
      );
    }

    return widget.child;
  }
}

/// Default error view displayed when error boundary catches an error
class _DefaultErrorView extends StatelessWidget {

  const _DefaultErrorView({
    required this.error,
    required this.onReset, this.stackTrace,
  });
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The app encountered an unexpected error.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (stackTrace != null) ...[
                ExpansionTile(
                  title: const Text('Error Details'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(error.toString()),
                          const SizedBox(height: 12),
                          const Text(
                            'Stack Trace:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            stackTrace.toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      // Copy error to clipboard
                      // Clipboard.setData(ClipboardData(
                      //   text: 'Error: $error\n\nStack Trace:\n$stackTrace',
                      // ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error details logged')),
                      );
                    },
                    child: const Text('View Logs'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget that catches errors in a specific subtree
class SafeWidget extends StatelessWidget {

  const SafeWidget({
    required this.child, super.key,
    this.errorBuilder,
  });
  final Widget child;
  final Widget Function(BuildContext, Object)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      errorBuilder: errorBuilder != null
          ? (context, error, stack) => errorBuilder!(context, error)
          : null,
      child: child,
    );
  }
}

