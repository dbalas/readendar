import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/option_selector.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

Future<void> _openHourSheet(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);

  final light = buildLightTheme();
  await tester.pumpWidget(
    MaterialApp(
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
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final l = AppL10n.of(context);
            return TextButton(
              onPressed: () => showOptionSelectorSheet<int>(
                context: context,
                label: l.quoteDailyHourLabel,
                value: 9,
                items: List.generate(
                  24,
                  (h) => OptionSelectorItem<int>(
                    value: h,
                    label: '${h.toString().padLeft(2, '0')}:00',
                  ),
                ),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'shows option descriptions in the field and sheet in ${brightness.name}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(
              body: OptionSelector<String>(
                label: 'Results',
                value: 'members',
                items: const [
                  OptionSelectorItem(
                    value: 'members',
                    label: 'Members only',
                    description: 'People outside the group cannot see results.',
                  ),
                  OptionSelectorItem(
                    value: 'public',
                    label: 'Public',
                    description: 'Anyone can see results.',
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(
          find.text('People outside the group cannot see results.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Members only'));
        await tester.pumpAndSettle();

        expect(
          find.text('People outside the group cannot see results.'),
          findsNWidgets(2),
        );
        expect(find.text('Anyone can see results.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'quote-of-the-day hour sheet header stays below the status bar ($platform)',
      (tester) async {
        await _openHourSheet(tester, platform: platform);
        expect(tester.takeException(), isNull);

        final header = find.text('Hora de la cita del día');
        expect(header, findsOneWidget);
        expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(59));

        final firstHour = find.text('00:00');
        expect(firstHour, findsOneWidget);
        expect(tester.getTopLeft(firstHour).dy, greaterThanOrEqualTo(59));
        expect(
          tester
              .getRect(firstHour)
              .overlaps(
                const Rect.fromLTWH(0, 0, 390, 59),
              ),
          isFalse,
        );
      },
    );
  }

  testWidgets(
    'short iOS option picker uses glass modal sheet, not an action sheet',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        Object? picked;
        final light = buildLightTheme();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: light.colorScheme,
              platform: TargetPlatform.iOS,
              cupertinoOverrideTheme: light.cupertinoOverrideTheme,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppL10n.of(context);
                  return TextButton(
                    onPressed: () async {
                      picked = await showOptionSelectorSheet<ThemeMode>(
                        context: context,
                        label: l.profileAppearance,
                        value: ThemeMode.dark,
                        items: [
                          OptionSelectorItem(
                            value: ThemeMode.light,
                            label: l.appearanceLight,
                            icon: LucideIcons.sun,
                          ),
                          OptionSelectorItem(
                            value: ThemeMode.dark,
                            label: l.appearanceDark,
                            icon: LucideIcons.moon,
                          ),
                          OptionSelectorItem(
                            value: ThemeMode.system,
                            label: l.appearanceSystem,
                            icon: LucideIcons.monitor,
                          ),
                        ],
                      );
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(RdGlassPanel), findsWidgets);
        expect(find.byType(CupertinoActionSheet), findsNothing);
        expect(find.text('Cancelar'), findsNothing);
        expect(find.byType(RdCard), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(find.text('Apariencia'), findsOneWidget);
        expect(find.text('Claro'), findsOneWidget);
        expect(find.text('Oscuro'), findsOneWidget);
        expect(find.text('Sistema'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(LucideIcons.sun)).color,
          tester.element(find.byIcon(LucideIcons.sun)).colors.accent,
        );
        expect(
          tester.widget<Icon>(find.byIcon(LucideIcons.moon)).color,
          tester.element(find.byIcon(LucideIcons.moon)).colors.accent,
        );

        await tester.tap(find.text('Sistema'));
        await tester.pumpAndSettle();
        expect(picked, ThemeMode.system);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
