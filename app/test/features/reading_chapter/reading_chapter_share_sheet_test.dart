import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/l10n/gen/app_localizations_es.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_share_sheet.dart';

void main() {
  testWidgets('share sheet stays local and never offers a public link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShareSheet(tester);

    await tester.tap(find.text('open-share'));
    await tester.pumpAndSettle();
    final l = AppL10nEs();
    expect(find.text(l.readingChapterShareTitle), findsOneWidget);
    final sheetL = AppL10n.of(
      tester.element(find.text(l.readingChapterShareTitle)),
    );

    expect(find.text(sheetL.readingChapterSharePrivacyBody), findsOneWidget);
    expect(find.text(sheetL.actionShare), findsOneWidget);
    expect(find.text('Identidad'), findsNothing);
    expect(find.text('Mostrar nombre visible'), findsNothing);
    expect(find.text('Mostrar foto de perfil'), findsNothing);
    expect(find.text('Crear enlace público'), findsNothing);
    expect(find.text('Actualizar enlace público'), findsNothing);
    expect(find.text('Pausar enlace público'), findsNothing);
    expect(find.text('Generar y compartir'), findsNothing);
    expect(find.byType(PageView), findsNothing);

    final circeCard = _story().cards.firstWhere(
      (card) => card.id == 'reflection-1',
    );
    await tester.scrollUntilVisible(
      find.text(sheetL.readingChapterIncludedCards.toUpperCase()),
      400,
    );
    expect(
      find.text(readingChapterShareCardPrimaryLabel(sheetL, circeCard)),
      findsNWidgets(2),
    );
    expect(find.text('Circe'), findsWidgets);
    expect(find.text(sheetL.readingChapterIncludeExcerpt), findsNWidgets(3));
    expect(find.text(sheetL.readingChapterIncludeExcerptBody), findsNothing);

    final shareButton = find.widgetWithText(RdButton, sheetL.actionShare);
    expect(tester.widget<RdButton>(shareButton).loading, isFalse);
    expect(tester.widget<RdButton>(shareButton).onPressed, isNotNull);
  });

  testWidgets('included books can be hidden before sharing', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShareSheet(tester);
    await tester.tap(find.text('open-share'));
    await tester.pumpAndSettle();

    final circeTile = find
        .ancestor(
          of: find.text('Circe'),
          matching: find.byType(RdCheckboxListTile),
        )
        .first;
    expect(tester.widget<RdCheckboxListTile>(circeTile).value, isTrue);
    await tester.tap(circeTile);
    await tester.pump();
    expect(tester.widget<RdCheckboxListTile>(circeTile).value, isFalse);
  });
}

Future<void> _pumpShareSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openReadingChapterShareSheet(
                context,
                story: _story(),
              ),
              child: const Text('open-share'),
            ),
          ),
        ),
      ),
    ),
  );
}

ReadingChapterStory _story() {
  const circe = ReadingChapterBook(
    entryId: 'circe',
    workKey: 'isbn:circe',
    title: 'Circe',
    primaryAuthor: 'Madeline Miller',
    coverUrl: '',
    format: 'physical',
    categories: [],
    categoryCodes: [],
    occurrences: 1,
  );
  const carl = ReadingChapterBook(
    entryId: 'carl',
    workKey: 'isbn:carl',
    title: 'Dungeon Crawler Carl',
    primaryAuthor: 'Matt Dinniman',
    coverUrl: '',
    format: 'ebook',
    categories: [],
    categoryCodes: [],
    occurrences: 1,
  );
  const hobbit = ReadingChapterBook(
    entryId: 'hobbit',
    workKey: 'isbn:hobbit',
    title: 'The Hobbit',
    primaryAuthor: 'J.R.R. Tolkien',
    coverUrl: '',
    format: 'physical',
    categories: [],
    categoryCodes: [],
    occurrences: 1,
  );
  ReadingChapterCard reflection({
    required String id,
    required String prompt,
    required ReadingChapterBook book,
  }) => ReadingChapterCard(
    id: id,
    kind: 'reflection',
    books: [book],
    rhythm: const [],
    formats: const [],
    reflection: ReadingChapterReflection(
      prompt: prompt,
      bookEntryId: book.entryId,
      excerpt: 'A line from ${book.title}',
      attribution: 'p. 12',
      spoiler: false,
    ),
  );
  return ReadingChapterStory(
    schemaVersion: 1,
    archetypeRuleVersion: 1,
    sourceRevision: '1-0',
    period: ReadingChapterPeriod(
      kind: ReadingChapterKind.year,
      key: '2025',
      timezone: 'UTC',
      startsAt: DateTime.utc(2025),
      endsAt: DateTime.utc(2026),
    ),
    reader: const ReadingChapterReader(
      displayName: 'Reader',
      locale: 'es',
    ),
    meaningful: true,
    cards: [
      const ReadingChapterCard(
        id: 'summary',
        kind: 'summary',
        books: [circe, carl, hobbit],
        rhythm: [],
        formats: [],
      ),
      reflection(id: 'reflection-1', prompt: 'favorite', book: circe),
      reflection(id: 'reflection-2', prompt: 'biggest_surprise', book: carl),
      reflection(id: 'reflection-3', prompt: 'comfort_read', book: hobbit),
    ],
    readiness: const [],
    curation: const [
      ReadingChapterReflection(
        prompt: 'favorite',
        bookEntryId: 'circe',
        excerpt: 'A line from Circe',
        attribution: 'p. 12',
        spoiler: false,
      ),
      ReadingChapterReflection(
        prompt: 'biggest_surprise',
        bookEntryId: 'carl',
        excerpt: 'A line from Dungeon Crawler Carl',
        attribution: 'p. 12',
        spoiler: false,
      ),
      ReadingChapterReflection(
        prompt: 'comfort_read',
        bookEntryId: 'hobbit',
        excerpt: 'A line from The Hobbit',
        attribution: 'p. 12',
        spoiler: false,
      ),
    ],
  );
}
