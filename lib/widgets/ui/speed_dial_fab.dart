import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

/// A single action for [SpeedDialFab].
class SpeedDialAction {

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
}

/// Expandable speed-dial FAB.
/// Tap the `+` button to expand mini-FABs above it; tap any action or the
/// main button again to collapse.
class SpeedDialFab extends StatefulWidget {

  const SpeedDialFab({required this.actions, super.key});
  final List<SpeedDialAction> actions;

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-close when this screen becomes inactive in an IndexedStack
    if (!TickerMode.of(context)) _close();
  }

  @override
  void deactivate() {
    _close();
    super.deactivate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _close() {
    if (_open) {
      setState(() => _open = false);
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Action items – each tappable row (label + icon) triggers the action
        for (final action in widget.actions.reversed)
          FadeTransition(
            opacity: _fade,
            child: SizeTransition(
              sizeFactor: _scale,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _close();
                    action.onPressed();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label bubble (tappable via parent GestureDetector)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Icon circle
                      Material(
                        color: action.color ?? Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(action.icon, size: 20, color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Main FAB
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: ThemeService.instance.cardGradient,
            shape: BoxShape.circle,
            boxShadow: ThemeService.instance.primaryShadow,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggleOpen,
              customBorder: const CircleBorder(),
              child: Center(
                child: AnimatedRotation(
                  turns: _open ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.add,
                    size: 28,
                    color: Colors.white,
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

