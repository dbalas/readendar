import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

/// A row of page-indicator dots for the onboarding tour. The active dot widens
/// into a pill tinted with [activeColor]; the indicator interpolates smoothly
/// because it's driven by the live fractional [page] value from the
/// `PageController`, not a settled integer index.
class OnboardingPageDots extends StatelessWidget {
  const OnboardingPageDots({
    required this.count,
    required this.page,
    required this.activeColor,
    super.key,
  });

  final int count;
  final double page;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) _dot(i, context.colors),
      ],
    );
  }

  Widget _dot(int i, ReadendarColors c) {
    // 1.0 at the active page, fading to 0 for neighbours.
    final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 8 + 16 * t,
      height: 8,
      decoration: BoxDecoration(
        color: Color.lerp(c.lineStrong, activeColor, t),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
    );
  }
}
