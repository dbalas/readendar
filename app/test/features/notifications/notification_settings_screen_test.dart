import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/local/local_reading_chapter_repository.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/notification_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quotes/quotes_test_utils.dart';

AppUser _user() => AppUser(
  id: 'user-1',
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: DateTime.utc(2026),
);

class _Session extends SessionNotifier {
  _Session(super.ref, AppUser user) {
    state = SessionState(user: user);
  }
}

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => const [];
}

LocalStore _memoryStore() {
  final dir = Directory.systemTemp.createTempSync('notif-chapter');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return LocalStore.memory(Directory('${dir.path}/covers')..createSync());
}

class _ChapterPreferenceRepo extends Fake implements ReadingChapterRepository {
  _ChapterPreferenceRepo({this.saveFails = false});

  final bool saveFails;
  var enabled = true;

  @override
  void dispose() {}

  @override
  ReadingChapterStory? cachedStory(ReadingChapterRequest request) => null;

  @override
  ReadingChapterArchive? cachedArchive({String kind = 'all'}) => null;

  @override
  ReadingChapterArchive? cachedLatest() => null;

  @override
  Future<Result<bool>> notificationPreference() async => Ok(enabled);

  @override
  Future<Result<bool>> saveNotificationPreference(bool value) async {
    if (saveFails) return const Err(NetworkFailure());
    enabled = value;
    return Ok(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'pendingNotificationRequests'
          ? <Map<Object?, Object?>>[]
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => {'identifier': 'UTC'},
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
  });

  testWidgets('quote-of-the-day switch reflects the local pref immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    final user = _user();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _Session(ref, user)),
          prefsStorageProvider.overrideWithValue(prefs),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          notificationPrefsProvider.overrideWith(
            (ref) async => NotificationPreferences(
              globalEnabled: true,
              defaultReminderMinutesBefore: 1440,
              allDayReminderHour: 9,
            ),
          ),
          readingChapterNotificationPreferenceProvider.overrideWith(
            (ref) async => false,
          ),
          quoteRepoProvider.overrideWithValue(FakeQuoteRepository([])),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l = AppL10n.of(
      tester.element(find.byType(NotificationSettingsScreen)),
    );
    expect(prefs.getQuoteDailyEnabled(user.id), isFalse);

    await tester.scrollUntilVisible(
      find.text(l.quoteDailySettingTitle),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final quoteRow = find
        .ancestor(
          of: find.text(l.quoteDailySettingTitle),
          matching: find.byType(ListTile),
        )
        .first;
    final quoteSwitch = find.descendant(
      of: quoteRow,
      matching: find.byType(Switch),
    );
    expect(quoteSwitch, findsOneWidget);
    expect(tester.widget<Switch>(quoteSwitch).value, isFalse);

    await tester.tap(quoteSwitch);
    // Pref write + tick bump rebuild the row before (or without waiting on)
    // the full notification resync.
    await tester.pump();
    await tester.pump();

    expect(prefs.getQuoteDailyEnabled(user.id), isTrue);
    expect(tester.widget<Switch>(quoteSwitch).value, isTrue);
    expect(find.text(l.quoteDailyHourLabel), findsOneWidget);
  });

  for (final failure in [false, true]) {
    testWidgets(
      'Reading Chapter notification switch shows ${failure ? 'error' : 'success'} feedback',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();
        final prefs = PrefsStorage(sharedPreferences);
        final ReadingChapterRepository repository = failure
            ? _ChapterPreferenceRepo(saveFails: true)
            : LocalReadingChapterRepository(_memoryStore(), prefs);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith((ref) => _Session(ref, _user())),
              prefsStorageProvider.overrideWithValue(prefs),
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              notificationPrefsProvider.overrideWith(
                (ref) async => NotificationPreferences(
                  globalEnabled: true,
                  defaultReminderMinutesBefore: 1440,
                  allDayReminderHour: 9,
                ),
              ),
              readingChapterRepoProvider.overrideWithValue(repository),
              quoteRepoProvider.overrideWithValue(FakeQuoteRepository([])),
              booksProvider.overrideWith((ref) async => const <Book>[]),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              theme: buildLightTheme(),
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              home: const NotificationSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l = AppL10n.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );
        final chapterRow = find
            .ancestor(
              of: find.text(l.readingChapterNotificationsTitle),
              matching: find.byType(ListTile),
            )
            .first;
        final chapterSwitch = find.descendant(
          of: chapterRow,
          matching: find.byType(Switch),
        );
        expect(tester.widget<Switch>(chapterSwitch).value, isTrue);
        await tester.tap(chapterSwitch);
        await tester.pumpAndSettle();

        expect(
          find.text(
            failure ? l.errorNetwork : l.readingChapterNotificationsSaved,
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Switch>(chapterSwitch).value,
          failure ? isTrue : isFalse,
        );
        if (!failure) {
          expect(
            (await repository.notificationPreference()).value,
            isFalse,
          );
        }
      },
    );
  }

  testWidgets(
    'Reading Chapter preference load failure shows retry, not an off switch',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      final prefs = PrefsStorage(sharedPreferences);
      final chapterPref = Completer<bool>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => _Session(ref, _user())),
            prefsStorageProvider.overrideWithValue(prefs),
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            notificationPrefsProvider.overrideWith(
              (ref) async => NotificationPreferences(
                globalEnabled: true,
                defaultReminderMinutesBefore: 1440,
                allDayReminderHour: 9,
              ),
            ),
            readingChapterNotificationPreferenceProvider.overrideWith(
              (ref) => chapterPref.future,
            ),
            quoteRepoProvider.overrideWithValue(FakeQuoteRepository([])),
            booksProvider.overrideWith((ref) async => const <Book>[]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      chapterPref.completeError(const FailureException(NetworkFailure()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('readingChapterNotifError')),
        findsOneWidget,
      );
      expect(find.text('Sin conexión. Revisa la red.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );
}
