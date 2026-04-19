import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureHint extends StatefulWidget {

  const FeatureHint({
    required this.featureKey, required this.message, required this.child, super.key,
    this.alignment = Alignment.topCenter,
    this.delay = const Duration(milliseconds: 800),
  });
  final String featureKey;
  final String message;
  final Widget child;
  final Alignment alignment;
  final Duration delay;

  @override
  State<FeatureHint> createState() => _FeatureHintState();
}

class _FeatureHintState extends State<FeatureHint> with SingleTickerProviderStateMixin {
  bool _showHint = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _checkAndShow();
  }

  Future<void> _checkAndShow() async {
    await Future.delayed(widget.delay);
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = prefs.getBool('hint_${widget.featureKey}') ?? false;
    
    if (!hasSeenHint && mounted) {
      setState(() => _showHint = true);
      _controller.forward();
      
      // Auto-dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _showHint) {
          _dismiss();
        }
      });
    }
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      setState(() => _showHint = false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hint_${widget.featureKey}', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_showHint)
          Positioned.fill(
            child: Align(
              alignment: widget.alignment,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 80),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _dismiss,
                            child: const Icon(Icons.close, color: Colors.white70, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Predefined feature hints
class FeatureHints {
  static const speedDial = 'speed_dial';
  static const swipeNavigation = 'swipe_navigation';
  static const timeFilter = 'time_filter';
  static const homeButton = 'home_button';
  static const aiChat = 'ai_chat';
  
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hint_$speedDial');
    await prefs.remove('hint_$swipeNavigation');
    await prefs.remove('hint_$timeFilter');
    await prefs.remove('hint_$homeButton');
    await prefs.remove('hint_$aiChat');
  }
}

