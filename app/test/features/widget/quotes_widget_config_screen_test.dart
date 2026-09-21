// The quotes-widget config screen lets the user pick what the widget shows
// (all / favorites / one book / one fixed quote) + rotation cadence, with a
// live preview, before adding it. The "Añadir widget" button is gated until a
// book/quote is chosen when the mode needs one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';
import 'package:readendar/features/widget/quotes_widget_config_screen.dart';
import 'package:readendar/features/widget/quotes_widget_preview.dart';
import 'package:readendar/features/widget/widget_models.dart';

import '../quotes/quotes_test_utils.dart';

Widget _host(
  FakeQuoteRepository repo,
  List<Book> books, {
  int? editWidgetId,
  QuotesWidgetConfig? initialConfig,
  TargetPlatform platform = TargetPlatform.android,
}) {
  final light = buildLightTheme();
  return ProviderScope(
    overrides: [
      quoteRepoProvider.overrideWithValue(repo),
      booksProvider.overrideWith((ref) async => books),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: light.colorScheme,
        platform: platform,
        cupertinoOverrideTheme: platform == TargetPlatform.iOS
            ? light.cupertinoOverrideTheme
            : null,
      ),
      home: QuotesWidgetConfigScreen(
        editWidgetId: editWidgetId,
        initialConfig: initialConfig,
      ),
    ),
  );
}

final List<Book> _books = [
  testBook(coverUrl: ''),
  testBook(id: 'b2', title: 'Pedro Páramo', coverUrl: ''),
];

List<Quote> _seed() => [
  testQuote(text: 'Muchos años después'),
  testQuote(id: 'q2', bookId: 'b2', text: 'Vine a Comala'),
];

