import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_screen.dart';
import 'package:readendar/features/onboarding/onboarding_tour_screen.dart';
import 'package:readendar/main.dart';
import '../quotes/quotes_test_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => true,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  AppUser localGuest() {
    final now = DateTime.utc(2026, 1, 1);
    return AppUser(
      id: localGuestUserId,
      email: '',
      displayName: '',
      preferredLocale: 'es',
      timezone: 'Europe/Madrid',
      onboardingCompletedAt: now,
      termsAcceptedAt: now,
      termsVersion: currentTermsVersion,
    );
  }

  gateOverrides({
    required SharedPreferences prefs,
    required SessionNotifier session,
    required LocalStore store,
  }) =>
      [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(store),
        sessionProvider.overrideWith((ref) => session),
        quoteRepoProvider.overrideWithValue(FakeQuoteRepository([])),
        booksProvider.overrideWith((ref) async => const <Book>[]),
        upcomingEventsProvider.overrideWith((ref) async => const <ReadingEvent>[]),
        notificationPrefsProvider.overrideWith(
          (ref) async => NotificationPreferences(
            globalEnabled: true,
            defaultReminderMinutesBefore: 1440,
            allDayReminderHour: 9,
          ),
        ),
        readingChapterLatestProvider.overrideWith(
          (ref) => Stream.value(
            const ReadingChapterArchive(
              items: [],
              nextCursor: '',
              hasUnread: false,
              capabilities: ReadingChapterCapabilities(
                privateGeneration: true,
              ),
            ),
          ),
        ),
      ];

  Future<LocalStore> openStore() async =>
      LocalStore.memory(Directory.systemTemp.createTempSync('onboarding-gate-'));

  testWidgets('cold start shows the feature tour before home', (tester) async {
    SharedPreferences.setMockInitialValues({
      'locale': 'es',
      dataPlanePrefsKey: 'local',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = await openStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: gateOverrides(
          prefs: prefs,
          store: store,
          session: _FakeSessionNotifier(localGuest()),
        ),
        child: const ReadendarApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byType(OnboardingTourScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Bienvenido a Readendar'), findsOneWidget);
  });

  testWidgets('finishing the tour persists device flag and opens home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'locale': 'es',
      dataPlanePrefsKey: 'local',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = await openStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: gateOverrides(
          prefs: prefs,
          store: store,
          session: _FakeSessionNotifier(localGuest()),
        ),
        child: const ReadendarApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.tap(find.text('Saltar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(PrefsStorage(prefs).isIntroSeen(), isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingTourScreen), findsNothing);
  });

  testWidgets('device intro flag skips the tour on later launches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'locale': 'es',
      dataPlanePrefsKey: 'local',
      'onboarding_intro_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = await openStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: gateOverrides(
          prefs: prefs,
          store: store,
          session: _FakeSessionNotifier(localGuest()),
        ),
        child: const ReadendarApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingTourScreen), findsNothing);
  });

  testWidgets('legacy per-user intro flag skips tour and promotes device key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'locale': 'es',
      dataPlanePrefsKey: 'local',
      'onboarding_intro_seen:user-legacy': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = await openStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: gateOverrides(
          prefs: prefs,
          store: store,
          session: _FakeSessionNotifier(localGuest()),
        ),
        child: const ReadendarApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingTourScreen), findsNothing);
    expect(prefs.getBool('onboarding_intro_seen'), isTrue);
  });

  testWidgets(
    'local guest with profile onboarding done still sees the welcome tour',
    (tester) async {
      SharedPreferences.setMockInitialValues({
      'locale': 'es',
      dataPlanePrefsKey: 'local',
    });
      final prefs = await SharedPreferences.getInstance();
      final store = await openStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: gateOverrides(
            prefs: prefs,
            store: store,
            session: _FakeSessionNotifier(localGuest()),
          ),
          child: const ReadendarApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OnboardingTourScreen), findsOneWidget);
    },
  );

  testWidgets('onboarded session skips tour and stamps device flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'locale': 'es',
      dataPlanePrefsKey: 'local',
    });
    final prefs = await SharedPreferences.getInstance();
    final user = AppUser(
      id: 'user-1',
      email: 'marina@example.com',
      displayName: 'marina',
      preferredLocale: 'es',
      timezone: 'Europe/Madrid',
      onboardingCompletedAt: DateTime(2026, 5, 19),
      termsVersion: '2026-05-01',
    );

    final store = await openStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: gateOverrides(
          prefs: prefs,
          store: store,
          session: _FakeSessionNotifier(user),
        ),
        child: const ReadendarApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(OnboardingTourScreen), findsNothing);
    expect(find.text('Términos actualizados'), findsOneWidget);
    expect(PrefsStorage(prefs).isIntroSeen(), isTrue);
    expect(prefs.getBool('onboarding_intro_seen'), isTrue);
  });
}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(AppUser user) : super(_testRef()) {
    state = SessionState(user: user);
  }

  @override
  Future<void> bootstrap() async {}

  @override
  Future<Result<void>> logout() async {
    state = const SessionState();
    return const Ok(null);
  }
}

Ref _testRef() => ProviderContainer().read(Provider<Ref>((ref) => ref));
