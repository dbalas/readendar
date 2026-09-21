import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/app_update/app_update_installed.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';
import 'package:readendar/features/app_update/app_update_play.dart';
import 'package:readendar/features/app_update/app_update_prompt.dart';
import 'package:readendar/features/product_feedback/product_feedback_eligibility.dart';
import 'package:readendar/features/product_feedback/product_feedback_modal.dart';

/// Shows the in-app feedback modal when eligibility says so.
///
/// Soft ask at most once: dismiss ("Not now" / barrier) permanently opts out.
/// CTA opens mail to hello@readendar.com and marks completed.
///
/// [stillVisible] should return false if the tab that triggered the ask is no
/// longer visible (retained root tabs stay mounted). Skip also when another
/// route was pushed over the shell so we do not interrupt that destination.
Future<bool> maybeShowProductFeedbackPrompt(
  BuildContext context,
  WidgetRef ref, {
  int? visitCount,
  bool Function()? stillVisible,
}) async {
  final user = ref.read(sessionProvider).user;
  if (user == null) return false;
  if (!context.mounted) return false;

  final prefs = ref.read(prefsStorageProvider);
  final visits = visitCount ?? prefs.getProductFeedbackVisitCount(user.id);
  if (!_eligible(prefs, user, visits)) return false;

  if (!_canShowNow(context, stillVisible: stillVisible)) {
    return false;
  }

  final result = await showProductFeedbackModalAndMail(context);
  // Mark after the dialog was presented so a skipped/raced frame does not burn
  // the soft ask.
  await prefs.setProductFeedbackPrompted(user.id);
  if (result == ProductFeedbackModalResult.share) {
    await prefs.setProductFeedbackCompleted(user.id);
    return true;
  }

  // Not now, barrier dismiss, or null: never soft-ask again.
  await prefs.setProductFeedbackDeclined(user.id);
  return true;
}

/// Records one root-tab visit and, after a short settle delay, maybe prompts.
///
/// Store-update is checked first so it wins over in-app feedback.
/// [settle] lets the tab paint before either modal.
Future<void> recordAppVisitAndMaybePrompt(
  BuildContext context,
  WidgetRef ref, {
  Duration settle = const Duration(milliseconds: 900),
  bool Function()? stillVisible,
  PlayUpdateChecker? playChecker,
  ItunesLookup? lookup,
  InstalledVersionReader? installedVersion,
}) async {
  final user = ref.read(sessionProvider).user;
  if (user == null) return;

  final prefs = ref.read(prefsStorageProvider);
  final visits = await prefs.incrementProductFeedbackVisitCount(user.id);
  if (!context.mounted) return;

  final feedbackEligible = _eligible(prefs, user, visits);
  if (feedbackEligible && settle > Duration.zero) {
    await Future<void>.delayed(settle);
    if (!context.mounted) return;
  }
  if (stillVisible != null && !stillVisible()) return;

  final updateShown = await maybeShowAppUpdatePrompt(
    context,
    ref,
    settle: feedbackEligible ? Duration.zero : settle,
    stillVisible: stillVisible,
    playChecker: playChecker,
    lookup: lookup,
    installedVersion: installedVersion,
  );
  if (updateShown) return;
  if (!context.mounted) return;
  if (stillVisible != null && !stillVisible()) return;
  if (!feedbackEligible) return;

  await maybeShowProductFeedbackPrompt(
    context,
    ref,
    visitCount: visits,
    stillVisible: stillVisible,
  );
}

bool _canShowNow(
  BuildContext context, {
  bool Function()? stillVisible,
}) {
  if (!context.mounted) return false;
  if (stillVisible != null && !stillVisible()) return false;
  // Root tabs stay mounted; IndexedStack keeps the route "current" even
  // when another tab is visible, so stillVisible covers that. isCurrent
  // catches a route pushed on top of the shell.
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
  return true;
}

bool _eligible(PrefsStorage prefs, AppUser user, int visitCount) {
  return ProductFeedbackEligibility.baseGate(
    onboardingDone: user.onboardingCompletedAt != null,
    alreadyPrompted: prefs.isProductFeedbackPrompted(user.id),
    alreadyCompleted: prefs.isProductFeedbackCompleted(user.id),
    declined: prefs.isProductFeedbackDeclined(user.id),
    visitCount: visitCount,
  );
}
