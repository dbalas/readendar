import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';
import 'package:readendar/features/library/book_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });
  late SharedPreferences prefs;
  setUp(() async {
    prefs = await SharedPreferences.getInstance();
  });
  final user = AppUser(
    id: 'user-1',
    email: 'marina@example.com',
    displayName: 'Marina',
    preferredLocale: 'es',
    timezone: 'Europe/Madrid',
    onboardingCompletedAt: DateTime.utc(2026),
  );

  // A non-milestone event so switching the type to a milestone leaves the
  // target field empty (the case the user hit: "save does nothing").
  ReadingEvent deadlineEvent() => ReadingEvent(
    id: 'event-1',
    ownerType: 'user',
    ownerId: 'user-1',
    bookId: 'book-1',
    type: 'deadline',
    title: 'Fecha límite',
    dateLocal: DateTime.utc(2026, 6, 20),
    status: EventStatus.active,
  );

  ReadingEvent reminderEvent({bool enabled = true}) => ReadingEvent(
    id: 'event-reminder',
    ownerType: OwnerType.user,
    ownerId: user.id,
    type: 'deadline',
    title: 'Fecha límite',
    dateLocal: DateTime.utc(2026, 8, 20),
    status: EventStatus.active,
    reminderEnabled: enabled,
    reminderMinutesBefore: enabled ? 30 : null,
  );

  Widget wrap(ReadingEvent event) => ProviderScope(
    overrides: [
      sessionProvider.overrideWith(
        (ref) => SessionNotifier(ref)..setUser(user),
      ),
      booksProvider.overrideWith((ref) async => <Book>[]),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationPrefsProvider.overrideWith(
        (ref) async => NotificationPreferences(
          globalEnabled: true,
          defaultReminderMinutesBefore: 1440,
          allDayReminderHour: 9,
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      theme: buildLightTheme(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: EventFormScreen(existing: event),
    ),
  );

  Widget wrapCreate(List<Book> books) => ProviderScope(
    overrides: [
      booksProvider.overrideWith((ref) async => books),
      notificationPrefsProvider.overrideWith(
        (ref) async => NotificationPreferences(
          globalEnabled: true,
          defaultReminderMinutesBefore: 1440,
          allDayReminderHour: 9,
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      theme: buildLightTheme(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const EventFormScreen(),
    ),
  );

  testWidgets('book field opens the shared full-screen library picker', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: OwnerType.user,
      ownerId: user.id,
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.reading,
    );
    await tester.pumpWidget(wrapCreate([book]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selecciona un libro'));
    await tester.pumpAndSettle();

    expect(find.byType(BookPickerScreen), findsOneWidget);
    expect(find.text('Dune'), findsWidgets);
    expect(find.byTooltip('Filtros'), findsOneWidget);
    expect(find.byTooltip('Añadir libro'), findsOneWidget);

    await tester.tap(find.text('Dune').last);
    await tester.pumpAndSettle();

    expect(find.byType(BookPickerScreen), findsNothing);
    expect(find.text('Dune'), findsWidgets);
  });

  testWidgets(
    'switching to a milestone type reveals its target field at once',
    (
      tester,
    ) async {
      await tester.pumpWidget(wrap(deadlineEvent()));
      await tester.pumpAndSettle();

      // The chapter-target field is not present for a deadline event.
      expect(find.textContaining('Capítulo objetivo'), findsNothing);

      // Open the type selector and pick "Hito de capítulo".
      await tester.tap(find.text('Fecha límite').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hito de capítulo').last);
      await tester.pumpAndSettle();

      // The target field appears immediately, without saving.
      expect(find.textContaining('Capítulo objetivo'), findsOneWidget);
    },
  );

  testWidgets(
    'notes stays last in General after milestone target fields',
    (tester) async {
      await tester.pumpWidget(wrap(deadlineEvent()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fecha límite').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hito de capítulo').last);
      await tester.pumpAndSettle();

      final notesY = tester.getTopLeft(find.textContaining('Notas')).dy;
      final targetY =
          tester.getTopLeft(find.textContaining('Capítulo objetivo')).dy;
      expect(notesY, greaterThan(targetY));
    },
  );

  testWidgets('saving a milestone with an empty target shows a SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(deadlineEvent()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fecha límite').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hito de capítulo').last);
    await tester.pumpAndSettle();

    // Press Save without filling the chapter target.
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    // Validation is no longer silent: a SnackBar surfaces the reason.
    expect(find.text('Añade un capítulo objetivo.'), findsWidgets);
  });

  test(
    'disabled saved reminder cancels without loading prefs or scheduling',
    () async {
      var cancelled = 0;
      var permissionRequests = 0;
      var schedules = 0;

      await reconcileSavedEventReminder(
        event: reminderEvent(enabled: false),
        loadGlobalEnabled: () async =>
            throw StateError('global prefs must not be loaded'),
        cancel: () async => cancelled++,
        requestPermission: () async {
          permissionRequests++;
          return true;
        },
        schedule: () async => schedules++,
      );

      expect(cancelled, 1);
      expect(permissionRequests, 0);
      expect(schedules, 0);
    },
  );

  test(
    'global-off saved reminder cancels without permission or scheduling',
    () async {
      var cancelled = 0;
      var permissionRequests = 0;
      var schedules = 0;

      await reconcileSavedEventReminder(
        event: reminderEvent(),
        loadGlobalEnabled: () async => false,
        cancel: () async => cancelled++,
        requestPermission: () async {
          permissionRequests++;
          return true;
        },
        schedule: () async => schedules++,
      );

      expect(cancelled, 1);
      expect(permissionRequests, 0);
      expect(schedules, 0);
    },
  );

  testWidgets('double-tap delete only issues one delete request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final repo = _SlowDeleteEventRepository();
    addTearDown(() {
      if (repo.pendingDelete != null && !repo.pendingDelete!.isCompleted) {
        repo.pendingDelete!.complete(const Ok(null));
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(
            (ref) => SessionNotifier(ref)..setUser(user),
          ),
          booksProvider.overrideWith((ref) async => <Book>[]),
          eventRepoProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: EventFormScreen(existing: deadlineEvent()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteFinder = find.byKey(const ValueKey('eventFormDelete'));
    await tester.tap(deleteFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pump();

    expect(repo.deleteCalls, 1);

    await tester.tap(deleteFinder);
    await tester.pump();

    expect(repo.deleteCalls, 1);
  });
}

class _SlowDeleteEventRepository extends ApiEventRepository {
  _SlowDeleteEventRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _NoopSecureStorage(),
          localeProvider: () => 'es',
        ),
      );

  int deleteCalls = 0;
  Completer<Result<void>>? pendingDelete;

  @override
  Future<Result<void>> delete(String id) async {
    deleteCalls++;
    pendingDelete = Completer<Result<void>>();
    return pendingDelete!.future;
  }
}

class _NoopSecureStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}
