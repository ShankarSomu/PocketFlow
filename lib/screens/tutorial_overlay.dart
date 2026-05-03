import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:pocket_flow/onboarding/onboarding_analytics.dart';
import 'package:pocket_flow/onboarding/onboarding_flow_controller.dart';
import 'package:pocket_flow/onboarding/onboarding_step.dart';
import 'package:pocket_flow/onboarding/onboarding_storage.dart';
import 'package:pocket_flow/onboarding/onboarding_target_registry.dart';

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({required this.onComplete, super.key});

  final VoidCallback onComplete;

  static const String _flowId = 'main_tour';
  static const int _flowVersion = 2;

  static OnboardingFlowDefinition _defaultFlow() {
    return const OnboardingFlowDefinition(
      id: _flowId,
      version: _flowVersion,
      defaultInteractionMode: OnboardingInteractionMode.guided,
      steps: <OnboardingStep>[
        OnboardingStep(
          id: 'welcome',
          title: 'Welcome to PocketFlow',
          description: 'A quick guided tour of the key areas.',
          blocking: false,
          preferredPlacement: OnboardingCardPlacement.bottom,
          icon: Icons.waving_hand_rounded,
        ),
        OnboardingStep(
          id: 'overview',
          title: 'Financial Overview',
          description: 'Your balance, income, expenses and savings are here.',
          targetId: 'home.header',
          optional: true,
          blocking: false,
          arrowDirection: OnboardingArrowDirection.up,
          icon: Icons.dashboard_rounded,
        ),
        OnboardingStep(
          id: 'chart',
          title: 'Insights Panel',
          description: 'Charts and progress indicators update with your data.',
          targetId: 'home.chart',
          optional: true,
          blocking: false,
          arrowDirection: OnboardingArrowDirection.up,
          icon: Icons.pie_chart_rounded,
        ),
        OnboardingStep(
          id: 'time_filter',
          title: 'Time Filter',
          description: 'Use this to switch between week, month and year views.',
          targetId: 'home.time_filter',
          optional: true,
          blocking: false,
          preferredPlacement: OnboardingCardPlacement.top,
          arrowDirection: OnboardingArrowDirection.down,
          spotlightShape: OnboardingSpotlightShape.circle,
          icon: Icons.date_range_rounded,
        ),
      ],
    );
  }

  static Future<bool> shouldShow() {
    return OnboardingStorage().shouldStart(
      flowId: _flowId,
      version: _flowVersion,
    );
  }

  static Future<void> markComplete() async {
    final flow = _defaultFlow();
    final stepIds = flow.steps.map((s) => s.id).toSet();
    await OnboardingStorage().markCompleted(
      flowId: flow.id,
      version: flow.version,
      completedStepIds: stepIds,
    );
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final OnboardingFlowController _controller;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  late final AnimationController _cardCtrl;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  late final AnimationController _arrowCtrl;
  late final Animation<double> _arrowBounce;

  Timer? _targetPoll;
  bool _reduceMotion = false;
  bool _bootstrapped = false;
  bool _resolvingTarget = false;
  Rect? _spot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

    _controller = OnboardingFlowController(
      flow: TutorialOverlay._defaultFlow(),
      storage: OnboardingStorage(),
      analytics: AppLoggerOnboardingAnalytics(),
      registry: OnboardingTargetRegistry.instance,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(_cardCtrl);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));

    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _arrowBounce = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );

    if (_reduceMotion) {
      _pulseCtrl.stop();
      _arrowCtrl.stop();
    }

    OnboardingTargetRegistry.instance.addListener(_onTargetsChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OnboardingTargetRegistry.instance.removeListener(_onTargetsChanged);
    _targetPoll?.cancel();
    _pulseCtrl.dispose();
    _cardCtrl.dispose();
    _arrowCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleTargetResolve();
  }

  Future<void> _bootstrap() async {
    final shouldShow = await _controller.shouldStart();
    if (!mounted) return;

    if (!shouldShow) {
      _finish();
      return;
    }

    await _controller.start();
    if (!mounted) return;

    _bootstrapped = true;
    _announceCurrentStep();
    if (_reduceMotion) {
      _cardCtrl.value = 1;
    } else {
      _cardCtrl.forward(from: 0);
    }
    _startTargetPolling();
    await _resolveStepTarget();
    if (mounted) setState(() {});
  }

  void _startTargetPolling() {
    _targetPoll?.cancel();
    _targetPoll = Timer.periodic(
      const Duration(milliseconds: 220),
      (_) => _scheduleTargetResolve(),
    );
  }

  void _onTargetsChanged() {
    _scheduleTargetResolve();
  }

  void _scheduleTargetResolve() {
    if (_resolvingTarget || !_bootstrapped || !mounted) return;
    _resolvingTarget = true;
    _resolveStepTarget().whenComplete(() {
      _resolvingTarget = false;
    });
  }

  Future<void> _resolveStepTarget() async {
    final step = _controller.currentStep;
    if (step == null) {
      _finish();
      return;
    }

    Rect? newSpot;
    final targetId = step.targetId;
    if (targetId != null) {
      newSpot = OnboardingTargetRegistry.instance.rectFor(targetId);
      if (newSpot == null) {
        final before = _controller.currentStep?.id;
        await _controller.handleMissingTarget();
        final after = _controller.currentStep?.id;
        if (!mounted) return;
        if (before != after) {
          await _animateStepChange();
          return;
        }
      }
    }

    if (_spot != newSpot && mounted) {
      setState(() => _spot = newSpot);
    }
  }

  Future<void> _animateStepChange() async {
    if (!_reduceMotion) {
      await _cardCtrl.reverse();
    }
    if (!mounted) return;
    _announceCurrentStep();
    _spot = null;
    if (_reduceMotion) {
      _cardCtrl.value = 1;
      setState(() {});
    } else {
      setState(() {});
      await _cardCtrl.forward(from: 0);
    }
    await _resolveStepTarget();
  }

  void _announceCurrentStep() {
    final step = _controller.currentStep;
    if (step == null) return;
    SemanticsService.announce(
      '${step.title}. ${step.description}',
      Directionality.of(context),
    );
  }

  Future<void> _next() async {
    await _controller.next();
    if (!mounted) return;
    if (_controller.finished) {
      _finish();
      return;
    }
    await _animateStepChange();
  }

  Future<void> _skip() async {
    await _controller.skip();
    if (!mounted) return;
    _finish();
  }

  Future<void> _finish() async {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const Material(color: Colors.transparent);
    }

    final step = _controller.currentStep;
    if (step == null) {
      return const Material(color: Colors.transparent);
    }

    final size = MediaQuery.of(context).size;
    final primary = Theme.of(context).colorScheme.primary;
    final blocking = step.blocking ||
        _controller.flow.defaultInteractionMode == OnboardingInteractionMode.strict;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !blocking,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.62),
                child: Stack(
                  children: <Widget>[
                    if (_spot != null)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => CustomPaint(
                          size: size,
                          painter: _CutoutPainter(
                            spot: _spot!,
                            pulse: _pulse.value,
                            primaryColor: primary,
                            shape: step.spotlightShape,
                          ),
                        ),
                      ),
                    if (_spot != null && step.arrowDirection != OnboardingArrowDirection.none)
                      AnimatedBuilder(
                        animation: _arrowBounce,
                        builder: (_, __) => _ArrowPointer(
                          spot: _spot!,
                          dir: step.arrowDirection,
                          bounce: _arrowBounce.value,
                          color: primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Semantics(
              liveRegion: true,
              child: _StepCard(
                step: step,
                stepIndex: _controller.stepIndex,
                totalSteps: _controller.flow.steps.length,
                cardFade: _cardFade,
                cardSlide: _cardSlide,
                screenSize: size,
                spot: _spot,
                onNext: _next,
                onSkip: _controller.stepIndex > 0 ? _skip : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPointer extends StatelessWidget {
  const _ArrowPointer({
    required this.spot,
    required this.dir,
    required this.bounce,
    required this.color,
  });

  final Rect spot;
  final OnboardingArrowDirection dir;
  final double bounce;
  final Color color;

  @override
  Widget build(BuildContext context) {
    double top;
    double left;
    double rotationTurns;

    switch (dir) {
      case OnboardingArrowDirection.up:
        left = spot.center.dx - 20;
        top = spot.top - 56 + bounce;
        rotationTurns = 0;
      case OnboardingArrowDirection.down:
        left = spot.center.dx - 20;
        top = spot.bottom + 8 - bounce;
        rotationTurns = 0.5;
      case OnboardingArrowDirection.left:
        left = spot.left - 56 + bounce;
        top = spot.center.dy - 20;
        rotationTurns = -0.25;
      case OnboardingArrowDirection.right:
        left = spot.right + 8 - bounce;
        top = spot.center.dy - 20;
        rotationTurns = 0.25;
      case OnboardingArrowDirection.none:
        return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: left,
      child: Transform.rotate(
        angle: rotationTurns * 2 * math.pi,
        child: CustomPaint(
          size: const Size(40, 48),
          painter: _ArrowPainter(color: color),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.65, size.height * 0.5)
      ..lineTo(size.width * 0.65, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..lineTo(size.width * 0.35, size.height * 0.5)
      ..lineTo(0, size.height * 0.5)
      ..close();

    // Avoid MaskFilter-based shadows here to keep Impeller happy.
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

class _CutoutPainter extends CustomPainter {
  const _CutoutPainter({
    required this.spot,
    required this.pulse,
    required this.primaryColor,
    required this.shape,
  });

  final Rect spot;
  final double pulse;
  final Color primaryColor;
  final OnboardingSpotlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final expanded = Rect.fromCenter(
      center: spot.center,
      width: spot.width + pulse * 8,
      height: spot.height + pulse * 8,
    );

    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (shape == OnboardingSpotlightShape.circle) {
      final radius = math.max(expanded.width, expanded.height) / 2;
      fullPath
        ..addOval(Rect.fromCircle(center: expanded.center, radius: radius))
        ..fillType = PathFillType.evenOdd;
    } else {
      fullPath
        ..addRRect(RRect.fromRectAndRadius(expanded, const Radius.circular(18)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(fullPath, overlayPaint);

    final borderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5 + pulse * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (shape == OnboardingSpotlightShape.circle) {
      final radius = math.max(expanded.width, expanded.height) / 2;
      canvas.drawCircle(expanded.center, radius, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(expanded, const Radius.circular(18)),
        borderPaint,
      );
    }

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2 + pulse * 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    if (shape == OnboardingSpotlightShape.circle) {
      final radius = math.max(expanded.width, expanded.height) / 2;
      canvas.drawCircle(expanded.center, radius, glowPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(expanded, const Radius.circular(18)),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CutoutPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.spot != spot ||
        oldDelegate.shape != shape;
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.cardFade,
    required this.cardSlide,
    required this.screenSize,
    required this.spot,
    required this.onNext,
    this.onSkip,
  });

  final OnboardingStep step;
  final int stepIndex;
  final int totalSteps;
  final Animation<double> cardFade;
  final Animation<Offset> cardSlide;
  final Size screenSize;
  final Rect? spot;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isLast = stepIndex == totalSteps - 1;
    final placeBottom = _shouldPlaceBottom();

    return Column(
      mainAxisAlignment: placeBottom ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: <Widget>[
        if (!placeBottom) SizedBox(height: _cardTopOffset()),
        SlideTransition(
          position: cardSlide,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 32),
              child: step.customCardBuilder?.call(context) ??
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[primary, Color.lerp(primary, Colors.black, 0.2)!],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: primary.withValues(alpha: 0.45),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (step.icon != null)
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(step.icon, color: Colors.white, size: 22),
                                ),
                              Expanded(
                                child: Text(
                                  step.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Row(
                                children: List<Widget>.generate(
                                  totalSteps,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.only(left: 4),
                                    width: i == stepIndex ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == stepIndex
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            step.description,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: <Widget>[
                              if (onSkip != null)
                                TextButton(
                                  onPressed: onSkip,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withValues(alpha: 0.65),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  ),
                                  child: const Text('Skip tour', style: TextStyle(fontSize: 14)),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: onNext,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  isLast ? 'Finish' : 'Next',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  bool _shouldPlaceBottom() {
    switch (step.preferredPlacement) {
      case OnboardingCardPlacement.top:
        return false;
      case OnboardingCardPlacement.bottom:
        return true;
      case OnboardingCardPlacement.auto:
        final target = spot;
        if (target == null) return true;
        final spaceAbove = target.top;
        final spaceBelow = screenSize.height - target.bottom;
        return spaceBelow >= spaceAbove;
    }
  }

  double _cardTopOffset() {
    final target = spot;
    if (target == null) return 60;
    final desired = target.bottom + 18;
    return desired.clamp(24.0, screenSize.height * 0.55);
  }
}
