import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';

/// Shared "event completed" badge — a filled sage circle with a white check.
///
/// Used everywhere a completion state is shown (event rows, event detail,
/// calendar day covers) so the indicator reads identically across the app.
/// The white ring keeps it legible when overlaid on a book cover.
class CompletedBadge extends StatelessWidget {
  const CompletedBadge({super.key, this.size = 18});

  /// The completion color is also used by controls that mark an event done.
  static const Color fillColor = ReadendarTokens.sage600;
  static const Color foregroundColor = ReadendarTokens.paper50;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: foregroundColor,
          width: (size * 0.1).clamp(1.0, 2.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.6,
        color: foregroundColor,
      ),
    );
  }
}
