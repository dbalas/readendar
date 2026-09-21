// WidgetPreview renders the in-app "this is what your widget will show"
// snapshot in the add-widget sheet. It mirrors the native widget layout: a
// "READENDAR" wordmark + a currently-reading cover strip on top, then the
// upcoming events as app-style EventCardCompact rows (empty-events message when
// there are none). widgetSummaryProvider is overridden per-state so these run
// as plain widget tests with no network.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widget_preview.dart';

Widget _wrap(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  // Match the production root scope (main.dart): no riverpod-3 automatic
  // retry, so a throwing provider surfaces its error state immediately.
  retry: (retryCount, error) => null,
  child: MaterialApp(
    theme: buildLightTheme(),
    locale: const Locale('es'), // pin so string assertions are deterministic
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: const Scaffold(body: Center(child: WidgetPreview())),
  ),
);

Override _summary(WidgetSummary s) =>
    widgetSummaryProvider.overrideWith((ref) async => s);

void main() {
  testWidgets('loading → shows the placeholder, no state text', (tester) async {
    await tester.pumpWidget(
      _wrap([
        // Never completes → stays in the loading state.
        widgetSummaryProvider.overrideWith(
          (ref) => Completer<WidgetSummary>().future,
        ),
      ]),
    );
    await tester.pump(); // one frame; do NOT settle (future never resolves)

    expect(find.byKey(const Key('widgetPreviewLoading')), findsOneWidget);
  });

  testWidgets('fetch error → shows the distinct error line', (tester) async {
    await tester.pumpWidget(
      _wrap([
        widgetSummaryProvider.overrideWith(
          (ref) async => throw Exception('boom'),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo actualizar'), findsOneWidget);
    // Not confused with the genuinely-empty state.
    expect(find.text('Añade una lectura'), findsNothing);
  });

  testWidgets('empty summary → shows the no-upcoming-events message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap([
        _summary(const WidgetSummary(readingBooks: [], events: [])),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay eventos próximos'), findsOneWidget);
    expect(find.text('No se pudo actualizar'), findsNothing);
  });

  testWidgets('reading book, no events → no strip (single book), empty msg', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap([
          _summary(
            const WidgetSummary(
              readingBooks: [
                WidgetBook(
                  id: 'b1',
                  title: 'El nombre del viento',
                  author: 'Patrick Rothfuss',
                  coverUrl: '',
                  progressPct: 42,
                ),
              ],
              events: [],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
    });

    // Single book doesn't show in the strip (strip only appears with 2+), and
    // the event area shows the empty-events message.
    expect(find.text('No hay eventos próximos'), findsOneWidget);
    expect(find.text('READENDAR'), findsOneWidget);
    // No strip, so the book initials don't appear.
    expect(find.text('El nombre del viento'), findsNothing);
  });

  testWidgets('upcoming events render as app-style rows', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap([
          _summary(
            const WidgetSummary(
              readingBooks: [
                WidgetBook(
                  id: 'b1',
                  title: 'Strip only',
                  author: 'X',
                  coverUrl: '',
                  progressPct: 10,
                ),
              ],
              events: [
                WidgetEvent(
                  id: 'e1',
                  type: 'deadline',
                  dateLocal: '2026-08-15',
                  bookTitle: 'El señor de los anillos',
                  bookAuthor: 'J. R. R. Tolkien',
                ),
              ],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
    });

    // The event renders as a full row: the book title shows (both in the row and
    // its own cover fallback chip → ≥1), plus the author and the type label.
    expect(find.text('El señor de los anillos'), findsAtLeastNWidgets(1));
    expect(find.text('J. R. R. Tolkien'), findsOneWidget);
    expect(find.text('Fecha límite'), findsOneWidget);
    expect(find.byType(ReadendarWidgetHeader), findsOneWidget);
    // A single reading book is NOT shown in the header strip (needs 2+).
    expect(find.text('Strip only'), findsNothing);
  });

  testWidgets('milestone event → book title then progress, no duplicate', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap([
          _summary(
            const WidgetSummary(
              readingBooks: [],
              events: [
                WidgetEvent(
                  id: 'e1',
                  type: 'page_milestone',
                  dateLocal: '2026-08-15',
                  bookTitle: 'Dune',
                  title: 'Página 143',
                ),
              ],
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
    });

    // Line 1 = book title, line 2 = the progress milestone; "Página 143" shows
    // exactly once (never duplicated), and the book title only in its row/chip.
    expect(find.text('Página 143'), findsOneWidget);
    expect(find.text('Dune'), findsAtLeastNWidgets(1));
  });

  testWidgets('milestone event without a resolvable book → no duplicate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap([
        _summary(
          const WidgetSummary(
            readingBooks: [],
            events: [
              WidgetEvent(
                id: 'e1',
                type: 'page_milestone',
                dateLocal: '2026-08-15',
                title: 'Página 143',
              ),
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // With no book, the milestone becomes the row's own title line and must not
    // also appear as a second line — exactly once total.
    expect(find.text('Página 143'), findsOneWidget);
  });

  testWidgets('completable rows show a check toggle; completed is checked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap([
        _summary(
          const WidgetSummary(
            readingBooks: [],
            events: [
              WidgetEvent(
                id: 'a',
                type: 'page_milestone',
                dateLocal: '2026-08-15',
                title: 'P1',
              ),
              WidgetEvent(
                id: 'b',
                type: 'page_milestone',
                dateLocal: '2026-08-16',
                title: 'P2',
                status: 'completed',
              ),
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // One active (outline circle) + one completed (filled check), mirroring native.
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('hasMore → shows the see-more footer', (tester) async {
    await tester.pumpWidget(
      _wrap([
        _summary(
          const WidgetSummary(
            readingBooks: [],
            hasMore: true,
            events: [
              WidgetEvent(
                id: 'e1',
                type: 'page_milestone',
                dateLocal: '2026-08-15',
                title: 'Página 1',
              ),
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver más en el calendario'), findsOneWidget);
  });
}
