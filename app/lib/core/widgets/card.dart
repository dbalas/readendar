import 'package:flutter/material.dart';

import 'package:readendar/core/theme/theme_catalog.dart';

/// A surface card following the design's soft-shadow + hairline style.
class RdCard extends StatelessWidget {
  const RdCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = context.componentStyle;
    final radius = BorderRadius.circular(style.cardRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(
        color: borderColor ?? cs.outline,
        width: style.borderWidth,
      ),
    );
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: style.cardShadow,
        gradient: gradient,
      ),
      child: Material(
        color: gradient == null
            ? backgroundColor ?? cs.surface
            : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: radius, child: content),
      ),
    );
  }
}
