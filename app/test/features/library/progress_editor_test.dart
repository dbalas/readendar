import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/progress_editor.dart';

Book _book() => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Pedro Paramo',
  authors: const ['Juan Rulfo'],
  status: BookStatus.reading,
  pageCount: 120,
  chapterCount: 50,
);

class _FakeProgressRepository extends Fake implements ProgressRepository {
  int calls = 0;
  int? lastPage;
  int? lastPercentage;
  int? lastChapter;

  @override
  Future<Result<Progress>> update(
    String bookId, {
    int? page,
    int? chapter,
    int? percentage,
  }) async {
    calls++;
    lastPage = page;
    lastPercentage = percentage;
    lastChapter = chapter;
    return Ok(
      Progress(
        bookEntryId: bookId,
        currentPage: page,
        currentChapter: chapter,
        currentPercentage: percentage,
      ),
    );
  }
}

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('progress sheet keeps field focus when the keyboard inset opens', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      final book = _book();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressRepoProvider.overrideWithValue(_FakeProgressRepository()),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showProgressEditorSheet(
                      context,
                      book: book,
                      initial: Progress(
                        bookEntryId: book.id,
                        currentPage: 24,
                        currentPercentage: 20,
                        currentChapter: 2,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final pageField = find.byKey(const Key('progressPageField'));
      expect(pageField, findsOneWidget);
      await tester.tap(pageField);
      await tester.pump();

      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      // Simulate the IME opening — previously swapped Padding in/out and
      // dismissed focus within a frame.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('progressPageField')), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      await tester.enterText(pageField, '36');
      await tester.pump();
      expect(find.text('36'), findsOneWidget);

      tester.view.resetViewInsets();
    });
  });

  testWidgets('Save PUTs through the shared progress helper', (tester) async {
    final book = _book();
    final repo = _FakeProgressRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepoProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showProgressEditorSheet(
                    context,
                    book: book,
                    initial: Progress(
                      bookEntryId: book.id,
                      currentPage: 24,
                      currentPercentage: 20,
                      currentChapter: 2,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('progressPageField')), '40');
    await tester.tap(find.byKey(const Key('progressSaveButton')));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.lastPage, 40);
    expect(find.text('Progreso actualizado'), findsOneWidget);
  });
}
