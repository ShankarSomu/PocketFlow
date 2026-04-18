import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialOverlay({super.key, required this.onComplete});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('tutorial_completed') ?? false);
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  int _step = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Welcome to PocketFlow!',
      description: 'Let\'s take a quick tour of the key features.',
      alignment: Alignment.center,
      spotlightRect: null,
    ),
    TutorialStep(
      title: 'Your Financial Overview',
      description: 'See your balance, income, expenses, and savings rate at a glance.',
      alignment: Alignment.topCenter,
      spotlightRect: const Rect.fromLTWH(14, 120, 0, 260),
    ),
    TutorialStep(
      title: 'Spending by Category',
      description: 'Visualize where your money goes with interactive charts.',
      alignment: Alignment.center,
      spotlightRect: const Rect.fromLTWH(14, 400, 0, 260),
    ),
    TutorialStep(
      title: 'Quick Actions',
      description: 'Tap the + button to add transactions, budgets, or goals instantly.',
      alignment: Alignment.bottomRight,
      spotlightRect: const Rect.fromLTWH(0, 0, 80, 80),
      spotlightPosition: SpotlightPosition.bottomRight,
    ),
    TutorialStep(
      title: 'Time Filter',
      description: 'Tap here to view different time periods (week, month, year).',
      alignment: Alignment.bottomLeft,
      spotlightRect: const Rect.fromLTWH(16, 0, 64, 64),
      spotlightPosition: SpotlightPosition.bottomLeft,
    ),
    TutorialStep(
      title: 'Navigate Tabs',
      description: 'Swipe left/right or tap the bottom bar to explore Transactions, Budgets, Goals, and more.',
      alignment: Alignment.bottomCenter,
      spotlightRect: const Rect.fromLTWH(0, 0, 0, 80),
      spotlightPosition: SpotlightPosition.bottom,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Only animate if device doesn't prefer reduced motion
    if (!_shouldReduceAnimations()) {
      _pulseController.repeat(reverse: true);
    }
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  bool _shouldReduceAnimations() {
    return WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      TutorialOverlay.markComplete();
      widget.onComplete();
    }
  }

  void _skip() {
    TutorialOverlay.markComplete();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        children: [
          // Spotlight
          if (step.spotlightRect != null)
            CustomPaint(
              size: size,
              painter: _SpotlightPainter(
                rect: _getSpotlightRect(step, size),
                pulseAnimation: _pulseAnimation,
              ),
            ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: _getMainAlignment(step.alignment),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (step.alignment == Alignment.topCenter) const SizedBox(height: 400),
                  if (step.alignment == Alignment.center && step.spotlightRect == null) const Spacer(),
                  if (step.alignment == Alignment.center && step.spotlightRect != null) const SizedBox(height: 200),
                  if (step.alignment == Alignment.bottomRight || step.alignment == Alignment.bottomLeft) const Spacer(),
                  _buildContent(step),
                  if (step.alignment == Alignment.center && step.spotlightRect == null) const Spacer(),
                  if (step.alignment == Alignment.bottomCenter) const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  MainAxisAlignment _getMainAlignment(Alignment alignment) {
    if (alignment == Alignment.topCenter) return MainAxisAlignment.start;
    if (alignment == Alignment.bottomCenter || alignment == Alignment.bottomRight || alignment == Alignment.bottomLeft) {
      return MainAxisAlignment.end;
    }
    return MainAxisAlignment.center;
  }

  Rect _getSpotlightRect(TutorialStep step, Size size) {
    final rect = step.spotlightRect!;
    switch (step.spotlightPosition) {
      case SpotlightPosition.bottomRight:
        return Rect.fromLTWH(
          size.width - 96,
          size.height - 160,
          80,
          80,
        );
      case SpotlightPosition.bottomLeft:
        return Rect.fromLTWH(16, size.height - 160, 64, 64);
      case SpotlightPosition.bottom:
        return Rect.fromLTWH(0, size.height - 80, size.width, 80);
      default:
        return Rect.fromLTWH(
          rect.left,
          rect.top,
          size.width - 28,
          rect.height,
        );
    }
  }

  Widget _buildContent(TutorialStep step) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${_step + 1}/${_steps.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  _step < _steps.length - 1 ? 'Next' : 'Got it!',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final Alignment alignment;
  final Rect? spotlightRect;
  final SpotlightPosition spotlightPosition;

  TutorialStep({
    required this.title,
    required this.description,
    required this.alignment,
    this.spotlightRect,
    this.spotlightPosition = SpotlightPosition.custom,
  });
}

enum SpotlightPosition {
  custom,
  bottomRight,
  bottomLeft,
  bottom,
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final Animation<double> pulseAnimation;

  _SpotlightPainter({required this.rect, required this.pulseAnimation}) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final expandedRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width * pulseAnimation.value,
      height: rect.height * pulseAnimation.value,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(expandedRect, const Radius.circular(16)),
      paint,
    );

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawRRect(
      RRect.fromRectAndRadius(expandedRect, const Radius.circular(16)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => true;
}
