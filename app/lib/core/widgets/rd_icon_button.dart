import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/utils/platform_chrome.dart';

/// Platform-adaptive icon action for toolbars and inline controls.
class RdIconButton extends StatelessWidget {
  const RdIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.color,
    this.size = 20,
    this.compact = false,
    this.padding,
    this.constraints,
    this.visualDensity,
    this.style,
  }) : child = null;

  /// Toolbar control whose visual is not a single [IconData] (badges, stacks).
  const RdIconButton.custom({
    required this.child,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.color,
    this.size = 20,
    this.compact = false,
    this.padding,
    this.constraints,
    this.visualDensity,
    this.style,
  }) : icon = null;

  /// Dense 28×28 control for inline rows. Cupertino still uses this size
  /// instead of the 44pt toolbar minimum.
  const RdIconButton.compact({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.color,
    this.size = 18,
    this.padding,
    this.constraints,
    this.visualDensity = VisualDensity.compact,
    this.style,
  }) : child = null,
       compact = true;

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final bool compact;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;
  final ButtonStyle? style;

  Widget get _visual => child ?? Icon(icon, size: size, color: color);

  @override
  Widget build(BuildContext context) {
    if (!usesCupertinoChrome(context)) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: color,
        visualDensity: visualDensity ?? (compact ? VisualDensity.compact : null),
        padding: padding,
        constraints:
            constraints ??
            (compact ? const BoxConstraints(minWidth: 28, minHeight: 28) : null),
        style:
            style ??
            (compact
                ? IconButton.styleFrom(
                    foregroundColor: color,
                    padding: padding ?? const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null),
        icon: _visual,
      );
    }
    final dimension = compact
        ? (constraints?.minWidth ?? 28)
        : 44.0;
    final button = SizedBox.square(
      dimension: dimension,
      child: CupertinoButton(
        padding: padding ?? EdgeInsets.zero,
        onPressed: onPressed,
        child: _visual,
      ),
    );
    final tooltipMessage = tooltip;
    if (tooltipMessage == null || tooltipMessage.isEmpty) return button;
    return Tooltip(message: tooltipMessage, child: button);
  }
}
