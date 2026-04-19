import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/theme_service.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final bool isFirstTime;

  const WelcomeScreen({super.key, required this.onGetStarted, this.isFirstTime = true});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _featuresOpacity;
  late Animation<double> _btnSlide;
  late Animation<double> _btnOpacity;
  late Animation<double> _pulse;

  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      icon: Icons.account_balance_wallet_rounded,
      title: 'All Your Finances,\nOne Place',
      subtitle: 'Track accounts, budgets, and bills with effortless clarity.',
    ),
    _OnboardPage(
      icon: Icons.insights_rounded,
      title: 'Smart Insights,\nReal Results',
      subtitle: 'AI-powered analytics that reveal where your money actually goes.',
    ),
    _OnboardPage(
      icon: Icons.flag_rounded,
      title: 'Goals You\'ll\nActually Reach',
      subtitle: 'Set savings goals and watch your progress in real time.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);

    // Disable pulse animation on low-end devices
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (!_shouldReduceAnimations()) {
      _pulseController.repeat(reverse: true);
    }
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.45, curve: Curves.elasticOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.45, 0.7, curve: Curves.easeOut)),
    );
    _featuresOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.55, 0.85, curve: Curves.easeOut)),
    );
    _btnSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );
    _btnOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    _entryController.forward();
    
    // Auto-dismiss for returning users after animation completes
    if (!widget.isFirstTime) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) widget.onGetStarted();
      });
    }
  }

  bool _shouldReduceAnimations() {
    return WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [Color(0xFF060E2D), Color(0xFF0F2044), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5 + _bgController.value * 0.2, 1.0],
              ),
            ),
            child: Stack(
              children: [
                _Orb(
                  size: size.width * 1.2,
                  color: ThemeService.instance.primaryColor,
                  opacity: 0.12 + _bgController.value * 0.06,
                  dx: -size.width * 0.3,
                  dy: -size.height * 0.15 + _bgController.value * 40,
                ),
                _Orb(
                  size: size.width * 1.0,
                  color: ThemeService.instance.primaryColor,
                  opacity: 0.10 + _bgController.value * 0.05,
                  dx: size.width * 0.5,
                  dy: size.height * 0.55 - _bgController.value * 40,
                ),
                _Orb(
                  size: size.width * 0.6,
                  color: ThemeService.instance.primaryColor,
                  opacity: 0.08 + _bgController.value * 0.04,
                  dx: size.width * 0.3,
                  dy: size.height * 0.3 + _bgController.value * 20,
                ),
                CustomPaint(
                  size: size,
                  painter: _GridPainter(),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                AnimatedBuilder(
                                  animation: _entryController,
                                  builder: (_, __) => Opacity(
                                    opacity: _logoOpacity.value,
                                    child: Transform.scale(
                                      scale: _logoScale.value,
                                      child: _buildLogo(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                AnimatedBuilder(
                                  animation: _entryController,
                                  builder: (_, __) => Opacity(
                                    opacity: _titleOpacity.value,
                                    child: Transform.translate(
                                      offset: Offset(0, _titleSlide.value),
                                      child: _buildTitle(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AnimatedBuilder(
                                  animation: _entryController,
                                  builder: (_, __) => Opacity(
                                    opacity: _subtitleOpacity.value,
                                    child: Text(
                                      widget.isFirstTime
                                          ? 'Experience financial clarity with intelligent\ntracking, beautiful insights, and effortless control.'
                                          : 'Welcome back! Loading your financial dashboard...',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF94A3B8),
                                        height: 1.6,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 52),
                                if (widget.isFirstTime)
                                  AnimatedBuilder(
                                    animation: _entryController,
                                    builder: (_, __) => Opacity(
                                      opacity: _featuresOpacity.value,
                                      child: _buildFeatureCarousel(),
                                    ),
                                  ),
                                if (widget.isFirstTime) const SizedBox(height: 52),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.isFirstTime)
                        AnimatedBuilder(
                          animation: _entryController,
                          builder: (_, __) => Opacity(
                            opacity: _btnOpacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _btnSlide.value),
                              child: _buildBottomCTA(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  ThemeService.instance.primaryColor.withValues(alpha: 0.35),
                  ThemeService.instance.primaryColor.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: ThemeService.instance.cardGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: ThemeService.instance.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 36,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: ThemeService.instance.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, size: 52, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFBAE6FD), Color(0xFF99F6E4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: const Text(
            'Pocket Flow',
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: ThemeService.instance.cardGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ThemeService.instance.primaryColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 13),
              SizedBox(width: 6),
              Text(
                'PREMIUM FINANCE MANAGER',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildPageCard(_pages[i]),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: active ? ThemeService.instance.cardGradient : null,
                color: active ? null : const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(4),
                boxShadow: active
                    ? [BoxShadow(color: ThemeService.instance.primaryColor.withValues(alpha: 0.5), blurRadius: 8)]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPageCard(_OnboardPage page) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14FFFFFF)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: ThemeService.instance.cardGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ThemeService.instance.primaryColor.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(page.icon, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  page.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  page.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onGetStarted,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No credit card required  ?  Free forever',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

// -- Supporting types/widgets --------------------------------------------------

class _Orb extends StatelessWidget {
  final double size, opacity, dx, dy;
  final Color color;
  const _Orb({required this.size, required this.color, required this.opacity, required this.dx, required this.dy});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: dx,
      top: dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x07FFFFFF)
      ..strokeWidth = 0.5;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardPage({required this.icon, required this.title, required this.subtitle});
}

