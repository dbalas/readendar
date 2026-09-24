import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/roulette/book_roulette_screen.dart';

import '../../helpers/linux_goldens.dart';

Book _book(
  String id, {
  String status = BookStatus.pending,
  String? title,
  String? author,
}) => Book(
  id: id,
  ownerType: 'user',
  ownerId: 'user-1',
  title: title ?? 'Book $id',
  authors: [author ?? 'Author $id'],
  status: status,
);

Widget _wrap(
  List<Book> books, {
  ThemeMode themeMode = ThemeMode.light,
}) => ProviderScope(
  overrides: [booksProvider.overrideWith((ref) async => books)],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    themeMode: themeMode,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: const BookRouletteScreen(),
  ),
);

void main() {
  testWidgets('no eligible books → empty nudge to add books', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap([_book('1', status: BookStatus.read)]));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Añade libros en Leyendo, Pendiente o Deseado y la ruleta '
          'elegirá tu próxima lectura.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RdButton, 'Añadir libros'),
        findsOneWidget,
      );
      // Shelf badges: Pending / Wanted first, Reading last.
      expect(find.byKey(const Key('roulette-status-pending')), findsOneWidget);
      expect(find.byKey(const Key('roulette-status-wanted')), findsOneWidget);
      expect(find.byKey(const Key('roulette-status-reading')), findsOneWidget);
    });
  });

  testWidgets(
    'reading-only library → filtered empty until Reading badge is on (M-01)',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap([_book('1', status: BookStatus.reading)]),
        );
        await tester.pumpAndSettle();

        // Reading starts off; Pending/Wanted are empty → filtered empty.
        expect(
          find.text(
            'Activa Leyendo, Pendiente o Deseado para incluir '
            'libros en la ruleta.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('roulette-status-reading')));
        await tester.pumpAndSettle();

        expect(find.textContaining('«Book 1»'), findsOneWidget);
        expect(
          find.widgetWithText(RdButton, 'Añadir más libros'),
          findsOneWidget,
        );
        expect(find.text('Desliza para girar'), findsNothing);
      });
    },
  );

  testWidgets('one pending book → shows it with add-more nudge', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap([_book('1')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('«Book 1»'), findsOneWidget);
      expect(
        find.widgetWithText(RdButton, 'Añadir más libros'),
        findsOneWidget,
      );
      expect(find.text('Desliza para girar'), findsNothing);
    });
  });

  testWidgets('pending + wanted → wheel; reading stays out until toggled', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap([
          _book('1', status: BookStatus.reading),
          _book('2'),
          _book('3', status: BookStatus.wanted),
        ]),
      );
      await tester.pumpAndSettle();

      // Default pool is pending+wanted (2) → wheel.
      expect(find.text('Desliza para girar'), findsOneWidget);
      expect(find.text('Tu próxima lectura'), findsNothing);
      expect(
        find.widgetWithText(RdButton, 'Abrir libro'),
        findsNothing,
      );
    });
  });

  testWidgets('wheel renders simplified portal chrome in light and dark', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          _wrap([_book('1'), _book('2'), _book('3')], themeMode: themeMode),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('roulette-center-spotlight')),
          findsNothing,
        );
        expect(find.byKey(const Key('roulette-rail-top')), findsOneWidget);
        expect(find.byKey(const Key('roulette-rail-bottom')), findsOneWidget);
        expect(find.byKey(const Key('roulette-pointer-top')), findsOneWidget);
        expect(
          find.byKey(const Key('roulette-pointer-bottom')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('roulette-strip'))).height,
          268,
        );
        expect(
          tester
              .widget<Positioned>(
                find.byKey(const Key('roulette-pointer-top-position')),
              )
              .top,
          21,
        );
        expect(
          tester
              .widget<Positioned>(
                find.byKey(const Key('roulette-pointer-bottom-position')),
              )
              .bottom,
          21,
        );
        expect(
          tester
              .widget<CustomPaint>(
                find.byKey(const Key('roulette-pointer-top')),
              )
              .size,
          const Size(18, 24),
        );
        expect(
          tester
              .widget<CustomPaint>(
                find.byKey(const Key('roulette-pointer-bottom')),
              )
              .size,
          const Size(18, 24),
        );
        expect(
          find.byKey(const Key('roulette-repaint-boundary')),
          findsOneWidget,
        );
      }
    });
  });

  testWidgets('status buttons share one row with equal widths and gaps', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap([_book('1'), _book('2'), _book('3')]));
      await tester.pumpAndSettle();

      final rects = [
        for (final status in kRouletteStatuses)
          tester.getRect(find.byKey(Key('roulette-status-$status'))),
      ];

      expect(rects[1].top, moreOrLessEquals(rects[0].top));
      expect(rects[2].top, moreOrLessEquals(rects[0].top));
      expect(rects[1].width, moreOrLessEquals(rects[0].width));
      expect(rects[2].width, moreOrLessEquals(rects[0].width));
      final firstGap = rects[1].left - rects[0].right;
      final secondGap = rects[2].left - rects[1].right;
      expect(firstGap, moreOrLessEquals(ReadendarTokens.sp3));
      expect(secondGap, moreOrLessEquals(firstGap));
    });
  });

  testWidgets('editorial pointers remain stationary while dragging', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap([_book('1'), _book('2'), _book('3')]));
      await tester.pumpAndSettle();

      final pointer = find.byKey(
        const Key('roulette-pointer-top-position'),
      );
      double pointerTop() => tester.widget<Positioned>(pointer).top!;
      final restingTop = pointerTop();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('roulette-strip'))),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();

      expect(pointerTop(), restingTop);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'editorial portal matches ${themeMode.name} golden',
      skip: !runLinuxGoldens,
      (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap([_book('1'), _book('2'), _book('3')], themeMode: themeMode),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(BookRouletteScreen),
          matchesGoldenFile(
            'goldens/roulette_editorial_portal_${themeMode.name}.png',
          ),
        );
      });
    });

    testWidgets(
      'winner panel matches ${themeMode.name} golden',
      skip: !runLinuxGoldens,
      (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap([
            _book('1', title: 'Libro', author: 'Autor'),
            _book('2', title: 'Libro', author: 'Autor'),
            _book('3', title: 'Libro', author: 'Autor'),
          ], themeMode: themeMode),
        );
        await tester.pumpAndSettle();

        await tester.fling(
          find.byKey(const Key('roulette-strip')),
          const Offset(-300, 0),
          1000,
        );
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 700));

        await expectLater(
          find.byKey(const Key('roulette-winner-panel')),
          matchesGoldenFile(
            'goldens/roulette_winner_panel_${themeMode.name}.png',
          ),
        );
      });
    });
  }

  testWidgets('deselecting all matching shelves → filtered empty', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap([_book('1')]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('«Book 1»'), findsOneWidget);

      await tester.tap(find.byKey(const Key('roulette-status-pending')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Activa Leyendo, Pendiente o Deseado para incluir '
          'libros en la ruleta.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RdButton, 'Añadir libros'),
        findsNothing,
      );
    });
  });

  testWidgets('toggling Wanted on mixes Wanted books into the wheel', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap([
          _book('1'),
          _book('2', status: BookStatus.wanted),
        ]),
      );
      await tester.pumpAndSettle();

      // Both default shelves on → wheel.
      expect(find.text('Desliza para girar'), findsOneWidget);

      // Drop Wanted → only one pending left → single state.
      await tester.tap(find.byKey(const Key('roulette-status-wanted')));
      await tester.pumpAndSettle();
      expect(find.textContaining('«Book 1»'), findsOneWidget);
      expect(find.text('Desliza para girar'), findsNothing);

      // Re-enable Wanted → wheel again.
      await tester.tap(find.byKey(const Key('roulette-status-wanted')));
      await tester.pumpAndSettle();
      expect(find.text('Desliza para girar'), findsOneWidget);
    });
  });

  testWidgets('winner panel favors clearance above the filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap([_book('1'), _book('2'), _book('3')]));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const Key('roulette-strip')),
        const Offset(-300, 0),
        1000,
      );
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 700));

      final wheel = tester.getRect(find.byKey(const Key('roulette-strip')));
      final panel = tester.getRect(
        find.byKey(const Key('roulette-winner-panel')),
      );
      final filtersTop = tester
          .getRect(find.byKey(const Key('roulette-status-pending')))
          .top;
      final lowerRailY = wheel.bottom - 33;
      final upperGap = panel.top - lowerRailY;
      final lowerGap = filtersTop - panel.bottom;

      expect(
        lowerGap - upperGap,
        moreOrLessEquals(
          ReadendarTokens.sp8,
          epsilon: ReadendarTokens.sp2,
        ),
      );
    });
  });

  testWidgets('swiping the wheel spins and lands on a winner', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap([_book('1'), _book('2'), _book('3')]));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const Key('roulette-strip')),
        const Offset(-300, 0),
        1000,
      );
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Tu próxima lectura'), findsOneWidget);
      expect(
        find.widgetWithText(RdButton, 'Abrir libro'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RdButton, 'Girar de nuevo'),
        findsOneWidget,
      );
      expect(find.text('Desliza para girar'), findsOneWidget);
    });
  });

  testWidgets('library load failure shows ErrorRetry instead of empty pool', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const BookRouletteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
  });
}
