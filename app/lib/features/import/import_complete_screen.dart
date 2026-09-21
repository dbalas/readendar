import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/improve_covers_screen.dart';
import 'package:readendar/features/import/import_progress_screen.dart';
import 'package:readendar/features/library/library_pane.dart';

/// Celebratory wrap-up of an import (Q9): confetti + the headline counts, then
/// the optional "fix covers" path and a way back to the library.
class ImportCompleteScreen extends ConsumerStatefulWidget {
  const ImportCompleteScreen({required this.summary, super.key});

  final ImportSummary summary;

  @override
  ConsumerState<ImportCompleteScreen> createState() =>
      _ImportCompleteScreenState();
}

class _ImportCompleteScreenState extends ConsumerState<ImportCompleteScreen> {
  late final ConfettiController _rain;

  @override
  void initState() {
    super.initState();
    _rain = ConfettiController(duration: const Duration(seconds: 4));
    // Only celebrate when something actually landed — and never when the user
    // has asked the OS to reduce motion (P3-C, accessibility).
    if (widget.summary.added > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (!reduceMotion) _rain.play();
      });
    }
  }

  @override
  void dispose() {
    _rain.dispose();
    super.dispose();
  }

  void _goToLibrary() {
    openLibrosTab(ref);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _improveCovers() {
    // Push (not replace) so a back gesture from the covers screen returns here,
    // to the summary — rather than skipping back to the stale intro picker that
    // still sits beneath the finished import flow.
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => ImproveCoversScreen(books: widget.summary.noCoverBooks),
      ),
    );
  }

  /// Re-runs the import with only the books that failed, so a transient network
  /// blip doesn't force a full re-import of the whole file (P1-A).
  void _retryFailed() {
    Navigator.of(context).pushReplacement(
      rdPageRoute<void>(
        context,
        builder: (_) => ImportProgressScreen(
          books: widget.summary.failedBooks,
          // Skip any that actually landed (committed but lost their response)
          // so a retry can never duplicate them.
          dedupAgainstLibrary: true,
        ),
      ),
    );
  }

  /// The wrap-up actions, ordered by priority. Only the first button is filled
  /// so we never show two competing primary actions.
  List<Widget> _actions(AppL10n l, ImportSummary s) {
    final buttons = <Widget>[];
    if (s.noCover > 0) {
      buttons.add(
        RdButton.primary(
          onPressed: _improveCovers,
          icon: LucideIcons.imagePlus,
          label: l.importImproveCovers(s.noCover),
        ),
      );
    }
    if (s.failed > 0 && s.failedBooks.isNotEmpty) {
      buttons.add(
        buttons.isEmpty
            ? RdButton.primary(
                onPressed: _retryFailed,
                icon: LucideIcons.refreshCw,
                label: l.importRetryFailed(s.failedBooks.length),
              )
            : RdButton.secondary(
                onPressed: _retryFailed,
                icon: LucideIcons.refreshCw,
                label: l.importRetryFailed(s.failedBooks.length),
              ),
      );
    }
    buttons.add(
      buttons.isEmpty
          ? RdButton.primary(
              onPressed: _goToLibrary,
              icon: LucideIcons.bookOpen,
              label: l.importGoToLibrary,
            )
          : RdButton.secondary(
              onPressed: _goToLibrary,
              label: l.importGoToLibrary,
            ),
    );

    final out = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) out.add(const SizedBox(height: ReadendarTokens.sp3));
      out.add(buttons[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = widget.summary;

    // The import is done and the intro/picker screens still sit beneath us in
    // the stack. A back gesture here should finish the flow into the library,
    // not drop the user back on the file picker mid-celebration.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToLibrary();
      },
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _rain,
                blastDirection: math.pi / 2,
                emissionFrequency: 0.05,
                maxBlastForce: 18,
                minBlastForce: 8,
                gravity: 0.25,
                colors: ReadendarTokens.confettiColors,
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(ReadendarTokens.sp6),
                children: [
                  const SizedBox(height: ReadendarTokens.sp6),
                  Icon(
                    s.cancelled
                        ? LucideIcons.circleStop
                        : LucideIcons.partyPopper,
                    size: 56,
                    color: context.colors.accent,
                  ),
                  const SizedBox(height: ReadendarTokens.sp4),
                  Text(
                    s.cancelled
                        ? l.importCancelledTitle
                        : l.importCompleteTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.colors.accent,
                    ),
                  ),
                  const SizedBox(height: ReadendarTokens.sp2),
                  Text(
                    l.importCompleteSubtitle(s.added),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.fg2,
                    ),
                  ),
                  const SizedBox(height: ReadendarTokens.sp6),
                  RdCard(
                    child: Column(
                      children: [
                        _StatRow(
                          icon: LucideIcons.check,
                          color: context.colors.success,
                          label: l.importStatAdded,
                          value: s.added,
                        ),
                        if (s.noCover > 0)
                          _StatRow(
                            icon: LucideIcons.imageOff,
                            color: context.colors.warning,
                            label: l.importStatNoCover,
                            value: s.noCover,
                          ),
                        if (s.failed > 0)
                          _StatRow(
                            icon: LucideIcons.triangleAlert,
                            color: context.colors.danger,
                            label: l.importStatFailed,
                            value: s.failed,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ReadendarTokens.sp6),
                  ..._actions(l, s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ReadendarTokens.sp2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: ReadendarTokens.sp3),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
