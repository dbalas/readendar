import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';

/// One segment in an adaptive segmented control.
class RdSegment<T extends Object> {
  const RdSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Mode toggle: [CupertinoSlidingSegmentedControl] on Apple platforms and a
/// branded tonal Material pill on Android.
class RdSegmentedControl<T extends Object> extends StatelessWidget {
  const RdSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
    this.expanded = true,
  });

  final List<RdSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expanded;

  @visibleForTesting
  static const ValueKey<String> trackKey = ValueKey('rd-segmented-track');

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      final children = <T, Widget>{
        for (final s in segments)
          s.value: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: s.icon == null
                ? Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
      };
      final control = CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        children: children,
        onValueChanged: (v) {
          if (v == null) return;
          unawaited(RdHaptics.selection());
          onChanged(v);
        },
      );
      if (!expanded) return control;
      return SizedBox(width: double.infinity, child: control);
    }
    final control = _MaterialSegmentedControl<T>(
      segments: segments,
      selected: selected,
      onChanged: onChanged,
      expanded: expanded,
    );
    return expanded
        ? SizedBox(width: double.infinity, child: control)
        : control;
  }
}

class _MaterialSegmentedControl<T extends Object> extends StatelessWidget {
  const _MaterialSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.expanded,
  });

  final List<RdSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final children = <Widget>[
      for (final segment in segments)
        _MaterialSegmentItem<T>(
          segment: segment,
          selected: segment.value == selected,
          onChanged: onChanged,
          textStyle: textTheme.labelLarge,
        ),
    ];

    return DecoratedBox(
      key: RdSegmentedControl.trackKey,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ReadendarTokens.sp2),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: expanded
              ? [for (final child in children) Expanded(child: child)]
              : children,
        ),
      ),
    );
  }
}

class _MaterialSegmentItem<T extends Object> extends StatelessWidget {
  const _MaterialSegmentItem({
    required this.segment,
    required this.selected,
    required this.onChanged,
    required this.textStyle,
  });

  final RdSegment<T> segment;
  final bool selected;
  final ValueChanged<T> onChanged;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = selected ? c.fgOnAccent : c.fg2;
    final radius = BorderRadius.circular(ReadendarTokens.radiusCard);

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        key: selected ? ValueKey('rd-segmented-active-${segment.value}') : null,
        duration: ReadendarMotion.standard,
        curve: ReadendarMotion.curve,
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: selected
                ? null
                : () {
                    unawaited(RdHaptics.selection());
                    onChanged(segment.value);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ReadendarTokens.sp3,
                vertical: ReadendarTokens.sp2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon case final icon?) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: ReadendarTokens.sp2),
                  ],
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: ReadendarMotion.standard,
                      curve: ReadendarMotion.curve,
                      style: (textStyle ?? const TextStyle()).copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      child: Text(
                        segment.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
