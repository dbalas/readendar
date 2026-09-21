import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/api_repo_stubs.dart';

ReadingEvent _chapterEvent() => ReadingEvent(
  id: 'event-1',
  ownerType: 'user',
  ownerId: 'user-1',
  bookId: 'book-1',
  type: 'chapter_milestone',
  title: 'Chapter 5',
  targetChapter: 5,
  dateLocal: DateTime.utc(2026, 6, 12),
  status: EventStatus.active,
);

// Presents the sheet the way the app does (a modal route over a base page), so
// the post-completion Navigator.pop() returns to the base instead of emptying
// the navigator history.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeEventRepository events,
  required _FakeProgressRepository progress,
  required PrefsStorage prefs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventRepoProvider.overrideWithValue(events),
        progressRepoProvider.overrideWithValue(progress),
        prefsStorageProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEventDetailSheet(context, _chapterEvent()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('completing a chapter milestone prompts to update the page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    final events = _FakeEventRepository();
    final progress = _FakeProgressRepository();

    await _pump(tester, events: events, progress: progress, prefs: prefs);

    await tester.tap(find.widgetWithText(RdButton, '¡Completar!'));
    await tester.pumpAndSettle();

    expect(find.text('¡Capítulo completado!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '120');
    await tester.pump();
    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(events.completedId, 'event-1');
    expect(progress.updatedBookId, 'book-1');
    expect(progress.updatedPage, 120);
  });

  testWidgets('empty Save is blocked and does not update progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    final events = _FakeEventRepository();
    final progress = _FakeProgressRepository();

    await _pump(tester, events: events, progress: progress, prefs: prefs);

    await tester.tap(find.widgetWithText(RdButton, '¡Completar!'));
    await tester.pumpAndSettle();

    expect(find.text('¡Capítulo completado!'), findsOneWidget);

    final saveButton = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Guardar'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pump();

    expect(progress.updatedBookId, isNull);
    expect(find.text('¡Capítulo completado!'), findsOneWidget);
  });

  testWidgets('"Ahora no" closes the prompt without updating progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    final events = _FakeEventRepository();
    final progress = _FakeProgressRepository();

    await _pump(tester, events: events, progress: progress, prefs: prefs);

    await tester.tap(find.widgetWithText(RdButton, '¡Completar!'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(RdButton, 'Ahora no'));
    await tester.pumpAndSettle();

    expect(events.completedId, 'event-1');
    expect(progress.updatedBookId, isNull);
  });

  testWidgets('checking "don\'t show again" suppresses the next prompt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    final events = _FakeEventRepository();
    final progress = _FakeProgressRepository();

    await _pump(tester, events: events, progress: progress, prefs: prefs);

    await tester.tap(find.widgetWithText(RdButton, '¡Completar!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No volver a mostrar para este libro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RdButton, 'Ahora no'));
    await tester.pumpAndSettle();

    expect(prefs.isChapterPromptHidden('book-1'), isTrue);

    // A second completion of the same book skips the prompt entirely.
    await _pump(tester, events: events, progress: progress, prefs: prefs);
    await tester.tap(find.widgetWithText(RdButton, '¡Completar!'));
    await tester.pumpAndSettle();
    expect(find.text('¡Capítulo completado!'), findsNothing);
  });
}

class _FakeEventRepository extends ApiEventRepository {
  _FakeEventRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  String? completedId;

  @override
  Future<Result<ReadingEvent>> complete(String id) async {
    completedId = id;
    return Ok(_chapterEvent());
  }
}

class _FakeProgressRepository extends ApiProgressRepository {
  _FakeProgressRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  String? updatedBookId;
  int? updatedPage;
  int? updatedChapter;
  int? updatedPercentage;

  @override
  Future<Result<Progress>> update(
    String bookId, {
    int? page,
    int? chapter,
    int? percentage,
  }) async {
    updatedBookId = bookId;
    updatedPage = page;
    updatedChapter = chapter;
    updatedPercentage = percentage;
    return Ok(Progress(bookEntryId: bookId, currentPage: page));
  }
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
