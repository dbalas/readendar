import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/store_review/store_review_eligibility.dart';

void main() {
  group('StoreReviewEligibility.baseGate', () {
    final now = DateTime.utc(2026, 8, 4);

    test('blocks before onboarding completes', () {
      expect(
        StoreReviewEligibility.baseGate(
          onboardingDone: false,
          alreadyCompleted: false,
          declined: false,
          attemptCount: 0,
          lastPromptAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('blocks after the user already reviewed', () {
      expect(
        StoreReviewEligibility.baseGate(
          onboardingDone: true,
          alreadyCompleted: true,
          declined: false,
          attemptCount: 1,
          lastPromptAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('blocks permanently after the user declined', () {
      expect(
        StoreReviewEligibility.baseGate(
          onboardingDone: true,
          alreadyCompleted: false,
          declined: true,
          attemptCount: 1,
          lastPromptAt: now.subtract(const Duration(days: 200)),
          now: now,
        ),
        isFalse,
      );
    });

    test('blocks inside the cooldown window', () {
      expect(
        StoreReviewEligibility.baseGate(
          onboardingDone: true,
          alreadyCompleted: false,
          declined: false,
          attemptCount: 1,
          lastPromptAt: now.subtract(const Duration(days: 30)),
          now: now,
        ),
        isFalse,
      );
    });

    test('allows after cooldown and under the attempt cap', () {
      expect(
        StoreReviewEligibility.baseGate(
          onboardingDone: true,
          alreadyCompleted: false,
          declined: false,
          attemptCount: 2,
          lastPromptAt: now.subtract(const Duration(days: 91)),
          now: now,
        ),
        isTrue,
      );
    });

    test('blocks at the lifetime attempt cap', () {
      expect(
        StoreReviewEligibility.baseGate(
          onboardingDone: true,
          alreadyCompleted: false,
          declined: false,
          attemptCount: StoreReviewEligibility.maxAttempts,
          lastPromptAt: now.subtract(const Duration(days: 200)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('celebrationOpportunity', () {
    test('allows the second personal finish', () {
      expect(
        StoreReviewEligibility.celebrationOpportunity(
          personalBooksRead: 2,
          bookSessions: 0,
        ),
        isTrue,
      );
    });

    test('allows a first finish only with tracked sessions', () {
      expect(
        StoreReviewEligibility.celebrationOpportunity(
          personalBooksRead: 1,
          bookSessions: 0,
        ),
        isFalse,
      );
      expect(
        StoreReviewEligibility.celebrationOpportunity(
          personalBooksRead: 1,
          bookSessions: 1,
        ),
        isTrue,
      );
    });
  });

  group('sessions and plan opportunities', () {
    test('sessions unlock at the threshold', () {
      expect(StoreReviewEligibility.sessionsOpportunity(6), isFalse);
      expect(StoreReviewEligibility.sessionsOpportunity(7), isTrue);
    });

    test('plan requires prior engagement', () {
      expect(
        StoreReviewEligibility.planOpportunity(
          personalBooksRead: 0,
          completedSessions: 3,
        ),
        isFalse,
      );
      expect(
        StoreReviewEligibility.planOpportunity(
          personalBooksRead: 1,
          completedSessions: 0,
        ),
        isTrue,
      );
      expect(
        StoreReviewEligibility.planOpportunity(
          personalBooksRead: 0,
          completedSessions: 7,
        ),
        isTrue,
      );
    });
  });
}
