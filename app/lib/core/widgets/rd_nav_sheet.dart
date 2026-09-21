import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/bottom_sheet_safe_area.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

/// One destination row in [showRdNavSheet].
class RdNavSheetItem {
  const RdNavSheetItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool destructive;
  final VoidCallback onTap;
}

/// Section of nav destinations (optional header).
class RdNavSheetSection {
  const RdNavSheetSection({required this.items, this.header});

  final String? header;
  final List<RdNavSheetItem> items;
}

/// Platform nav sheet that replaces Material end-drawers for “more”
/// destinations. Glass modal sheet on Apple; Material bottom sheet elsewhere.
///
/// This is a destination list, not a choice menu. Do not route it through
/// [showRdMenu] (that owns overflow actions).
Future<void> showRdNavSheet({
  required BuildContext context,
  required List<RdNavSheetSection> sections,
  String? title,
}) async {
  Widget body(BuildContext sheetContext) => _RdNavSheetBody(
    title: title,
    sections: sections,
  );

  if (usesCupertinoChrome(context)) {
    await showRdModalSheet<void>(
      context: context,
      builder: body,
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: readendarOverlayAnimationStyle,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ReadendarFadeIn(
      child: BottomSheetSafeArea(
        child: SafeArea(
          child: body(sheetContext),
        ),
      ),
    ),
  );
}

class _RdNavSheetBody extends StatelessWidget {
  const _RdNavSheetBody({required this.sections, this.title});

  final String? title;
  final List<RdNavSheetSection> sections;

  @override
  Widget build(BuildContext context) {
    final ios = usesCupertinoChrome(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: ReadendarTokens.sp4),
        children: [
          if (title != null)
            ios
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : ListTile(
                    title: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
          for (final section in sections) ...[
            if (section.header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  section.header!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.colors.fg3,
                  ),
                ),
              ),
            for (final item in section.items)
              ios
                  ? _IosNavRow(item: item)
                  : ListTile(
                      leading: item.icon == null
                          ? null
                          : Icon(
                              item.icon,
                              color: rdSheetItemIconColor(
                                context,
                                destructive: item.destructive,
                              ),
                            ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: item.destructive
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                      subtitle: item.subtitle == null
                          ? null
                          : Text(item.subtitle!),
                      trailing: item.destructive
                          ? null
                          : const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () {
                        Navigator.of(context).pop();
                        item.onTap();
                      },
                    ),
          ],
        ],
      ),
    );
  }
}

/// Destination row for the iOS glass modal sheet. Same IA as Material
/// [ListTile] (icon, label, chevron) without Material list chrome.
class _IosNavRow extends StatelessWidget {
  const _IosNavRow({required this.item});

  final RdNavSheetItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = item.destructive ? c.danger : c.fg1;
    final iconColor = rdSheetItemIconColor(
      context,
      destructive: item.destructive,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: item.destructive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(fontSize: 13, color: c.fg3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.destructive) ...[
                  const SizedBox(width: 12),
                  Icon(LucideIcons.chevronRight, size: 18, color: c.fg3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
