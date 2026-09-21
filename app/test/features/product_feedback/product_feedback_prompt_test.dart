import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/product_feedback/product_feedback_eligibility.dart';
import 'package:readendar/features/product_feedback/product_feedback_prompt.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _user({DateTime? onboarded}) => AppUser(
  id: 'user-1',
  email: 'a@b.co',
  displayName: 'Ada',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: onboarded ?? DateTime.utc(2026),
);

Widget _wrap({
  required List<Override> overrides,
  required Widget home,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('shows modal at visit threshold and opens feedback on CTA', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    feedbackLaunchUrl = (uri) async {
      expect(uri.scheme, 'mailto');
      expect(uri.path, feedbackSupportEmail);
      return true;
    };
    addTearDown(() {
      feedbackLaunchUrl = (uri) =>
          throw StateError('unexpected mailto $uri');
    });

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowProductFeedbackPrompt(
              context,
              ref,
              visitCount: ProductFeedbackEligibility.visitThreshold,
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Cómo va Readendar?'), findsOneWidget);
    // Prompted is recorded when the dialog closes, not when it opens.
    expect(prefs.isProductFeedbackPrompted('user-1'), isFalse);

    await tester.tap(find.text('Enviar feedback'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
    expect(prefs.isProductFeedbackPrompted('user-1'), isTrue);
    expect(prefs.isProductFeedbackCompleted('user-1'), isTrue);
  });

  testWidgets('does not show before the visit threshold', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowProductFeedbackPrompt(
              context,
              ref,
              visitCount: ProductFeedbackEligibility.visitThreshold - 1,
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
    expect(prefs.isProductFeedbackPrompted('user-1'), isFalse);
  });

  testWidgets('decline permanently suppresses later soft prompts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowProductFeedbackPrompt(
              context,
              ref,
              visitCount: ProductFeedbackEligibility.visitThreshold,
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(prefs.isProductFeedbackDeclined('user-1'), isTrue);

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
  });

  testWidgets('recordAppVisitAndMaybePrompt waits then prompts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    for (var i = 0; i < ProductFeedbackEligibility.visitThreshold - 1; i++) {
      await prefs.incrementProductFeedbackVisitCount('user-1');
    }

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => recordAppVisitAndMaybePrompt(
              context,
              ref,
              settle: const Duration(milliseconds: 50),
            ),
            child: const Text('visit'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('visit'));
    await tester.pump();
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Cómo va Readendar?'), findsOneWidget);
    expect(prefs.getProductFeedbackVisitCount('user-1'), 3);
  });

  testWidgets('skips after settle if the tab is no longer active', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    for (var i = 0; i < ProductFeedbackEligibility.visitThreshold - 1; i++) {
      await prefs.incrementProductFeedbackVisitCount('user-1');
    }
    var onHome = true;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => recordAppVisitAndMaybePrompt(
              context,
              ref,
              settle: const Duration(milliseconds: 50),
              stillVisible: () => onHome,
            ),
            child: const Text('visit'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('visit'));
    await tester.pump();
    onHome = false;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
    expect(prefs.isProductFeedbackPrompted('user-1'), isFalse);
    expect(prefs.getProductFeedbackVisitCount('user-1'), 3);
  });

  testWidgets('skips delay when the visit cannot produce a prompt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => recordAppVisitAndMaybePrompt(
              context,
              ref,
              settle: const Duration(milliseconds: 50),
            ),
            child: const Text('visit'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('visit'));
    await tester.pump();
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
    expect(prefs.getProductFeedbackVisitCount('user-1'), 1);
    expect(prefs.isProductFeedbackPrompted('user-1'), isFalse);
  });
}
