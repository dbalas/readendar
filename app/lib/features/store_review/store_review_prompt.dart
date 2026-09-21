import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/store/store_urls.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/store_review/in_app_review_gateway.dart';
import 'package:readendar/features/store_review/store_review_eligibility.dart';
import 'package:readendar/features/store_review/store_review_modal.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which product moment asked for a review (logging / tests only).
enum StoreReviewTrigger { celebration, sessions, plan, profile }

/// Counts personal books currently in "read" status.
int countPersonalBooksRead(Iterable<Book> books) =>
    books.where((b) => b.status == BookStatus.read).length;

/// Shows a review ask when [StoreReviewEligibility] says so.
///
/// On iOS / Android / macOS soft triggers use the native StoreKit / Play
/// in-app review sheet (no branded modal). Desktop / unavailable native falls
/// back to the branded modal + store URL. Soft dismiss permanently opts out
/// of automatic prompts. The profile row is a separate escape hatch that
/// always opens the store listing — see [showStoreReviewFromProfile].
Future<bool> maybeShowStoreReviewPrompt(
  BuildContext context,
  WidgetRef ref, {
  required StoreReviewTrigger trigger,
  int? personalBooksRead,
  int? bookSessions,
  int? completedSessions,
  TargetPlatform? platform,
  DateTime? now,
  Future<bool> Function(Uri uri)? launch,
  InAppReviewRequester? requestNativeReview,
  bool? forceBrandedModal,
}) async {
  final user = ref.read(sessionProvider).user;
  if (user == null) return false;
  if (!context.mounted) return false;

  final prefs = ref.read(prefsStorageProvider);
  final clock = now ?? DateTime.now();
  // Profile is explicit user intent — skip cooldown / attempt / decline gate.
  // Soft triggers still go through the full base gate.
  if (trigger != StoreReviewTrigger.profile &&
      !_baseEligible(prefs, user, clock)) {
    return false;
  }
  if (trigger == StoreReviewTrigger.profile &&
      (user.onboardingCompletedAt == null ||
          prefs.isStoreReviewCompleted(user.id))) {
    return false;
  }

  final sessions =
      completedSessions ?? prefs.getStoreReviewSessionCount(user.id);
  final booksRead =
      personalBooksRead ??
      countPersonalBooksRead(ref.read(booksProvider).value ?? const []);

  final opportunity = switch (trigger) {
    StoreReviewTrigger.celebration =>
      StoreReviewEligibility.celebrationOpportunity(
        personalBooksRead: booksRead,
        bookSessions: bookSessions ?? 0,
      ),
    StoreReviewTrigger.sessions => StoreReviewEligibility.sessionsOpportunity(
      sessions,
    ),
    StoreReviewTrigger.plan => StoreReviewEligibility.planOpportunity(
      personalBooksRead: booksRead,
      completedSessions: sessions,
    ),
    StoreReviewTrigger.profile => true,
  };
  if (!opportunity) return false;

  await prefs.recordStoreReviewPrompt(user.id, clock);
  if (!context.mounted) return false;

  final resolvedPlatform = platform ?? Theme.of(context).platform;
  final useNative =
      forceBrandedModal != true &&
      prefersNativeInAppReview(platform: resolvedPlatform);

  if (useNative) {
    final requester = requestNativeReview ?? requestNativeStoreReview;
    final accepted = await requester();
    if (accepted) {
      // Native API accepted the request — OS may still suppress the sheet.
      // Do NOT mark "completed" (that means the user rated). Cooldown + attempt
      // cap from recordStoreReviewPrompt already prevent soft-nag spam.
      return true;
    }
    if (!context.mounted) return false;
    // Native unavailable — fall back to branded modal once.
    return _showBrandedAndMaybeLaunch(
      context,
      prefs: prefs,
      userId: user.id,
      platform: resolvedPlatform,
      launch: launch,
    );
  }

  return _showBrandedAndMaybeLaunch(
    context,
    prefs: prefs,
    userId: user.id,
    platform: resolvedPlatform,
    launch: launch,
  );
}

Future<bool> _showBrandedAndMaybeLaunch(
  BuildContext context, {
  required PrefsStorage prefs,
  required String userId,
  required TargetPlatform platform,
  Future<bool> Function(Uri uri)? launch,
}) async {
  final result = await showStoreReviewModal(context, platform: platform);
  if (result == StoreReviewModalResult.review) {
    if (!context.mounted) return true;

    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    await prefs.setStoreReviewCompleted(userId);
    final uri = storeReviewUri(platform: platform);
    final opener =
        launch ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    final ok = await opener(uri);
    if (!ok) {
      if (!context.mounted) return true;
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: l.storeReviewOpenFailed,
        messenger: messenger,
      );
    }
    return true;
  }

  // Not now, barrier dismiss, or null — never soft-ask again.
  await prefs.setStoreReviewDeclined(userId);
  return true;
}

/// Profile escape hatch: always open the store listing.
///
/// Native in-app review (Play / StoreKit) can silently no-op — quota,
/// sideload, debug builds — so it must not be the only path for an explicit
/// "leave a review" control. Soft prompts still use native via
/// [maybeShowStoreReviewPrompt].
Future<void> showStoreReviewFromProfile(
  BuildContext context,
  WidgetRef ref, {
  TargetPlatform? platform,
  Future<bool> Function(Uri uri)? launch,
}) async {
  final user = ref.read(sessionProvider).user;
  if (user == null || !context.mounted) return;
  final resolvedPlatform = platform ?? Theme.of(context).platform;
  final uri = storeReviewUri(platform: resolvedPlatform);
  final opener =
      launch ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
  final ok = await opener(uri);
  if (!ok && context.mounted) {
    final l = AppL10n.of(context);
    showRdToast(
      context,
      tone: RdToastTone.error,
      message: l.storeReviewOpenFailed,
    );
  }
}

bool _baseEligible(PrefsStorage prefs, AppUser user, DateTime now) {
  final lastMs = prefs.getStoreReviewLastPromptMs(user.id);
  return StoreReviewEligibility.baseGate(
    onboardingDone: user.onboardingCompletedAt != null,
    alreadyCompleted: prefs.isStoreReviewCompleted(user.id),
    declined: prefs.isStoreReviewDeclined(user.id),
    attemptCount: prefs.getStoreReviewAttemptCount(user.id),
    lastPromptAt: lastMs == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastMs),
    now: now,
  );
}
