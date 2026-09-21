import 'dart:async';

import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/count_badge.dart';

/// Slightly taller than [kTextTabBarHeight] for the recessed pill track.
const kRdSectionTabBarHeight = 52.0;

/// One in-screen section tab (label, optional icon, optional count badge).
class RdSectionTab {
  const RdSectionTab({
    required this.label,
    this.icon,
    this.count,
  });

  final String label;
  final IconData? icon;

  /// When non-null and greater than 0, a [CountBadge] sits beside the label.
  final int? count;
}

/// In-screen section tabs — unified pill track on every platform.
///
/// Full rounded row (recessed track) with a sliding active pill (solid primary
/// [ReadendarColors.accent] fill + [ReadendarColors.fgOnAccent] labels — no
/// outline, no shadow/blur). The pill follows [TabController.animation] when a
/// controller is provided (same continuous slide as Material's tab indicator);
/// otherwise it animates between discrete [index] values.
///
/// Intentional exception to adaptive Material/Cupertino chrome: section tabs
/// share one look so Android and iOS stay visually identical here.
///
/// When [controller] is provided, selection stays in sync with a [TabBarView].
/// Otherwise use [index] + [onChanged].
///
/// [preferredSize] always matches [kRdSectionTabBarHeight] so [AppBar.bottom] and
/// [SliverPersistentHeader] layoutExtent equals paintExtent.
class RdSectionTabs extends StatefulWidget implements PreferredSizeWidget {
  const RdSectionTabs({
    required this.tabs,
    super.key,
    this.controller,
    this.index,
    this.onChanged,
    this.isScrollable = false,
  }) : assert(
         controller != null || (index != null && onChanged != null),
         'Provide either a TabController or index+onChanged',
       );

  /// Finds the recessed pill track in widget tests.
  static const trackKey = ValueKey<String>('rd_section_tabs_track');

  /// Finds the sliding active pill in widget tests.
  static const activePillKey = ValueKey<String>('rd_section_tabs_active_pill');

  final List<RdSectionTab> tabs;
  final TabController? controller;
  final int? index;
  final ValueChanged<int>? onChanged;

  /// Kept for API compatibility; pill tabs are equal-width and not scrollable.
  final bool isScrollable;

  @override
  Size get preferredSize => const Size.fromHeight(kRdSectionTabBarHeight);

  @override
  State<RdSectionTabs> createState() => _RdSectionTabsState();
}

class _RdSectionTabsState extends State<RdSectionTabs> {
  /// Set on tap so label styling updates immediately while the pill animates.
  int? _tapTarget;

  void _select(int i) {
    unawaited(RdHaptics.selection());
    final c = widget.controller;
    if (c != null && c.index != i) {
      setState(() => _tapTarget = i);
      c.animateTo(i);
    } else if (widget.index != i) {
      setState(() => _tapTarget = i);
    }
    widget.onChanged?.call(i);
  }

  void _syncTapTarget(TabController c) {
    if (_tapTarget == null) return;
    if (!c.indexIsChanging && c.index == _tapTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tapTarget != c.index) return;
        setState(() => _tapTarget = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c != null) {
      final anim = c.animation;
      return AnimatedBuilder(
        animation: anim ?? c,
        builder: (context, _) {
          _syncTapTarget(c);
          final position = (anim?.value ?? c.index.toDouble()).clamp(
            0.0,
            (widget.tabs.length - 1).toDouble(),
          );
          final labelPosition = _tapTarget?.toDouble() ?? position;
          return _PillSectionTabs(
            tabs: widget.tabs,
            position: position,
            labelPosition: labelPosition,
            discreteIndex: c.index.clamp(0, widget.tabs.length - 1),
            animateDiscrete: false,
            onChanged: _select,
          );
        },
      );
    }
    final i = widget.index!.clamp(0, widget.tabs.length - 1);
    final visualPosition = _tapTarget?.toDouble() ?? i.toDouble();
    if (_tapTarget == i) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tapTarget != widget.index) return;
        setState(() => _tapTarget = null);
      });
    }
    return _PillSectionTabs(
      tabs: widget.tabs,
      position: visualPosition,
      labelPosition: visualPosition,
      discreteIndex: i,
      animateDiscrete: true,
      onChanged: _select,
    );
  }
}