Future<void> _openBookPicker(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      _host(FakeQuoteRepository(_seed()), _books, platform: platform),
    );
    await tester.pumpAndSettle();
  });
  await tester.tap(find.text('Un libro'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Elegir el libro'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('shows mode + cadence controls and the add button', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_host(FakeQuoteRepository(_seed()), _books));
      await tester.pumpAndSettle();
    });

    expect(find.text('Todas las citas'), findsOneWidget);
    expect(find.text('Favoritas'), findsOneWidget);
    expect(find.text('Un libro'), findsOneWidget);
    expect(find.text('Una cita fija'), findsOneWidget);
    expect(find.text('Cada día'), findsOneWidget);
    expect(find.text('Añadir widget'), findsOneWidget);
  });

  testWidgets('preview stays pinned while the form scrolls', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_host(FakeQuoteRepository(_seed()), _books));
      await tester.pumpAndSettle();
    });

    expect(find.byType(QuotesWidgetPreview), findsOneWidget);
    final before = tester.getRect(find.byType(QuotesWidgetPreview));

    final swatch = find.byKey(const ValueKey('quoteStyle_noirGold'));
    await tester.scrollUntilVisible(
      swatch,
      80,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuotesWidgetPreview).hitTestable(), findsOneWidget);
    expect(
      tester.getRect(find.byType(QuotesWidgetPreview)).top,
      closeTo(before.top, 0.5),
    );
  });

  testWidgets('style swatches include auto plus every share-card appearance', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_host(FakeQuoteRepository(_seed()), _books));
      await tester.pumpAndSettle();
    });

    final formScroll = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('quoteStyle_auto')),
      80,
      scrollable: formScroll,
    );

    expect(find.byKey(const ValueKey('quoteStyle_auto')), findsOneWidget);
    for (final style in QuoteCardStyle.values) {
      expect(
        find.byKey(ValueKey('quoteStyle_${style.name}')),
        findsOneWidget,
        reason: 'missing swatch for share style ${style.name}',
      );
    }
  });

  testWidgets('cadence hides for the fixed-quote mode', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_host(FakeQuoteRepository(_seed()), _books));
      await tester.pumpAndSettle();
    });

    expect(find.text('Cada día'), findsOneWidget);
    await tester.tap(find.text('Una cita fija'));
    await tester.pumpAndSettle();
    // Cadence chips are gone; the quote picker appears.
    expect(find.text('Cada día'), findsNothing);
    expect(find.text('Elegir la cita'), findsOneWidget);
  });

  testWidgets('add button disabled until a book is chosen in book mode', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_host(FakeQuoteRepository(_seed()), _books));
      await tester.pumpAndSettle();
    });

    await tester.tap(find.text('Un libro'));
    await tester.pumpAndSettle();

    final addButton = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Añadir widget'),
    );
    expect(addButton.onPressed, isNull, reason: 'no book picked yet');

    // Pick a book from the picker sheet.
    await tester.tap(find.text('Elegir el libro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Páramo').last);
    await tester.pumpAndSettle();

    final addAfter = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Añadir widget'),
    );
    expect(addAfter.onPressed, isNotNull, reason: 'book chosen → enabled');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('book picker lists books and filters by search ($platform)', (
      tester,
    ) async {
      await _openBookPicker(tester, platform: platform);

      expect(tester.takeException(), isNull);
      expect(find.byType(ListTile), findsNWidgets(2));
      final tile = tester.getRect(
        find.widgetWithText(ListTile, 'Pedro Páramo'),
      );
      expect(tile.height, greaterThan(40));
      expect(tile.width, greaterThan(100));

      final searchInput = find.descendant(
        of: find.byType(RdSearchField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchInput, 'pedro');
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Pedro Páramo'), findsOneWidget);
    });

    testWidgets('quote picker lists quotes on $platform', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _host(
            FakeQuoteRepository(_seed()),
            _books,
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
      });

      await tester.tap(find.text('Una cita fija'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir la cita'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(ListTile, '«Muchos años después»'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ListTile, '«Vine a Comala»'), findsOneWidget);
      final quoteTile = tester.getRect(
        find.widgetWithText(ListTile, '«Vine a Comala»'),
      );
      expect(quoteTile.height, greaterThan(40));
      await tester.tap(find.widgetWithText(ListTile, '«Vine a Comala»'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RdSearchField), findsNothing);
      expect(find.text('Elegir la cita'), findsNothing);
      expect(find.text('«Vine a Comala»'), findsWidgets);
    });

    testWidgets(
      'book picker content stays above the bottom system inset ($platform)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(bottom: 48);
        addTearDown(tester.view.reset);

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _host(
              FakeQuoteRepository(_seed()),
              _books,
              platform: platform,
            ),
          );
          await tester.pumpAndSettle();
        });

        await tester.tap(find.text('Un libro'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elegir el libro'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(ListTile), findsWidgets);
        expect(
          tester.getRect(find.byType(ListTile).first).bottom,
          lessThanOrEqualTo(700 - 48),
        );
      },
    );
  }

  testWidgets('empty library shows the add-a-quote-first CTA', (tester) async {
    await tester.pumpWidget(_host(FakeQuoteRepository([]), _books));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Añadir widget'), findsNothing);
  });

  testWidgets('notes-only library still shows the add-a-quote-first CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([
          testQuote(text: 'una nota', category: AnnotationCategory.note),
        ]),
        _books,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Añadir widget'), findsNothing);
  });

  testWidgets('edit mode saves the instance config via the native channel', (
    tester,
  ) async {
    const channel = MethodChannel('readendar/widget_pin');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _host(
          FakeQuoteRepository(_seed()),
          _books,
          editWidgetId: 7,
          initialConfig: const QuotesWidgetConfig(
            mode: QuotesWidgetMode.favorites,
            cadence: QuotesWidgetCadence.sixHourly,
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    // Edit affordances: edit title + a Save button (not "Añadir widget").
    expect(find.text('Editar widget'), findsOneWidget);
    expect(find.widgetWithText(RdButton, 'Guardar'), findsOneWidget);
    expect(find.text('Añadir widget'), findsNothing);

    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(calls.single.method, 'saveQuotesWidgetConfig');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['appWidgetId'], 7);
    expect(find.text('Widget actualizado'), findsOneWidget);
  });

  testWidgets('picking an appearance style carries it into the saved config', (
    tester,
  ) async {
    const channel = MethodChannel('readendar/widget_pin');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _host(
          FakeQuoteRepository(_seed()),
          _books,
          editWidgetId: 3,
          initialConfig: const QuotesWidgetConfig(),
        ),
      );
      await tester.pumpAndSettle();
    });

    // The appearance section shows a swatch per style; pick the sunset gradient
    // (it's below the fold, so scroll it into view first).
    final swatch = find.byKey(const ValueKey('quoteStyle_gradientSunset'));
    await tester.scrollUntilVisible(
      swatch,
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(swatch);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(calls.single.method, 'saveQuotesWidgetConfig');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(
      arguments['config'],
      contains('"style":"gradientSunset"'),
    );
  });
}
