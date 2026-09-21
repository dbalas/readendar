import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/plan/domain/replan.dart';
import 'package:readendar/features/plan/presentation/plan_screen.dart';

/// Loads the live events of [run] (those still tagged with its plan id), derives
/// the [ReplanState], and pushes [PlanScreen] in replan mode. Shared by the plan
/// history card and the book detail launcher. Returns false (with a snackbar)
/// when the events can't be loaded or nothing is left to replan.
Future<bool> openReplan(
  BuildContext context,
  WidgetRef ref, {
  required Book book,
  required PlanRun run,
  Progress? progress,
}) async {
  final l = AppL10n.of(context);
  final res = await ref.read(eventRepoProvider).listAllForBook(book.id);
  if (!context.mounted) return false;
  final events = res.value;
  if (events == null) {
    _snack(context, l.planFailed);
    return false;
  }
  final planEvents = events
      .where((e) => e.planId == run.id)
      .toList(growable: false);
  final state = buildReplanState(
    planEvents,
    run: run,
    book: book,
    now: DateTime.now(),
  );
  if (state == null) {
    _snack(context, l.planReplanNothing);
    return false;
  }
  await Navigator.of(context).push(
    rdPageRoute<void>(
      context,
      builder: (_) => PlanScreen(
        book: book,
        progress: progress,
        replan: ReplanLaunch(
          planId: run.id,
          state: state,
          allBookEvents: events,
        ),
      ),
    ),
  );
  return true;
}

void _snack(BuildContext context, String message) {
  showRdToast(context, tone: RdToastTone.error, message: message);
}
