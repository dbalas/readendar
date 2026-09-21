import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/store/store_urls.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';
import 'package:readendar/features/app_update/app_update_play.dart';
import 'package:readendar/features/app_update/app_update_prompt.dart';
import 'package:readendar/features/product_feedback/product_feedback_eligibility.dart';
import 'package:readendar/features/product_feedback/product_feedback_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _user({bool onboarded = true, String? termsVersion}) => AppUser(
  id: 'user-1',
  email: 'a@b.co',
  displayName: 'Ada',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: onboarded ? DateTime.utc(2026) : null,
  termsVersion: termsVersion ?? currentTermsVersion,
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

Future<PrefsStorage> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PrefsStorage(await SharedPreferences.getInstance());
  await prefs.setIntroSeen();
  await prefs.setLocale('es');
  return prefs;
}

void main() {
  setUp(resetAppUpdatePromptGuard);

  test('login surface is idle only on the empty email step', () {
    expect(
      appUpdateLoginSurfaceIdle(
        codeStep: false,
        loading: false,
        hasEmailText: false,
        hasCodeText: false,
        keyboardOpen: false,
      ),
      isTrue,
    );
    expect(
      appUpdateLoginSurfaceIdle(
        codeStep: true,
        loading: false,
        hasEmailText: false,
        hasCodeText: false,
        keyboardOpen: false,
      ),
      isFalse,
    );
    expect(
      appUpdateLoginSurfaceIdle(
        codeStep: false,
        loading: true,
        hasEmailText: false,
        hasCodeText: false,
        keyboardOpen: false,
      ),
      isFalse,
    );
    expect(
      appUpdateLoginSurfaceIdle(
        codeStep: false,
        loading: false,
        hasEmailText: true,
        hasCodeText: false,
        keyboardOpen: false,
      ),
      isFalse,
    );
  });

  testWidgets('shows lookup notes and opens the App Store URL', (tester) async {
    final prefs = await _prefs();
    Uri? launched;
    var lookups = 0;

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
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              platform: TargetPlatform.iOS,
              playChecker: () async => PlayUpdateInfo.unavailable,
              lookup: ({required country}) async {
                lookups += 1;
                expect(country, 'es');
                return const ItunesLookupResult(
                  version: '1.1.7',
                  releaseNotes: 'Notes for 1.1.7',
                  trackViewUrl: 'https://apps.apple.com/app/id99',
                );
              },
              installedVersion: () async => '1.1.6',
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
    await tester.pump();
    expect(find.text('Actualización disponible'), findsOneWidget);
    expect(find.text('Notes for 1.1.7'), findsOneWidget);

    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    await tester.pump();
    expect(launched?.toString(), 'https://apps.apple.com/app/id99');
    expect(prefs.getAppUpdateSnoozedVersion(), '1.1.7');
    expect(lookups, 1);
  });

  testWidgets('Later snoozes that version', (tester) async {
    final prefs = await _prefs();
    var shown = 0;

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
            onPressed: () async {
              final ok = await maybeShowAppUpdatePrompt(
                context,
                ref,
                settle: Duration.zero,
                platform: TargetPlatform.iOS,
                lookup: ({required country}) async => const ItunesLookupResult(
                  version: '1.2.0',
                  releaseNotes: 'Two',
                  trackViewUrl: 'https://apps.apple.com/app/id2',
                ),
                installedVersion: () async => '1.1.6',
                launch: (uri) async => true,
              );
              if (ok) shown += 1;
            },
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Más tarde'));
    await tester.pump();
    await tester.pump();
    expect(prefs.getAppUpdateSnoozedVersion(), '1.2.0');

    resetAppUpdatePromptGuard();
    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización disponible'), findsNothing);
    expect(shown, 1);
  });

  testWidgets('Play-ahead shows generic body and Play listing', (tester) async {
    final prefs = await _prefs();
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
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              platform: TargetPlatform.android,
              playChecker: () async => const PlayUpdateInfo(
                available: true,
                availableVersionCode: 12,
              ),
              lookup: ({required country}) async =>
                  const ItunesLookupResult(version: '1.1.6'),
              installedVersion: () async => '1.1.6',
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
    await tester.pump();
    expect(
      find.text('Hay una versión nueva de Readendar en la tienda.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    await tester.pump();
    expect(launched?.toString(), googlePlayStoreUrl);
    expect(prefs.getAppUpdateSnoozedVersion(), 'play:12');
  });

  testWidgets('toasts when the store URL fails to open', (tester) async {
    final prefs = await _prefs();

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
              onPressed: () => maybeShowAppUpdatePrompt(
                context,
                ref,
                settle: Duration.zero,
                platform: TargetPlatform.iOS,
                lookup: ({required country}) async => const ItunesLookupResult(
                  version: '9.0.0',
                  releaseNotes: 'Nine',
                  trackViewUrl: 'https://apps.apple.com/app/id9',
                ),
                installedVersion: () async => '1.0.0',
                launch: (uri) async => false,
              ),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text("No se pudo abrir la tienda. Inténtalo de nuevo."),
      findsOneWidget,
    );
  });

  testWidgets('update prompt wins over product feedback', (tester) async {
    final prefs = await _prefs();
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
              settle: Duration.zero,
              playChecker: () async => const PlayUpdateInfo(
                available: true,
                availableVersionCode: 20,
              ),
              lookup: ({required country}) async => const ItunesLookupResult(
                version: '2.0.0',
                releaseNotes: 'Two oh',
                trackViewUrl: 'https://apps.apple.com/app/id20',
              ),
              installedVersion: () async => '1.0.0',
            ),
            child: const Text('visit'),
          ),
        ),
      ),
    );

    // Inject via a second pump using a wrapper that cannot easily override
    // the nested recordAppVisit call's update fakes. Direct prompt first:
    await tester.tap(find.text('visit'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización disponible'), findsOneWidget);
    expect(find.text('Two oh'), findsOneWidget);
    expect(find.text('¿Cómo va Readendar?'), findsNothing);
  });

  testWidgets('skips when intro has not been seen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    var lookups = 0;

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
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              platform: TargetPlatform.iOS,
              lookup: ({required country}) async {
                lookups += 1;
                return const ItunesLookupResult(version: '9.0.0');
              },
              installedVersion: () async => '1.0.0',
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    expect(find.text('Actualización disponible'), findsNothing);
    expect(lookups, 0);
  });

  testWidgets('stays silent when Play reports no update', (tester) async {
    final prefs = await _prefs();
    var lookups = 0;

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
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              platform: TargetPlatform.android,
              playChecker: () async => PlayUpdateInfo.unavailable,
              lookup: ({required country}) async {
                lookups += 1;
                return const ItunesLookupResult(version: '9.0.0');
              },
              installedVersion: () async => '1.0.0',
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización disponible'), findsNothing);
    expect(lookups, 0);
  });

  testWidgets('skips onboarding and unsigned terms', (tester) async {
    final prefs = await _prefs();
    var lookups = 0;

    Future<void> ask(AppUser user) async {
      await tester.pumpWidget(
        _wrap(
          overrides: [
            prefsStorageProvider.overrideWithValue(prefs),
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            sessionProvider.overrideWith((ref) {
              final n = SessionNotifier(ref);
              n.setUser(user);
              return n;
            }),
          ],
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => maybeShowAppUpdatePrompt(
                context,
                ref,
                settle: Duration.zero,
                platform: TargetPlatform.iOS,
                lookup: ({required country}) async {
                  lookups += 1;
                  return const ItunesLookupResult(version: '9.0.0');
                },
                installedVersion: () async => '1.0.0',
              ),
              child: const Text('ask'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ask'));
      await tester.pump();
      await tester.pump();
    }

    await ask(_user(onboarded: false));
    expect(find.text('Actualización disponible'), findsNothing);
    resetAppUpdatePromptGuard();
    await ask(_user(termsVersion: 'old'));
    expect(find.text('Actualización disponible'), findsNothing);
    expect(lookups, 0);
  });

  testWidgets('resume cooldown suppresses a repeat check', (tester) async {
    final prefs = await _prefs();
    final now = DateTime.utc(2026, 9, 5, 12);
    await prefs.setAppUpdateLastCheckMs(now.millisecondsSinceEpoch);
    var lookups = 0;

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
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              fromResume: true,
              now: now.add(const Duration(hours: 1)),
              platform: TargetPlatform.iOS,
              lookup: ({required country}) async {
                lookups += 1;
                return const ItunesLookupResult(version: '9.0.0');
              },
              installedVersion: () async => '1.0.0',
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización disponible'), findsNothing);
    expect(lookups, 0);
  });

  testWidgets('update can still prompt after intro', (tester) async {
    final prefs = await _prefs();

    await tester.pumpWidget(
      _wrap(
        overrides: [
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              platform: TargetPlatform.iOS,
              lookup: ({required country}) async => const ItunesLookupResult(
                version: '2.0.0',
                releaseNotes: 'Logged out notes',
                trackViewUrl: 'https://apps.apple.com/app/id2',
              ),
              installedVersion: () async => '1.0.0',
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización disponible'), findsOneWidget);
    expect(find.text('Logged out notes'), findsOneWidget);
  });

  testWidgets('outside tap does not dismiss the update prompt', (tester) async {
    final prefs = await _prefs();

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
            onPressed: () => maybeShowAppUpdatePrompt(
              context,
              ref,
              settle: Duration.zero,
              platform: TargetPlatform.iOS,
              lookup: ({required country}) async => const ItunesLookupResult(
                version: '2.0.0',
                releaseNotes: 'Stay',
                trackViewUrl: 'https://apps.apple.com/app/id2',
              ),
              installedVersion: () async => '1.0.0',
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización disponible'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.text('Actualización disponible'), findsOneWidget);
    expect(prefs.getAppUpdateSnoozedVersion(), isNull);
    await tester.tap(find.text('Más tarde'));
    await tester.pump();
    await tester.pump();
    expect(prefs.getAppUpdateSnoozedVersion(), '2.0.0');
  });
}
