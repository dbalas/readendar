import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/brand_wordmark.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/data/local/import_service.dart';
import 'package:readendar/features/offline/data_transfer_progress.dart';
import 'package:url_launcher/url_launcher.dart';

typedef MigrationImportHandler =
    Future<bool> Function(void Function(ImportProgress progress) onProgress);

enum MigrationPromptResult { imported, continued, dismissed }

class MigrationPromptOutcome {
  const MigrationPromptOutcome({
    required this.result,
    this.hideNextTime = false,
  });

  final MigrationPromptResult result;
  final bool hideNextTime;
}

/// Full-screen dimmed prompt to copy cloud library to this device before API
/// shutdown. Returns [MigrationPromptOutcome] with [MigrationPromptResult.imported]
/// when import succeeds.
Future<MigrationPromptOutcome?> showMigrationPromptModal(
  BuildContext context, {
  required String formattedShutdownDate,
  required MigrationImportHandler onImport,
}) {
  return showGeneralDialog<MigrationPromptOutcome>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secondary) => MigrationPromptModal(
      formattedShutdownDate: formattedShutdownDate,
      onImport: onImport,
    ),
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

@visibleForTesting
class MigrationPromptModal extends StatefulWidget {
  const MigrationPromptModal({
    required this.formattedShutdownDate,
    required this.onImport,
    super.key,
  });

  final String formattedShutdownDate;
  final MigrationImportHandler onImport;

  @override
  State<MigrationPromptModal> createState() => _MigrationPromptModalState();
}

class _MigrationPromptModalState extends State<MigrationPromptModal> {
  bool _hideNextTime = false;
  bool _busy = false;
  ImportProgress? _progress;

  Future<void> _runImport() async {
    if (_busy) return;
    _busy = true;
    final onImport = widget.onImport;
    if (!mounted) return;
    // Cloud import may open Google/Apple sign-in. Credential Manager and
    // ASWebAuthenticationSession are unreliable when a dimmed dialog still
    // covers the root navigator, so close this prompt before auth runs.
    Navigator.of(context).pop();
    await onImport((_) {});
  }

  void _continueLater() {
    Navigator.of(context).pop(
      MigrationPromptOutcome(
        result: MigrationPromptResult.continued,
        hideNextTime: _hideNextTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: constraints.maxHeight,
              child: Material(
                color: colors.surface1,
                elevation: 12,
                shadowColor: colors.fg1.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MigrationLogo(label: l.appName),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _MigrationPromptBody(
                            date: widget.formattedShutdownDate,
                            l: l,
                            colors: colors,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _busy
                            ? null
                            : () => setState(
                                () => _hideNextTime = !_hideNextTime,
                              ),
                        borderRadius: BorderRadius.circular(
                          ReadendarTokens.radiusSm,
                        ),
                        child: Row(
                          children: [
                            RdCheckbox(
                              value: _hideNextTime,
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(
                                      () => _hideNextTime = v ?? false,
                                    ),
                            ),
                            Expanded(
                              child: Text(
                                l.migrationBannerHide,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_busy && _progress != null) ...[
                        DataTransferProgressBar(
                          label: importProgressLabel(l, _progress!),
                          fraction: _progress!.fraction,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.center,
                        child: RdButton.primary(
                          onPressed: _busy ? null : _runImport,
                          icon: LucideIcons.download,
                          label: l.migrationBannerImport,
                          loading: _busy && _progress == null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RdButton.plain(
                        onPressed: _busy ? null : _continueLater,
                        label: l.migrationBannerContinue,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MigrationLogo extends StatelessWidget {
  const _MigrationLogo({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/icons/app-icon.svg',
          width: 64,
          height: 64,
          semanticsLabel: label,
        ),
        const SizedBox(height: 12),
        BrandWordmark(
          label: label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _MigrationPromptBody extends StatefulWidget {
  const _MigrationPromptBody({
    required this.date,
    required this.l,
    required this.colors,
  });

  final String date;
  final AppL10n l;
  final ReadendarColors colors;

  @override
  State<_MigrationPromptBody> createState() => _MigrationPromptBodyState();
}

class _MigrationPromptBodyState extends State<_MigrationPromptBody> {
  late final TapGestureRecognizer _repoLinkRecognizer;

  @override
  void initState() {
    super.initState();
    _repoLinkRecognizer = TapGestureRecognizer()
      ..onTap = () {
        unawaited(
          launchUrl(
            migrationOpenSourceRepoUri,
            mode: LaunchMode.externalApplication,
          ),
        );
      };
  }

  @override
  void dispose() {
    _repoLinkRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final colors = widget.colors;
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colors.fg2,
      height: 1.55,
    );
    final emphasis = base?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.fg1,
    );
    final dateStyle = base?.copyWith(
      fontWeight: FontWeight.w700,
      color: colors.fg1,
    );
    final link = base?.copyWith(
      color: colors.accentSoftFg,
      decoration: TextDecoration.underline,
      decorationColor: colors.accentSoftFg,
    );

    TextSpan span(String text, TextStyle? style) =>
        TextSpan(text: text, style: style);

    Widget paragraph(List<InlineSpan> children) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RichText(
          textAlign: TextAlign.start,
          text: TextSpan(style: base, children: children),
        ),
      );
    }

    return Column(
      key: const Key('migration_prompt_body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        paragraph([
          span(l.migrationBannerBodyP1Before, base),
          span(widget.date, dateStyle),
          span(l.migrationBannerBodyP1After, base),
        ]),
        paragraph([
          span(l.migrationBannerBodyP2Before, base),
          span(l.migrationBannerBodyP2EmphasisFunction, emphasis),
          span(l.migrationBannerBodyP2MidPrivacy, base),
          span(l.migrationBannerBodyP2EmphasisPrivacy, emphasis),
          span(l.migrationBannerBodyP2MidRepo, base),
          TextSpan(
            text: l.migrationBannerBodyP2LinkLabel,
            style: link,
            recognizer: _repoLinkRecognizer,
          ),
          span(l.migrationBannerBodyP2After, base),
        ]),
        paragraph([
          span(l.migrationBannerBodyP3Before, base),
          span(l.migrationBannerBodyP3Emphasis, emphasis),
          span(l.migrationBannerBodyP3After, base),
        ]),
      ],
    );
  }
}
