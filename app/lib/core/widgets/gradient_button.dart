import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// A full-width filled button with a colourful gradient, used for the app's
/// "special", core launchers (book roulette, reading-plan generator) so they
/// stand apart from the plain filled/outlined actions.
///
/// Pass a null [onPressed] to render it disabled (the gradient dims).
/// Pill-shaped on Apple; Material radius on Android.
class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = const [
      ReadendarTokens.periwinkle500,
      ReadendarTokens.teal500,
    ],
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = usesCupertinoChrome(context)
        ? ReadendarTokens.radiusPill
        : ReadendarTokens.radiusSm;
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: ReadendarTokens.paper50,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: ReadendarTokens.paper50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            onPressed: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: ReadendarTokens.sp3),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
