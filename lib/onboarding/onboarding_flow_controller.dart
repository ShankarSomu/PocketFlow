import 'dart:async';

import 'onboarding_analytics.dart';
import 'onboarding_step.dart';
import 'onboarding_storage.dart';
import 'onboarding_target_registry.dart';

class OnboardingFlowController {
  OnboardingFlowController({
    required this.flow,
    required this.storage,
    required this.analytics,
    required this.registry,
  });

  final OnboardingFlowDefinition flow;
  final OnboardingStorage storage;
  final OnboardingAnalytics analytics;
  final OnboardingTargetRegistry registry;

  int _stepIndex = -1;
  bool _started = false;
  bool _finished = false;
  bool _skipped = false;
  final Set<String> _completedStepIds = <String>{};
  final Map<String, int> _missingTargetAttempts = <String, int>{};

  bool get started => _started;
  bool get finished => _finished;
  bool get skipped => _skipped;
  int get stepIndex => _stepIndex;
  Set<String> get completedStepIds => Set<String>.from(_completedStepIds);

  OnboardingStep? get currentStep {
    if (_stepIndex < 0 || _stepIndex >= flow.steps.length) return null;
    return flow.steps[_stepIndex];
  }

  Future<bool> shouldStart() {
    return storage.shouldStart(flowId: flow.id, version: flow.version);
  }

  Future<void> start() async {
    final progress = await storage.readProgress(flow.id);

    if (progress.version != flow.version) {
      _completedStepIds.clear();
    } else {
      _completedStepIds
        ..clear()
        ..addAll(progress.completedStepIds);
    }

    _started = true;
    _finished = false;
    _skipped = false;
    _stepIndex = _findNextIndex(from: 0);

    analytics.track(event: 'tutorial_started', flowId: flow.id);
    _trackStepViewed();
  }

  Future<void> complete() async {
    if (_finished) return;

    final step = currentStep;
    if (step != null) {
      _completedStepIds.add(step.id);
    }

    _finished = true;
    await storage.markCompleted(
      flowId: flow.id,
      version: flow.version,
      completedStepIds: _completedStepIds,
    );

    analytics.track(event: 'tutorial_completed', flowId: flow.id);
  }

  Future<void> skip() async {
    if (_finished) return;

    _skipped = true;
    _finished = true;
    await storage.markSkipped(
      flowId: flow.id,
      version: flow.version,
      completedStepIds: _completedStepIds,
    );

    analytics.track(
      event: 'tutorial_skipped',
      flowId: flow.id,
      stepId: currentStep?.id,
      stepIndex: _stepIndex,
    );
  }

  Future<void> next() async {
    if (_finished) return;

    final step = currentStep;
    if (step != null) {
      _completedStepIds.add(step.id);
      analytics.track(
        event: 'step_completed',
        flowId: flow.id,
        stepId: step.id,
        stepIndex: _stepIndex,
      );
      await storage.saveStepProgress(
        flowId: flow.id,
        version: flow.version,
        completedStepIds: _completedStepIds,
      );
    }

    final nextIndex = _findNextIndex(from: _stepIndex + 1);
    if (nextIndex == -1) {
      await complete();
      return;
    }

    _stepIndex = nextIndex;
    await _applyDelayIfAny(currentStep);
    _trackStepViewed();
  }

  Future<void> previous() async {
    if (_finished) return;
    for (var i = _stepIndex - 1; i >= 0; i--) {
      if (_isEligible(flow.steps[i])) {
        _stepIndex = i;
        _trackStepViewed();
        return;
      }
    }
  }

  Future<void> handleMissingTarget() async {
    final step = currentStep;
    if (step == null || step.targetId == null || !step.optional) return;

    final attempts = (_missingTargetAttempts[step.id] ?? 0) + 1;
    _missingTargetAttempts[step.id] = attempts;

    if (attempts < 6) return;

    analytics.track(
      event: 'step_skipped_missing_target',
      flowId: flow.id,
      stepId: step.id,
      stepIndex: _stepIndex,
      metadata: <String, Object?>{'targetId': step.targetId},
    );

    await next();
  }

  bool targetAvailableForCurrentStep() {
    final step = currentStep;
    final targetId = step?.targetId;
    if (targetId == null) return true;
    return registry.hasTarget(targetId);
  }

  int _findNextIndex({required int from}) {
    for (var i = from; i < flow.steps.length; i++) {
      if (_isEligible(flow.steps[i])) {
        return i;
      }
    }
    return -1;
  }

  bool _isEligible(OnboardingStep step) {
    final condition = step.condition;
    if (condition == null) return true;
    return condition();
  }

  Future<void> _applyDelayIfAny(OnboardingStep? step) async {
    if (step == null || step.delay == Duration.zero) return;
    await Future<void>.delayed(step.delay);
  }

  void _trackStepViewed() {
    final step = currentStep;
    if (step == null) return;
    analytics.track(
      event: 'step_viewed',
      flowId: flow.id,
      stepId: step.id,
      stepIndex: _stepIndex,
    );
  }
}
