import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/widgets/settings_group.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/data/local/import_service.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/offline/cloud_import_auth.dart';
import 'package:readendar/features/offline/data_transfer_progress.dart';
import 'package:share_plus/share_plus.dart';

class SettingsDataGroup extends ConsumerStatefulWidget {
  const SettingsDataGroup({super.key});

  @override
  ConsumerState<SettingsDataGroup> createState() => _SettingsDataGroupState();
}

class _SettingsDataGroupState extends ConsumerState<SettingsDataGroup> {
  bool _exporting = false;
  String? _exportLabel;
  double? _exportFraction;

  bool _importing = false;
  ImportProgress? _importProgress;

  bool _restoring = false;
  ImportProgress? _restoreProgress;

  Future<void> _exportData() async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _exporting = true;
      _exportLabel = l.profileExportPreparing;
      _exportFraction = null;
    });
    if (ref.read(dataPlaneProvider) == DataPlane.local) {
      try {
        final dir = await getTemporaryDirectory();
        final dest = Directory(
          '${dir.path}/readendar-backup-${DateTime.now().microsecondsSinceEpoch}',
        );
        await ref.read(importServiceProvider).writeZipBackup(dest);
        if (!mounted) return;
        setState(() => _exportLabel = l.profileExportSharing);
        final zip = File('${dest.path}/readendar-backup.zip');
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zip.path, mimeType: 'application/zip')],
            subject: l.profileExportTitle,
          ),
        );
      } on Object {
        if (!mounted) return;
        showRdToast(
          context,
          messenger: messenger,
          tone: RdToastTone.error,
          message: l.errorGeneric,
        );
      } finally {
        if (mounted) {
          setState(() {
            _exporting = false;
            _exportLabel = null;
            _exportFraction = null;
          });
        }
      }
      return;
    }
    final result = await ref.read(userRepoProvider).exportData();
    if (!mounted) return;
    if (!result.isOk) {
      setState(() {
        _exporting = false;
        _exportLabel = null;
      });
      showRdFailureToast(context, result.failure!, messenger: messenger);
      return;
    }
    setState(() => _exportLabel = l.profileExportSharing);
    final dir = await getTemporaryDirectory();
    try {
      final dest = Directory(
        '${dir.path}/readendar-backup-${DateTime.now().microsecondsSinceEpoch}',
      );
      final serverArchive = jsonDecode(result.value!) as Map<String, dynamic>;
      final zip = await ref
          .read(importServiceProvider)
          .writeZipBackupFromServerArchive(dest, serverArchive);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zip.path, mimeType: 'application/zip')],
          subject: l.profileExportTitle,
        ),
      );
    } on Object {
      if (mounted) {
        showRdToast(
          context,
          messenger: messenger,
          tone: RdToastTone.error,
          message: l.errorGeneric,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportLabel = null;
        });
      }
    }
  }

  Future<void> _importFromApi() async {
    if (_importing || !tryBeginCloudImport(ref)) return;
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final authed = await ensureCloudImportAuth(context: context, ref: ref);
      if (!authed || !mounted) return;
      setState(() {
        _importProgress = const ImportProgress(phase: ImportPhase.fetching);
      });
      final result = await ref
          .read(importServiceProvider)
          .importFromApi(
            onProgress: (p) {
              if (mounted) setState(() => _importProgress = p);
            },
          );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importProgress = null;
      });
      if (result.isOk) {
        await ref.read(secureStorageProvider).clear();
        if (!mounted) return;
        ref.read(cloudImportAvailableProvider.notifier).state = false;
        await ref.read(prefsStorageProvider).setMigrationBannerHidden(true);
        await ref.read(prefsStorageProvider).setMigrationPromptDismissed(true);
        if (!mounted) return;
        showRdToast(
          context,
          messenger: messenger,
          message: l.migrationImportSuccess,
          tone: RdToastTone.success,
        );
        await ref.read(sessionProvider.notifier).bootstrap();
        if (!mounted) return;
        ref.invalidate(booksProvider);
        ref.invalidate(upcomingEventsProvider);
      } else {
        showRdToast(
          context,
          messenger: messenger,
          message: l.migrationImportFailure,
          tone: RdToastTone.error,
        );
      }
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

  Future<void> _restoreBackup() async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'readendar',
          extensions: ['zip', 'json'],
        ),
      ],
    );
    if (picked == null) return;
    setState(() {
      _restoring = true;
      _restoreProgress = const ImportProgress(phase: ImportPhase.persisting);
    });
    try {
      await ref
          .read(importServiceProvider)
          .restoreBackupFile(
            File(picked.path),
            onProgress: (p) {
              if (mounted) setState(() => _restoreProgress = p);
            },
          );
      if (!mounted) return;
      await ref.read(sessionProvider.notifier).bootstrap();
      ref.invalidate(booksProvider);
      ref.invalidate(upcomingEventsProvider);
      showRdToast(
        context,
        messenger: messenger,
        message: l.settingsRestoreZipDone,
      );
    } on Object {
      if (!mounted) return;
      showRdToast(
        context,
        messenger: messenger,
        tone: RdToastTone.error,
        message: l.errorGeneric,
      );
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
          _restoreProgress = null;
        });
      }
    }
  }

  Widget? _progressBelow(String label, double? fraction) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DataTransferProgressBar(label: label, fraction: fraction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final showCloudImport = ref.watch(cloudImportAvailableProvider);
    return SettingsGroup(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: LucideIcons.download,
              title: l.profileExportData,
              description: l.profileExportHint,
              onTap: _exporting ? null : _exportData,
            ),
            if (_exporting && _exportLabel != null)
              _progressBelow(_exportLabel!, _exportFraction)!,
          ],
        ),
        if (showCloudImport)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsRow(
                icon: LucideIcons.archive,
                title: l.settingsImportLocal,
                description: l.settingsImportLocalHint,
                onTap: _importing ? null : _importFromApi,
              ),
              if (_importing && _importProgress != null)
                _progressBelow(
                  importProgressLabel(l, _importProgress!),
                  _importProgress!.fraction,
                )!,
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: LucideIcons.folderOpen,
              title: l.settingsRestoreZip,
              description: l.settingsRestoreZipHint,
              onTap: _restoring ? null : _restoreBackup,
            ),
            if (_restoring && _restoreProgress != null)
              _progressBelow(
                importProgressLabel(l, _restoreProgress!),
                _restoreProgress!.fraction,
              )!,
          ],
        ),
      ],
    );
  }
}
