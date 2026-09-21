import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_circular_progress.dart';
import 'package:readendar/core/widgets/rd_section_tabs.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/rating_sheet.dart';
import 'package:readendar/features/search/search_screen.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  testWidgets('re-read action explains and waits for confirmation', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          bookRepoProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookDetailScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Re-read lives in the app-bar overflow (⋯), not as an inline button.
    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relectura').last);
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres releerlo?'), findsOneWidget);
    expect(
      find.textContaining('Empezarás de cero'),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.bookCopy), findsWidgets);
    expect(repo.rereadCount, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.rereadCount, 0);

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relectura').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Relectura'));
    await tester.pumpAndSettle();

    expect(repo.rereadCount, 1);
    expect(find.text('Relectura: «Pedro Paramo»'), findsOneWidget);
  });

  testWidgets('tapping header cover opens enlarged preview', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bookDetailCover')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Pedro Paramo'), findsWidgets);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('create menu offers add-event; overflow keeps manage actions', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    // Inline add-event / re-read buttons are gone from the body.
    expect(find.widgetWithText(FilledButton, 'Añadir evento'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Relectura'), findsNothing);

    // Creates live on FAB / AppBar +, not in the ⋯ overflow.
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Añadir'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Añadir'), findsNothing);
    expect(find.text('Añadir evento'), findsOneWidget);
    expect(find.text('Añadir nota'), findsOneWidget);
    expect(find.text('Añadir cita'), findsOneWidget);
    expect(find.text('Añadir teoría'), findsOneWidget);
    expect(find.text('Añadir pregunta'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Añadir evento')).style?.color,
      isNull,
    );
    expect(
      tester.widget<Text>(find.text('Añadir cita')).style?.color,
      isNull,
    );
    final createSheet = find.byType(BottomSheet);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: createSheet,
              matching: find.byIcon(LucideIcons.calendarPlus),
            ),
          )
          .color,
      tester
          .element(
            find.descendant(
              of: createSheet,
              matching: find.byIcon(LucideIcons.calendarPlus),
            ),
          )
          .colors
          .accentSoftFg,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: createSheet,
              matching: find.byIcon(LucideIcons.quote),
            ),
          )
          .color,
      ReadendarTokens.annQuote,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: createSheet,
              matching: find.byIcon(LucideIcons.stickyNote),
            ),
          )
          .color,
      ReadendarTokens.annNote,
    );
    Navigator.of(tester.element(find.text('Añadir evento'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();

    expect(find.text('Añadir evento'), findsNothing);
    expect(find.text('Relectura'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
  });

  testWidgets('quotes card uses the quote action color', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    final quoteIcon = find.byIcon(LucideIcons.notebookPen);
    expect(quoteIcon, findsOneWidget);
    final colors = tester.element(quoteIcon).colors;
    expect(tester.widget<Icon>(quoteIcon).color, colors.warningSoftFg);
    expect(
      find
          .ancestor(of: quoteIcon, matching: find.byType(Container))
          .evaluate()
          .any(
            (element) =>
                element.widget is Container &&
                (element.widget as Container).decoration is BoxDecoration &&
                ((element.widget as Container).decoration! as BoxDecoration)
                        .color ==
                    colors.warningSoftBg,
          ),
      isTrue,
    );
  });

  testWidgets('sticky tabs cover Detalle and Eventos', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      description: 'Una sinopsis breve para el tab Detalle.',
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    expect(find.byType(RdSectionTabs), findsOneWidget);
    expect(find.text('Detalle'), findsWidgets);
    expect(find.text('Eventos'), findsOneWidget);

    // Detalle (default) hosts synopsis.
    await tester.scrollUntilVisible(
      find.textContaining('Una sinopsis breve'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Una sinopsis breve'), findsOneWidget);

    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Aún no hay eventos para este libro'),
      findsOneWidget,
    );
    // Empty pane has no CTA — create is the FAB / AppBar + menu.
    expect(find.text('Añadir evento'), findsNothing);
  });


  testWidgets('custom fields lead the details tab when values exist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final book = Book(
      id: 'book-fields',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.reading,
      description: 'Desert planet.',
    );
    const fields = [
      BookCustomField(
        fieldId: 'field-1',
        name: 'My copy',
        iconKey: 'heart',
        position: 0,
        source: 'personal',
        readOnly: false,
        historical: false,
        value: CustomFieldValue(
          kind: CustomFieldType.boolean,
          boolean: true,
        ),
      ),
    ];

    await tester.pumpWidget(
      _personalDetail(
        book,
        _FakeBookRepository(book),
        customFields: fields,
      ),
    );
    await tester.pumpAndSettle();

    final customField = find.text('My copy');
    final synopsisLabel = find.text('Sinopsis');
    await tester.scrollUntilVisible(
      customField,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(customField, findsOneWidget);
    await tester.scrollUntilVisible(
      synopsisLabel,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(synopsisLabel, findsOneWidget);
    // Custom fields render before synopsis in the shared metadata card.
    expect(
      tester.getTopLeft(customField).dy,
      lessThan(tester.getTopLeft(synopsisLabel).dy),
    );
    await _revealInBookDetail(
      tester,
      find.byKey(const Key('bookDetailManageCustomFields')),
    );
    expect(
      find.byKey(const Key('bookDetailManageCustomFields')),
      findsOneWidget,
    );
    expect(find.text('Gestionar campos'), findsOneWidget);
    expect(find.text('Campos personalizados'), findsNothing);
  });

  testWidgets('details tab respects hidden metadata from layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final book = Book(
      id: 'book-layout',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.reading,
      description: 'Desert planet.',
      publisher: 'Chilton',
    );

    await tester.pumpWidget(
      _personalDetail(
        book,
        _FakeBookRepository(book),
        customFieldLayout: [
          const BookDetailFieldLayoutItem(
            key: 'synopsis',
            kind: BookDetailFieldKind.system,
            hidden: false,
          ),
          const BookDetailFieldLayoutItem(
            key: 'publisher',
            kind: BookDetailFieldKind.system,
            hidden: true,
          ),
          for (final key in bookDetailSystemFieldKeys)
            if (key != 'synopsis' && key != 'publisher')
              BookDetailFieldLayoutItem(
                key: key,
                kind: BookDetailFieldKind.system,
                hidden: false,
              ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _revealInBookDetail(tester, find.text('Sinopsis'));
    expect(find.text('Sinopsis'), findsOneWidget);
    expect(find.text('Editorial'), findsNothing);
    expect(find.text('Chilton'), findsNothing);
  });

  testWidgets('uses the shared editorial hierarchy in book details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      description: 'Una sinopsis breve para comprobar la jerarquía.',
      publisher: 'Editorial RM',
      language: 'es',
      isbn13: '9788415118220',
    );

    await tester.pumpWidget(
      _personalDetail(book, _FakeBookRepository(book)),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const Key('bookDetailEditorialTitle')),
    );
    expect(title.style?.fontFamily, ReadendarTokens.fontDisplay);
    expect(title.style?.fontSize, 26);
    expect(title.style?.fontWeight, FontWeight.w600);

    expect(find.text('Sinopsis'), findsOneWidget);
    expect(find.byKey(const Key('bookDetailSynopsisText')), findsOneWidget);

    await _revealInBookDetail(
      tester,
      find.byKey(const Key('bookDetailMetadataCard')),
    );
    expect(find.text('INFORMACIÓN DEL LIBRO'), findsNothing);
    expect(find.text('SINOPSIS'), findsNothing);
    expect(find.byKey(const Key('bookDetailMetadataCard')), findsOneWidget);
    expect(find.byIcon(LucideIcons.building2), findsOneWidget);
    expect(find.byIcon(LucideIcons.globe2), findsOneWidget);
    expect(find.byIcon(LucideIcons.barcode), findsOneWidget);
  });

  testWidgets(
    'details metadata rows use roomy padding with distinct field titles',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final book = Book(
        id: 'book-meta-compact',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
        publisher: 'Editorial RM',
        language: 'es',
      );

      await tester.pumpWidget(
        _personalDetail(book, _FakeBookRepository(book)),
      );
      await tester.pumpAndSettle();

      await _revealInBookDetail(tester, find.text('Editorial'));
      final label = tester.widget<Text>(find.text('Editorial'));
      expect(label.style?.fontSize, 14);
      expect(label.style?.fontWeight, FontWeight.w600);
      expect(
        label.style?.color,
        tester.element(find.text('Editorial')).colors.fg2,
      );

      final valueText = find.text('Editorial RM');
      expect(tester.widget<Text>(valueText).style, isNull);
      final valueStyle = DefaultTextStyle.of(tester.element(valueText)).style;
      expect(valueStyle.fontSize, 13);
      expect(valueStyle.color, tester.element(valueText).colors.fg1);
      expect(label.style!.fontSize! > valueStyle.fontSize!, isTrue);

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.building2));
      expect(icon.size, 13);
      final iconTile = find.ancestor(
        of: find.byIcon(LucideIcons.building2),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  tester
                      .element(find.byIcon(LucideIcons.building2))
                      .colors
                      .accentSoftBg,
        ),
      );
      expect(tester.getSize(iconTile), const Size(24, 24));

      final rowPadding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text('Editorial'),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Padding &&
                    w.padding == const EdgeInsets.all(ReadendarTokens.sp4),
              ),
            )
            .first,
      );
      expect(rowPadding.padding, const EdgeInsets.all(ReadendarTokens.sp4));
    },
  );

  testWidgets('localizes catalog language codes in book metadata', (
    tester,
  ) async {
    final book = Book(
      id: 'book-language-code',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'The Left Hand of Darkness',
      authors: const ['Ursula K. Le Guin'],
      status: BookStatus.reading,
      language: 'en',
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    await _revealInBookDetail(tester, find.text('Idioma'));
    expect(find.text('Inglés'), findsOneWidget);
    expect(find.text('en'), findsNothing);
  });

  testWidgets('localizes consumption format in book metadata', (tester) async {
    final book = Book(
      id: 'book-format',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Mistborn',
      authors: const ['Brandon Sanderson'],
      status: BookStatus.reading,
      format: BookFormat.physical,
      binding: 'Hardcover',
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    await _revealInBookDetail(tester, find.text('Formato'));
    expect(find.text('Físico'), findsOneWidget);
    expect(find.text('physical'), findsNothing);
    expect(find.byIcon(LucideIcons.book), findsWidgets);
    await _revealInBookDetail(tester, find.text('Encuadernación'));
    expect(find.text('Tapa dura'), findsOneWidget);
    expect(find.text('Hardcover'), findsNothing);
  });

  testWidgets(
    'keeps an unrecognized catalog binding visible in book metadata',
    (
      tester,
    ) async {
      final book = Book(
        id: 'book-binding-unknown',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Rare Binding',
        authors: const ['A. Writer'],
        status: BookStatus.reading,
        binding: 'Pop-up',
      );

      await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
      await tester.pumpAndSettle();

      await _revealInBookDetail(tester, find.text('Encuadernación'));
      expect(find.text('Pop-up'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps an unrecognized catalog language visible in book metadata',
    (
      tester,
    ) async {
      final book = Book(
        id: 'book-language-unknown',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Unknown Tongue',
        authors: const ['A. Writer'],
        status: BookStatus.reading,
        language: 'zz',
      );

      await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
      await tester.pumpAndSettle();

      await _revealInBookDetail(tester, find.text('Idioma'));
      expect(find.text('zz'), findsOneWidget);
    },
  );

  testWidgets('editorial hierarchy keeps semantic contrast on dark Apple UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final book = Book(
      id: 'book-dark',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      description: 'Una sinopsis breve.',
      publisher: 'Editorial RM',
    );
    final theme = buildDarkTheme().copyWith(platform: TargetPlatform.iOS);

    await tester.pumpWidget(
      _personalDetail(
        book,
        _FakeBookRepository(book),
        theme: theme,
      ),
    );
    await tester.pumpAndSettle();

    final synopsisFinder = find.byKey(const Key('bookDetailSynopsisText'));
    final colors = tester.element(synopsisFinder).colors;
    expect(tester.widget<Text>(synopsisFinder).style?.color, colors.fg1);
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.building2)).color,
      colors.accentSoftFg,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'personal detail formats year precision and omits a missing date',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final dated = Book(
        id: 'book-year',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Year Book',
        authors: const ['Autor'],
        status: BookStatus.reading,
        publicationDate: DateTime.utc(2006),
        publicationDatePrecision: PublicationDatePrecision.year,
        categories: const ['Science Fiction & Fantasy'],
        categoryCodes: const ['fantasy', 'science_fiction'],
      );
      await tester.pumpWidget(
        _personalDetail(dated, _FakeBookRepository(dated)),
      );
      await tester.pumpAndSettle();
      await _revealInBookDetail(
        tester,
        find.byKey(const Key('bookPublicationDateValue')),
      );

      expect(find.text('Fecha de publicación'), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
      expect(
        find.text(DateFormat.y('es').format(dated.publicationDate!)),
        findsOneWidget,
      );
      await _revealInBookDetail(
        tester,
        find.text('Fantasía, Ciencia ficción'),
      );
      expect(find.text('Fantasía, Ciencia ficción'), findsOneWidget);
      expect(find.text('Science Fiction & Fantasy'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final missing = Book(
        id: 'book-missing-date',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Undated Book',
        authors: const ['Autor'],
        status: BookStatus.reading,
      );
      await tester.pumpWidget(
        _personalDetail(missing, _FakeBookRepository(missing)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bookPublicationDateValue')), findsNothing);
      expect(find.text('Fecha de publicación'), findsNothing);
    },
  );

  testWidgets(
    'author link opens author catalog search and related row is hidden',
    (
      tester,
    ) async {
      // Header + sticky tabs leave little room for Detalle metadata on the
      // default 600px surface; use a taller viewport so related links stay
      // reachable after NestedScrollView coordination.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Trono de cristal',
        authors: const ['Sarah J. Maas'],
        status: BookStatus.reading,
        related: const ['9780765311788'],
      );
      final repo = _FakeBookRepository(book);

      await tester.pumpWidget(_personalDetail(book, repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('authorSearchLink-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('authorSearchLink-0')));
      await tester.pumpAndSettle();

      final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
      expect(search.initialQuery, 'Sarah J. Maas');
      expect(search.initialColumn, 'author');

      Navigator.of(tester.element(find.byType(SearchScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('relatedSearchLink-0')), findsNothing);
      expect(find.text('Libros relacionados'), findsNothing);
    },
  );

  testWidgets('detail does not offer adding a total chapter count', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    expect(find.text('Añadir nº de capítulos'), findsNothing);
  });

  testWidgets('header replaces totals with a tappable rating', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 500,
      chapterCount: 50,
      rating: 3.5,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    final rating = find.byKey(const Key('bookHeaderRating'));
    expect(rating, findsOneWidget);
    expect(find.text('500 pp.'), findsNothing);
    expect(find.text('50 capítulos'), findsNothing);
    expect(
      find.descendant(of: rating, matching: find.byType(Icon)),
      findsNWidgets(5),
    );
    expect(
      find.descendant(
        of: rating,
        matching: find.byIcon(Icons.star_half_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('3.5'), findsOneWidget);

    await tester.tap(rating);
    await tester.pumpAndSettle();

    // Personal rating opens the rating+review sheet (not rating-only).
    expect(find.byType(HalfStarPicker), findsOneWidget);
    expect(find.byKey(const Key('rating-review-save')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rating-review-save')));
    await tester.pumpAndSettle();
    expect(repo.personalRating, 3.5);
  });

  testWidgets('header shows a truncated review caption under the stars', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.read,
      rating: 4.5,
      reviewMarkdown: 'Una voz que atraviesa el polvo\ny no se calla nunca.',
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    final preview = find.byKey(const Key('bookHeaderReviewPreview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('bookHeaderRating')),
        matching: preview,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(preview).data,
      'Una voz que atraviesa el polvo y no se calla nunca.',
    );
    expect(tester.widget<Text>(preview).maxLines, 1);
    expect(tester.widget<Text>(preview).overflow, TextOverflow.ellipsis);
    expect(tester.widget<Text>(preview).style?.fontStyle, FontStyle.italic);
  });

  testWidgets('header omits review caption when there is no review', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.read,
      rating: 4.5,
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bookHeaderReviewPreview')), findsNothing);
  });

  testWidgets('unrated header renders five empty stars', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    final rating = find.byKey(const Key('bookHeaderRating'));
    expect(
      find.descendant(
        of: rating,
        matching: find.byIcon(Icons.star_outline_rounded),
      ),
      findsNWidgets(5),
    );
    expect(
      find.descendant(of: rating, matching: find.byIcon(LucideIcons.pencil)),
      findsOneWidget,
    );
  });

  testWidgets('plan-history button and a clamped, expandable synopsis render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 120,
      description: List.generate(
        40,
        (i) =>
            'Línea de sinopsis número $i con texto suficiente para envolver.',
      ).join(' '),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          // One past plan run → replan appears beside the gradient
          // "Planificar lectura" button (V2f soft tint).
          bookPlansProvider(book.id).overrideWith(
            (ref) async => [
              PlanRun(
                id: 'run-1',
                bookId: book.id,
                eventCount: 5,
                mode: 'pace',
                unit: 'pages',
                createdAt: DateTime.utc(2026, 6),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookDetailScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The planner + its history button render together (near the top).
    expect(find.text('Planificar lectura'), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarClock), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarSync), findsOneWidget);

    // Synopsis is clamped with a "Ver más" affordance that opens a full
    // screen instead of expanding inline.
    final synopsisPreview = tester.widget<Text>(
      find.byKey(const Key('bookDetailSynopsisText')),
    );
    expect(synopsisPreview.style?.fontFamily, ReadendarTokens.fontUi);
    await _revealInBookDetail(tester, find.text('Ver más'));
    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final synopsisFull = tester.widget<Text>(
      find.byKey(const Key('bookDetailSynopsisFullText')),
    );
    expect(synopsisFull.style?.fontFamily, ReadendarTokens.fontUi);
    expect(find.byKey(const Key('bookDetailSynopsisFullCard')), findsOneWidget);
    expect(find.text('Ver menos'), findsNothing);
  });

  testWidgets('shows and updates book progress', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 120,
      chapterCount: 50,
    );
    final progress = Progress(
      bookEntryId: book.id,
      currentPage: 24,
      currentPercentage: 20,
      currentChapter: 2,
    );
    final progressRepo = _FakeProgressRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(book.id).overrideWith((ref) async => progress),
          progressRepoProvider.overrideWithValue(progressRepo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookDetailScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Circular progress shows percent in the ring; totals sit under it as
    // plain page / chapter lines (no progressTitle label), with a compact Edit.
    expect(find.byType(RdCircularProgress), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('24 / 120'), findsOneWidget);
    expect(find.text('2 / 50'), findsOneWidget);
    expect(find.text('Progreso'), findsNothing);
    expect(find.byKey(const Key('progressEditButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('progressEditButton')));
    await tester.pumpAndSettle();

    // Editing the page auto-syncs the percentage from the 120-page total.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '36');
    // The chapter field (third) is editable and sent on save.
    await tester.enterText(fields.at(2), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RdButton, 'Actualizar progreso'));
    await tester.pumpAndSettle();

    expect(progressRepo.updatedBookId, book.id);
    expect(progressRepo.updatedPage, 36);
    expect(progressRepo.updatedPercentage, 30);
    expect(progressRepo.updatedChapter, 3);
  });

  testWidgets(
    'progress badge derives percent from pages when stored values disagree',
    (tester) async {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
        pageCount: 120,
      );
      final progress = Progress(
        bookEntryId: book.id,
        currentPage: 51,
        currentPercentage: 20,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookProvider(book.id).overrideWith((ref) async => book),
            eventsForBookProvider(
              book.id,
            ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
            booksProvider.overrideWith((ref) async => [book]),
            progressProvider(book.id).overrideWith((ref) async => progress),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: BookDetailScreen(bookId: book.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('51 / 120'), findsOneWidget);
      expect(find.text('43%'), findsOneWidget);
      expect(find.text('20%'), findsNothing);
    },
  );

  testWidgets('clearing progress resets pages, percentage, and chapter', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 120,
    );
    final progressRepo = _FakeProgressRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(book.id).overrideWith(
            (ref) async => Progress(
              bookEntryId: book.id,
              currentPage: 24,
              currentPercentage: 20,
              currentChapter: 2,
            ),
          ),
          progressRepoProvider.overrideWithValue(progressRepo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookDetailScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RdCircularProgress));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.enterText(find.byType(TextField).at(2), '');
    await tester.tap(find.widgetWithText(RdButton, 'Actualizar progreso'));
    await tester.pumpAndSettle();

    expect(progressRepo.updatedBookId, book.id);
    expect(progressRepo.updatedPage, 0);
    expect(progressRepo.updatedPercentage, 0);
    expect(progressRepo.updatedChapter, 0);
  });

  testWidgets(
    'progress card keeps last value while background refresh runs',
    (tester) async {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
        pageCount: 120,
        chapterCount: 50,
      );
      final initial = Progress(
        bookEntryId: book.id,
        currentPage: 24,
        currentPercentage: 20,
        currentChapter: 2,
      );
      final refreshed = Progress(
        bookEntryId: book.id,
        currentPage: 48,
        currentPercentage: 40,
        currentChapter: 4,
      );
      var fetches = 0;
      Completer<Progress>? pending;

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookProvider(book.id).overrideWith((ref) async => book),
            eventsForBookProvider(
              book.id,
            ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
            booksProvider.overrideWith((ref) async => [book]),
            progressProvider(book.id).overrideWith((ref) async {
              fetches += 1;
              if (fetches == 1) return initial;
              pending = Completer<Progress>();
              return pending!.future;
            }),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                locale: const Locale('es'),
                theme: buildLightTheme(),
                localizationsDelegates: AppL10n.localizationsDelegates,
                supportedLocales: AppL10n.supportedLocales,
                home: BookDetailScreen(bookId: book.id),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('24 / 120'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('Cargando…'), findsNothing);
      expect(find.byType(RdCircularProgress), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is LinearProgressIndicator && w.value == null,
        ),
        findsNothing,
      );

      // Mimic RevalidateOnEnter / pull-to-refresh: invalidate keeps prior data
      // while the next GET is in flight.
      container.invalidate(progressProvider(book.id));
      await tester.pump();

      expect(find.textContaining('24 / 120'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('Cargando…'), findsNothing);
      expect(find.byType(RdCircularProgress), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is LinearProgressIndicator && w.value == null,
        ),
        findsNothing,
      );
      expect(pending, isNotNull);

      pending!.complete(refreshed);
      await tester.pumpAndSettle();

      expect(find.textContaining('48 / 120'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.textContaining('24 / 120'), findsNothing);
    },
  );

  testWidgets(
    'progress card shows empty label instead of loading on first fetch',
    (tester) async {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
        pageCount: 120,
      );
      final pending = Completer<Progress>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookProvider(book.id).overrideWith((ref) async => book),
            eventsForBookProvider(
              book.id,
            ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
            booksProvider.overrideWith((ref) async => [book]),
            progressProvider(book.id).overrideWith((ref) => pending.future),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: BookDetailScreen(bookId: book.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // First fetch: ring is present with empty totals label (no progressTitle,
      // no indeterminate LinearProgressIndicator).
      expect(find.byType(RdCircularProgress), findsOneWidget);
      expect(find.text('Progreso'), findsNothing);
      expect(find.text('0%'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Sin progreso registrado'), findsOneWidget);
      expect(find.text('Cargando…'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is LinearProgressIndicator && w.value == null,
        ),
        findsNothing,
      );

      pending.complete(
        Progress(
          bookEntryId: book.id,
          currentPage: 12,
          currentPercentage: 10,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('12 / 120'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('Sin progreso registrado'), findsNothing);
    },
  );

  testWidgets('progress action stays above the bottom system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 120,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          progressRepoProvider.overrideWithValue(_FakeProgressRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookDetailScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RdCircularProgress));
    await tester.pumpAndSettle();

    final update = find.widgetWithText(RdButton, 'Actualizar progreso');
    await tester.ensureVisible(update);
    await tester.pumpAndSettle();

    expect(tester.getRect(update).bottom, lessThanOrEqualTo(800 - 48));
  });

  testWidgets('delete pops before a 404 can paint the generic error', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(
      _pushedPersonalDetail(book, repo, libraryLabel: 'library-root'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('library-root'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repo.deleted, isTrue);
    expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsNothing);
    expect(find.text('library-root'), findsOneWidget);
    expect(find.text('Libro eliminado de tu biblioteca'), findsOneWidget);
  });

  testWidgets('opening a deleted owned book pops instead of generic error', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.wanted,
    );
    final repo = _FakeBookRepository(book)..deleted = true;

    await tester.pumpWidget(
      _pushedPersonalDetail(book, repo, libraryLabel: 'library-root'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('library-root'));
    await tester.pumpAndSettle();

    expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsNothing);
    expect(find.text('library-root'), findsOneWidget);
    expect(find.byType(BookDetailScreen), findsNothing);
  });

  testWidgets('delete failure stays on detail and surfaces the error', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book)
      ..deleteFailure = const NetworkFailure();

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repo.deleted, isFalse);
    expect(find.text('Sin conexión. Revisa la red.'), findsOneWidget);
    expect(find.text('Pedro Paramo'), findsWidgets);
  });

  testWidgets('delete action lives in the overflow menu', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    // No bottom delete button — delete is the last overflow item.
    expect(find.widgetWithText(RdButton, 'Eliminar'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar'), findsOneWidget);
  });





  _statusTests();
}
Widget _pushedPersonalDetail(
  Book book,
  _FakeBookRepository repo, {
  required String libraryLabel,
}) => ProviderScope(
  overrides: [
    ..._personalDetailOverrides(book, repo),
    upcomingEventsProvider.overrideWith(
      (ref) async => const <ReadingEvent>[],
    ),
  ],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => BookDetailScreen(bookId: book.id),
            ),
          ),
          child: Text(libraryLabel),
        ),
      ),
    ),
  ),
);

List<Override> _personalDetailOverrides(
  Book book,
  _FakeBookRepository repo, {
  List<BookCustomField> customFields = const [],
  List<BookDetailFieldLayoutItem>? customFieldLayout,
}) => [
  // Resolve through the repo so a post-mutation refresh sees the new status
  // (mirrors GET /v1/books/:id returning the committed change).
  bookProvider(book.id).overrideWith((ref) async {
    final r = await repo.get(book.id);
    return r.fold((v) => v, (f) => throw FailureException(f));
  }),
  eventsForBookProvider(
    book.id,
  ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
  booksProvider.overrideWith((ref) async => [book]),
  progressProvider(
    book.id,
  ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
  bookRepoProvider.overrideWithValue(repo),
  dataPlaneProvider.overrideWith((ref) => DataPlane.api),
  bookPlansProvider(book.id).overrideWith((ref) async => const []),
  customFieldRepoProvider.overrideWithValue(
    _FakeCustomFieldRepository(customFields, layout: customFieldLayout),
  ),
];

Widget _personalDetail(
  Book book,
  _FakeBookRepository repo, {
  ThemeData? theme,
  List<BookCustomField> customFields = const [],
  List<BookDetailFieldLayoutItem>? customFieldLayout,
}) => ProviderScope(
  overrides: _personalDetailOverrides(
    book,
    repo,
    customFields: customFields,
    customFieldLayout: customFieldLayout,
  ),
  child: MaterialApp(
    locale: const Locale('es'),
    theme: theme ?? buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: BookDetailScreen(bookId: book.id),
  ),
);

class _FakeCustomFieldRepository extends ApiCustomFieldRepository {
  _FakeCustomFieldRepository(
    this.fields, {
    this.layout,
  }) : super(
         ApiClient(
           baseUrl: 'http://localhost',
           storage: _FakeSecureTokenStorage(),
           localeProvider: () => 'es',
         ),
       );

  final List<BookCustomField> fields;
  final List<BookDetailFieldLayoutItem>? layout;

  @override
  Future<Result<List<BookCustomField>>> listForBook(String bookId) async =>
      Ok(fields);

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout() async => Ok(
    layout ??
        [
          for (final field in fields)
            BookDetailFieldLayoutItem(
              key: field.fieldId,
              kind: BookDetailFieldKind.custom,
              hidden: false,
            ),
          for (final key in bookDetailSystemFieldKeys)
            BookDetailFieldLayoutItem(
              key: key,
              kind: BookDetailFieldKind.system,
              hidden: false,
            ),
        ],
  );
}

/// NestedScrollView keeps Detalle content under a tall header + sticky tabs.
/// Drag the coordinated outer scroll view until [item] is on-screen, then
/// ensureVisible for a reliable hit target.
Future<void> _revealInBookDetail(WidgetTester tester, Finder item) async {
  expect(item, findsWidgets);
  final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var i = 0; i < 24; i++) {
    final rect = tester.getRect(item);
    if (rect.top >= 0 && rect.bottom <= viewSize.height) {
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
}

void _statusTests() {
  testWidgets('status selector and progress share one reading cockpit', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    final cockpit = find
        .ancestor(of: find.text('Leyendo'), matching: find.byType(RdCard))
        .first;
    expect(
      find.descendant(of: cockpit, matching: find.byType(RdCircularProgress)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cockpit, matching: find.text('Progreso')),
      findsNothing,
    );
    expect(
      find.descendant(of: cockpit, matching: find.byIcon(LucideIcons.history)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cockpit,
        matching: find.byIcon(LucideIcons.chevronDown),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cockpit,
        matching: find.byKey(const Key('progressEditButton')),
      ),
      findsOneWidget,
    );

    // History sits inside the status chip (same row, to the right of status).
    final statusCenter = tester.getCenter(find.text('Leyendo'));
    final historyCenter = tester.getCenter(find.byIcon(LucideIcons.history));
    expect(historyCenter.dy, closeTo(statusCenter.dy, 8));
    expect(historyCenter.dx, greaterThan(statusCenter.dx));
  });

  testWidgets('status selector shows status date under status name', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.abandoned,
      statusChangedAt: DateTime.utc(2026, 3, 15, 12),
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    expect(find.text('Estado'), findsNothing);
    expect(find.text('Abandonado'), findsOneWidget);
    // Europe/Madrid session from _personalDetail — medium date in es locale.
    expect(find.text('15 mar 2026'), findsOneWidget);
  });

  testWidgets('plan actions float without a wrapping card', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );

    await tester.pumpWidget(_personalDetail(book, _FakeBookRepository(book)));
    await tester.pumpAndSettle();

    expect(find.text('Planificar lectura'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Planificar lectura'),
        matching: find.byType(RdCard),
      ),
      findsNothing,
    );
  });

  testWidgets('reading status and progress use distinct accent families', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );

    await tester.pumpWidget(
      _personalDetail(book, _FakeBookRepository(book)),
    );
    await tester.pumpAndSettle();

    const colors = ReadendarColors.light;

    Color? statusTileBg() {
      final containers = find.descendant(
        of: find
            .ancestor(of: find.text('Leyendo'), matching: find.byType(RdCard))
            .first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == colors.accentSoftBg,
        ),
      );
      if (containers.evaluate().isEmpty) return null;
      return (tester.widget<Container>(containers.first).decoration!
              as BoxDecoration)
          .color;
    }

    // Status leading icon = periwinkle soft; progress ring = success family.
    expect(statusTileBg(), colors.accentSoftBg);
    expect(find.byType(RdCircularProgress), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RdCircularProgress),
        matching: find.byWidgetPredicate(
          (w) => w is Text && w.style?.color == colors.successSoftFg,
        ),
      ),
      findsOneWidget,
    );
    expect(colors.successSoftFg, isNot(colors.accentSoftFg));
    expect(colors.successSoftBg, isNot(colors.accent2SoftBg));
  });

  testWidgets('status history is an outlined sibling of the selector', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    final historyIcon = find.byIcon(LucideIcons.history);
    expect(historyIcon, findsOneWidget);
    // Outside the status selector (not nested in BookFieldCard).
    expect(
      find.ancestor(
        of: historyIcon,
        matching: find.byType(BookFieldCard),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: historyIcon,
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );

    await tester.tap(historyIcon);
    await tester.pumpAndSettle();

    expect(find.text('Historial de estados'), findsOneWidget);
  });

  testWidgets('iOS edge swipe pops status history', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
      );
      final repo = _FakeBookRepository(book);

      await tester.pumpWidget(
        _personalDetail(
          book,
          repo,
          theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.history));
      await tester.pumpAndSettle();

      expect(find.text('Historial de estados'), findsOneWidget);
      final route =
          ModalRoute.of(tester.element(find.text('Historial de estados')))!
              as PageRoute<void>;
      expect(route, isA<CupertinoPageRoute<void>>());
      expect(route.popGestureEnabled, isTrue);

      await tester.timedDragFrom(
        const Offset(5, 300),
        const Offset(400, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de estados'), findsNothing);
      expect(find.byIcon(LucideIcons.history), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('changing status updates optimistically', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book);

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    expect(find.text('Leyendo'), findsOneWidget);
    expect(find.byIcon(LucideIcons.history), findsOneWidget);
    await tester.tap(find.text('Leyendo'));
    await tester.pumpAndSettle();

    // Pick "Pendiente" in the option sheet (avoids the celebration push that
    // "Leído" would trigger).
    await tester.tap(find.text('Pendiente').last);
    await tester.pumpAndSettle();

    expect(repo.statusChangedTo, BookStatus.pending);
    // The status row reflects the new value (overlay then confirmed refetch).
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Leyendo'), findsNothing);
  });

  testWidgets('marking as read finishes and refreshes progress', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 180,
    );
    final repo = _FakeBookRepository(book);
    var progressFetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async {
            final r = await repo.get(book.id);
            return r.value!;
          }),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          bookEventsHistoryProvider(
            book.id,
          ).overrideWith((ref) async => const <ReadingEvent>[]),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(book.id).overrideWith((ref) async {
            progressFetches++;
            if (repo.statusChangedTo == BookStatus.read) {
              return Progress(
                bookEntryId: book.id,
                currentPage: 180,
                currentPercentage: 100,
              );
            }
            return Progress(
              bookEntryId: book.id,
              currentPage: 40,
              currentPercentage: 22,
            );
          }),
          bookRepoProvider.overrideWithValue(repo),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepository(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookDetailScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('40 / 180'), findsOneWidget);
    await tester.tap(find.text('Leyendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leído').last);
    await tester.pump(); // start finish + celebration route
    await tester.pump(const Duration(seconds: 3)); // drain celebration timers

    expect(repo.statusChangedTo, BookStatus.read);
    expect(progressFetches, greaterThan(1));
  });

  testWidgets('a failed status change reverts and shows an error', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final repo = _FakeBookRepository(book)
      ..changeStatusFailure = const NetworkFailure();

    await tester.pumpWidget(_personalDetail(book, repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leyendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendiente').last);
    await tester.pumpAndSettle();

    // Reverted to the original status; a snackbar surfaced the failure.
    expect(find.text('Leyendo'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

class _FakeBookRepository extends ApiBookRepository {
  _FakeBookRepository(this.book)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  final Book book;
  int rereadCount = 0;
  String? statusChangedTo;
  double? personalRating;
  bool deleted = false;
  // When set, changeStatus returns this failure instead of succeeding.
  Failure? changeStatusFailure;
  Failure? deleteFailure;

  @override
  Future<Result<Book>> reread(String id) async {
    rereadCount += 1;
    return Ok(book);
  }

  @override
  Future<Result<Book>> updateTotals(
    String id, {
    int? pageCount,
    int? chapterCount,
  }) async {
    return Ok(book.copyWith(chapterCount: chapterCount));
  }

  @override
  Future<Result<Book>> updatePersonal(
    String id, {
    required double? rating,
  }) async {
    personalRating = rating;
    return Ok(
      book.copyWith(
        rating: rating,
        clearRating: rating == null,
      ),
    );
  }

  @override
  Future<Result<Book>> updateRatingReview(
    String id, {
    required double? rating,
    required String reviewMarkdown,
  }) async {
    personalRating = rating;
    return Ok(
      book.copyWith(
        rating: rating,
        clearRating: rating == null,
        reviewMarkdown: reviewMarkdown,
      ),
    );
  }

  @override
  Future<Result<Book>> finish(
    String id, {
    required String idempotencyKey,
    double? rating,
    String reviewMarkdown = '',
    bool saveRatingReview = false,
  }) async {
    statusChangedTo = BookStatus.read;
    return Ok(book.copyWith(status: BookStatus.read));
  }

  @override
  Future<Result<Book>> changeStatus(String id, String status) async {
    if (changeStatusFailure != null) return Err(changeStatusFailure!);
    statusChangedTo = status; // commit only on success
    return Ok(book.copyWith(status: status));
  }

  @override
  Future<Result<BookStatusHistoryPage>> listStatusHistory(
    String bookId, {
    String? cursor,
    int limit = 20,
  }) async => Ok(BookStatusHistoryPage(items: const []));

  @override
  Future<Result<void>> delete(String id) async {
    if (deleteFailure != null) return Err(deleteFailure!);
    deleted = true;
    return const Ok(null);
  }

  @override
  Future<Result<Book>> get(String id) async {
    if (deleted) return const Err(NotFoundFailure());
    return Ok(
      book.copyWith(
        status: statusChangedTo ?? book.status,
      ),
    );
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
    return Ok(
      Progress(
        bookEntryId: bookId,
        currentPage: page,
        currentPercentage: percentage,
      ),
    );
  }
}


class _FakeSecureTokenStorage extends SecureTokenStorage {
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
