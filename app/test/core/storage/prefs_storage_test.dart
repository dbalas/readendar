import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('spoiler quote reveals are durable and scoped per user', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getRevealedSpoilerQuoteIds('user-1'), isEmpty);
    expect(await storage.revealSpoilerQuote('user-1', 'quote-2'), isTrue);
    expect(await storage.revealSpoilerQuote('user-1', 'quote-1'), isTrue);
    expect(await storage.revealSpoilerQuote('user-1', 'quote-1'), isTrue);

    expect(storage.getRevealedSpoilerQuoteIds('user-1'), {
      'quote-1',
      'quote-2',
    });
    expect(storage.getRevealedSpoilerQuoteIds('user-2'), isEmpty);
  });

  test(
    'spoiler quote reveals retain v1 values during bucket migration',
    () async {
      SharedPreferences.setMockInitialValues({
        'revealed_spoiler_quotes:v1:user-1': ['legacy-quote'],
      });
      final preferences = await SharedPreferences.getInstance();
      final storage = PrefsStorage(preferences);

      expect(storage.getRevealedSpoilerQuoteIds('user-1'), {'legacy-quote'});
      expect(
        await storage.revealSpoilerQuote('user-1', 'legacy-quote'),
        isTrue,
      );
      expect(
        await storage.revealSpoilerQuote('user-1', 'current-quote'),
        isTrue,
      );
      expect(storage.getRevealedSpoilerQuoteIds('user-1'), {
        'legacy-quote',
        'current-quote',
      });
    },
  );

  test('theme preset is device-local and durable', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getThemePreset(), isNull);
    expect(await storage.setThemePreset('sakura'), isTrue);
    expect(storage.getThemePreset(), 'sakura');
  });

  test('store review prefs are scoped per user', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);
    final at = DateTime.utc(2026, 8, 4);

    expect(storage.getStoreReviewAttemptCount('user-1'), 0);
    expect(storage.getStoreReviewSessionCount('user-1'), 0);
    expect(storage.isStoreReviewCompleted('user-1'), isFalse);

    await storage.recordStoreReviewPrompt('user-1', at);
    expect(storage.getStoreReviewAttemptCount('user-1'), 1);
    expect(
      storage.getStoreReviewLastPromptMs('user-1'),
      at.millisecondsSinceEpoch,
    );
    expect(storage.getStoreReviewAttemptCount('user-2'), 0);

    expect(await storage.incrementStoreReviewSessionCount('user-1'), 1);
    expect(await storage.incrementStoreReviewSessionCount('user-1'), 2);
    expect(storage.getStoreReviewSessionCount('user-2'), 0);

    await storage.setStoreReviewCompleted('user-1');
    expect(storage.isStoreReviewCompleted('user-1'), isTrue);
    expect(storage.isStoreReviewCompleted('user-2'), isFalse);

    expect(storage.isStoreReviewDeclined('user-1'), isFalse);
    await storage.setStoreReviewDeclined('user-1');
    expect(storage.isStoreReviewDeclined('user-1'), isTrue);
    expect(storage.isStoreReviewDeclined('user-2'), isFalse);
  });

  test('app update snooze prefs are device-scoped', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getAppUpdateSnoozedVersion(), isNull);
    expect(storage.getAppUpdateLastCheckMs(), 0);
    await storage.setAppUpdateSnoozedVersion('1.2.0');
    await storage.setAppUpdateLastCheckMs(42);
    expect(storage.getAppUpdateSnoozedVersion(), '1.2.0');
    expect(storage.getAppUpdateLastCheckMs(), 42);
  });

  test('in-app feedback prefs are scoped per user', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getProductFeedbackVisitCount('user-1'), 0);
    expect(storage.isProductFeedbackPrompted('user-1'), isFalse);
    expect(storage.isProductFeedbackCompleted('user-1'), isFalse);
    expect(storage.isProductFeedbackDeclined('user-1'), isFalse);

    expect(await storage.incrementProductFeedbackVisitCount('user-1'), 1);
    expect(await storage.incrementProductFeedbackVisitCount('user-1'), 2);
    expect(storage.getProductFeedbackVisitCount('user-2'), 0);

    await storage.setProductFeedbackPrompted('user-1');
    expect(storage.isProductFeedbackPrompted('user-1'), isTrue);
    expect(storage.isProductFeedbackPrompted('user-2'), isFalse);

    await storage.setProductFeedbackCompleted('user-1');
    expect(storage.isProductFeedbackCompleted('user-1'), isTrue);
    expect(storage.isProductFeedbackCompleted('user-2'), isFalse);

    await storage.setProductFeedbackDeclined('user-1');
    expect(storage.isProductFeedbackDeclined('user-1'), isTrue);
    expect(storage.isProductFeedbackDeclined('user-2'), isFalse);
  });

  test('migrates legacy in-app feedback prefs keys on write', () async {
    SharedPreferences.setMockInitialValues({
      'community_feedback_visit_count:user-1': 2,
      'community_feedback_prompted:user-1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getProductFeedbackVisitCount('user-1'), 2);
    expect(storage.isProductFeedbackPrompted('user-1'), isTrue);

    await storage.incrementProductFeedbackVisitCount('user-1');
    expect(storage.getProductFeedbackVisitCount('user-1'), 3);
    expect(preferences.containsKey('community_feedback_visit_count:user-1'), isFalse);
    expect(preferences.containsKey('product_feedback_visit_count:user-1'), isTrue);
  });

  test('plan unit preference is scoped per user', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getPlanUnit('user-1'), isNull);
    await storage.setPlanUnit('user-1', 'chapters');
    expect(storage.getPlanUnit('user-1'), 'chapters');
    expect(storage.getPlanUnit('user-2'), isNull);
    await storage.setPlanUnit('user-1', 'pages');
    expect(storage.getPlanUnit('user-1'), 'pages');
  });

  test('plan mode preference is scoped per user', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getPlanMode('user-1'), isNull);
    await storage.setPlanMode('user-1', 'before_event');
    expect(storage.getPlanMode('user-1'), 'before_event');
    expect(storage.getPlanMode('user-2'), isNull);
    await storage.setPlanMode('user-1', 'deadline');
    expect(storage.getPlanMode('user-1'), 'deadline');
  });

  test('list filters json is device-scoped by screen id', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.getListFiltersJson('explore_upcoming'), isNull);
    expect(
      await storage.setListFiltersJson(
        'explore_upcoming',
        '{"language":"cat"}',
      ),
      isTrue,
    );
    expect(
      storage.getListFiltersJson('explore_upcoming'),
      '{"language":"cat"}',
    );
    expect(storage.getListFiltersJson('explore_onscreen'), isNull);
    expect(await storage.setListFiltersJson('', '{"language":"cat"}'), isFalse);
    expect(await storage.clearListFilters('explore_upcoming'), isTrue);
    expect(storage.getListFiltersJson('explore_upcoming'), isNull);
  });

  test('intro seen is device-scoped', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PrefsStorage(preferences);

    expect(storage.isIntroSeen(), isFalse);
    await storage.setIntroSeen();
    expect(storage.isIntroSeen(), isTrue);
    expect(preferences.getBool('onboarding_intro_seen'), isTrue);
  });

  test(
    'intro seen honors legacy per-user keys and promotes device key',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_intro_seen:user-legacy': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final storage = PrefsStorage(preferences);

      expect(storage.isIntroSeen(), isTrue);
      expect(preferences.getBool('onboarding_intro_seen'), isTrue);
      // Second read hits the device key only (no reliance on the legacy scan).
      expect(storage.isIntroSeen(), isTrue);
    },
  );
}
