import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/filters/filter_search_field.dart';
import 'package:readendar/features/filters/filters_sheet.dart';

void main() {
  testWidgets('calendar filters omit status, completion, and date controls', (
    tester,
  ) async {
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
                onPressed: () => showFiltersSheet(context, calendarOnly: true),
                child: const Text('Open filters'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-status-reading')), findsNothing);
    expect(find.text('Finalización'), findsNothing);
    expect(find.text('Fecha'), findsNothing);
    expect(find.text('Contexto'), findsNothing);
    expect(find.text('Solo personal'), findsNothing);
    expect(
      find.byKey(const Key('filter-event-deadline')),
      findsOneWidget,
    );
    expect(find.byType(FilterSearchField), findsNothing);
  });
}
