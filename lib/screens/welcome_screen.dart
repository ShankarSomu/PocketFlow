import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_blob.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final bool isFirstTime;

  const WelcomeScreen({super.key, required this.onGetStarted, this.isFirstTime = true});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Animated background blobs
            AnimatedBlob(
              color: AppTheme.emerald.withOpacity(0.2),
              size: 800,
              duration: const Duration(seconds: 8),
              alignment: const Alignment(-0.5, -0.8),
            ),
            AnimatedBlob(
              color: AppTheme.blue.withOpacity(0.2),
              size: 900,
              duration: const Duration(seconds: 10),
              alignment: const Alignment(0.5, 0.8),
            ),
            
            // Content
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: _buildLogo(),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Title
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFFD1FAE5), Color(0xFFDEEBFF)],
                              ).createShader(bounds),
                              child: const Text(
                                'Pocket Flow',
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: AppTheme.emerald, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'PREMIUM FINANCE MANAGER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.emerald,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Subtitle
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(opacity: value, child: child);
                        },
                        child: const Text(
                          'Experience financial clarity with intelligent\ntracking, beautiful insights, and effortless control',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFFCBD5E1),
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 64),
                      
                      // Features - only for first time
                      if (isFirstTime) _buildFeatures(),
                      
                      if (isFirstTime) const SizedBox(height: 64),
                      
                      // CTA Button - only for first time
                      if (isFirstTime)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            _buildGetStartedButton(context),
                            const SizedBox(height: 16),
                            const Text(
                              'No credit card required • Free forever',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.emeraldBlueGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFeatures() {
    final features = [
      _Feature(Icons.trending_up_rounded, 'Smart\nAnalytics', AppTheme.emeraldGradient),
      _Feature(Icons.track_changes_rounded, 'Goal\nTracking', AppTheme.blueGradient),
      _Feature(Icons.calendar_month_rounded, 'Budget\nPlanning', const LinearGradient(colors: [Color(0xFFA78BFA), Color(0xFF8B5CF6)])),
      _Feature(Icons.account_balance_wallet_rounded, 'Account\nSync', const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)])),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: features.map((f) => _buildFeatureCard(f)).toList(),
    );
  }

  Widget _buildFeatureCard(_Feature feature) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: feature.gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(feature.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              feature.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE2E8F0),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onGetStarted,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 64),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(4 * value, 0),
                    child: child,
                  );
                },
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final Gradient gradient;
  _Feature(this.icon, this.label, this.gradient);
}
