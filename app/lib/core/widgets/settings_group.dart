import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// Bordered settings surface with consistent internal dividers.
///
/// On iOS/macOS uses inset-grouped styling (larger corner radius, no hard
/// outer border — hairline dividers only) to match Settings-like lists.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    super.key,
    this.dividerIndent = 56,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cupertino = usesCupertinoChrome(context);
    final themeStyle = context.componentStyle;
    final radius = cupertino ? themeStyle.cardRadius : themeStyle.controlRadius;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: cupertino
            ? null
            : Border.all(
                color: cs.outline,
                width: themeStyle.borderWidth,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(
                  indent: cupertino ? 16 : dividerIndent,
                  endIndent: 0,
                  height: 1,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Canonical navigation/destructive row inside a [SettingsGroup].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    super.key,
    this.description,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? description;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.danger : null;
    return ListTile(
      minLeadingWidth: 24,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: description == null ? null : Text(description!),
      trailing: destructive
          ? null
          : const Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
    );
  }
}
