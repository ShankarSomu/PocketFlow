import 'package:flutter/material.dart';

class OnboardingTargetRegistry extends ChangeNotifier {
  OnboardingTargetRegistry._();

  static final OnboardingTargetRegistry instance = OnboardingTargetRegistry._();

  final Map<String, GlobalKey> _targets = <String, GlobalKey>{};

  void register(String id, GlobalKey key) {
    _targets[id] = key;
    notifyListeners();
  }

  void unregister(String id, GlobalKey key) {
    final existing = _targets[id];
    if (identical(existing, key)) {
      _targets.remove(id);
      notifyListeners();
    }
  }

  Rect? rectFor(String id) {
    final key = _targets[id];
    if (key == null) return null;
    final context = key.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  bool hasTarget(String id) => rectFor(id) != null;
}
