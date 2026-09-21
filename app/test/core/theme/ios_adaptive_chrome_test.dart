import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/platform_chrome_theme.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/rd_create_action.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/settings_group.dart';

ThemeData _iosTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: buildLightTheme().colorScheme,
  platform: TargetPlatform.iOS,
  cupertinoOverrideTheme: buildLightTheme().cupertinoOverrideTheme,
);

ThemeData _androidTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: buildLightTheme().colorScheme,
  platform: TargetPlatform.android,
);

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  test('all platforms use the fast fade transition', () {
    final builders = readendarPageTransitionsTheme.builders;
    for (final platform in TargetPlatform.values) {
      final builder = builders[platform];
      expect(builder, isA<ReadendarPageTransitionsBuilder>());
      expect(builder?.transitionDuration, ReadendarMotion.fast);
    }
  });

  test('light and dark themes leave AppBar title centering to the platform', () {
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      expect(theme.appBarTheme.centerTitle, isNull);
      expect(theme.cupertinoOverrideTheme, isNotNull);
    }
  });

  test('ThemeData.platform drives usesCupertinoChrome', () {
    expect(_iosTheme().platform, TargetPlatform.iOS);
    expect(_androidTheme().platform, TargetPlatform.android);
  });

  testWidgets('usesCupertinoChrome is true on iOS theme', (tester) async {
    late bool cupertino;
    await tester.pumpWidget(
      MaterialApp(
        theme: _iosTheme(),
        home: Builder(
          builder: (context) {
            cupertino = usesCupertinoChrome(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(cupertino, isTrue);
  });

  testWidgets('usesCupertinoChrome is false on Android theme', (tester) async {
    late bool cupertino;
    late TargetPlatform platform;
    await tester.pumpWidget(
      MaterialApp(
        theme: _androidTheme(),
        home: Builder(
          builder: (context) {
            platform = Theme.of(context).platform;
            cupertino = usesCupertinoChrome(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(platform, TargetPlatform.android);
    expect(cupertino, isFalse);
  });

  testWidgets('showConfirmDialog uses CupertinoAlertDialog on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      bool? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: _iosTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showConfirmDialog(
                    context: context,
                    title: 'Delete book',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Eliminar',
                    destructive: true,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(captured, isTrue);
    });
  });

  test('clampRdDate keeps values inside bounds', () {
    final first = DateTime(2024);
    final last = DateTime(2026);
    expect(clampRdDate(DateTime(2020), first, last), first);
    expect(clampRdDate(DateTime(2030), first, last), last);
    expect(clampRdDate(DateTime(2025, 6), first, last), DateTime(2025, 6));
  });

  testWidgets('Cupertino date Confirm returns clamped initial without scroll', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      DateTime? picked;
      final first = DateTime(2025);
      final last = DateTime(2026);
      final outOfRange = DateTime(2020);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: _iosTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  picked = await showRdDatePicker(
                    context: context,
                    initialDate: outOfRange,
                    firstDate: first,
                    lastDate: last,
                  );
                },
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(picked, first);
    });
  });

  testWidgets('type-to-confirm stays disabled until match on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      bool? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: _iosTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showTypeToConfirmDialog(
                    context: context,
                    title: 'Deactivate',
                    message: 'Type the handle',
                    matchText: 'reader',
                    confirmLabel: 'Deactivate',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final deactivate = find.text('Deactivate').last;
      await tester.tap(deactivate);
      await tester.pumpAndSettle();
      // Still open — confirm disabled.
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(captured, isNull);

      await tester.enterText(find.byType(CupertinoTextField), 'reader');
      await tester.pump();
      await tester.tap(deactivate);
      await tester.pumpAndSettle();
      expect(captured, isTrue);
    });
  });

  testWidgets('RdSearchField uses branded glass pill on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: const Scaffold(
            body: RdSearchField(hintText: 'Buscar libros'),
          ),
        ),
      );

      expect(find.byKey(RdSearchField.iosFieldKey), findsOneWidget);
      expect(find.byType(CupertinoSearchTextField), findsNothing);
      expect(find.byType(SearchBar), findsNothing);
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
    });
  });

  testWidgets(
    'RdSearchField on iOS has no extra submit icon beside the pill',
    (tester) async {
      await _withIosPlatform(() async {
        final submitted = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: _iosTheme(),
            home: Scaffold(
              body: RdSearchField(
                hintText: 'Buscar libros',
                showSubmitButton: true,
                onSubmitted: submitted.add,
              ),
            ),
          ),
        );

        final pill = find.byKey(RdSearchField.iosFieldKey);
        expect(pill, findsOneWidget);
        expect(find.byIcon(LucideIcons.search), findsOneWidget);
        // Submit is the in-pill search glyph, not a second control beside the pill.
        expect(find.byType(CupertinoButton), findsOneWidget);
        expect(
          find.descendant(
            of: pill,
            matching: find.byType(CupertinoButton),
          ),
          findsOneWidget,
        );

        await tester.enterText(find.byType(CupertinoTextField), 'dune');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(submitted, ['dune']);
      });
    },
  );

  testWidgets('RdSwitchListTile uses adaptive Switch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: RdSwitchListTile(
            title: const Text('Notify'),
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('RdProgress is Cupertino on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: const Scaffold(body: RdProgress()),
        ),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('RdCreateAction hides FAB on iOS and shows app-bar action', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                actions: RdCreateAction.appBarActions(
                  context: context,
                  onPressed: () => taps++,
                  tooltip: 'Add',
                ),
              ),
              floatingActionButton: RdCreateAction.fab(
                context: context,
                onPressed: () => taps++,
                tooltip: 'Add',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });
  });

  testWidgets(
    'RdCreateAction pads FAB above floating root nav when requested',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _androidTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              floatingActionButton: RdCreateAction.fab(
                context: context,
                aboveFloatingNav: true,
                onPressed: () {},
                tooltip: 'Add',
              ),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(FloatingActionButton),
          matching: find.byType(Padding),
        ),
      );
      expect(
        padding.padding,
        EdgeInsets.only(bottom: RdRootNavBarMetrics.contentInset),
      );
    },
  );

  testWidgets(
    'RdCreateAction FABs on one route do not collide on pop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _androidTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: IndexedStack(
                index: 0,
                children: [
                  Scaffold(
                    floatingActionButton: RdCreateAction.fab(
                      context: context,
                      onPressed: () {},
                      tooltip: 'Añadir evento',
                    ),
                  ),
                  Scaffold(
                    floatingActionButton: RdCreateAction.fab(
                      context: context,
                      onPressed: () {},
                      tooltip: 'Añadir cita',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final fabs = find.byType(
        FloatingActionButton,
        skipOffstage: false,
      );
      expect(fabs, findsNWidgets(2));
      for (final fab in tester.widgetList<FloatingActionButton>(fabs)) {
        expect(fab.heroTag, isNull);
      }

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('pushed')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Apple chrome uses Cupertino back instead of rounded Material', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      final theme = withCupertinoSplashSuppressed(
        buildLightTheme().copyWith(platform: TargetPlatform.iOS),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Inner')),
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  test('Android chrome leaves Material action icons alone', () {
    final theme = withCupertinoSplashSuppressed(
      buildLightTheme().copyWith(platform: TargetPlatform.android),
    );
    expect(theme.actionIconTheme, isNull);
  });

  test('Apple chrome installs Cupertino action icons', () {
    final theme = withCupertinoSplashSuppressed(
      buildLightTheme().copyWith(platform: TargetPlatform.iOS),
    );
    expect(theme.actionIconTheme, isNotNull);
    expect(theme.actionIconTheme!.backButtonIconBuilder, isNotNull);
    expect(theme.actionIconTheme!.closeButtonIconBuilder, isNotNull);
  });

  testWidgets('SettingsGroup drops outer border on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: const Scaffold(
            body: SettingsGroup(
              children: [ListTile(title: Text('One'))],
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SettingsGroup),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
    });
  });
}
