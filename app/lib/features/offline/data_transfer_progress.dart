import 'package:flutter/material.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/data/local/import_service.dart';

String importProgressLabel(AppL10n l, ImportProgress progress) {
  switch (progress.phase) {
    case ImportPhase.fetching:
      return l.profileExportInProgress;
    case ImportPhase.persisting:
      return l.migrationImportPersisting;
    case ImportPhase.covers:
      final done = progress.done ?? 0;
      final total = progress.total ?? 0;
      if (total <= 0) return l.migrationImportCovers;
      return l.migrationImportCoversProgress(done, total);
  }
}

/// Indeterminate or determinate bar with a short status line.
class DataTransferProgressBar extends StatelessWidget {
  const DataTransferProgressBar({
    required this.label,
    this.fraction,
    super.key,
  });

  final String label;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.fg2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (fraction != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction!.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colors.surface2,
              color: colors.accent,
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: colors.surface2,
              color: colors.accent,
            ),
          ),
      ],
    );
  }
}
