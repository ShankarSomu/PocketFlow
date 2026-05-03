import 'package:pocket_flow/services/app_logger.dart';

abstract class OnboardingAnalytics {
  void track({
    required String event,
    required String flowId,
    String? stepId,
    int? stepIndex,
    Map<String, Object?> metadata,
  });
}

class AppLoggerOnboardingAnalytics implements OnboardingAnalytics {
  @override
  void track({
    required String event,
    required String flowId,
    String? stepId,
    int? stepIndex,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final detail = <String, Object?>{
      'event': event,
      'flow': flowId,
      if (stepId != null) 'stepId': stepId,
      if (stepIndex != null) 'stepIndex': stepIndex,
      ...metadata,
    };

    AppLogger.log(
      LogLevel.info,
      LogCategory.navigation,
      'Onboarding event',
      detail: detail.toString(),
    );
  }
}
