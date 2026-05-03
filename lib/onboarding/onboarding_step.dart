import 'package:flutter/material.dart';

enum OnboardingArrowDirection { up, down, left, right, none }

enum OnboardingCardPlacement { auto, top, bottom }

enum OnboardingSpotlightShape { roundedRect, circle }

enum OnboardingInteractionMode { strict, guided, passive }

class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.title,
    required this.description,
    this.targetId,
    this.optional = false,
    this.blocking = false,
    this.preferredPlacement = OnboardingCardPlacement.auto,
    this.spotlightShape = OnboardingSpotlightShape.roundedRect,
    this.arrowDirection = OnboardingArrowDirection.none,
    this.icon,
    this.delay = Duration.zero,
    this.condition,
    this.customCardBuilder,
  });

  final String id;
  final String title;
  final String description;
  final String? targetId;

  final bool optional;
  final bool blocking;

  final OnboardingCardPlacement preferredPlacement;
  final OnboardingSpotlightShape spotlightShape;
  final OnboardingArrowDirection arrowDirection;

  final IconData? icon;
  final Duration delay;
  final bool Function()? condition;
  final WidgetBuilder? customCardBuilder;
}

class OnboardingFlowDefinition {
  const OnboardingFlowDefinition({
    required this.id,
    required this.version,
    required this.steps,
    this.defaultInteractionMode = OnboardingInteractionMode.guided,
  });

  final String id;
  final int version;
  final List<OnboardingStep> steps;
  final OnboardingInteractionMode defaultInteractionMode;
}
