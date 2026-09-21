import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/import/import_intro_screen.dart';
import 'package:readendar/features/import/import_sources_screen.dart';

Widget _wrap(Widget home, {ThemeData? theme}) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('es'),
    theme: theme ?? buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('StoryGraph source opens its CSV export flow', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ImportSourcesScreen()));

    expect(find.text('StoryGraph'), findsOneWidget);
    expect(find.text('Selecciona un CSV'), findsOneWidget);

    await tester.tap(find.text('StoryGraph'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportIntroScreen), findsOneWidget);
    expect(find.text('Importar de StoryGraph'), findsOneWidget);
    expect(find.text('Seleccionar CSV de StoryGraph'), findsOneWidget);
    expect(find.textContaining('Manage Your Data'), findsOneWidget);
  });

  testWidgets('StoryGraph export action opens the direct export page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Uri? openedUri;
    await tester.pumpWidget(
      _wrap(
        ImportIntroScreen.storygraph(
          storygraphExportLauncher: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir exportación de StoryGraph'));
    await tester.pump();

    expect(openedUri, Uri.parse(storygraphExportUrl));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('StoryGraph export action reports launch failures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        ImportIntroScreen.storygraph(
          storygraphExportLauncher: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Abrir exportación de StoryGraph'));
    await tester.pump();

    expect(
      find.text(
        "No hemos podido abrir StoryGraph. Sigue los pasos en la app de StoryGraph.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('StoryGraph intro renders in dark mode', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ImportIntroScreen.storygraph(),
        theme: buildDarkTheme(),
      ),
    );

    expect(find.text('Importar de StoryGraph'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
