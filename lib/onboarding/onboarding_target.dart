import 'package:flutter/material.dart';

import 'onboarding_target_registry.dart';

class OnboardingTarget extends StatefulWidget {
  const OnboardingTarget({
    required this.id,
    required this.child,
    super.key,
  });

  final String id;
  final Widget child;

  @override
  State<OnboardingTarget> createState() => _OnboardingTargetState();
}

class _OnboardingTargetState extends State<OnboardingTarget> {
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      OnboardingTargetRegistry.instance.register(widget.id, _targetKey);
    });
  }

  @override
  void didUpdateWidget(covariant OnboardingTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      OnboardingTargetRegistry.instance.unregister(oldWidget.id, _targetKey);
      OnboardingTargetRegistry.instance.register(widget.id, _targetKey);
    }
  }

  @override
  void dispose() {
    OnboardingTargetRegistry.instance.unregister(widget.id, _targetKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _targetKey,
      child: widget.child,
    );
  }
}
