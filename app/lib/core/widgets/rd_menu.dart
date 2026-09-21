import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/bottom_sheet_safe_area.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

/// One entry in an adaptive overflow / action menu.
class RdMenuItem<T> {
  const RdMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
    this.enabled = true,
    this.selected = false,
    this.color,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
  final bool enabled;

  /// Marks the current value in picker-style menus (trailing check).
  final bool selected;

  /// Optional label color. When null, [destructive] maps to error/danger.
  final Color? color;

  /// Optional icon-only color. When null, falls back to [color], then
  /// destructive danger, then the theme accent (primary).
  final Color? iconColor;
}

/// Presents a platform menu: glass modal sheet on Apple platforms,
/// Material [PopupMenuButton]-style bottom sheet / popup elsewhere.
///
/// Prefer [RdOverflowMenu] when the trigger is a trailing AppBar icon.
/// Pass [selectedValue] for picker menus so the current choice shows a check.
Future<T?> showRdMenu<T>({
  required BuildContext context,
  required List<RdMenuItem<T>> items,
  String? title,
  T? selectedValue,
}) {
  bool isSelected(RdMenuItem<T> item) =>
      item.selected || (selectedValue != null && item.value == selectedValue);

  if (usesCupertinoChrome(context)) {
    return showRdModalSheet<T>(
      context: context,
      builder: (_) => _RdIosMenuSheet<T>(
        title: title,
        items: items.where((item) => item.enabled).toList(),
        isSelected: isSelected,
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    sheetAnimationStyle: readendarOverlayAnimationStyle,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      Color? itemColor(RdMenuItem<T> item) =>
          item.color ??
          (item.destructive ? Theme.of(sheetContext).colorScheme.error : null);
      Color itemIconColor(RdMenuItem<T> item) => rdSheetItemIconColor(
        sheetContext,
        color: item.iconColor ?? item.color,
        destructive: item.destructive,
      );
      final viewPadding = MediaQuery.viewPaddingOf(sheetContext);
      final maxHeight =
          MediaQuery.sizeOf(sheetContext).height -
          viewPadding.top -
          viewPadding.bottom;
      return ReadendarFadeIn(
        child: BottomSheetSafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    ListTile(
                      title: Text(
                        title,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                  for (final item in items)
                    ListTile(
                      enabled: item.enabled,
                      leading: item.icon == null
                          ? null
                          : Icon(item.icon, color: itemIconColor(item)),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: isSelected(item) ? FontWeight.w700 : null,
                          color: itemColor(item),
                        ),
                      ),
                      trailing: isSelected(item)
                          ? Icon(
                              LucideIcons.check,
                              size: 18,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            )
                          : null,
                      onTap: item.enabled
                          ? () => Navigator.of(sheetContext).pop(item.value)
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// AppBar / trailing overflow trigger that opens [showRdMenu].
///
/// Material: classic [PopupMenuButton]. Cupertino: icon button → glass sheet.
class RdOverflowMenu<T> extends StatelessWidget {
  const RdOverflowMenu({
    required this.items,
    required this.onSelected,
    super.key,
    this.icon = LucideIcons.ellipsisVertical,
    this.tooltip,
    this.title,
  });

  final List<RdMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final IconData icon;
  final String? tooltip;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: () async {
          final value = await showRdMenu<T>(
            context: context,
            items: items,
            title: title,
          );
          if (value != null) onSelected(value);
        },
      );
    }
    return PopupMenuButton<T>(
      icon: Icon(icon),
      tooltip: tooltip,
      popUpAnimationStyle: readendarOverlayAnimationStyle,
      onSelected: onSelected,
      itemBuilder: (menuContext) {
        return [
          for (final item in items)
            PopupMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              child: _RdPopupMenuRow(item: item),
            ),
        ];
      },
    );
  }
}

/// Popup row: optional leading icon, label, trailing check when [RdMenuItem.selected].
class _RdPopupMenuRow<T> extends StatelessWidget {
  const _RdPopupMenuRow({required this.item});

  final RdMenuItem<T> item;

  @override
  Widget build(BuildContext context) {
    final color =
        item.color ??
        (item.destructive ? Theme.of(context).colorScheme.error : null);
    final iconColor = rdSheetItemIconColor(
      context,
      color: item.iconColor ?? item.color,
      destructive: item.destructive,
    );
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            item.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: item.selected ? FontWeight.w700 : null,
              color: color,
            ),
          ),
        ),
        if (item.selected) ...[
          const SizedBox(width: 12),
          Icon(
            LucideIcons.check,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );
  }
}

/// Glass modal sheet body for Apple menus. Same IA as Material [ListTile]
/// without Material list chrome or a Cancel plate.
class _RdIosMenuSheet<T> extends StatelessWidget {
  const _RdIosMenuSheet({
    required this.items,
    required this.isSelected,
    this.title,
  });

  final String? title;
  final List<RdMenuItem<T>> items;
  final bool Function(RdMenuItem<T> item) isSelected;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final maxHeight =
        (MediaQuery.sizeOf(context).height -
            viewPadding.top -
            viewPadding.bottom) *
        0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: ReadendarTokens.sp4),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return _RdIosMenuRow<T>(
                  item: item,
                  selected: isSelected(item),
                  onTap: () {
                    unawaited(RdHaptics.selection());
                    Navigator.of(context).pop(item.value);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RdIosMenuRow<T> extends StatelessWidget {
  const _RdIosMenuRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final RdMenuItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelColor = item.color ?? (item.destructive ? c.danger : c.fg1);
    final iconColor = rdSheetItemIconColor(
      context,
      color: item.iconColor ?? item.color,
      destructive: item.destructive,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 20, color: iconColor),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: item.destructive || selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  Icon(LucideIcons.check, size: 18, color: c.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
