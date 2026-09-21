import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

/// Trailing swipe actions on a list row (Mail-style reveal).
///
/// Owns the card chrome (radius, hairline, shadow) so the Delete strip and the
/// sliding content share one rounded clip. The child should be card-less
/// content (`BookRow(card: false)`). Same gesture on every platform so long-press
/// stays free for reorder (`RdReorderableRow`).
class RdListItemActions extends StatelessWidget {
  const RdListItemActions({
    required this.child,
    required this.items,
    required this.onSelected,
    super.key,
    this.title,
    this.extent = 88,
    this.backgroundColor,
    this.border,
  });

  final Widget child;
  final List<RdMenuItem<String>> items;
  final ValueChanged<String> onSelected;

  /// Unused; kept for call-site compatibility with menu-style APIs.
  final String? title;

  /// Width of each trailing swipe action.
  final double extent;

  /// Optional override for the sliding panel fill (defaults to surface).
  final Color? backgroundColor;

  /// Optional outer border (pin / highlight). Keeps the delete strip inside
  /// the same framed chrome as the sliding content.
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final enabled = items.where((i) => i.enabled).toList(growable: false);
    if (enabled.isEmpty) return child;

    return _SwipeActions(
      items: enabled,
      onSelected: onSelected,
      extent: extent,
      backgroundColor: backgroundColor,
      border: border,
      child: child,
    );
  }
}

class _SwipeActions extends StatefulWidget {
  const _SwipeActions({
    required this.child,
    required this.items,
    required this.onSelected,
    required this.extent,
    required this.backgroundColor,
    required this.border,
  });

  final Widget child;
  final List<RdMenuItem<String>> items;
  final ValueChanged<String> onSelected;
  final double extent;
  final Color? backgroundColor;
  final BorderSide? border;

  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle;

  double get _maxExtent => widget.extent * widget.items.length;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _settle.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _settle.value = (_settle.value - delta).clamp(0.0, _maxExtent);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Commit early: a short swipe should still open the full action panel,
    // not leave a thin red crescent at the card edge.
    final open = _settle.value > _maxExtent * 0.22 || velocity < -180;
    _settle.animateTo(
      open ? _maxExtent : 0.0,
      duration: Duration(milliseconds: open ? 260 : 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _close() {
    if (_settle.value == 0) return;
    _settle.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _onAction(RdMenuItem<String> item) {
    widget.onSelected(item.value);
    unawaited(RdHaptics.selection());
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cs = Theme.of(context).colorScheme;
    final style = context.componentStyle;
    final radius = BorderRadius.circular(style.cardRadius);
    final surface = widget.backgroundColor ?? cs.surface;
    final side =
        widget.border ??
        BorderSide(color: cs.outline, width: style.borderWidth);
    final slidingChild = RepaintBoundary(child: widget.child);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: style.cardShadow,
      ),
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rowWidth = constraints.maxWidth;
            return AnimatedBuilder(
              animation: _settle,
              child: slidingChild,
              builder: (context, child) {
                final offset = _settle.value;
                final open = offset > 0.5;
                return Stack(
                  children: [
                    // Always mounted so the first drag reveals a full panel,
                    // not a one-frame empty strip.
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: _maxExtent,
                      child: Row(
                        children: [
                          for (final item in widget.items)
                            SizedBox(
                              width: widget.extent,
                              child: Material(
                                color: item.destructive
                                    ? colors.danger
                                    : colors.accent,
                                child: InkWell(
                                  key: ValueKey<String>(
                                    'rd-swipe-action-${item.value}',
                                  ),
                                  onTap: () => _onAction(item),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (item.icon != null)
                                        Icon(
                                          item.icon,
                                          color: colors.fgOnAccent,
                                          size: 22,
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.fgOnAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      key: const ValueKey<String>('rd-swipe-slider'),
                      offset: Offset(-offset, 0),
                      child: GestureDetector(
                        onHorizontalDragStart: _handleDragStart,
                        onHorizontalDragUpdate: _handleDragUpdate,
                        onHorizontalDragEnd: _handleDragEnd,
                        onTap: open ? _close : null,
                        behavior: open
                            ? HitTestBehavior.opaque
                            : HitTestBehavior.deferToChild,
                        // Full-width opaque slab: parent clips to card radius,
                        // so settle-to-open reveals the entire Delete panel.
                        child: SizedBox(
                          width: rowWidth,
                          child: Material(
                            color: surface,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
