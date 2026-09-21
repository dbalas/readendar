import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_confirm_screen.dart';
import 'package:readendar/features/import/import_handoff.dart';
import 'package:readendar/features/import/import_intro_screen.dart';

const _validStoryGraphCsv =
    'Title,Authors,ISBN/UID,Format,Read Status,Star Rating,Review\n"StoryGraph book","Author","9780316229296","digital","read","4.25","A review"';

Widget _wrap(Widget home) => ProviderScope(
  overrides: [
    booksProvider.overrideWith((ref) async => const <Book>[]),
  ],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('StoryGraph CSV enters the shared confirmation flow', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _HandoffHost(_validStoryGraphCsv)));

    await tester.runAsync(() async {
      await tester.tap(find.text('go'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ImportConfirmScreen), findsOneWidget);
    expect(find.text('Hemos encontrado 1 libro'), findsOneWidget);
    expect(find.text('StoryGraph book'), findsWidgets);
  });

  testWidgets('invalid StoryGraph CSV shows a source-specific error', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _HandoffHost('not StoryGraph data')));

    await tester.runAsync(() async {
      await tester.tap(find.text('go'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ImportConfirmScreen), findsNothing);
    expect(
      find.text(
        "Esto no parece una exportación CSV válida de StoryGraph.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('auto-opened StoryGraph CSV enters its parser, not Goodreads', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ImportIntroScreen.autoCsv(
          source: ImportFileSource.storygraph,
          content: _validStoryGraphCsv,
        ),
      ),
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ImportConfirmScreen), findsOneWidget);
    expect(find.text('StoryGraph book'), findsWidgets);
  });
}

class _HandoffHost extends StatelessWidget {
  const _HandoffHost(this.content);

  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => openStoryGraphImportConfirm(context, content),
          child: const Text('go'),
        ),
      ),
    );
  }
}
