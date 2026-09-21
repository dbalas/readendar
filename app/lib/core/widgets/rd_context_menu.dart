import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

/// Long-press context actions.
///
/// Apple: [CupertinoContextMenu] preview + action list. Material: long-press
/// opens [showRdMenu]. Prefer this over feature-local long-press handlers.
class RdContextMenu extends StatelessWidget {
  const RdContextMenu({
    required this.child,
    required this.items,
    required this.onSelected,
    super.key,
    this.title,
  });

  final Widget child;
  final List<RdMenuItem<String>> items;
  final ValueChanged<String> onSelected;
  final String? title;

  Future<void> _openMaterialMenu(BuildContext context) async {
    unawaited(RdHaptics.selection());
    final picked = await showRdMenu<String>(
      context: context,
      title: title,
      items: items,
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!usesCupertinoChrome(context)) {
      return GestureDetector(
        onLongPress: () => unawaited(_openMaterialMenu(context)),
        child: child,
      );
    }

    return CupertinoContextMenu.builder(
      actions: [
        for (final item in items)
          if (item.enabled)
            CupertinoContextMenuAction(
              isDestructiveAction: item.destructive,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                unawaited(RdHaptics.selection());
                onSelected(item.value);
              },
              trailingIcon: item.icon,
              child: Text(item.label),
            ),
      ],
      builder: (context, animation) => child,
    );
  }
}
