import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/theme_labels.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/theme_preview_card.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/theme_selection.dart';
import 'package:readendar/features/profile/premium_themes_screen.dart';
import 'package:readendar/features/profile/theme_selection_feedback.dart';

class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final selected = ref.watch(effectiveReadendarThemeProvider);
    final selection = ref.watch(themeSelectionControllerProvider);
    final brightness = Theme.of(context).brightness;
    final items = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          l.themesIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      _PremiumThemesSettingsRow(
        key: const Key('premiumThemesEntry'),
        title: l.premiumThemesEntryTitle,
        subtitle: l.premiumThemesHeroTitle,
        onPressed: () => Navigator.of(context).push(
          rdPageRoute<void>(
            context,
            builder: (_) => const PremiumThemesScreen(),
          ),
        ),
      ),
      for (final definition in ReadendarThemes.standard)
        ThemePreviewCard(
          key: ValueKey(definition.id),
          definition: definition,
          label: readendarThemeLabel(l, definition.id),
          brightness: brightness,
          selected: definition.id == selected,
          enabled: !selection.isSaving,
          busy: definition.id == selection.pendingTheme,
          onPressed: () => selectThemeWithFeedback(
            context,
            ref,
            definition.id,
          ),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.themesTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

/// Compact navigation treatment for the premium theme collection.
///
/// It deliberately uses settings-row proportions rather than a theme preview:
/// the collection is a destination, not a selectable theme. The accent wash
/// marks a special product surface without competing with the theme choices
/// below.
class _PremiumThemesSettingsRow extends StatelessWidget {
  const _PremiumThemesSettingsRow({
    required this.title,
    required this.subtitle,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(ReadendarTokens.radiusLg);
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accentSoftBg, colors.accent2SoftBg],
              ),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.accent, colors.accent2],
                      ),
                      borderRadius: BorderRadius.circular(
                        ReadendarTokens.radiusSm,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 18,
                      color: colors.fgOnAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: colors.fg1,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: colors.fg2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: colors.accentSoftFg,
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
