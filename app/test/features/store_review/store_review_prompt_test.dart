import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/store/store_urls.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/store_review/store_review_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _user({DateTime? onboarded}) => AppUser(
  id: 'user-1',
  email: 'a@b.co',
  displayName: 'Ada',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: onboarded ?? DateTime.utc(2026),
);

Book _readBook(String id) => Book(
  id: id,
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Book $id',
  authors: const ['A'],
  status: BookStatus.read,
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
  testWidgets('celebration trigger shows modal for 2nd finish and opens store', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    Uri? launched;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          booksProvider.overrideWith(
            (ref) async => [_readBook('1'), _readBook('2')],
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowStoreReviewPrompt(
              context,
              ref,
              trigger: StoreReviewTrigger.celebration,
              personalBooksRead: 2,
              bookSessions: 0,
              platform: TargetPlatform.android,
              forceBrandedModal: true,
              launch: (uri) async {
                launched = uri;
                return true;
              },
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Te está gustando Readendar?'), findsOneWidget);

    await tester.tap(find.text('Valorar en Google Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(launched?.toString(), googlePlayStoreUrl);
    expect(prefs.isStoreReviewCompleted('user-1'), isTrue);
    expect(prefs.getStoreReviewAttemptCount('user-1'), 1);
  });

  testWidgets('dismiss permanently opts out of soft prompts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    var secondShown = false;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          booksProvider.overrideWith(
            (ref) async => [_readBook('1'), _readBook('2')],
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => Column(
            children: [
              TextButton(
                onPressed: () => maybeShowStoreReviewPrompt(
                  context,
                  ref,
                  trigger: StoreReviewTrigger.celebration,
                  personalBooksRead: 2,
                  bookSessions: 0,
                  platform: TargetPlatform.android,
                  forceBrandedModal: true,
                  launch: (_) async => true,
                ),
                child: const Text('ask-first'),
              ),
              TextButton(
                onPressed: () async {
                  secondShown = await maybeShowStoreReviewPrompt(
                    context,
                    ref,
                    trigger: StoreReviewTrigger.sessions,
                    completedSessions: 7,
                    now: DateTime.utc(2026, 12),
                    platform: TargetPlatform.android,
                    forceBrandedModal: true,
                    launch: (_) async => true,
                  );
                },
                child: const Text('ask-again'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask-first'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Te está gustando Readendar?'), findsOneWidget);

    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(prefs.isStoreReviewDeclined('user-1'), isTrue);

    await tester.tap(find.text('ask-again'));
    await tester.pump();
    expect(secondShown, isFalse);
    expect(find.text('¿Te está gustando Readendar?'), findsNothing);
  });

  testWidgets('soft trigger respects cooldown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    await prefs.recordStoreReviewPrompt('user-1', DateTime.utc(2026, 8));
    var shown = false;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          booksProvider.overrideWith((ref) async => [_readBook('1')]),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async {
              shown = await maybeShowStoreReviewPrompt(
                context,
                ref,
                trigger: StoreReviewTrigger.sessions,
                completedSessions: 7,
                now: DateTime.utc(2026, 8, 4),
                platform: TargetPlatform.android,
                forceBrandedModal: true,
                launch: (_) async => true,
              );
            },
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    expect(shown, isFalse);
    expect(find.text('¿Te está gustando Readendar?'), findsNothing);
  });

  testWidgets('iOS soft trigger uses native review and skips branded modal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    var nativeCalls = 0;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          booksProvider.overrideWith(
            (ref) async => [_readBook('1'), _readBook('2')],
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowStoreReviewPrompt(
              context,
              ref,
              trigger: StoreReviewTrigger.celebration,
              personalBooksRead: 2,
              bookSessions: 0,
              platform: TargetPlatform.iOS,
              requestNativeReview: () async {
                nativeCalls += 1;
                return true;
              },
              launch: (_) async => true,
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('¿Te está gustando Readendar?'), findsNothing);
    expect(nativeCalls, 1);
    // Native request accepted ≠ user completed a store rating.
    expect(prefs.isStoreReviewCompleted('user-1'), isFalse);
    expect(prefs.getStoreReviewAttemptCount('user-1'), 1);
  });

  testWidgets('profile CTA opens Play Store listing on Android', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    Uri? launched;

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
            onPressed: () => showStoreReviewFromProfile(
              context,
              ref,
              platform: TargetPlatform.android,
              launch: (uri) async {
                launched = uri;
                return true;
              },
            ),
            child: const Text('profile-review'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('profile-review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Explicit profile CTA must open the listing — not native in-app review.
    expect(find.text('¿Te está gustando Readendar?'), findsNothing);
    expect(launched?.toString(), googlePlayStoreUrl);
  });

  testWidgets('profile CTA shows error toast when store launch fails', (
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
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showStoreReviewFromProfile(
                context,
                ref,
                platform: TargetPlatform.android,
                launch: (_) async => false,
              ),
              child: const Text('profile-review'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('profile-review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('No se pudo abrir la tienda. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('native unavailable falls back to branded modal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    Uri? launched;

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          booksProvider.overrideWith(
            (ref) async => [_readBook('1'), _readBook('2')],
          ),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref);
            n.setUser(_user());
            return n;
          }),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowStoreReviewPrompt(
              context,
              ref,
              trigger: StoreReviewTrigger.celebration,
              personalBooksRead: 2,
              bookSessions: 0,
              platform: TargetPlatform.iOS,
              requestNativeReview: () async => false,
              launch: (uri) async {
                launched = uri;
                return true;
              },
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Te está gustando Readendar?'), findsOneWidget);

    await tester.tap(find.text('Valorar en App Store'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(launched?.toString(), appStoreSearchUrl);
  });
}
