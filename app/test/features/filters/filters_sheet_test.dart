import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/features/filters/filter_search_field.dart';
import 'package:readendar/features/filters/filters_sheet.dart';

Widget _wrap({bool booksOnly = true}) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showFiltersSheet(context, booksOnly: booksOnly),
            child: const Text('Open filters'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Library filters keep only focused controls and state colors', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    expect(find.text('Tipo de evento'), findsNothing);
    expect(find.text('Finalización'), findsNothing);
    expect(find.text('Fecha'), findsNothing);
    expect(find.text('Contexto'), findsNothing);
    expect(find.text('Solo personal'), findsNothing);
    expect(find.byType(RdTextField), findsNothing);
    expect(find.byType(FilterSearchField), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);

    final reading = find.byKey(const Key('filter-status-reading'));
    expect(reading, findsOneWidget);
    expect(tester.getSize(reading).width, lessThan(180));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Radio<bool>), findsNothing);
    await tester.tap(reading);
    await tester.pump();
    final card = tester.widget<Material>(
      find.descendant(of: reading, matching: find.byType(Material)).first,
    );
    expect(
      card.color,
      bookStatusTint(BookStatus.reading, ReadendarColors.light),
    );
  });

  testWidgets('event type filters use compact highlighted cards', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(booksOnly: false));
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    final event = find.byKey(
      Key('filter-event-${EventType.values.first.backendValue}'),
    );
    expect(event, findsOneWidget);
    expect(tester.getSize(event).width, lessThan(240));
    expect(find.byType(FilterSearchField), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Radio<bool>), findsNothing);
    expect(find.text('Contexto'), findsNothing);
    expect(find.byKey(const Key('filter-context-personal')), findsNothing);
  });
}