class _SectionTabLabel extends StatelessWidget {
  const _SectionTabLabel({
    required this.tab,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.iconSize,
    required this.gap,
    required this.color,
    required this.fontWeight,
  });

  final RdSectionTab tab;
  final Color badgeColor;
  final Color badgeTextColor;
  final double iconSize;
  final double gap;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final count = tab.count;
    final showBadge = count != null && count > 0;
    final style = TextStyle(
      color: color,
      fontWeight: fontWeight,
      fontSize: 13,
      height: 1.1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (tab.icon != null) ...[
          Icon(tab.icon, size: iconSize, color: color),
          SizedBox(width: gap),
        ],
        Flexible(
          child: Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (showBadge) ...[
          SizedBox(width: gap),
          CountBadge(
            count: count,
            color: badgeColor,
            textColor: badgeTextColor,
            size: 16,
          ),
        ],
      ],
    );
  }
}

class _PillSectionTabs extends StatelessWidget {
  const _PillSectionTabs({
    required this.tabs,
    required this.position,
    required this.labelPosition,
    required this.discreteIndex,
    required this.animateDiscrete,
    required this.onChanged,
  });

  final List<RdSectionTab> tabs;
  final double position;
  final double labelPosition;
  final int discreteIndex;
  final bool animateDiscrete;
  final ValueChanged<int> onChanged;

  static const _trackInset = 3.0;

  Alignment _pillAlignment(double t) {
    final n = tabs.length;
    if (n <= 1) return Alignment.center;
    return Alignment(-1.0 + 2.0 * t / (n - 1), 0);
  }

  double _labelActivation(int index) =>
      (1.0 - (labelPosition - index).abs()).clamp(0.0, 1.0);

  Widget _pillTabHitTarget({
    required ReadendarColors colors,
    required RdSectionTab tab,
    required double activation,
    required VoidCallback? onTap,
  }) {
    final t = activation;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _SectionTabLabel(
            tab: tab,
            // Invert badge on the primary pill so the count stays readable.
            badgeColor: Color.lerp(colors.accent, colors.fgOnAccent, t)!,
            badgeTextColor: Color.lerp(colors.fgOnAccent, colors.accent, t)!,
            iconSize: 14,
            gap: 4,
            color: Color.lerp(colors.fg3, colors.fgOnAccent, t)!,
            fontWeight: FontWeight.lerp(FontWeight.w500, FontWeight.w600, t)!,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = tabs.length;
    final trackColor = Color.alphaBlend(c.fg1.withValues(alpha: 0.06), c.bg);
    final pillRadius = BorderRadius.circular(ReadendarTokens.radiusPill);

    // Solid primary fill (opaque in both themes). Labels use [fgOnAccent] —
    // paper white on light periwinkle, dark ink on the brighter dark accent.
    final pill = FractionallySizedBox(
      widthFactor: n == 0 ? 1 : 1 / n,
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.all(_trackInset),
        child: DecoratedBox(
          key: RdSectionTabs.activePillKey,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: pillRadius,
          ),
        ),
      ),
    );

    final slidingPill = animateDiscrete
        ? AnimatedAlign(
            duration: ReadendarMotion.standard,
            curve: ReadendarMotion.curve,
            alignment: _pillAlignment(position),
            child: pill,
          )
        : Align(alignment: _pillAlignment(position), child: pill);

    return SizedBox(
      height: kRdSectionTabBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ReadendarTokens.sp4,
          vertical: 4,
        ),
        child: DecoratedBox(
          key: RdSectionTabs.trackKey,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: pillRadius,
          ),
          child: Stack(
            children: [
              Positioned.fill(child: slidingPill),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: _pillTabHitTarget(
                        colors: c,
                        tab: tabs[i],
                        activation: _labelActivation(i),
                        onTap: i == discreteIndex ? null : () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
