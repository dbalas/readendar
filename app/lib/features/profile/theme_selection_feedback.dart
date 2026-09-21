import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/theme_selection.dart';

Future<void> selectThemeWithFeedback(
  BuildContext context,
  WidgetRef ref,
  ReadendarThemeId id,
) async {
  final outcome = await ref
      .read(themeSelectionControllerProvider.notifier)
      .select(id);
  if (!context.mounted || outcome == ThemeSelectionOutcome.unchanged) return;
  final l = AppL10n.of(context);
  showRdToast(
    context,
    tone: switch (outcome) {
      ThemeSelectionOutcome.applied => RdToastTone.success,
      ThemeSelectionOutcome.appliedWithWidgetWarning ||
      ThemeSelectionOutcome.failed ||
      ThemeSelectionOutcome.notEntitled => RdToastTone.error,
      ThemeSelectionOutcome.unchanged => RdToastTone.neutral,
    },
    message: switch (outcome) {
      ThemeSelectionOutcome.applied => l.themeApplied,
      ThemeSelectionOutcome.appliedWithWidgetWarning =>
        l.themeWidgetSyncWarning,
      ThemeSelectionOutcome.failed => l.themeSaveError,
      ThemeSelectionOutcome.notEntitled => l.premiumThemeUnavailable,
      ThemeSelectionOutcome.unchanged => '',
    },
  );
}
