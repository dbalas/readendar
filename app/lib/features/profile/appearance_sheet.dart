import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/option_selector.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';

/// Localized label for a stored [ThemeMode].
String appearanceLabel(AppL10n l, ThemeMode mode) => switch (mode) {
  ThemeMode.light => l.appearanceLight,
  ThemeMode.dark => l.appearanceDark,
  ThemeMode.system => l.appearanceSystem,
};

/// Icon for the stored appearance choice.
///
/// Light and Dark use sun/moon. System uses the same sun/moon as the OS
/// brightness so the control matches what the app currently looks like
/// (the picker still uses a distinct System glyph).
IconData appearanceIcon(ThemeMode mode, Brightness platformBrightness) =>
    switch (mode) {
      ThemeMode.light => LucideIcons.sun,
      ThemeMode.dark => LucideIcons.moon,
      ThemeMode.system =>
        platformBrightness == Brightness.dark
            ? LucideIcons.moon
            : LucideIcons.sun,
    };

/// Opens the Light / Dark / System picker and persists the selection.
///
/// Pushes only the theme key into home-screen widgets (no session mint). A
/// full `syncWidget` on theme flip previously raced App Group I/O + WidgetKit
/// reloads against the MaterialApp rebuild and could take down the iOS process.
Future<void> showAppearanceSheet(BuildContext context, WidgetRef ref) async {
  final l = AppL10n.of(context);
  final current = ref.read(themeModeProvider);
  final next = await showOptionSelectorSheet<ThemeMode>(
    context: context,
    label: l.profileAppearance,
    value: current,
    items: [
      OptionSelectorItem(
        value: ThemeMode.light,
        label: l.appearanceLight,
        icon: LucideIcons.sun,
      ),
      OptionSelectorItem(
        value: ThemeMode.dark,
        label: l.appearanceDark,
        icon: LucideIcons.moon,
      ),
      OptionSelectorItem(
        value: ThemeMode.system,
        label: l.appearanceSystem,
        icon: LucideIcons.monitor,
      ),
    ],
  );
  if (next == null || next == current) return;
  // Let the sheet route finish tearing down before MaterialApp swaps themes.
  await Future<void>.delayed(Duration.zero);
  await ref.read(themeModeProvider.notifier).setMode(next);
  unawaited(pushWidgetTheme(next));
}
