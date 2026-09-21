import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/theme_labels.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/settings_group.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/debug/debug_screen.dart';
import 'package:readendar/features/notifications/notification_settings_screen.dart';
import 'package:readendar/features/profile/app_behavior_settings_screen.dart';
import 'package:readendar/features/profile/appearance_sheet.dart';
import 'package:readendar/features/profile/profile_editor_screen.dart';
import 'package:readendar/features/profile/settings_data_group.dart';
import 'package:readendar/features/profile/themes_screen.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

/// App settings, reached from the gear icon in the "Tú" tab. Holds the
/// low-frequency configuration that used to crowd the Profile screen:
/// preferences, local profile, data backup, legal, and (debug-only)
/// maintenance. Feature hubs (stats, quotes, roulette, import, widgets) live in
/// the "Tú" tab instead — this screen is deliberately just settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final appTheme = ref.watch(readendarThemeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: LucideIcons.user,
                  title: l.profileEditTitle,
                  description: l.profileTimezone,
                  onTap: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const ProfileEditorScreen(),
                    ),
                  ),
                ),
                SettingsRow(
                  icon: LucideIcons.slidersHorizontal,
                  title: l.settingsAppBehaviorTitle,
                  description: l.settingsAppBehaviorSubtitle,
                  onTap: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const AppBehaviorSettingsScreen(),
                    ),
                  ),
                ),
                SettingsRow(
                  icon: appearanceIcon(
                    themeMode,
                    MediaQuery.platformBrightnessOf(context),
                  ),
                  title: l.profileAppearance,
                  description: appearanceLabel(l, themeMode),
                  onTap: () => showAppearanceSheet(context, ref),
                ),
                SettingsRow(
                  icon: LucideIcons.palette,
                  title: l.profileThemes,
                  description: readendarThemeLabel(l, appTheme),
                  onTap: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const ThemesScreen(),
                    ),
                  ),
                ),
                SettingsRow(
                  icon: LucideIcons.bell,
                  title: l.profileNotifications,
                  onTap: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SettingsDataGroup(),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: LucideIcons.shield,
                  title: l.profilePrivacy,
                  onTap: () => _openLegal(
                    context,
                    privacyPolicyUrl('es'),
                  ),
                ),
                SettingsRow(
                  icon: LucideIcons.fileText,
                  title: l.legalTerms,
                  onTap: () => _openLegal(
                    context,
                    termsOfUseUrl('es'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: LucideIcons.trash2,
                  title: l.settingsWipeLocal,
                  destructive: true,
                  onTap: () => _wipeLocal(context, ref),
                ),
              ],
            ),
            // Debug builds only: a maintenance screen with destructive data wipes.
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: LucideIcons.wrench,
                    title: l.profileDebugTools,
                    onTap: () => Navigator.of(context).push(
                      rdPageRoute<void>(
                        context,
                        builder: (_) => const DebugScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _wipeLocal(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      icon: LucideIcons.trash2,
      title: l.settingsWipeLocal,
      message: l.settingsWipeLocalConfirm,
      confirmLabel: l.settingsWipeLocal,
      confirmIcon: LucideIcons.trash2,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(localStoreProvider).clearAll();
      await ref.read(prefsStorageProvider).clearImportCheckpoint();
      await ref.read(prefsStorageProvider).setLocalProfileJson('');
      await ref.read(prefsStorageProvider).setDataPlane('local');
      await ref.read(prefsStorageProvider).setMigrationPromptDismissed(true);
      await ref.read(secureStorageProvider).clear();
      ref.read(dataPlaneTickProvider.notifier).state++;
      ref.read(cloudImportAvailableProvider.notifier).state = false;
      await clearWidgetData();
      await ref.read(sessionProvider.notifier).bootstrap();
      ref.invalidate(booksProvider);
      ref.invalidate(upcomingEventsProvider);
      ref.invalidateCalendarEvents(clearCache: true);
      ref.invalidatePersonalStats();
      ref.read(tabIndexProvider.notifier).state = 0;
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on Object {
      if (context.mounted) {
        showRdToast(
          context,
          tone: RdToastTone.error,
          message: l.errorGeneric,
        );
      }
    }
  }

  Future<void> _openLegal(BuildContext context, Uri uri) async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch returned false');
    } catch (_) {
      if (!context.mounted) return;
      showRdToast(
        context,
        messenger: messenger,
        tone: RdToastTone.error,
        message: l.errorGeneric,
      );
    }
  }
}
