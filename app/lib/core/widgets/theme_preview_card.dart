import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_background.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/rd_progress.dart';

/// Reusable, platform-adaptive theme choice with a live component preview.
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({
    required this.definition,
    required this.label,
    required this.brightness,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    this.busy = false,
    this.previewHeight = 132,
    super.key,
  });

  final ReadendarThemeDefinition definition;
  final String label;
  final Brightness brightness;
  final bool selected;
  final bool enabled;
  final bool busy;
  final double previewHeight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final previewTheme = brightness == Brightness.dark
        ? buildDarkTheme(themeId: definition.id)
        : buildLightTheme(themeId: definition.id);
    final outerColors = context.colors;
    final frameRadius = BorderRadius.circular(18);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: outerColors.surface1,
        borderRadius: frameRadius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: frameRadius,
        border: Border.all(
          color: selected ? outerColors.accent : outerColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: previewTheme,
        child: SizedBox(
          height: previewHeight,
          child: ReadendarThemeBackground(
            key: Key('themePreviewBackground-${definition.id.wire}'),
            animateEffects: definition.isPremium,
            child: Builder(
              builder: (previewContext) => Stack(
                fit: StackFit.expand,
                children: [
                  if (definition.isPremium)
                    _PremiumThemePreview(
                      definition: definition,
                      label: label,
                    )
                  else
                    _MiniThemePreview(label: label),
                  if (busy || selected)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _PreviewStatusBadge(
                        busy: busy,
                        icon: Icons.check_rounded,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final interactive = usesCupertinoChrome(context)
        ? IgnorePointer(
            ignoring: !enabled,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onPressed,
              child: content,
            ),
          )
        : Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: frameRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: frameRadius,
              onTap: enabled ? onPressed : null,
              child: content,
            ),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: ExcludeSemantics(child: interactive),
    );
  }
}

class _PremiumThemePreview extends StatelessWidget {
  const _PremiumThemePreview({required this.definition, required this.label});

  final ReadendarThemeDefinition definition;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.componentStyle;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panelStart = colors.surface1.withValues(alpha: dark ? 0.78 : 0.86);
    final panelEnd = colors.surface1.withValues(alpha: dark ? 0.62 : 0.72);
    return Stack(
      key: Key('premiumIdentityPreview-${definition.id.wire}'),
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [panelStart, panelEnd]),
              borderRadius: BorderRadius.circular(style.cardRadius),
              border: Border.all(
                color: colors.lineStrong.withValues(alpha: dark ? 0.58 : 0.46),
                width: style.borderWidth,
              ),
              boxShadow: style.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(style.controlRadius),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.bookOpen,
                    size: 19,
                    color: colors.fgOnAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.accent, colors.accent2],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 24,
                            height: 3,
                            decoration: BoxDecoration(
                              color: colors.lineStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewStatusBadge extends StatelessWidget {
  const _PreviewStatusBadge({required this.busy, required this.icon});

  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: busy ? colors.surface1 : colors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface1, width: 2),
      ),
      alignment: Alignment.center,
      child: busy
          ? RdProgress(color: colors.accent)
          : Icon(icon, size: 18, color: colors.fgOnAccent),
    );
  }
}

class _MiniThemePreview extends StatelessWidget {
  const _MiniThemePreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.componentStyle;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 56,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(style.controlRadius),
            ),
            child: Center(
              child: Icon(LucideIcons.bookOpen, color: colors.fgOnAccent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(style.cardRadius),
                border: Border.all(
                  color: colors.line,
                  width: style.borderWidth,
                ),
                boxShadow: style.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.72,
                    child: Container(height: 5, color: colors.accent2),
                  ),
                  const SizedBox(height: 6),
                  FractionallySizedBox(
                    widthFactor: 0.48,
                    child: Container(height: 4, color: colors.lineStrong),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
