import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

/// Drag wrapper for [ReorderableListView] rows: delayed long-press on the whole
/// [child] (no grip handle). Pair with swipe delete (`RdListItemActions`) so
/// long-press stays free for reorder on every platform.
class RdReorderableRow extends StatelessWidget {
  const RdReorderableRow({
    required this.index,
    required this.child,
    super.key,
    this.enabled = true,
  });

  final int index;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      enabled: enabled,
      child: child,
    );
  }
}

/// Elevates only the dragged card (transparent fill, rounded shadow).
///
/// Use as [ReorderableListView.proxyDecorator] with a rebuilt row that omits
/// list spacing / insets so Material does not paint the lateral gap or the
/// inter-row bottom padding.
@visibleForTesting
Widget rdReorderableDragProxy({
  required BuildContext context,
  required Animation<double> animation,
  required Widget child,
  double? borderRadius,
}) {
  final radius = borderRadius ?? context.componentStyle.cardRadius;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(animation.value);
      return Material(
        elevation: lerpDouble(0, 6, t)!,
        color: Colors.transparent,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    },
    child: child,
  );
}
