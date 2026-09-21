import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

/// One root shell destination.
class RdNavDestination {
  const RdNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
}

/// Root bottom navigation.
///
/// Apple: floating [RdGlassPanel] pill with glass items. Material: same
/// translucent glass shell with compact destinations whose selected/hover
/// stadium covers icon + label (end items align with the pill edge).
/// Same index/callback contract on both.
class RdRootNavBar extends StatelessWidget {
  const RdRootNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Test / semantics key for the iOS glass shell.
  static const iosBarKey = Key('rd_root_nav_bar_ios');

  /// Test / semantics key for the Android floating glass shell.
  static const androidBarKey = Key('rd_root_nav_bar_android');

  /// Compact Material destination row height inside the glass pill.
  static const double materialBarHeight = 56;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<RdNavDestination> destinations;

  /// Stronger lift so the translucent pill separates from paper / night canvas.
  static List<BoxShadow> materialNavShadows(Brightness brightness) =>
      brightness == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0xA6000000),
            offset: Offset(0, 10),
            blurRadius: 28,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Color(0x73000000),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x3D0F1014), // ~24% ink-900
            offset: Offset(0, 10),
            blurRadius: 28,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Color(0x1F0F1014), // ~12% ink-900
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ];

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return _RdGlassRootNavBar(
        key: iosBarKey,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      );
    }
    return _RdMaterialFloatingRootNavBar(
      key: androidBarKey,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
  }
}

class _RdMaterialFloatingRootNavBar extends StatelessWidget {
  const _RdMaterialFloatingRootNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<RdNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navTheme = theme.navigationBarTheme;
    final brightness = theme.brightness;
    final indicator =
        navTheme.indicatorColor ?? theme.colorScheme.secondaryContainer;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RdRootNavBarMetrics.horizontalPad,
          0,
          RdRootNavBarMetrics.horizontalPad,
          RdRootNavBarMetrics.bottomPad,
        ),
        child: RdGlassPanel(
          borderRadius: RdGlassPanel.pillRadius,
          boxShadow: RdRootNavBar.materialNavShadows(brightness),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: RdRootNavBar.materialBarHeight,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _RdMaterialNavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        indicatorColor: indicator,
                        iconColor: navTheme.iconTheme?.resolve({
                          if (i == selectedIndex) WidgetState.selected,
                        })?.color,
                        labelStyle: navTheme.labelTextStyle?.resolve({
                          if (i == selectedIndex) WidgetState.selected,
                        }),
                        onTap: () {
                          if (i == selectedIndex) return;
                          onDestinationSelected(i);
                        },
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

/// Full-height stadium item: selected/hover fill covers icon + label so end
/// tabs share the pill's rounded edge.
class _RdMaterialNavItem extends StatelessWidget {
  const _RdMaterialNavItem({
    required this.destination,
    required this.selected,
    required this.indicatorColor,
    required this.onTap,
    this.iconColor,
    this.labelStyle,
  });

  final RdNavDestination destination;
  final bool selected;
  final Color indicatorColor;
  final Color? iconColor;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final fg = iconColor ?? (selected ? theme.colorScheme.primary : c.fg3);
    final icon = selected
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;
    final textStyle =
        (labelStyle ??
                TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ))
            .copyWith(
              fontSize: 9,
              height: 1,
              letterSpacing: -0.1,
              color: labelStyle?.color ?? fg,
            );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      // Full-height stadium: end caps are r=28 at barHeight 56, matching
      // [RdGlassPanel.pillRadius] so edge tabs share the container curve.
      child: Material(
        color: selected ? indicatorColor : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            // Vertical pad trades 1px each side for a clearer icon↔label gap;
            // bar height stays [RdRootNavBar.materialBarHeight].
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: fg, size: 20),
                  child: icon,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RdGlassRootNavBar extends StatelessWidget {
  const _RdGlassRootNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<RdNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RdRootNavBarMetrics.horizontalPad,
          0,
          RdRootNavBarMetrics.horizontalPad,
          RdRootNavBarMetrics.bottomPad,
        ),
        child: RdGlassPanel(
          borderRadius: RdGlassPanel.pillRadius,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: RdRootNavBarMetrics.barHeight,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _RdGlassNavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () {
                          if (i == selectedIndex) return;
                          onDestinationSelected(i);
                        },
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

class _RdGlassNavItem extends StatelessWidget {
  const _RdGlassNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final RdNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.accent : c.fg3;
    final icon = selected
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          // Vertical pad trades 1px each side for a clearer icon↔label gap;
          // bar height stays [RdRootNavBarMetrics.barHeight].
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: fg, size: 22),
                child: icon,
              ),
              const SizedBox(height: 5),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
