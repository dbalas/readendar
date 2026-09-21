// A widget preview wrapped as a tap target with an icon-only "+" "sticker" over
// its top-right corner. Shared by the events add button (tap = add directly)
// and the quotes hub entry (tap = open the config screen). Keeps the affordance
// identical across both widgets.

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

class WidgetPreviewCard extends StatelessWidget {
  const WidgetPreviewCard({
    required this.child,
    required this.onTap,
    required this.tooltip,
    super.key,
  });

  /// The preview to wrap — the whole thing becomes the tap target.
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
            child: child,
          ),
        ),
        // Icon-only "+" floating over the top-right corner — a "sticker" on the
        // current semantic accent so the installation affordance belongs to the
        // selected app theme in both brightness modes.
        Positioned(
          top: -6,
          right: -6,
          child: Tooltip(
            message: tooltip,
            child: Material(
              color: context.colors.accent,
              shape: CircleBorder(
                side: BorderSide(color: context.colors.surface1, width: 2),
              ),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    LucideIcons.plus,
                    size: 18,
                    color: context.colors.fgOnAccent,
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
