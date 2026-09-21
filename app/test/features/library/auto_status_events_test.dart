import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/auto_status_events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../helpers/api_repo_stubs.dart';

ReadingEvent _event({
  required String type,
  required DateTime dateLocal,
  String status = EventStatus.active,
}) => ReadingEvent(
  id: 'e-$type-${dateLocal.toIso8601String()}',
  ownerType: OwnerType.user,
  ownerId: 'u1',
  type: type,
  title: type,
  dateLocal: dateLocal,
  status: status,
  bookId: 'b1',
);

Book _book({String status = BookStatus.pending}) => Book(
  id: 'b1',
  ownerType: OwnerType.user,
  ownerId: 'u1',
  title: 'Dune',
  authors: const ['Frank Herbert'],
  status: status,
);

AppUser _user({bool autoCreate = true}) => AppUser(
  id: 'u1',
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime.utc(2026, 1, 2),
  autoCreateStatusEvents: autoCreate,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('autoStatusEventType', () {
    test('returns start when moving to reading with flag on', () {
      expect(
        autoStatusEventType(
          enabled: true,
          previousStatus: BookStatus.pending,
          newStatus: BookStatus.reading,
        ),
        EventType.start,
      );
    });

    test('returns finish when moving to read with flag on', () {
      expect(
        autoStatusEventType(
          enabled: true,
          previousStatus: BookStatus.reading,
          newStatus: BookStatus.read,
        ),
        EventType.finish,
      );
    });

    test('noop when flag off, same status, or other status', () {
      expect(
        autoStatusEventType(
          enabled: false,
          previousStatus: BookStatus.pending,
          newStatus: BookStatus.reading,
        ),
        isNull,
      );
      expect(
        autoStatusEventType(
          enabled: true,
          previousStatus: BookStatus.reading,
          newStatus: BookStatus.reading,
        ),
        isNull,
      );
      expect(
        autoStatusEventType(
          enabled: true,
          previousStatus: BookStatus.reading,
          newStatus: BookStatus.abandoned,
        ),
        isNull,
      );
    });
  });

  group('hasActiveAutoStatusEventOnDay', () {
    test('only matches same civil day', () {
      final today = DateTime(2026, 8, 10);
      expect(
        hasActiveAutoStatusEventOnDay(
          [_event(type: 'start', dateLocal: today)],
          EventType.start,
          today,
        ),
        isTrue,
      );
      expect(
        hasActiveAutoStatusEventOnDay(
          [_event(type: 'start', dateLocal: DateTime(2026, 8, 9))],
          EventType.start,
          today,
        ),
        isFalse,
      );
      expect(
        hasActiveAutoStatusEventOnDay(
          [
            _event(
              type: 'start',
              dateLocal: today,
              status: EventStatus.cancelled,
            ),
          ],
          EventType.start,
          today,
        ),
        isFalse,
      );
    });
  });

  group('civilTodayInAppTimeZone', () {
    test('uses IANA civil day, not UTC day', () {
      final today = civilTodayInAppTimeZone(
        'America/Los_Angeles',
        nowUtc: DateTime.utc(2026, 8, 10, 1, 30),
      );
      expect(today, DateTime(2026, 8, 9));
      expect(tz.getLocation('America/Los_Angeles'), isNotNull);
    });
  });

  group('maybeAutoCreateStatusEvents', () {
    testWidgets('creates start event when user flag enabled', (tester) async {
      final events = _FakeEventRepository();
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(events),
            sessionProvider.overrideWith((r) {
              final n = SessionNotifier(r)..setUser(_user());
              return n;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l = AppL10n.of(tester.element(find.byType(Scaffold)));
      await maybeAutoCreateStatusEvents(
        ref: ref,
        context: tester.element(find.byType(Scaffold)),
        book: _book(),
        previousStatus: BookStatus.pending,
        newStatus: BookStatus.reading,
        l: l,
      );
      await tester.pump();

      expect(events.createCalls, 1);
      expect(events.lastType, 'start');
      expect(events.lastReminderEnabled, isFalse);
    });

    testWidgets('skips only when same-day start exists', (tester) async {
      final today = civilTodayInAppTimeZone('Europe/Madrid');
      final events = _FakeEventRepository(
        existing: [
          _event(
            type: 'start',
            dateLocal: today.subtract(const Duration(days: 3)),
          ),
        ],
      );
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(events),
            sessionProvider.overrideWith((r) {
              final n = SessionNotifier(r)..setUser(_user());
              return n;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l = AppL10n.of(tester.element(find.byType(Scaffold)));
      await maybeAutoCreateStatusEvents(
        ref: ref,
        context: tester.element(find.byType(Scaffold)),
        book: _book(),
        previousStatus: BookStatus.pending,
        newStatus: BookStatus.reading,
        l: l,
      );
      await tester.pump();
      expect(events.createCalls, 1);

      events.existing = [_event(type: 'start', dateLocal: today)];
      events.createCalls = 0;
      await maybeAutoCreateStatusEvents(
        ref: ref,
        context: tester.element(find.byType(Scaffold)),
        book: _book(),
        previousStatus: BookStatus.pending,
        newStatus: BookStatus.reading,
        l: l,
      );
      await tester.pump();
      expect(events.createCalls, 0);
    });

    testWidgets('noop when user flag disabled', (tester) async {
      final events = _FakeEventRepository();
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(events),
            sessionProvider.overrideWith((r) {
              final n = SessionNotifier(r)..setUser(_user(autoCreate: false));
              return n;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l = AppL10n.of(tester.element(find.byType(Scaffold)));
      await maybeAutoCreateStatusEvents(
        ref: ref,
        context: tester.element(find.byType(Scaffold)),
        book: _book(),
        previousStatus: BookStatus.pending,
        newStatus: BookStatus.reading,
        l: l,
      );
      expect(events.createCalls, 0);
    });

    testWidgets('shows failure toast when create fails', (tester) async {
      final events = _FakeEventRepository(failCreate: true);
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(events),
            sessionProvider.overrideWith((r) {
              final n = SessionNotifier(r)..setUser(_user());
              return n;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l = AppL10n.of(tester.element(find.byType(Scaffold)));
      await maybeAutoCreateStatusEvents(
        ref: ref,
        context: tester.element(find.byType(Scaffold)),
        book: _book(status: BookStatus.reading),
        previousStatus: BookStatus.reading,
        newStatus: BookStatus.read,
        l: l,
      );
      await tester.pump();

      expect(events.createCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

class _FakeEventRepository extends ApiEventRepository {
  _FakeEventRepository({List<ReadingEvent>? existing, this.failCreate = false})
    : existing = existing ?? <ReadingEvent>[],
      super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  List<ReadingEvent> existing;
  final bool failCreate;
  int createCalls = 0;
  String? lastType;
  bool? lastReminderEnabled;

  @override
  Future<Result<List<ReadingEvent>>> listForBook(String bookId) async =>
      Ok(existing);

  @override
  Future<Result<ReadingEvent>> create({
    required String ownerType,
    required String ownerId,
    required String type,
    required String title,
    required DateTime dateLocal,
    String? bookId,
    String? timeLocal,
    String? tz,
    String description = '',
    int? targetChapter,
    int? targetPage,
    bool reminderEnabled = true,
    int? reminderMinutesBefore,
    String? idempotencyKey,
  }) async {
    createCalls++;
    lastType = type;
    lastReminderEnabled = reminderEnabled;
    if (failCreate) {
      return const Err(NetworkFailure('offline'));
    }
    return Ok(
      ReadingEvent(
        id: 'new-$type',
        ownerType: ownerType,
        ownerId: ownerId,
        type: type,
        title: title,
        dateLocal: dateLocal,
        status: EventStatus.active,
        bookId: bookId,
        reminderEnabled: reminderEnabled,
      ),
    );
  }
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
