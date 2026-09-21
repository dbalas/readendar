import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/theme_labels.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/settings_group.dart';
import 'package:readendar/core/widgets/theme_preview_card.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/theme_selection.dart';
import 'package:readendar/features/profile/theme_selection_feedback.dart';

class PremiumThemesScreen extends ConsumerWidget {
  const PremiumThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final selected = ref.watch(effectiveReadendarThemeProvider);
    final selection = ref.watch(themeSelectionControllerProvider);
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(title: Text(l.premiumThemesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final definition in ReadendarThemes.premium) ...[
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
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          SettingsGroup(
            children: [
              RdSwitchListTile(
                key: const Key('premiumCoverAtmosphereToggle'),
                value: ref.watch(premiumCoverAtmosphereProvider),
                onChanged: (enabled) async {
                  final saved = await ref
                      .read(premiumCoverAtmosphereProvider.notifier)
                      .setEnabled(enabled);
                  if (!saved && context.mounted) {
                    showRdToast(
                      context,
                      tone: RdToastTone.error,
                      message: l.premiumCoverAtmosphereSaveError,
                    );
                  }
                },
                title: Text(l.premiumCoverAtmosphereTitle),
                subtitle: Text(l.premiumCoverAtmosphereHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
