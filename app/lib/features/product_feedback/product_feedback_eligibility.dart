/// Pure rules for when the soft in-app feedback modal may appear.
///
/// We ask once after a little real use, never on first open.
class ProductFeedbackEligibility {
  ProductFeedbackEligibility._();

  /// How many root-tab entries (with an onboarded session) before we ask.
  static const visitThreshold = 3;

  /// Shared suppressors: onboarding incomplete, already prompted / completed /
  /// declined, or not enough app use yet.
  static bool baseGate({
    required bool onboardingDone,
    required bool alreadyPrompted,
    required bool alreadyCompleted,
    required bool declined,
    required int visitCount,
  }) {
    if (!onboardingDone) return false;
    if (alreadyPrompted) return false;
    if (alreadyCompleted) return false;
    if (declined) return false;
    if (visitCount < visitThreshold) return false;
    return true;
  }
}
