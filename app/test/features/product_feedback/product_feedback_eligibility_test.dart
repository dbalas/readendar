import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/product_feedback/product_feedback_eligibility.dart';

void main() {
  group('ProductFeedbackEligibility.baseGate', () {
    test('blocks before onboarding completes', () {
      expect(
        ProductFeedbackEligibility.baseGate(
          onboardingDone: false,
          alreadyPrompted: false,
          alreadyCompleted: false,
          declined: false,
          visitCount: ProductFeedbackEligibility.visitThreshold,
        ),
        isFalse,
      );
    });

    test('blocks before enough app visits', () {
      expect(
        ProductFeedbackEligibility.baseGate(
          onboardingDone: true,
          alreadyPrompted: false,
          alreadyCompleted: false,
          declined: false,
          visitCount: ProductFeedbackEligibility.visitThreshold - 1,
        ),
        isFalse,
      );
    });

    test('allows at the visit threshold', () {
      expect(
        ProductFeedbackEligibility.baseGate(
          onboardingDone: true,
          alreadyPrompted: false,
          alreadyCompleted: false,
          declined: false,
          visitCount: ProductFeedbackEligibility.visitThreshold,
        ),
        isTrue,
      );
    });

    test('blocks after the soft prompt was already shown', () {
      expect(
        ProductFeedbackEligibility.baseGate(
          onboardingDone: true,
          alreadyPrompted: true,
          alreadyCompleted: false,
          declined: false,
          visitCount: 10,
        ),
        isFalse,
      );
    });

    test('blocks after the user shared feedback via the prompt', () {
      expect(
        ProductFeedbackEligibility.baseGate(
          onboardingDone: true,
          alreadyPrompted: false,
          alreadyCompleted: true,
          declined: false,
          visitCount: 10,
        ),
        isFalse,
      );
    });

    test('blocks permanently after the user declined', () {
      expect(
        ProductFeedbackEligibility.baseGate(
          onboardingDone: true,
          alreadyPrompted: false,
          alreadyCompleted: false,
          declined: true,
          visitCount: 10,
        ),
        isFalse,
      );
    });
  });
}
