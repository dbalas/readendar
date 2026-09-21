import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';

/// Platform-adaptive checkbox.
///
/// Material [Checkbox] on Android; Cupertino check glyph on Apple platforms.
class RdCheckbox extends StatelessWidget {
  const RdCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
    this.activeColor,
    this.tapTargetSize,
  });

  /// Visual size of the iOS checkbox glyph. Stock [CupertinoCheckbox] paints
  /// at 14px, which reads as a speck in list rows.
  static const double iosVisualSize = 22;

  /// Test key for the scaled iOS checkbox glyph.
  static const iosVisualKey = Key('rd_checkbox_ios_visual');

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;

  /// Hit-target / layout size. Null keeps the platform default (44pt on iOS).
  final Size? tapTargetSize;

  ValueChanged<bool?>? get _hapticOnChanged {
    final next = onChanged;
    if (next == null) return null;
    return (v) {
      unawaited(RdHaptics.selection());
      next(v);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      final hit =
          tapTargetSize ?? const Size.square(kMinInteractiveDimensionCupertino);
      return SizedBox(
        width: hit.width,
        height: hit.height,
        child: Center(
          child: SizedBox(
            key: iosVisualKey,
            width: iosVisualSize,
            height: iosVisualSize,
            child: FittedBox(
              child: CupertinoCheckbox(
                value: value,
                onChanged: _hapticOnChanged,
                activeColor: activeColor,
                tapTargetSize: const Size.square(CupertinoCheckbox.width),
              ),
            ),
          ),
        ),
      );
    }
    return Checkbox(
      value: value,
      onChanged: _hapticOnChanged,
      activeColor: activeColor,
      materialTapTargetSize: tapTargetSize == null
          ? null
          : MaterialTapTargetSize.shrinkWrap,
      visualDensity: tapTargetSize == null ? null : VisualDensity.compact,
    );
  }
}

/// Settings-style checkbox row with adaptive control chrome.
class RdCheckboxListTile extends StatelessWidget {
  const RdCheckboxListTile({
    required this.value,
    required this.onChanged,
    super.key,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.visualDensity,
    this.minTileHeight,
    this.titleTextStyle,
    this.controlAffinity = ListTileControlAffinity.platform,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final VisualDensity? visualDensity;
  final double? minTileHeight;
  final TextStyle? titleTextStyle;
  final ListTileControlAffinity controlAffinity;

  void _toggle() {
    unawaited(RdHaptics.selection());
    onChanged?.call(!value);
  }

  ListTileControlAffinity _resolvedAffinity(BuildContext context) {
    if (controlAffinity != ListTileControlAffinity.platform) {
      return controlAffinity;
    }
    return usesCupertinoChrome(context)
        ? ListTileControlAffinity.trailing
        : ListTileControlAffinity.leading;
  }

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      final affinity = _resolvedAffinity(context);
      // Tile owns the tap; ignore the control so iOS does not double-toggle.
      final control = IgnorePointer(
        child: RdCheckbox(value: value, onChanged: onChanged),
      );
      final leading = affinity == ListTileControlAffinity.trailing
          ? secondary
          : control;
      final trailing = affinity == ListTileControlAffinity.trailing
          ? control
          : secondary;
      // ListTile requires a Material ancestor. CupertinoAlertDialog (and other
      // Apple chrome) does not provide one, so wrap transparently.
      return Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: contentPadding,
          dense: dense,
          visualDensity: visualDensity,
          minTileHeight: minTileHeight,
          titleTextStyle: titleTextStyle,
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: onChanged == null ? null : _toggle,
        ),
      );
    }
    final tile = CheckboxListTile(
      value: value,
      onChanged: onChanged == null
          ? null
          : (v) {
              unawaited(RdHaptics.selection());
              onChanged!(v);
            },
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      contentPadding: contentPadding,
      dense: dense,
      visualDensity: visualDensity,
      minTileHeight: minTileHeight,
      controlAffinity: controlAffinity,
    );
    if (titleTextStyle == null) return tile;
    return ListTileTheme.merge(titleTextStyle: titleTextStyle, child: tile);
  }
}
