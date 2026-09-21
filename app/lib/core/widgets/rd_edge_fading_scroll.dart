import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';

/// Horizontal scroller with soft edge fades that appear only when more content
/// exists (or the scroll offset has moved) on that side.
///
/// Prefer putting this as a direct child of a clipped surface; pass [padding]
/// for inner inset of the scrolled content.
class RdEdgeFadingScrollView extends StatefulWidget {
  const RdEdgeFadingScrollView({
    required this.child,
    super.key,
    this.scrollKey,
    this.controller,
    this.padding,
    this.fadeWidth = 20,
    this.surfaceColor,
  });

  final Widget child;
  final Key? scrollKey;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final double fadeWidth;

  /// Optional fill behind the fade (matches toolbar surface). The visible
  /// cue is a soft ink shadow, not a surface-to-surface blend.
  final Color? surfaceColor;

  static const startShadowKey = Key('rd_edge_fade_start');
  static const endShadowKey = Key('rd_edge_fade_end');

  @override
  State<RdEdgeFadingScrollView> createState() => _RdEdgeFadingScrollViewState();
}

class _RdEdgeFadingScrollViewState extends State<RdEdgeFadingScrollView> {
  ScrollController? _owned;
  bool _showStart = false;
  bool _showEnd = false;
  bool _updateScheduled = false;

  ScrollController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = ScrollController();
    }
    _controller.addListener(_scheduleUpdate);
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(covariant RdEdgeFadingScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _owned)?.removeListener(_scheduleUpdate);
      if (oldWidget.controller == null) {
        _owned?.dispose();
        _owned = null;
      }
      if (widget.controller == null) {
        _owned = ScrollController();
      }
      _controller.addListener(_scheduleUpdate);
      _scheduleUpdate();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scheduleUpdate);
    _owned?.dispose();
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      _updateEdges();
    });
  }

  void _updateEdges() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final showStart = position.pixels > position.minScrollExtent + 0.5;
    final showEnd = position.pixels < position.maxScrollExtent - 0.5;
    if (showStart == _showStart && showEnd == _showEnd) return;
    setState(() {
      _showStart = showStart;
      _showEnd = showEnd;
    });
  }

  Widget _edgeFade({required bool start}) {
    final surface = widget.surfaceColor ?? context.colors.surface1;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final peak = dark ? 0.08 : 0.03;
    final mid = dark ? 0.03 : 0.01;
    return Positioned(
      key: start
          ? RdEdgeFadingScrollView.startShadowKey
          : RdEdgeFadingScrollView.endShadowKey,
      left: start ? 0 : null,
      right: start ? null : 0,
      top: 0,
      bottom: 0,
      width: widget.fadeWidth,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: start ? Alignment.centerLeft : Alignment.centerRight,
              end: start ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                surface,
                surface.withValues(alpha: 0.96),
                surface.withValues(alpha: 0.72),
                surface.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.25, 0.65, 1.0],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: start ? Alignment.centerLeft : Alignment.centerRight,
                end: start ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  context.colors.fg1.withValues(alpha: peak),
                  context.colors.fg1.withValues(alpha: mid),
                  context.colors.fg1.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        _scheduleUpdate();
        return Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.hardEdge,
          children: [
            SingleChildScrollView(
              key: widget.scrollKey,
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              child: widget.child,
            ),
            if (_showStart) _edgeFade(start: true),
            if (_showEnd) _edgeFade(start: false),
          ],
        );
      },
    );
  }
}
