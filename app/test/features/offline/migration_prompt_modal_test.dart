import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/offline/migration_prompt_modal.dart';

void main() {
  const tallPhone = Size(390, 960);

  Future<void> tapWhenVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 48);
    await tester.tap(finder);
  }

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('shows icon, copy, and compact import CTA', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await showMigrationPromptModal(
                context,
                formattedShutdownDate: '15 oct 2026',
                onImport: (_) async => false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('migration_prompt_body')), findsOneWidget);
    expect(find.text('Descargar mis datos'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);
  });

  testWidgets('returns continued with hide flag when checkbox set', (tester) async {
    await tester.binding.setSurfaceSize(tallPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    MigrationPromptOutcome? outcome;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              outcome = await showMigrationPromptModal(
                context,
                formattedShutdownDate: '15 oct 2026',
                onImport: (_) async => false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tapWhenVisible(tester, find.text('No volver a mostrar'));
    await tester.pump();
    await tapWhenVisible(tester, find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(outcome?.result, MigrationPromptResult.continued);
    expect(outcome?.hideNextTime, isTrue);
  });

  testWidgets('returns imported when onImport succeeds', (tester) async {
    await tester.binding.setSurfaceSize(tallPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    MigrationPromptOutcome? outcome;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              outcome = await showMigrationPromptModal(
                context,
                formattedShutdownDate: '15 oct 2026',
                onImport: (_) async => true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tapWhenVisible(tester, find.text('Descargar mis datos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(outcome, isNull);
    expect(find.text('Descargar mis datos'), findsNothing);
  });
}
