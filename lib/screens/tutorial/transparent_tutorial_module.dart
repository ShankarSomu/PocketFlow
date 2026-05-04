import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pocket_flow/onboarding/onboarding_storage.dart';
import 'package:pocket_flow/onboarding/onboarding_target_registry.dart';

class TransparentTutorialModule extends StatefulWidget {
  const TransparentTutorialModule({required this.onComplete, super.key});

  final VoidCallback onComplete;

  static const String _flowId = 'main_tour';
  static const int _flowVersion = 3;

  static Future<bool> shouldShow() {
    return OnboardingStorage().shouldStart(
      flowId: _flowId,
      version: _flowVersion,
    );
  }

  static Future<void> markComplete() async {
    final stepIds = _steps.map((s) => s.id).toSet();
    await OnboardingStorage().markCompleted(
      flowId: _flowId,
      version: _flowVersion,
      completedStepIds: stepIds,
    );
  }

  static const List<_CoachStep> _steps = [
    _CoachStep(
      id: 'welcome',
      title: 'Welcome to PocketFlow',
      description: 'Let us quickly show you where the important things live.',
      targetId: null,
    ),
    _CoachStep(
      id: 'overview',
      title: 'Financial Overview',
      description: 'This area shows your balance, income, expense, and savings.',
      targetId: 'home.header',
      optional: true,
    ),
    _CoachStep(
      id: 'chart',
      title: 'Insights Panel',
      description: 'Charts and progress indicators update as your data changes.',
      targetId: 'home.chart',
      optional: true,
    ),
    _CoachStep(
      id: 'time_filter',
      title: 'Time Filter',
      description: 'Switch week/month/year here to analyze trends faster.',
      targetId: 'home.time_filter',
      optional: true,
    ),
  ];

  @override
  State<TransparentTutorialModule> createState() =>
      _TransparentTutorialModuleState();
}

class _TransparentTutorialModuleState extends State<TransparentTutorialModule> {
  final OnboardingStorage _storage = OnboardingStorage();
  final Set<String> _completed = <String>{};
  final Map<String, int> _missingAttempts = <String, int>{};

  Timer? _targetPoll;
  int _index = 0;
  Rect? _spot;
  bool _ready = false;

  _CoachStep get _step => TransparentTutorialModule._steps[_index];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _targetPoll?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final show = await TransparentTutorialModule.shouldShow();
    if (!mounted) return;

    if (!show) {
      widget.onComplete();
      return;
    }

    setState(() {
      _ready = true;
    });

    _startPollingTargets();
  }

  void _startPollingTargets() {
    _targetPoll?.cancel();
    _targetPoll = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _resolveTarget(),
    );
  }

  void _resolveTarget() {
    if (!mounted || !_ready) return;

    final targetId = _step.targetId;
    if (targetId == null) {
      if (_spot != null) {
        setState(() => _spot = null);
      }
      return;
    }

    final rect = OnboardingTargetRegistry.instance.rectFor(targetId);

    if (rect == null && _step.optional) {
      final attempts = (_missingAttempts[_step.id] ?? 0) + 1;
      _missingAttempts[_step.id] = attempts;
      if (attempts >= 6) {
        _next(skipCompletion: true);
      }
      return;
    }

    if (_spot != rect) {
      setState(() => _spot = rect);
    }
  }

  Future<void> _next({bool skipCompletion = false}) async {
    if (!skipCompletion) {
      _completed.add(_step.id);
      await _storage.saveStepProgress(
        flowId: TransparentTutorialModule._flowId,
        version: TransparentTutorialModule._flowVersion,
        completedStepIds: _completed,
      );
    }

    if (_index >= TransparentTutorialModule._steps.length - 1) {
      await _storage.markCompleted(
        flowId: TransparentTutorialModule._flowId,
        version: TransparentTutorialModule._flowVersion,
        completedStepIds: _completed,
      );
      if (!mounted) return;
      widget.onComplete();
      return;
    }

    setState(() {
      _index += 1;
      _spot = null;
    });
  }

  Future<void> _skip() async {
    await _storage.markSkipped(
      flowId: TransparentTutorialModule._flowId,
      version: TransparentTutorialModule._flowVersion,
      completedStepIds: _completed,
    );
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Material(color: Colors.transparent);
    }

    final step = _step;
    final isLast = _index == TransparentTutorialModule._steps.length - 1;
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _spot == null
                  ? Container(color: Colors.black.withValues(alpha: 0.22))
                  : ClipPath(
                      clipper: _SpotlightClipper(_spot!, radius: 14),
                      child: Container(color: Colors.black.withValues(alpha: 0.22)),
                    ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: _cardAlignment(size),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.description,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_index + 1}/${TransparentTutorialModule._steps.length}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _skip,
                          child: const Text('Skip'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _next,
                          child: Text(isLast ? 'Finish' : 'Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Alignment _cardAlignment(Size size) {
    final spot = _spot;
    if (spot == null) return Alignment.bottomCenter;

    final spaceAbove = spot.top;
    final spaceBelow = size.height - spot.bottom;
    return spaceBelow >= spaceAbove ? Alignment.bottomCenter : Alignment.topCenter;
  }
}

class _CoachStep {
  const _CoachStep({
    required this.id,
    required this.title,
    required this.description,
    required this.targetId,
    this.optional = false,
  });

  final String id;
  final String title;
  final String description;
  final String? targetId;
  final bool optional;
}

class _SpotlightClipper extends CustomClipper<Path> {
  _SpotlightClipper(this.target, {required this.radius});

  final Rect target;
  final double radius;

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(target.inflate(8), Radius.circular(radius)),
      );

    return Path.combine(PathOperation.difference, full, hole);
  }

  @override
  bool shouldReclip(covariant _SpotlightClipper oldClipper) {
    return oldClipper.target != target || oldClipper.radius != radius;
  }
}
