import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/nav_box.dart';
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
  test('import picker declares native CSV and XLSX file types', () {
    for (final source in [
      ImportFileSource.goodreads,
      ImportFileSource.storygraph,
      ImportFileSource.babelio,
    ]) {
      final group = importFileTypeGroup(source);
      expect(group.extensions, ['csv']);
      expect(group.mimeTypes, contains('text/csv'));
      expect(
        group.uniformTypeIdentifiers,
        contains('public.comma-separated-values-text'),
      );
    }

    final xlsx = importFileTypeGroup(ImportFileSource.bookmory);
    expect(xlsx.extensions, ['xlsx']);
    expect(
      xlsx.mimeTypes,
      equals([
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ]),
    );
    expect(xlsx.mimeTypes, isNot(contains('text/csv')));
    expect(xlsx.mimeTypes, isNot(contains('application/vnd.ms-excel')));
    expect(xlsx.mimeTypes, isNot(contains('application/octet-stream')));
    expect(
      xlsx.uniformTypeIdentifiers,
      contains('org.openxmlformats.spreadsheetml.sheet'),
    );
  });

  testWidgets('each import source uses its own platform tint', (tester) async {
    await tester.pumpWidget(_wrap(const ImportSourcesScreen()));

    List<(Color?, Color?)> sourceTints() => tester
        .widgetList<NavBox>(find.byType(NavBox))
        .map((box) => (box.tintBg, box.tintFg))
        .toList();

    final lightTints = sourceTints();
    expect(lightTints, hasLength(4));
    expect(
      lightTints.expand((tint) => [tint.$1, tint.$2]),
      everyElement(isNotNull),
    );
    expect(lightTints.toSet(), hasLength(4));
    expect(lightTints, [
      (
        ReadendarColors.light.warningSoftBg,
        ReadendarColors.light.warningSoftFg,
      ),
      (ReadendarColors.light.surface2, ReadendarColors.light.fg1),
      (ReadendarColors.light.accentSoftBg, ReadendarColors.light.accentSoftFg),
      (
        ReadendarColors.light.highlightSoft,
        ReadendarColors.light.warningSoftFg,
      ),
    ]);

    await tester.pumpWidget(
      _wrap(const ImportSourcesScreen(), theme: buildDarkTheme()),
    );
    await tester.pumpAndSettle();

    final darkTints = sourceTints();
    expect(darkTints.toSet(), hasLength(4));
    expect(darkTints, [
      (
        ReadendarColors.dark.warningSoftBg,
        ReadendarColors.dark.warningSoftFg,
      ),
      (ReadendarColors.dark.surface2, ReadendarColors.dark.fg1),
      (ReadendarColors.dark.accentSoftBg, ReadendarColors.dark.accentSoftFg),
      (
        ReadendarColors.dark.highlightSoft,
        ReadendarColors.dark.warningSoftFg,
      ),
    ]);
  });

  testWidgets('hub lists all working sources and keeps Goodreads flow', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ImportSourcesScreen()));

    expect(find.text('Importar datos'), findsOneWidget);
    expect(find.text('Goodreads'), findsOneWidget);
    expect(find.text('Bookmory'), findsOneWidget);
    expect(find.text('Babelio'), findsOneWidget);
    expect(find.text('StoryGraph'), findsOneWidget);
    expect(find.text('Selecciona el CSV exportado'), findsOneWidget);
    expect(
      find.text('Exporta tu biblioteca y selecciona el CSV'),
      findsOneWidget,
    );

    await tester.tap(find.text('Goodreads'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportIntroScreen), findsOneWidget);
  });

  testWidgets('Bookmory uses shared file intro with two localized steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const ImportIntroScreen.bookmory()),
    );

    expect(find.text('Importar de Bookmory'), findsOneWidget);
    expect(find.text('Seleccionar archivo Excel'), findsOneWidget);
    expect(find.textContaining('Mi página → Exportar'), findsOneWidget);
    expect(find.textContaining('Pulsa Exportar'), findsOneWidget);
    expect(find.textContaining('Goodreads → My Books'), findsNothing);
  });

  testWidgets('Bookmory opens instructions before the file picker', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ImportSourcesScreen()));
    await tester.tap(find.text('Bookmory'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportIntroScreen), findsOneWidget);
    expect(find.text('Seleccionar archivo Excel'), findsOneWidget);
    expect(find.textContaining('Mi página → Exportar'), findsOneWidget);
  });

  testWidgets('StoryGraph opens export instructions before the file picker', (
    tester,
  ) async {
    Uri? openedUri;
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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

    expect(find.text('Importar de StoryGraph'), findsOneWidget);
    expect(find.text('Seleccionar CSV de StoryGraph'), findsOneWidget);
    expect(
      find.text(
        'En la app de StoryGraph, abre Perfil, toca el menú de arriba a la derecha (☰) y elige Manage Account.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'En Manage Your Data, toca Export StoryGraph Library y Generate Export. Cuando StoryGraph te envíe un correo, descarga el CSV y selecciónalo aquí.',
      ),
      findsOneWidget,
    );

    final openExport = find.text('Abrir exportación de StoryGraph');
    await tester.ensureVisible(openExport);
    await tester.tap(openExport);
    await tester.pump();

    expect(openedUri, Uri.parse(storygraphExportUrl));
  });

  testWidgets('StoryGraph reports when its export page cannot open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        ImportIntroScreen.storygraph(
          storygraphExportLauncher: (_) async => false,
        ),
      ),
    );

    final openExport = find.text('Abrir exportación de StoryGraph');
    await tester.ensureVisible(openExport);
    await tester.tap(openExport);
    await tester.pump();

    expect(
      find.text(
        'No hemos podido abrir StoryGraph. Sigue los pasos en la app de StoryGraph.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Babelio opens CSV instructions before the file picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ImportSourcesScreen()));
    await tester.tap(find.text('Babelio'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportIntroScreen), findsOneWidget);
    expect(find.text('Importar de Babelio'), findsOneWidget);
    expect(find.text('Abrir exportación de Babelio'), findsOneWidget);
    expect(find.text('Seleccionar CSV de Babelio'), findsOneWidget);
    expect(find.textContaining('inicia sesión si te lo pide'), findsOneWidget);
    expect(find.textContaining('primer botón'), findsOneWidget);
  });

  testWidgets('Babelio opens the direct export page', (tester) async {
    Uri? openedUri;
    await tester.pumpWidget(
      _wrap(
        ImportIntroScreen.babelio(
          babelioExportLauncher: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir exportación de Babelio'));
    await tester.pump();

    expect(openedUri, Uri.parse(babelioExportUrl));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Babelio reports when the export page cannot open', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ImportIntroScreen.babelio(
          babelioExportLauncher: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Abrir exportación de Babelio'));
    await tester.pump();

    expect(
      find.text("No hemos podido abrir Babelio. Prueba a exportar desde el navegador."),
      findsOneWidget,
    );
  });

  testWidgets('hub and source intros render in dark mode', (tester) async {
    await tester.pumpWidget(
      _wrap(const ImportSourcesScreen(), theme: buildDarkTheme()),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrap(
        const ImportIntroScreen.bookmory(),
        theme: buildDarkTheme(),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrap(
        const ImportIntroScreen.storygraph(),
        theme: buildDarkTheme(),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrap(
        const ImportIntroScreen.babelio(),
        theme: buildDarkTheme(),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
