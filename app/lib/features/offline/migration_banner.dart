import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/data/local/import_service.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/auth/magic_link_deep_link.dart';
import 'package:readendar/features/offline/cloud_import_auth.dart';
import 'package:readendar/features/offline/data_transfer_progress.dart';
import 'package:readendar/features/offline/migration_prompt_modal.dart';

/// Presents the offline migration prompt once, then a Home row until import.
class MigrationBanner extends ConsumerStatefulWidget {
  const MigrationBanner({super.key});

  @override
  ConsumerState<MigrationBanner> createState() => _MigrationBannerState();
}

class _MigrationBannerState extends ConsumerState<MigrationBanner> {
  bool _scheduled = false;
  bool _presenting = false;
  bool _importing = false;
  ImportProgress? _importProgress;

  bool get _importAvailable => ref.watch(cloudImportAvailableProvider);

  bool _showHomeRow() {
    if (!_importAvailable) return false;
    try {
      return ref.read(prefsStorageProvider).isMigrationPromptDismissed();
    } on Object {
      return false;
    }
  }

  bool _shouldPresentModal() {
    if (!_importAvailable) return false;
    try {
      final prefs = ref.read(prefsStorageProvider);
      return !prefs.isMigrationPromptDismissed();
    } on Object {
      return false;
    }
  }

  String _formattedDate() =>
      DateFormat("d 'de' MMM 'de' y", 'es').format(apiShutdownAt.toLocal());

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(magicLinkSignedInTickProvider, (previous, next) {
      if (previous == next || !_importAvailable || _importing) return;
      if (ref.read(cloudImportInFlightProvider)) return;
      unawaited(_importFromApi());
    });
    if (_shouldPresentModal()) {
      if (!_scheduled) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentIfNeeded());
      }
    } else {
      _scheduled = false;
    }
    if (!_showHomeRow()) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final c = context.colors;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: RdCard(
        backgroundColor: c.accentSoftBg,
        borderColor: c.accent.withValues(alpha: 0.28),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.download,
                    size: 22,
                    color: c.fgOnAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.migrationHomeRowTitle,
                        key: const Key('migrationHomeRow'),
                        style: theme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: c.fg1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.migrationHomeRowBody(_formattedDate()),
                        style: theme.bodySmall?.copyWith(
                          color: c.fg2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_importing && _importProgress != null) ...[
              const SizedBox(height: 10),
              DataTransferProgressBar(
                label: importProgressLabel(l, _importProgress!),
                fraction: _importProgress!.fraction,
              ),
            ] else ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: RdButton.primary(
                  compact: true,
                  icon: LucideIcons.download,
                  label: l.migrationBannerImport,
                  onPressed: _importing
                      ? null
                      : () => unawaited(_importFromApi()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _presentIfNeeded() async {
    if (_presenting || !mounted || !_shouldPresentModal()) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _presenting = true;
    final outcome = await showMigrationPromptModal(
      context,
      formattedShutdownDate: _formattedDate(),
      onImport: (onProgress) => _importFromApi(onProgress: onProgress),
    );
    _presenting = false;
    if (!mounted) return;
    // Import closes the modal without an outcome; dismissal prefs follow import.
    if (outcome == null) return;
    if (outcome.result != MigrationPromptResult.imported) {
      await ref.read(prefsStorageProvider).setMigrationPromptDismissed(true);
    }
    setState(() {});
  }

  Future<bool> _importFromApi({
    void Function(ImportProgress progress)? onProgress,
  }) async {
    if (_importing || !tryBeginCloudImport(ref)) return false;
    setState(() => _importing = true);
    try {
      final authed = await ensureCloudImportAuth(context: context, ref: ref);
      if (!authed || !mounted) return false;
      setState(() {
        _importProgress = const ImportProgress(phase: ImportPhase.fetching);
      });
      onProgress?.call(_importProgress!);
      final result = await ref
          .read(importServiceProvider)
          .importFromApi(
            onProgress: (p) {
              if (mounted) setState(() => _importProgress = p);
              onProgress?.call(p);
            },
          );
      if (!mounted) return false;
      setState(() {
        _importing = false;
        _importProgress = null;
      });
      final l = AppL10n.of(context);
      if (result.isOk) {
        await ref.read(secureStorageProvider).clear();
        if (!mounted) return true;
        ref.read(cloudImportAvailableProvider.notifier).state = false;
        await ref.read(prefsStorageProvider).setMigrationPromptDismissed(true);
        await ref.read(prefsStorageProvider).setMigrationBannerHidden(true);
        if (!mounted) return true;
        showRdToast(
          context,
          message: l.migrationImportSuccess,
          tone: RdToastTone.success,
        );
        await ref.read(sessionProvider.notifier).bootstrap();
        ref.invalidate(booksProvider);
        ref.invalidate(upcomingEventsProvider);
        return true;
      }
      showRdToast(
        context,
        message: l.migrationImportFailure,
        tone: RdToastTone.error,
      );
      return false;
    } finally {
      endCloudImport(ref);
      if (mounted && _importing) {
        setState(() {
          _importing = false;
          _importProgress = null;
        });
      }
    }
  }
}
