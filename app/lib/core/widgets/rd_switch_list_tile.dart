import 'dart:async';

import 'package:flutter/material.dart';

import 'package:readendar/core/utils/rd_haptics.dart';

/// Settings-style toggle row with a platform-adaptive switch.
///
/// Same role as [SwitchListTile] on every platform; Cupertino switch chrome on
/// iOS/macOS via [Switch.adaptive].
class RdSwitchListTile extends StatelessWidget {
  const RdSwitchListTile({
    required this.value,
    required this.onChanged,
    super.key,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.isThreeLine = false,
    this.switchOnSubtitle = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool isThreeLine;

  /// Place the switch on the subtitle row so [title] can use the full width
  /// beside [secondary]. No-op when [subtitle] is null.
  final bool switchOnSubtitle;

  void _set(bool next) {
    unawaited(RdHaptics.selection());
    onChanged?.call(next);
  }

  Widget _switch() => Switch.adaptive(
    value: value,
    onChanged: onChanged == null ? null : _set,
  );

  @override
  Widget build(BuildContext context) {
    final onSubtitle = switchOnSubtitle && subtitle != null;
    return ListTile(
      contentPadding: contentPadding,
      dense: dense,
      isThreeLine: isThreeLine,
      leading: secondary,
      title: title,
      subtitle: onSubtitle
          ? Row(
              children: [
                Expanded(child: subtitle!),
                const SizedBox(width: 8),
                _switch(),
              ],
            )
          : subtitle,
      trailing: onSubtitle ? null : _switch(),
      onTap: onChanged == null ? null : () => _set(!value),
    );
  }
}
