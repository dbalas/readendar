/// Soft rules for when the soft store-review ask may appear.
///
/// Platform quotas (Apple ~3/year, Play similar) still apply to native sheets;
/// this gate is the app-side spacing so we do not nag.
class StoreReviewEligibility {
  StoreReviewEligibility._();

  static const cooldown = Duration(days: 90);
  static const maxAttempts = 3;
  static const sessionThreshold = 7;

  /// Shared suppressors: onboarding incomplete, already reviewed, declined,
  /// attempt cap, or still inside the cooldown window.
  ///
  /// A single dismiss ("Not now" / barrier) sets [declined] permanently for soft
  /// prompts — we ask at most once unless the user later opens Settings.
  static bool baseGate({
    required bool onboardingDone,
    required bool alreadyCompleted,
    required bool declined,
    required int attemptCount,
    required DateTime? lastPromptAt,
    required DateTime now,
  }) {
    if (!onboardingDone) return false;
    if (alreadyCompleted) return false;
    if (declined) return false;
    if (attemptCount >= maxAttempts) return false;
    if (lastPromptAt != null && now.difference(lastPromptAt) < cooldown) {
      return false;
    }
    return true;
  }

  /// After leaving celebration: 2+ personal finishes, or 1st finish with at
  /// least one tracked reading session on that book.
  static bool celebrationOpportunity({
    required int personalBooksRead,
    required int bookSessions,
  }) {
    if (personalBooksRead >= 2) return true;
    if (personalBooksRead >= 1 && bookSessions >= 1) return true;
    return false;
  }

  /// After completing the Nth personal milestone session.
  static bool sessionsOpportunity(int completedSessions) =>
      completedSessions >= sessionThreshold;

  /// After creating a personal reading plan: only if the user already finished
  /// a book or has formed a session habit.
  static bool planOpportunity({
    required int personalBooksRead,
    required int completedSessions,
  }) => personalBooksRead >= 1 || completedSessions >= sessionThreshold;
}
