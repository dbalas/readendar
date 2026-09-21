import 'package:flutter/material.dart';

/// Builds the animated "hero" illustration for a slide. The `entrance` value is
/// the slide's scroll "reveal" (0 when off-centre, 1 when centred), so the hero
/// animates in/out smoothly with the swipe instead of snapping on a settle.
typedef OnboardingHeroBuilder = Widget Function(double entrance);

/// One page of the first-run feature tour: an accent colour, a Lucide icon, a
/// localized title/subtitle and a bespoke animated hero. Pure data — the screen
/// owns layout and animation.
@immutable
class OnboardingSlide {
  const OnboardingSlide({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.heroBuilder,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final OnboardingHeroBuilder heroBuilder;
}
